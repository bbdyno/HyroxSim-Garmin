//
//  SegmentRecord.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;

// Completed segment record. Dictionary-backed for JSON round-tripping.
//
//   {
//     "id"                      => String,
//     "segmentId"               => String,
//     "index"                   => Number,
//     "type"                    => SegmentType string,
//     "startedAtMs"             => Long,
//     "endedAtMs"               => Long,
//     "pausedDurationMs"        => Long,
//     "measurements"            => { "heartRateSamples" => [...], "locationSamples" => [...] },
//     "stationDisplayName"      => String or null,
//     "plannedDistanceMeters"   => Number or null,
//     "goalDurationSeconds"     => Number or null
//   }
module SegmentRecord {
    const ID = "id";
    const SEGMENT_ID = "segmentId";
    const INDEX = "index";
    const TYPE = "type";
    const STARTED_AT_MS = "startedAtMs";
    const ENDED_AT_MS = "endedAtMs";
    const PAUSED_DURATION_MS = "pausedDurationMs";
    const MEASUREMENTS = "measurements";
    const STATION_DISPLAY_NAME = "stationDisplayName";
    const PLANNED_DISTANCE_METERS = "plannedDistanceMeters";
    const GOAL_DURATION_SECONDS = "goalDurationSeconds";

    function make(
            segmentId as String,
            index as Number,
            type as String,
            startedAtMs as Long,
            endedAtMs as Long,
            pausedDurationMs as Long,
            measurements as Dictionary,
            stationDisplayName as String?,
            plannedDistanceMeters as Number?,
            goalDurationSeconds as Number?) as Dictionary {
        return {
            ID => WorkoutSegment.newId(),
            SEGMENT_ID => segmentId,
            INDEX => index,
            TYPE => type,
            STARTED_AT_MS => startedAtMs,
            ENDED_AT_MS => endedAtMs,
            PAUSED_DURATION_MS => pausedDurationMs,
            MEASUREMENTS => measurements,
            STATION_DISPLAY_NAME => stationDisplayName,
            PLANNED_DISTANCE_METERS => plannedDistanceMeters,
            GOAL_DURATION_SECONDS => goalDurationSeconds
        };
    }

    // Wall-clock duration (includes paused time) in milliseconds.
    function durationMs(record as Dictionary) as Long {
        return (record[ENDED_AT_MS] as Long) - (record[STARTED_AT_MS] as Long);
    }

    // Active exercise duration (excludes paused time) in milliseconds.
    function activeDurationMs(record as Dictionary) as Long {
        return durationMs(record) - (record[PAUSED_DURATION_MS] as Long);
    }
}
