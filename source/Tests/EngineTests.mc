//
//  EngineTests.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;
import Toybox.Test;

// Toybox.Test requires (:test) annotations and Logger-taking function signatures.
// Tests are compiled only when monkeyc is invoked with -t / --unit-test.
module EngineTests {

    function makeTinyTemplate() as Dictionary {
        // 3-segment template: Run → Station → Run
        var segs = [
            WorkoutSegment.run(1000),
            WorkoutSegment.station(StationKind.SKI_ERG, StationTarget.distance(1000), null, null),
            WorkoutSegment.run(1000)
        ];
        return WorkoutTemplate.make("Tiny", HyroxDivision.MEN_OPEN_SINGLE, segs, false, false);
    }

    (:test)
    function testStartAdvanceFinish(logger as Logger) as Boolean {
        var eng = new WorkoutEngine(makeTinyTemplate());
        Test.assertEqual(EngineState.label(eng.state), "idle");

        eng.start(1000l);
        Test.assertEqual(EngineState.label(eng.state), "running");
        Test.assertEqual(eng.currentSegmentIndex(), 0);

        eng.advance(6000l);
        Test.assertEqual(eng.records.size(), 1);
        Test.assertEqual(eng.currentSegmentIndex(), 1);

        eng.advance(11000l);
        Test.assertEqual(eng.records.size(), 2);
        Test.assertEqual(eng.currentSegmentIndex(), 2);

        eng.advance(16000l);
        Test.assert(eng.isFinished());
        Test.assertEqual(eng.records.size(), 3);

        // Total elapsed = 16000 - 1000 = 15000 ms
        Test.assertEqual(eng.totalElapsedMs(99999l), 15000l);
        return true;
    }

    (:test)
    function testPauseResumeExcludesPausedTime(logger as Logger) as Boolean {
        var eng = new WorkoutEngine(makeTinyTemplate());
        eng.start(0l);

        // Run active 3s.
        eng.pause(3000l);
        Test.assertEqual(EngineState.label(eng.state), "paused");
        Test.assertEqual(eng.segmentElapsedMs(99999l), 3000l);
        Test.assertEqual(eng.totalElapsedMs(99999l), 3000l);

        // Pause 5s. Resume at t=8000.
        eng.resume(8000l);
        Test.assertEqual(EngineState.label(eng.state), "running");

        // Active time should NOT include the pause window.
        // segmentElapsed at t=10000 should equal 3000 + (10000-8000) = 5000.
        Test.assertEqual(eng.segmentElapsedMs(10000l), 5000l);
        Test.assertEqual(eng.totalElapsedMs(10000l), 5000l);
        return true;
    }

    (:test)
    function testInvalidTransitionsThrow(logger as Logger) as Boolean {
        var eng = new WorkoutEngine(makeTinyTemplate());
        var threw = false;
        try {
            eng.advance(0l);
        } catch (e instanceof EngineError) {
            threw = e.reason.equals(EngineError.REASON_INVALID_TRANSITION);
        }
        Test.assert(threw);

        eng.start(0l);
        var threwPauseOnRunningOK = false;
        try {
            eng.resume(100l);
        } catch (e instanceof EngineError) {
            threwPauseOnRunningOK = true;
        }
        Test.assert(threwPauseOnRunningOK);
        return true;
    }

    (:test)
    function testUndoRestoresPreviousIndex(logger as Logger) as Boolean {
        var eng = new WorkoutEngine(makeTinyTemplate());
        eng.start(0l);
        eng.advance(1000l);
        Test.assertEqual(eng.currentSegmentIndex(), 1);

        eng.undo(2000l);
        Test.assertEqual(eng.currentSegmentIndex(), 0);
        Test.assertEqual(eng.records.size(), 0);
        Test.assertEqual(EngineState.label(eng.state), "running");
        return true;
    }

    (:test)
    function testFinishFromPausedUsesActiveTime(logger as Logger) as Boolean {
        var eng = new WorkoutEngine(makeTinyTemplate());
        eng.start(0l);
        eng.pause(5000l);
        // 5s active + 2s paused, then finish. Duration should reflect active only.
        eng.finish(7000l);
        Test.assert(eng.isFinished());
        Test.assertEqual(eng.records.size(), 1);
        var rec = eng.records[0] as Dictionary;
        Test.assertEqual(SegmentRecord.activeDurationMs(rec), 5000l);
        return true;
    }

    (:test)
    function testHyroxPresetProduces31Segments(logger as Logger) as Boolean {
        var t = WorkoutTemplate.hyroxPreset(HyroxDivision.MEN_OPEN_SINGLE);
        var segs = t[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        // 8 runs + 8 stations + 15 RoxZones = 31.
        Test.assertEqual(segs.size(), 31);

        var runs = 0;
        var stations = 0;
        var rox = 0;
        for (var i = 0; i < segs.size(); i += 1) {
            var ty = (segs[i] as Dictionary)[WorkoutSegment.TYPE] as String;
            if (ty.equals(SegmentType.RUN)) { runs += 1; }
            else if (ty.equals(SegmentType.STATION)) { stations += 1; }
            else if (ty.equals(SegmentType.ROX_ZONE)) { rox += 1; }
        }
        Test.assertEqual(runs, 8);
        Test.assertEqual(stations, 8);
        Test.assertEqual(rox, 15);

        // First segment is Run, last is Station (no trailing RoxZone).
        Test.assertEqual((segs[0] as Dictionary)[WorkoutSegment.TYPE] as String, SegmentType.RUN);
        Test.assertEqual((segs[30] as Dictionary)[WorkoutSegment.TYPE] as String, SegmentType.STATION);
        return true;
    }

    (:test)
    function testDivisionSpecWeights(logger as Logger) as Boolean {
        var mensPro = HyroxDivisionSpec.stationsFor(HyroxDivision.MEN_PRO_SINGLE);
        // Men's Pro Sled Push = 202 kg.
        var sledPush = mensPro[1] as Dictionary;
        Test.assertEqual(sledPush[HyroxDivisionSpec.WEIGHT_KG] as Number, 202);
        // Women's Open Wall Balls = 75 reps × 4kg.
        var womensOpen = HyroxDivisionSpec.stationsFor(HyroxDivision.WOMEN_OPEN_SINGLE);
        var wb = womensOpen[7] as Dictionary;
        Test.assertEqual(wb[HyroxDivisionSpec.WEIGHT_KG] as Number, 4);
        var target = wb[HyroxDivisionSpec.TARGET] as Dictionary;
        Test.assertEqual(target[StationTarget.COUNT] as Number, 75);
        return true;
    }
}
