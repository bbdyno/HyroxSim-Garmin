//
//  TemplateStore.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Application;
import Toybox.Lang;

// Persists phone-provided WorkoutTemplate dictionaries so the watch can
// run custom user-built workouts (including `usesRoxZone=false` variants)
// without regenerating from scratch.
//
// Store layout in Application.Storage:
//   key "templates_v1" → Array<Dictionary> (WorkoutTemplate dicts)
//
// Upsert semantics: dedupe by template["id"]. Most-recent entry wins.
module TemplateStore {
    const KEY = "templates_v1";
    const kMaxTemplates = 20;

    function list() as Array<Dictionary> {
        var raw = Application.Storage.getValue(KEY);
        if (raw == null) { return []; }
        return raw as Array<Dictionary>;
    }

    function upsert(template as Dictionary) as Void {
        var id = template[WorkoutTemplate.ID] as String;
        if (id == null) { return; }
        var current = list();
        var out = [];
        for (var i = 0; i < current.size(); i += 1) {
            var entry = current[i] as Dictionary;
            if (!(entry[WorkoutTemplate.ID] as String).equals(id)) {
                out.add(entry);
            }
        }
        out.add(template);
        // Trim oldest if over cap.
        while (out.size() > kMaxTemplates) {
            out = _sliceFrom(out, 1);
        }
        Application.Storage.setValue(KEY, out);
    }

    function findById(id as String) as Dictionary? {
        var all = list();
        for (var i = 0; i < all.size(); i += 1) {
            var entry = all[i] as Dictionary;
            if ((entry[WorkoutTemplate.ID] as String).equals(id)) {
                return entry;
            }
        }
        return null;
    }

    function remove(id as String) as Void {
        var current = list();
        var out = [];
        for (var i = 0; i < current.size(); i += 1) {
            var entry = current[i] as Dictionary;
            if (!(entry[WorkoutTemplate.ID] as String).equals(id)) {
                out.add(entry);
            }
        }
        Application.Storage.setValue(KEY, out);
    }

    function count() as Number {
        return list().size();
    }

    function _sliceFrom(arr as Array, start as Number) as Array {
        var out = [];
        for (var i = start; i < arr.size(); i += 1) {
            out.add(arr[i]);
        }
        return out;
    }
}
