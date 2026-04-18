//
//  DeltaCalculator.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Lang;

// Pure delta math. Positive value = behind target (slower), negative = ahead.
module DeltaCalculator {

    // Cumulative target up to and *including* segmentIndex.
    function cumulativeTargetMs(
            goal as Dictionary,
            segmentIndex as Number) as Long {
        var arr = goal[GoalStore.TARGET_SEGMENTS_MS] as Array<Long>;
        var sum = 0l;
        var end = segmentIndex + 1;
        if (end > arr.size()) { end = arr.size(); }
        for (var i = 0; i < end; i += 1) {
            sum += arr[i];
        }
        return sum;
    }

    // Target for the current segment alone.
    function currentSegmentTargetMs(
            goal as Dictionary,
            segmentIndex as Number) as Long {
        var arr = goal[GoalStore.TARGET_SEGMENTS_MS] as Array<Long>;
        if (segmentIndex < 0 || segmentIndex >= arr.size()) { return 0l; }
        return arr[segmentIndex];
    }

    // Delta within the current segment: how many ms ahead/behind the
    // target finishing time of this segment. Negative = ahead.
    function currentSegmentDeltaMs(
            engine as WorkoutEngine,
            goal as Dictionary,
            nowMs as Long) as Long {
        var idx = engine.currentSegmentIndex();
        if (idx == null) { return 0l; }
        var elapsed = engine.segmentElapsedMs(nowMs);
        var target = currentSegmentTargetMs(goal, idx);
        return elapsed - target;
    }

    // Delta against the cumulative target up to and including the current
    // segment position. Matches iOS "totalDelta" semantics in PaceCard.
    function totalDeltaMs(
            engine as WorkoutEngine,
            goal as Dictionary,
            nowMs as Long) as Long {
        var idx = engine.currentSegmentIndex();
        if (idx == null) {
            if (engine.isFinished()) {
                // Compare final total vs targetTotalMs
                return engine.totalElapsedMs(nowMs) - (goal[GoalStore.TARGET_TOTAL_MS] as Long);
            }
            return 0l;
        }
        var totalElapsed = engine.totalElapsedMs(nowMs);
        var cumTarget = cumulativeTargetMs(goal, idx);
        return totalElapsed - cumTarget;
    }
}
