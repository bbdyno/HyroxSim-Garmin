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
            return stored;
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
}
