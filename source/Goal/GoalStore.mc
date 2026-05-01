//
//  GoalStore.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Application;
import Toybox.Lang;

// Persists the most recently received `goal.set` payload. Read at workout
// start to populate the delta calculator — phone push is fire-and-forget.
//
// Stored shape:
//   {
//     "division"           => <HyroxDivision string>,
//     "templateName"       => <String>,
//     "targetTotalMs"      => <Long>,
//     "targetSegmentsMs"   => <Array<Long>>,
//     "receivedAtMs"       => <Long>
//   }
module GoalStore {
    const KEY = "goal_v1";
    const DIVISION = "division";
    const TEMPLATE_NAME = "templateName";
    const TARGET_TOTAL_MS = "targetTotalMs";
    const TARGET_SEGMENTS_MS = "targetSegmentsMs";
    const RECEIVED_AT_MS = "receivedAtMs";

    function save(goal as Dictionary) as Void {
        Application.Storage.setValue(KEY, goal);
    }

    function load() as Dictionary? {
        var raw = Application.Storage.getValue(KEY);
        if (raw == null) { return null; }
        return raw as Dictionary;
    }

    // Resolves the goal to use for a given template. Priority:
    //   1. Stored goal whose division matches the template.
    //   2. PaceReference default using `referenceTotalSeconds` × 1000 for ms.
    function resolve(template as Dictionary) as Dictionary {
        var stored = load();
        var division = template[WorkoutTemplate.DIVISION] as String;
        if (stored != null
                && (stored[DIVISION] as String).equals(division)) {
            return _adaptToTemplate(stored, template);
        }
        var defaultSeconds = PaceReference.referenceTotalSeconds(division);
        var segTargets = PaceReference.defaultTargetsForPreset(template, defaultSeconds);
        var segMs = new Array<Long>[segTargets.size()];
        for (var i = 0; i < segTargets.size(); i += 1) {
            segMs[i] = (segTargets[i] as Number).toLong() * 1000l;
        }
        return {
            DIVISION => division,
            TEMPLATE_NAME => template[WorkoutTemplate.NAME] as String,
            TARGET_TOTAL_MS => defaultSeconds.toLong() * 1000l,
            TARGET_SEGMENTS_MS => segMs,
            RECEIVED_AT_MS => 0l
        };
    }

    // Reshape a stored goal so its `targetSegmentsMs` matches the
    // current template's segment count. The watch's ROX zone toggle
    // (DivisionPicker → RoxZoneTogglePicker → OFF) builds a 16-segment
    // template at run time even when iOS authored the goal for the
    // standard 31-segment HYROX layout. Without this, DeltaCalculator
    // would index a 31-element array against a 16-element template
    // and read meaningless ROX-zone targets in place of station ones.
    //
    // Standard HYROX 31-segment layout has ROX zones at every odd
    // index (Run @ 0,4,8,..; Sta @ 2,6,10,..; Rox @ 1,3,5,..). Stripping
    // odd indices yields the 16-element [Run, Sta, Run, Sta, ...] order.
    // ROX entries carry 0 budget (iOS folds rox time into the preceding
    // run's goalDurationSeconds), so totalTargetMs is preserved.
    function _adaptToTemplate(stored as Dictionary, template as Dictionary) as Dictionary {
        var segments = template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var targets = stored[TARGET_SEGMENTS_MS] as Array<Long>;
        if (targets == null || segments.size() == targets.size()) {
            return stored;
        }
        if (targets.size() == 31 && segments.size() == 16) {
            var trimmed = new Array<Long>[16];
            var w = 0;
            for (var i = 0; i < 31; i += 1) {
                if (i % 2 == 1) { continue; }
                trimmed[w] = targets[i];
                w += 1;
            }
            return {
                DIVISION            => stored[DIVISION],
                TEMPLATE_NAME       => stored[TEMPLATE_NAME],
                TARGET_TOTAL_MS     => stored[TARGET_TOTAL_MS],
                TARGET_SEGMENTS_MS  => trimmed,
                RECEIVED_AT_MS      => stored[RECEIVED_AT_MS]
            };
        }
        return stored;
    }
}
