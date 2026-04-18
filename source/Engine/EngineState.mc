//
//  EngineState.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;

// Tagged union expressed as a Dictionary:
//   idle:     { "kind" => "idle" }
//   running:  { "kind" => "running",
//               "index" => Number,
//               "segmentStartedAtMs" => Long,
//               "workoutStartedAtMs" => Long }
//   paused:   { "kind" => "paused",
//               "index" => Number,
//               "segmentElapsedMs" => Long,
//               "totalElapsedMs" => Long }
//   finished: { "kind" => "finished",
//               "workoutStartedAtMs" => Long,
//               "finishedAtMs" => Long }
module EngineState {
    const KIND = "kind";
    const KIND_IDLE = "idle";
    const KIND_RUNNING = "running";
    const KIND_PAUSED = "paused";
    const KIND_FINISHED = "finished";

    const INDEX = "index";
    const SEGMENT_STARTED_AT_MS = "segmentStartedAtMs";
    const WORKOUT_STARTED_AT_MS = "workoutStartedAtMs";
    const SEGMENT_ELAPSED_MS = "segmentElapsedMs";
    const TOTAL_ELAPSED_MS = "totalElapsedMs";
    const FINISHED_AT_MS = "finishedAtMs";

    function idle() as Dictionary {
        return { KIND => KIND_IDLE };
    }

    function running(
            index as Number,
            segmentStartedAtMs as Long,
            workoutStartedAtMs as Long) as Dictionary {
        return {
            KIND => KIND_RUNNING,
            INDEX => index,
            SEGMENT_STARTED_AT_MS => segmentStartedAtMs,
            WORKOUT_STARTED_AT_MS => workoutStartedAtMs
        };
    }

    function paused(
            index as Number,
            segmentElapsedMs as Long,
            totalElapsedMs as Long) as Dictionary {
        return {
            KIND => KIND_PAUSED,
            INDEX => index,
            SEGMENT_ELAPSED_MS => segmentElapsedMs,
            TOTAL_ELAPSED_MS => totalElapsedMs
        };
    }

    function finished(
            workoutStartedAtMs as Long,
            finishedAtMs as Long) as Dictionary {
        return {
            KIND => KIND_FINISHED,
            WORKOUT_STARTED_AT_MS => workoutStartedAtMs,
            FINISHED_AT_MS => finishedAtMs
        };
    }

    function is(state as Dictionary, kind as String) as Boolean {
        return (state[KIND] as String).equals(kind);
    }

    function label(state as Dictionary) as String {
        return state[KIND] as String;
    }
}
