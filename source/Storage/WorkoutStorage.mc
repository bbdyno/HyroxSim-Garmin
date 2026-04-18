//
//  WorkoutStorage.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Application;
import Toybox.Lang;

// Persists completed workouts to Application.Storage so they survive app
// restarts and device reboots. Acts as an outbox for the phone bridge:
//
//   1. Workout finishes  → enqueue()
//   2. Phone reachable   → PhoneMessageHandler reads list(), sends each
//                          with id; on ACK calls markSynced()
//   3. Storage ages out synced records after a grace period
//
// Memory budget note: FR265 has ~128KB app heap. Each CompletedWorkout with
// HR samples downsampled to 0.2Hz is ~3-4KB, so 20 entries ≈ 80KB max.
// We cap at kMaxRecords to keep headroom.
module WorkoutStorage {
    const KEY = "outbox_v1";
    const kMaxRecords = 20;

    // Entry shape:
    //   {
    //     "id"      => <String>      (same as CompletedWorkout id)
    //     "payload" => <Dictionary>  (CompletedWorkout)
    //     "synced"  => <Boolean>
    //     "addedMs" => <Long>
    //   }

    function list() as Array<Dictionary> {
        var raw = Application.Storage.getValue(KEY);
        if (raw == null) { return []; }
        return raw as Array<Dictionary>;
    }

    function enqueue(completedWorkout as Dictionary) as Void {
        var current = list();
        var entry = {
            "id" => completedWorkout["id"] as String,
            "payload" => completedWorkout,
            "synced" => false,
            "addedMs" => Toybox.Time.now().value().toLong() * 1000l
        };
        current.add(entry);
        // Trim oldest synced entries first if over capacity.
        while (current.size() > kMaxRecords) {
            var removed = false;
            for (var i = 0; i < current.size(); i += 1) {
                if ((current[i] as Dictionary)["synced"] as Boolean) {
                    current = _sliceExcluding(current, i);
                    removed = true;
                    break;
                }
            }
            if (!removed) {
                // No synced entries to drop — evict oldest unsynced (we lose a record).
                current = _sliceExcluding(current, 0);
            }
        }
        Application.Storage.setValue(KEY, current);
    }

    function markSynced(id as String) as Void {
        var current = list();
        for (var i = 0; i < current.size(); i += 1) {
            var entry = current[i] as Dictionary;
            if ((entry["id"] as String).equals(id)) {
                entry["synced"] = true;
                current[i] = entry;
                break;
            }
        }
        Application.Storage.setValue(KEY, current);
    }

    // Drop synced records older than graceMs. Called opportunistically after
    // a successful sync to keep the queue from growing unbounded.
    function vacuum(graceMs as Long) as Void {
        var current = list();
        var cutoff = (Toybox.Time.now().value().toLong() * 1000l) - graceMs;
        var out = [];
        for (var i = 0; i < current.size(); i += 1) {
            var entry = current[i] as Dictionary;
            var isSynced = entry["synced"] as Boolean;
            var added = entry["addedMs"] as Long;
            if (isSynced && added < cutoff) { continue; }
            out.add(entry);
        }
        Application.Storage.setValue(KEY, out);
    }

    function pendingCount() as Number {
        var current = list();
        var c = 0;
        for (var i = 0; i < current.size(); i += 1) {
            if (!((current[i] as Dictionary)["synced"] as Boolean)) { c += 1; }
        }
        return c;
    }

    function _sliceExcluding(arr as Array, idx as Number) as Array {
        var out = [];
        for (var i = 0; i < arr.size(); i += 1) {
            if (i != idx) { out.add(arr[i]); }
        }
        return out;
    }
}
