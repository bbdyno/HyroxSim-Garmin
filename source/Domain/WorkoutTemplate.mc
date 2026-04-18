//
//  WorkoutTemplate.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;
import Toybox.Time;

// Template expressed as a Dictionary:
//   {
//     "id"            => <String>,
//     "name"          => <String>,
//     "division"      => <HyroxDivision string or null>,
//     "segments"      => <Array<WorkoutSegment dict>>,
//     "usesRoxZone"   => <Boolean>,
//     "createdAtMs"   => <Long>,
//     "isBuiltIn"     => <Boolean>
//   }
module WorkoutTemplate {
    const ID = "id";
    const NAME = "name";
    const DIVISION = "division";
    const SEGMENTS = "segments";
    const USES_ROX_ZONE = "usesRoxZone";
    const CREATED_AT_MS = "createdAtMs";
    const IS_BUILT_IN = "isBuiltIn";

    function make(
            name as String,
            division as String?,
            segments as Array<Dictionary>,
            usesRoxZone as Boolean,
            isBuiltIn as Boolean) as Dictionary {
        return {
            ID => WorkoutSegment.newId(),
            NAME => name,
            DIVISION => division,
            SEGMENTS => segments,
            USES_ROX_ZONE => usesRoxZone,
            CREATED_AT_MS => Time.now().value().toLong() * 1000,
            IS_BUILT_IN => isBuiltIn
        };
    }

    // MARK: - Built-in HYROX preset (31 segments)

    // Generates the canonical HYROX layout for the given division:
    //   Run #1 → RoxZone → Station #1 → RoxZone → Run #2 → RoxZone → Station #2 ...
    //   → Run #8 → RoxZone → Station #8
    // Total: 8 runs + 8 stations + 15 RoxZones = 31 segments.
    function hyroxPreset(division as String) as Dictionary {
        var stationSpecs = HyroxDivisionSpec.stationsFor(division);
        var logicalSegments = [];

        // Build 16-entry logical sequence: Run #1, Station #1, Run #2, Station #2, ...
        for (var i = 0; i < 8; i += 1) {
            logicalSegments.add(WorkoutSegment.run(1000));
            var spec = stationSpecs[i] as Dictionary;
            var seg = WorkoutSegment.station(
                spec[HyroxDivisionSpec.KIND] as String,
                spec[HyroxDivisionSpec.TARGET] as Dictionary,
                spec[HyroxDivisionSpec.WEIGHT_KG] as Number?,
                spec[HyroxDivisionSpec.WEIGHT_NOTE] as String?
            );
            logicalSegments.add(seg);
        }

        var materialized = materializedSegments(logicalSegments, true, []);
        return make(
            presetName(division),
            division,
            materialized,
            true,
            true
        );
    }

    function presetName(division as String) as String {
        return "HYROX " + HyroxDivision.displayName(division);
    }

    // MARK: - RoxZone materialization

    // Mirrors iOS WorkoutTemplate.materializedSegments:
    //   - If usesRoxZone is false → return logicalSegments unchanged.
    //   - Otherwise insert a RoxZone between each (run, station) or (station, run) pair.
    //   - preservedRoxZones lets callers retain user-customized transitions
    //     when flipping the flag back on.
    function materializedSegments(
            logicalSegments as Array<Dictionary>,
            usesRoxZone as Boolean,
            preservedRoxZones as Array<Dictionary>) as Array<Dictionary> {
        if (!usesRoxZone) { return logicalSegments; }

        var out = [];
        var preservedIdx = 0;
        var count = logicalSegments.size();
        for (var i = 0; i < count; i += 1) {
            var seg = logicalSegments[i] as Dictionary;
            out.add(seg);
            if (i >= count - 1) { continue; }
            var next = logicalSegments[i + 1] as Dictionary;
            if (needsRoxZoneBetween(seg, next)) {
                if (preservedIdx < preservedRoxZones.size()) {
                    out.add(preservedRoxZones[preservedIdx] as Dictionary);
                    preservedIdx += 1;
                } else {
                    out.add(WorkoutSegment.roxZone());
                }
            }
        }
        return out;
    }

    function needsRoxZoneBetween(current as Dictionary, next as Dictionary) as Boolean {
        var a = current[WorkoutSegment.TYPE] as String;
        var b = next[WorkoutSegment.TYPE] as String;
        if (a.equals(SegmentType.RUN) && b.equals(SegmentType.STATION)) { return true; }
        if (a.equals(SegmentType.STATION) && b.equals(SegmentType.RUN)) { return true; }
        return false;
    }

    // MARK: - Derived

    function logicalSegments(template as Dictionary) as Array<Dictionary> {
        var segs = template[SEGMENTS] as Array<Dictionary>;
        var out = [];
        for (var i = 0; i < segs.size(); i += 1) {
            var s = segs[i] as Dictionary;
            if (!(s[WorkoutSegment.TYPE] as String).equals(SegmentType.ROX_ZONE)) {
                out.add(s);
            }
        }
        return out;
    }

    function stationCount(template as Dictionary) as Number {
        var segs = template[SEGMENTS] as Array<Dictionary>;
        var c = 0;
        for (var i = 0; i < segs.size(); i += 1) {
            var s = segs[i] as Dictionary;
            if ((s[WorkoutSegment.TYPE] as String).equals(SegmentType.STATION)) {
                c += 1;
            }
        }
        return c;
    }

    function estimatedDurationSeconds(template as Dictionary) as Number {
        var segs = template[SEGMENTS] as Array<Dictionary>;
        var total = 0;
        for (var i = 0; i < segs.size(); i += 1) {
            var s = segs[i] as Dictionary;
            var goal = s[WorkoutSegment.GOAL_DURATION_SECONDS];
            if (goal == null) {
                goal = WorkoutSegment.defaultGoalDurationSeconds(
                    s[WorkoutSegment.TYPE] as String,
                    s[WorkoutSegment.DISTANCE_METERS] as Number?
                );
            }
            total += (goal as Number);
        }
        return total;
    }
}
