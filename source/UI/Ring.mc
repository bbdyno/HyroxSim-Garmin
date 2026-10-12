//
//  Ring.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 10/12/26.
//

import Toybox.Graphics;
import Toybox.Lang;

// Progress ring logic — pure, no drawing, unit-tested in RingTests.
//
// The ring has one block per run and per station, in race order (16 for a
// HYROX preset). A ROX zone is not a block of its own: it is folded into the
// run next to it, so "run 2" covers station exit → 1 km → station entry.
module RingModel {
    const UPCOMING = 0;   // not reached yet
    const CURRENT  = 1;   // in progress
    const AHEAD    = 2;   // done, on or under its goal
    const BEHIND   = 3;   // done, over its goal

    // Block index for every segment of a template.
    function blockMap(segments as Array<Dictionary>) as Array<Number> {
        var n = segments.size();
        var map = new Array<Number>[n];
        var block = -1;            // last block handed out
        var prevIsRun = false;     // type of that block
        for (var i = 0; i < n; i += 1) {
            var type = (segments[i] as Dictionary)[WorkoutSegment.TYPE] as String;
            if (!type.equals(SegmentType.ROX_ZONE)) {
                block += 1;
                map[i] = block;
                prevIsRun = type.equals(SegmentType.RUN);
                continue;
            }
            // ROX zone: find what comes after it.
            var nextType = null;
            for (var j = i + 1; j < n; j += 1) {
                var t = (segments[j] as Dictionary)[WorkoutSegment.TYPE] as String;
                if (!t.equals(SegmentType.ROX_ZONE)) {
                    nextType = t;
                    break;
                }
            }
            if (nextType != null && (nextType as String).equals(SegmentType.RUN)) {
                map[i] = block + 1;                 // walking out to the next run
            } else if (block >= 0 && prevIsRun) {
                map[i] = block;                     // walking in from the last run
            } else if (nextType != null) {
                map[i] = block + 1;                 // no run on either side
            } else {
                map[i] = block >= 0 ? block : 0;
            }
        }
        return map;
    }

    function blockCount(map as Array<Number>) as Number {
        var n = map.size();
        return n == 0 ? 0 : map[n - 1] + 1;
    }

    // State of every block.
    //   durationsMs  — active time of each finished segment, in order
    //   targetsMs    — goal per segment (may be null / shorter)
    //   currentIndex — segment in progress, null when idle or finished
    function blockStates(
            map as Array<Number>,
            durationsMs as Array<Long>,
            targetsMs as Array?,
            currentIndex as Number?) as Array<Number> {
        var count = blockCount(map);
        var states = new Array<Number>[count];
        var actual = new Array<Long>[count];
        var target = new Array<Long>[count];
        for (var b = 0; b < count; b += 1) {
            states[b] = UPCOMING;
            actual[b] = 0l;
            target[b] = -1l;       // -1 = no goal known for this block
        }
        var done = durationsMs.size();
        if (done > map.size()) { done = map.size(); }
        for (var i = 0; i < done; i += 1) {
            var blk = map[i];
            states[blk] = AHEAD;
            actual[blk] = actual[blk] + durationsMs[i];
            if (targetsMs != null && i < targetsMs.size() && targetsMs[i] != null) {
                var t = (targetsMs[i] as Number or Long).toLong();
                target[blk] = (target[blk] < 0l ? 0l : target[blk]) + t;
            }
        }
        for (var b = 0; b < count; b += 1) {
            if (states[b] == AHEAD && target[b] >= 0l && actual[b] > target[b]) {
                states[b] = BEHIND;
            }
        }
        if (currentIndex != null && currentIndex >= 0 && currentIndex < map.size()) {
            states[map[currentIndex]] = CURRENT;
        }
        return states;
    }

    // Active duration of every recorded segment.
    function durations(records as Array) as Array<Long> {
        var out = new Array<Long>[records.size()];
        for (var i = 0; i < records.size(); i += 1) {
            out[i] = SegmentRecord.activeDurationMs(records[i] as Dictionary);
        }
        return out;
    }

    // Index of the station record that lost the most time against its goal
    // (or gained the least). -1 when no station has a goal to compare with.
    function worstStation(records as Array, targetsMs as Array?) as Number {
        var worst = -1;
        var worstDelta = 0l;
        if (targetsMs == null) { return worst; }
        for (var i = 0; i < records.size() && i < targetsMs.size(); i += 1) {
            var rec = records[i] as Dictionary;
            if (!(rec[SegmentRecord.TYPE] as String).equals(SegmentType.STATION)) { continue; }
            if (targetsMs[i] == null) { continue; }
            var delta = SegmentRecord.activeDurationMs(rec)
                - (targetsMs[i] as Number or Long).toLong();
            if (worst < 0 || delta > worstDelta) {
                worst = i;
                worstDelta = delta;
            }
        }
        return worst;
    }

    // Finish delta. A completed workout is judged against the goal total;
    // one that was ended early only against the goals of what was done.
    function finishDeltaMs(
            totalMs as Long,
            recordCount as Number,
            segmentCount as Number,
            targetsMs as Array?,
            targetTotalMs as Long) as Long {
        if (recordCount >= segmentCount || targetsMs == null) {
            return totalMs - targetTotalMs;
        }
        var sum = 0l;
        for (var i = 0; i < recordCount && i < targetsMs.size(); i += 1) {
            if (targetsMs[i] != null) {
                sum += (targetsMs[i] as Number or Long).toLong();
            }
        }
        return totalMs - sum;
    }
}

// Draws the segmented ring on the outer edge of a round display.
module Ring {
    function colorFor(state as Number) as Number {
        if (state == RingModel.CURRENT) { return Styles.COLOR_TEXT; }
        if (state == RingModel.AHEAD)   { return Palette.GOLD; }
        if (state == RingModel.BEHIND)  { return Palette.ORANGE; }
        return Palette.UPCOMING;
    }

    // `states` — one RingModel state per block; `solid` (optional colour)
    // paints every block the same and ignores the states.
    function draw(dc as Graphics.Dc, states as Array<Number>?, count as Number, solid as Number?) as Void {
        if (count <= 0) { return; }
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var pen = Ui.px(dc, 7);
        var radius = Ui.px(dc, 93);
        var step = 360.0 / count;
        // ~3° between blocks; long custom workouts get a tighter gap.
        var gap = 3.0;
        if (step < 9.0) { gap = step / 3.0; }
        dc.setPenWidth(pen);
        for (var i = 0; i < count; i += 1) {
            var color = solid != null ? solid : colorFor((states as Array<Number>)[i]);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            // Clockwise from 12 o'clock; Connect IQ angles run counter-
            // clockwise from 3 o'clock.
            var a0 = 90.0 - i * step - gap / 2;
            var a1 = 90.0 - (i + 1) * step + gap / 2;
            if (a0 < 0.0) { a0 += 360.0; }
            if (a1 < 0.0) { a1 += 360.0; }
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, a0, a1);
        }
        dc.setPenWidth(1);
    }
}
