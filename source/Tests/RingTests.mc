//
//  RingTests.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 10/12/26.
//

import Toybox.Lang;
import Toybox.Test;

// Progress-ring logic and the 2.0 formatters.
module RingTests {

    function preset() as Dictionary {
        return WorkoutTemplate.hyroxPreset(HyroxDivision.MEN_OPEN_SINGLE);
    }

    function fill(count as Number, value as Long) as Array<Long> {
        var out = new Array<Long>[count];
        for (var i = 0; i < count; i += 1) { out[i] = value; }
        return out;
    }

    // 31 segments → 16 blocks; each ROX zone joins the run next to it.
    (:test)
    function testPresetMapsTo16Blocks(logger as Logger) as Boolean {
        var segs = preset()[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var map = RingModel.blockMap(segs);
        Test.assertEqual(map.size(), 31);
        Test.assertEqual(RingModel.blockCount(map), 16);
        Test.assertEqual(map[0], 0);    // run 1
        Test.assertEqual(map[1], 0);    // ROX in  → run 1
        Test.assertEqual(map[2], 1);    // station 1
        Test.assertEqual(map[3], 2);    // ROX out → run 2
        Test.assertEqual(map[4], 2);    // run 2
        Test.assertEqual(map[5], 2);    // ROX in  → run 2
        Test.assertEqual(map[6], 3);    // station 2
        Test.assertEqual(map[29], 14);  // last ROX in → run 8
        Test.assertEqual(map[30], 15);  // station 8
        return true;
    }

    (:test)
    function testNoRoxTemplateIsOneBlockPerSegment(logger as Logger) as Boolean {
        var segs = WorkoutTemplate.logicalSegments(preset());
        var map = RingModel.blockMap(segs);
        Test.assertEqual(RingModel.blockCount(map), 16);
        for (var i = 0; i < 16; i += 1) { Test.assertEqual(map[i], i); }
        Test.assertEqual(RingModel.blockCount(RingModel.blockMap([] as Array<Dictionary>)), 0);
        return true;
    }

    // ROX zones with no run beside them still land on a neighbour.
    (:test)
    function testRoxWithoutRunNeighbour(logger as Logger) as Boolean {
        var segs = [
            WorkoutSegment.roxZone(),
            WorkoutSegment.station(StationKind.SKI_ERG, null, null, null),
            WorkoutSegment.roxZone(),
            WorkoutSegment.station(StationKind.ROWING, null, null, null),
            WorkoutSegment.roxZone()
        ] as Array<Dictionary>;
        var map = RingModel.blockMap(segs);
        Test.assertEqual(RingModel.blockCount(map), 2);
        Test.assertEqual(map[0], 0);
        Test.assertEqual(map[2], 1);
        Test.assertEqual(map[4], 1);
        return true;
    }

    (:test)
    function testBlockStates(logger as Logger) as Boolean {
        var segs = preset()[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var map = RingModel.blockMap(segs);
        var targets = fill(31, 100000l);
        // Seven segments done, the eighth (index 7, ROX out → run 3) running.
        var done = fill(7, 90000l);
        done[2] = 130000l;                  // station 1 over its goal
        done[4] = 150000l;                  // run 2 slow, but its two ROX
        done[3] = 60000l;                   //   zones were quick enough:
        done[5] = 60000l;                   //   270 s against 300 s
        var states = RingModel.blockStates(map, done, targets, 7);
        Test.assertEqual(states.size(), 16);
        Test.assertEqual(states[0], RingModel.AHEAD);
        Test.assertEqual(states[1], RingModel.BEHIND);
        Test.assertEqual(states[2], RingModel.AHEAD);
        Test.assertEqual(states[3], RingModel.AHEAD);
        Test.assertEqual(states[4], RingModel.CURRENT);
        Test.assertEqual(states[5], RingModel.UPCOMING);
        Test.assertEqual(states[15], RingModel.UPCOMING);

        // Finished: no current block; without goals nothing is "behind".
        var all = RingModel.blockStates(map, fill(31, 999000l), null, null);
        for (var i = 0; i < 16; i += 1) { Test.assertEqual(all[i], RingModel.AHEAD); }
        // Goals stored as plain Numbers (phone JSON) work too.
        var mixed = RingModel.blockStates(map, fill(31, 200l), [100, 500] as Array, null);
        Test.assertEqual(mixed[0], RingModel.AHEAD);   // 400 vs 600
        return true;
    }

    (:test)
    function testWorstStationAndFinishDelta(logger as Logger) as Boolean {
        var eng = new WorkoutEngine(preset());
        var t = 0l;
        eng.start(t);
        for (var i = 0; i < 31; i += 1) {
            t += (i == 14) ? 300000l : 100000l;     // Burpees take 5:00
            eng.advance(t);
        }
        var targets = fill(31, 120000l);
        Test.assertEqual(RingModel.worstStation(eng.records as Array, targets), 14);
        Test.assertEqual(RingModel.worstStation(eng.records as Array, null), -1);
        Test.assertEqual(RingModel.durations(eng.records as Array)[14], 300000l);

        // Full race: against the goal total. Cut short: against what was done.
        Test.assertEqual(RingModel.finishDeltaMs(3300000l, 31, 31, targets, 3600000l), -300000l);
        Test.assertEqual(RingModel.finishDeltaMs(500000l, 4, 31, targets, 3600000l), 20000l);
        return true;
    }

    (:test)
    function testClockAndDeltaFormat(logger as Logger) as Boolean {
        Test.assertEqual(Styles.formatClock(252000l), "4:12");
        Test.assertEqual(Styles.formatClock(5000l), "0:05");
        Test.assertEqual(Styles.formatClock(754999l), "12:34");
        Test.assertEqual(Styles.formatClock(4472000l), "1:14:32");
        Test.assertEqual(Styles.formatDelta(-12000l), "-0:12");
        Test.assertEqual(Styles.formatDelta(21000l), "+0:21");
        Test.assertEqual(Styles.formatDelta(0l), "-0:00");
        Test.assertEqual(Styles.colorForDelta(0l), Palette.GOLD);
        Test.assertEqual(Styles.colorForDelta(1l), Palette.ORANGE);
        return true;
    }

    (:test)
    function testLabels(logger as Logger) as Boolean {
        Test.assertEqual(HyroxDivision.categoryLabel(HyroxDivision.WOMEN_PRO_DOUBLE), "WOMEN PRO");
        Test.assertEqual(HyroxDivision.formatLabel(HyroxDivision.WOMEN_PRO_DOUBLE), "DOUBLES");
        Test.assertEqual(HyroxDivision.formatLabel(HyroxDivision.MEN_OPEN_SINGLE), "SINGLES");
        Test.assertEqual(StationKind.shortName(StationKind.BURPEE_BROAD_JUMPS), "BURPEE BJ");
        Test.assert(Ui.isPlain("SLED PUSH 50 M · 152 KG"));
        Test.assert(!Ui.isPlain("Sled day"));
        Test.assert(!Ui.isPlain("주말"));
        return true;
    }
}
