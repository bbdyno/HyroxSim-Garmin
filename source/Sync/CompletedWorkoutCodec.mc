//
//  CompletedWorkoutCodec.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Lang;

// Encodes a `WorkoutEngine.records` snapshot into the `workout.completed`
// payload. HR samples are downsampled to 0.2 Hz (every 5 s) to fit under
// the ~10 KB per-message limit; at 31 segments × ~5 min avg = ~9300 s of
// workout, full-rate 1 Hz samples would overflow.
module CompletedWorkoutCodec {
    const HR_DOWNSAMPLE_INTERVAL_MS = 5000l;

    function encode(
            engine as WorkoutEngine,
            source as String) as Dictionary {
        var template = engine.template;
        var finishedMs = 0l;
        var startedMs = 0l;
        if (EngineState.is(engine.state, EngineState.KIND_FINISHED)) {
            finishedMs = engine.state[EngineState.FINISHED_AT_MS] as Long;
            startedMs  = engine.state[EngineState.WORKOUT_STARTED_AT_MS] as Long;
        }

        var segmentsOut = [];
        var records = engine.records;
        for (var i = 0; i < records.size(); i += 1) {
            segmentsOut.add(_encodeSegment(records[i] as Dictionary));
        }

        return {
            "id"            => WorkoutSegment.newId(),
            "templateName"  => template[WorkoutTemplate.NAME] as String,
            "division"      => template[WorkoutTemplate.DIVISION],
            "startedAtMs"   => startedMs,
            "finishedAtMs"  => finishedMs,
            "source"        => source,
            "segments"      => segmentsOut
        };
    }

    function _encodeSegment(record as Dictionary) as Dictionary {
        var measurements = record[SegmentRecord.MEASUREMENTS] as Dictionary;
        var hrSamples = _downsampleHr(
            measurements[SegmentMeasurements.HEART_RATE_SAMPLES] as Array<Dictionary>);
        return {
            "index"                 => record[SegmentRecord.INDEX] as Number,
            "type"                  => record[SegmentRecord.TYPE] as String,
            "startedAtMs"           => record[SegmentRecord.STARTED_AT_MS] as Long,
            "endedAtMs"             => record[SegmentRecord.ENDED_AT_MS] as Long,
            "pausedDurationMs"      => record[SegmentRecord.PAUSED_DURATION_MS] as Long,
            "plannedDistanceMeters" => record[SegmentRecord.PLANNED_DISTANCE_METERS],
            "goalDurationSeconds"   => record[SegmentRecord.GOAL_DURATION_SECONDS],
            "stationDisplayName"    => record[SegmentRecord.STATION_DISPLAY_NAME],
            "heartRateSamples"      => hrSamples
        };
    }

    // Keeps at most one sample per HR_DOWNSAMPLE_INTERVAL_MS window.
    function _downsampleHr(samples as Array<Dictionary>) as Array<Dictionary> {
        var out = [];
        var lastT = -1l;
        for (var i = 0; i < samples.size(); i += 1) {
            var s = samples[i] as Dictionary;
            var t = s["tMs"] as Long;
            if (lastT < 0l || (t - lastT) >= HR_DOWNSAMPLE_INTERVAL_MS) {
                out.add({ "tMs" => t, "bpm" => s["bpm"] as Number });
                lastT = t;
            }
        }
        return out;
    }
}
