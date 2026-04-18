//
//  PaceReference.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Lang;

// Division-specific benchmark totals (seconds) used as fallback when the
// phone has not pushed an explicit goal. Numbers are median-ish reference
// times — adjust as HYROX publishes updated leaderboards.
//
// Source of truth for the full curve lives in iOS `PaceReference.swift`.
// Here we only store the aggregate seconds to keep RAM usage tiny.
module PaceReference {
    // Reference total seconds per division.
    function referenceTotalSeconds(division as String) as Number {
        if (division.equals(HyroxDivision.MEN_OPEN_SINGLE))    { return 75 * 60; }
        if (division.equals(HyroxDivision.MEN_OPEN_DOUBLE))    { return 65 * 60; }
        if (division.equals(HyroxDivision.MEN_PRO_SINGLE))     { return 70 * 60; }
        if (division.equals(HyroxDivision.MEN_PRO_DOUBLE))     { return 60 * 60; }
        if (division.equals(HyroxDivision.WOMEN_OPEN_SINGLE))  { return 90 * 60; }
        if (division.equals(HyroxDivision.WOMEN_OPEN_DOUBLE))  { return 78 * 60; }
        if (division.equals(HyroxDivision.WOMEN_PRO_SINGLE))   { return 82 * 60; }
        if (division.equals(HyroxDivision.WOMEN_PRO_DOUBLE))   { return 70 * 60; }
        if (division.equals(HyroxDivision.MIXED_DOUBLE))       { return 72 * 60; }
        return 80 * 60;
    }

    // Default per-segment duration bucket used to fabricate `targetSegmentsMs`
    // when only a total goal is available. Rough proportional split:
    //   run: 47%, station: 46%, rox zone: 7%
    function defaultSegmentSeconds(type as String, totalSeconds as Number) as Number {
        if (type.equals(SegmentType.RUN)) {
            return ((totalSeconds * 47) / 100 / 8).toNumber();
        }
        if (type.equals(SegmentType.STATION)) {
            return ((totalSeconds * 46) / 100 / 8).toNumber();
        }
        return ((totalSeconds * 7) / 100 / 15).toNumber();
    }

    // Build a 31-segment target array aligned with a HYROX preset. Falls back
    // to `referenceTotalSeconds` if `totalSecondsOverride` is null.
    function defaultTargetsForPreset(
            template as Dictionary,
            totalSecondsOverride as Number?) as Array<Number> {
        var total = totalSecondsOverride != null
            ? totalSecondsOverride
            : referenceTotalSeconds(template[WorkoutTemplate.DIVISION] as String);

        var segs = template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var out = new Array<Number>[segs.size()];
        for (var i = 0; i < segs.size(); i += 1) {
            var t = (segs[i] as Dictionary)[WorkoutSegment.TYPE] as String;
            out[i] = defaultSegmentSeconds(t, total);
        }
        return out;
    }
}
