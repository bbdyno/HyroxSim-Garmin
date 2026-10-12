//
//  CompletedWorkoutCodec.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Lang;

// Encodes a `WorkoutEngine.records` snapshot into the `workout.completed`
// payload, and splits it into parts small enough for one phone message.
//
// A full 31-segment workout does not fit in a single message (the keys
// alone are ~7 KB), so `split` cuts the segment list into parts; the phone
// reassembles them. HR is bounded per segment so one long segment can
// never outgrow a part on its own.
module CompletedWorkoutCodec {
    const HR_DOWNSAMPLE_INTERVAL_MS = 5000l;
    const kMaxHrSamplesPerSegment = 40;
    // Rough serialized-size budget per part, well under the message limit.
    const kPartBudgetBytes = 3000;
    const kSegmentBaseBytes = 260;
    const kHrSampleBytes = 45;

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

    // Cuts an encoded workout into message-sized parts. Part 0 carries the
    // header fields plus its share of segments; later parts carry only
    // `{ "segments" => [...] }`. Always returns at least one part.
    function split(payload as Dictionary) as Array<Dictionary> {
        var segs = payload["segments"] as Array<Dictionary>;
        var groups = [];
        var cur = [];
        var curCost = 0;
        for (var i = 0; i < segs.size(); i += 1) {
            var seg = segs[i] as Dictionary;
            var hr = seg["heartRateSamples"] as Array;
            var cost = kSegmentBaseBytes + kHrSampleBytes * hr.size();
            if (cur.size() > 0 && (curCost + cost) > kPartBudgetBytes) {
                groups.add(cur);
                cur = [];
                curCost = 0;
            }
            cur.add(seg);
            curCost += cost;
        }
        if (cur.size() > 0 || groups.size() == 0) { groups.add(cur); }

        var parts = [];
        for (var g = 0; g < groups.size(); g += 1) {
            if (g == 0) {
                parts.add({
                    "id"            => payload["id"],
                    "templateName"  => payload["templateName"],
                    "division"      => payload["division"],
                    "startedAtMs"   => payload["startedAtMs"],
                    "finishedAtMs"  => payload["finishedAtMs"],
                    "source"        => payload["source"],
                    "segments"      => groups[g]
                });
            } else {
                parts.add({ "segments" => groups[g] });
            }
        }
        return parts;
    }

    // Keeps at most one sample per window, widening the window for long
    // segments so the result never exceeds kMaxHrSamplesPerSegment.
    function _downsampleHr(samples as Array<Dictionary>) as Array<Dictionary> {
        var out = [];
        var lastT = -1l;
        var interval = HR_DOWNSAMPLE_INTERVAL_MS;
        if (samples.size() > 1) {
            var span = ((samples[samples.size() - 1] as Dictionary)["tMs"] as Long)
                     - ((samples[0] as Dictionary)["tMs"] as Long);
            var needed = span / kMaxHrSamplesPerSegment + 1l;
            if (needed > interval) { interval = needed; }
        }
        for (var i = 0; i < samples.size(); i += 1) {
            var s = samples[i] as Dictionary;
            var t = s["tMs"] as Long;
            if (lastT < 0l || (t - lastT) >= interval) {
                out.add({ "tMs" => t, "bpm" => s["bpm"] as Number });
                lastT = t;
            }
        }
        return out;
    }
}
