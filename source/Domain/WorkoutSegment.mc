//
//  WorkoutSegment.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

// Value-type segment expressed as a Dictionary for JSON round-tripping:
//   {
//     "id"                    => <String>,
//     "type"                  => <SegmentType string>,
//     "distanceMeters"        => <Float or null>,
//     "goalDurationSeconds"   => <Float or null>,
//     "stationKind"           => <StationKind string or null>,
//     "stationTarget"         => <StationTarget dict or null>,
//     "weightKg"              => <Float or null>,
//     "weightNote"            => <String or null>
//   }
module WorkoutSegment {
    const ID = "id";
    const TYPE = "type";
    const DISTANCE_METERS = "distanceMeters";
    const GOAL_DURATION_SECONDS = "goalDurationSeconds";
    const STATION_KIND = "stationKind";
    const STATION_TARGET = "stationTarget";
    const WEIGHT_KG = "weightKg";
    const WEIGHT_NOTE = "weightNote";

    // MARK: - Convenience constructors

    function run(distanceMeters as Number) as Dictionary {
        return {
            ID => newId(),
            TYPE => SegmentType.RUN,
            DISTANCE_METERS => distanceMeters,
            GOAL_DURATION_SECONDS => defaultGoalDurationSeconds(SegmentType.RUN, distanceMeters),
            STATION_KIND => null,
            STATION_TARGET => null,
            WEIGHT_KG => null,
            WEIGHT_NOTE => null
        };
    }

    function roxZone() as Dictionary {
        return {
            ID => newId(),
            TYPE => SegmentType.ROX_ZONE,
            DISTANCE_METERS => null,
            GOAL_DURATION_SECONDS => defaultGoalDurationSeconds(SegmentType.ROX_ZONE, null),
            STATION_KIND => null,
            STATION_TARGET => null,
            WEIGHT_KG => null,
            WEIGHT_NOTE => null
        };
    }

    function station(
            kind as String,
            target as Dictionary?,
            weightKg as Number?,
            weightNote as String?) as Dictionary {
        return {
            ID => newId(),
            TYPE => SegmentType.STATION,
            DISTANCE_METERS => null,
            GOAL_DURATION_SECONDS => defaultGoalDurationSeconds(SegmentType.STATION, null),
            STATION_KIND => kind,
            STATION_TARGET => target,
            WEIGHT_KG => weightKg,
            WEIGHT_NOTE => weightNote
        };
    }

    // MARK: - Defaults

    // Mirrors iOS WorkoutSegment.defaultGoalDurationSeconds:
    //   run:      meters * 0.36  (≈ 6:00/km baseline, 1 km → 360s)
    //   roxZone:  30s flat
    //   station:  240s flat (4:00 reference)
    function defaultGoalDurationSeconds(
            type as String,
            distanceMeters as Number?) as Number {
        if (type.equals(SegmentType.RUN)) {
            var d = distanceMeters;
            if (d == null) { d = 1000; }
            return (d * 0.36).toNumber();
        }
        if (type.equals(SegmentType.ROX_ZONE)) {
            return 30;
        }
        return 240;
    }

    // MARK: - ID helpers

    // Monkey C has no native UUID. We produce a "unique enough" string by
    // combining the current epoch second with a 32-bit random, which is
    // sufficient for idempotent upsert keys on the phone side.
    function newId() as String {
        // iOS/Android 코덱은 UUID 형식만 받는다. 난수 4개로 v4 UUID 문자열을 만든다.
        var a = Math.rand();
        var b = Math.rand();
        var c = Math.rand();
        var d = Math.rand();
        return _hex4(a >> 16) + _hex4(a) + "-"
            + _hex4(b >> 16) + "-"
            + _hex4((b & 0x0FFF) | 0x4000) + "-"
            + _hex4((c & 0x3FFF) | 0x8000) + "-"
            + _hex4(c >> 16) + _hex4(d >> 16) + _hex4(d);
    }

    function _hex4(value as Number) as String {
        return (value & 0xFFFF).format("%04x");
    }
}
