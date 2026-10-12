//
//  OutboxTests.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 10/12/26.
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Covers the path a finished workout takes to the phone: encode → split
// into parts → per-part storage → ack cleanup. Runs a full-length race so
// the memory headroom at the worst moment (encode at finish) is visible.
module OutboxTests {

    // 31 segments, 3 min each (93 min), one HR reading per second.
    function runFullRace() as WorkoutEngine {
        var template = WorkoutTemplate.hyroxPreset(HyroxDivision.MEN_OPEN_SINGLE);
        var eng = new WorkoutEngine(template);
        var t = 1000000000000l;
        eng.start(t);
        for (var s = 0; s < 31; s += 1) {
            for (var sec = 0; sec < 180; sec += 1) {
                t += 1000l;
                eng.ingestHeartRate(t, 150 + (sec % 20));
                eng.ingestLocation(t, 37.5d, 127.0d, 30.0d, null, 3.0d);
            }
            eng.advance(t);
        }
        return eng;
    }

    (:test)
    function testFullRaceSplitsIntoBoundedParts(logger as Logger) as Boolean {
        var before = System.getSystemStats().usedMemory;
        var eng = runFullRace();
        Test.assert(eng.isFinished());
        var afterRace = System.getSystemStats().usedMemory;

        var payload = CompletedWorkoutCodec.encode(eng, "garmin");
        var parts = CompletedWorkoutCodec.split(payload);
        var stats = System.getSystemStats();
        logger.debug("memory used: start=" + before + " afterRace=" + afterRace
            + " afterEncode=" + stats.usedMemory + " free=" + stats.freeMemory
            + " total=" + stats.totalMemory + " parts=" + parts.size());

        Test.assert(parts.size() > 1);
        var total = 0;
        for (var p = 0; p < parts.size(); p += 1) {
            var segs = (parts[p] as Dictionary)["segments"] as Array<Dictionary>;
            Test.assert(segs.size() > 0);
            var cost = 0;
            for (var i = 0; i < segs.size(); i += 1) {
                var hr = (segs[i] as Dictionary)["heartRateSamples"] as Array;
                Test.assert(hr.size() <= CompletedWorkoutCodec.kMaxHrSamplesPerSegment);
                // Segments stay in race order across parts.
                Test.assertEqual((segs[i] as Dictionary)["index"] as Number, total + i);
                cost += CompletedWorkoutCodec.kSegmentBaseBytes
                      + CompletedWorkoutCodec.kHrSampleBytes * hr.size();
            }
            // A part may exceed the budget only when it is a single segment.
            Test.assert(cost <= CompletedWorkoutCodec.kPartBudgetBytes || segs.size() == 1);
            total += segs.size();
        }
        Test.assertEqual(total, 31);
        // Only part 0 carries the header.
        Test.assert((parts[0] as Dictionary)["id"] != null);
        Test.assert((parts[1] as Dictionary)["id"] == null);
        // At least half the heap must still be free at the worst point.
        Test.assert(stats.freeMemory > stats.totalMemory / 2);
        return true;
    }

    (:test)
    function testLongSegmentHeartRateIsCapped(logger as Logger) as Boolean {
        // One 2-hour segment: far more readings than a part can hold.
        var segs = [WorkoutSegment.run(20000)];
        var eng = new WorkoutEngine(
            WorkoutTemplate.make("Long", HyroxDivision.MEN_OPEN_SINGLE, segs, false, false));
        var t = 1000000000000l;
        eng.start(t);
        for (var sec = 0; sec < 7200; sec += 1) {
            t += 1000l;
            eng.ingestHeartRate(t, 140);
        }
        eng.advance(t);
        var payload = CompletedWorkoutCodec.encode(eng, "garmin");
        var hr = ((payload["segments"] as Array<Dictionary>)[0] as Dictionary)["heartRateSamples"] as Array;
        logger.debug("long segment hr samples=" + hr.size());
        Test.assert(hr.size() > 0);
        Test.assert(hr.size() <= CompletedWorkoutCodec.kMaxHrSamplesPerSegment);
        return true;
    }

    (:test)
    function testOutboxStoresPartsAndCleansUpOnAck(logger as Logger) as Boolean {
        Application.Storage.clearValues();
        var payload = CompletedWorkoutCodec.encode(runFullRace(), "garmin");
        var id = payload["id"] as String;
        Test.assertEqual(id.length(), 36);

        WorkoutStorage.enqueue(payload);
        var index = WorkoutStorage.list();
        Test.assertEqual(index.size(), 1);
        var entry = index[0] as Dictionary;
        var n = entry["n"] as Number;
        Test.assert(n > 1);
        Test.assertEqual(WorkoutStorage.pendingCount(), 1);
        for (var p = 0; p < n; p += 1) {
            Test.assert(WorkoutStorage.loadPart(id, p) != null);
        }

        WorkoutStorage.markSynced(id);
        Test.assertEqual(WorkoutStorage.pendingCount(), 0);
        for (var p = 0; p < n; p += 1) {
            Test.assert(WorkoutStorage.loadPart(id, p) == null);
        }
        Application.Storage.clearValues();
        return true;
    }

    (:test)
    function testOutboxKeepsNewestWhenFull(logger as Logger) as Boolean {
        Application.Storage.clearValues();
        var eng = runFullRace();
        var lastId = "";
        for (var k = 0; k < WorkoutStorage.kMaxRecords + 2; k += 1) {
            var payload = CompletedWorkoutCodec.encode(eng, "garmin");
            lastId = payload["id"] as String;
            WorkoutStorage.enqueue(payload);
        }
        var index = WorkoutStorage.list();
        Test.assertEqual(index.size(), WorkoutStorage.kMaxRecords);
        Test.assertEqual(
            (index[index.size() - 1] as Dictionary)["id"] as String, lastId);
        Test.assert(WorkoutStorage.loadPart(lastId, 0) != null);
        Application.Storage.clearValues();
        return true;
    }

    (:test)
    function testLegacyOutboxIsMigratedWithUuid(logger as Logger) as Boolean {
        Application.Storage.clearValues();
        var payload = CompletedWorkoutCodec.encode(runFullRace(), "garmin");
        payload["id"] = "1234-legacy";   // pre-2.0 ids were not UUIDs
        Application.Storage.setValue(WorkoutStorage.LEGACY_KEY, [{
            "id" => "1234-legacy",
            "payload" => { "id" => "1234-legacy", "templateName" => "T", "division" => null,
                           "startedAtMs" => 1l, "finishedAtMs" => 2l, "source" => "garmin",
                           "segments" => [] },
            "synced" => false,
            "addedMs" => 1l
        }]);
        var index = WorkoutStorage.list();
        Test.assertEqual(index.size(), 1);
        var id = (index[0] as Dictionary)["id"] as String;
        Test.assertEqual(id.length(), 36);
        Test.assert(Application.Storage.getValue(WorkoutStorage.LEGACY_KEY) == null);
        var part = WorkoutStorage.loadPart(id, 0) as Dictionary;
        Test.assertEqual(part["id"] as String, id);
        Application.Storage.clearValues();
        return true;
    }

    (:test)
    function testClockAdvancesInMilliseconds(logger as Logger) as Boolean {
        var a = Clock.nowMs();
        var spin = 0;
        var b = a;
        // Busy-wait until the clock moves; with a 1 s clock this would
        // jump by 1000, with the timer-backed one by a few ms.
        while (b == a && spin < 2000000) { b = Clock.nowMs(); spin += 1; }
        logger.debug("clock step ms=" + (b - a));
        Test.assert(b > a);
        Test.assert((b - a) < 500l);
        return true;
    }
}
