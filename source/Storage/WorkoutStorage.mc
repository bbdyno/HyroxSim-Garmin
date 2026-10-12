//
//  WorkoutStorage.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// Persists completed workouts to Application.Storage so they survive app
// restarts and device reboots. Acts as an outbox for the phone bridge:
//
//   1. Workout finishes  → enqueue()
//   2. Phone reachable   → PhoneMessageHandler sends each part in turn;
//                          on ACK calls markSynced()
//   3. Synced records are deleted after a grace period
//
// Layout (v2). A whole outbox in one value hit the per-value size limit
// after a couple of workouts and had to be read into memory in full just
// to list it, so each workout part now lives under its own key:
//
//   "outbox_idx_v2" => [ { "id", "synced", "addedMs", "n" }, ... ]
//   "ob_<id>_<i>"   => part i of that workout (see CompletedWorkoutCodec.split)
module WorkoutStorage {
    const INDEX_KEY = "outbox_idx_v2";
    const LEGACY_KEY = "outbox_v1";
    const kMaxRecords = 10;

    function _partKey(id as String, i as Number) as String {
        return "ob_" + id + "_" + i.toString();
    }

    // Index entries only — cheap. Use loadPart() for payload data.
    function list() as Array<Dictionary> {
        _migrateLegacy();
        var raw = Application.Storage.getValue(INDEX_KEY);
        if (raw == null) { return []; }
        return raw as Array<Dictionary>;
    }

    function loadPart(id as String, i as Number) as Dictionary? {
        var raw = Application.Storage.getValue(_partKey(id, i));
        if (raw == null) { return null; }
        return raw as Dictionary;
    }

    function enqueue(completedWorkout as Dictionary) as Void {
        var id = completedWorkout["id"] as String;
        var parts = CompletedWorkoutCodec.split(completedWorkout);
        var index = list();

        // Make room first: oldest synced entries go before any unsynced one.
        while (index.size() >= kMaxRecords) {
            var victim = 0;
            for (var i = 0; i < index.size(); i += 1) {
                if ((index[i] as Dictionary)["synced"] as Boolean) { victim = i; break; }
            }
            _deleteParts(index[victim] as Dictionary);
            index = _sliceExcluding(index, victim);
        }

        try {
            for (var p = 0; p < parts.size(); p += 1) {
                Application.Storage.setValue(_partKey(id, p), parts[p] as Dictionary);
            }
            index.add({
                "id" => id,
                "synced" => false,
                "addedMs" => Toybox.Time.now().value().toLong() * 1000l,
                "n" => parts.size()
            });
            Application.Storage.setValue(INDEX_KEY, index);
        } catch (ex) {
            // Storage full. Leave no half-written workout behind.
            System.println("outbox write failed: " + ex.getErrorMessage());
            for (var p = 0; p < parts.size(); p += 1) {
                Application.Storage.deleteValue(_partKey(id, p));
            }
        }
    }

    function markSynced(id as String) as Void {
        var index = list();
        var changed = false;
        for (var i = 0; i < index.size(); i += 1) {
            var entry = index[i] as Dictionary;
            if ((entry["id"] as String).equals(id) && !(entry["synced"] as Boolean)) {
                // The phone has it; the payload is no longer needed.
                _deleteParts(entry);
                entry["synced"] = true;
                index[i] = entry;
                changed = true;
                break;
            }
        }
        if (changed) { Application.Storage.setValue(INDEX_KEY, index); }
    }

    // Drop synced records older than graceMs. Called opportunistically after
    // a successful sync to keep the queue from growing unbounded.
    function vacuum(graceMs as Long) as Void {
        var index = list();
        var cutoff = (Toybox.Time.now().value().toLong() * 1000l) - graceMs;
        var out = [];
        for (var i = 0; i < index.size(); i += 1) {
            var entry = index[i] as Dictionary;
            var isSynced = entry["synced"] as Boolean;
            var added = entry["addedMs"] as Long;
            if (isSynced && added < cutoff) {
                _deleteParts(entry);
                continue;
            }
            out.add(entry);
        }
        if (out.size() != index.size()) { Application.Storage.setValue(INDEX_KEY, out); }
    }

    function pendingCount() as Number {
        var index = list();
        var c = 0;
        for (var i = 0; i < index.size(); i += 1) {
            if (!((index[i] as Dictionary)["synced"] as Boolean)) { c += 1; }
        }
        return c;
    }

    function _deleteParts(entry as Dictionary) as Void {
        var id = entry["id"] as String;
        var n = entry["n"] as Number;
        for (var p = 0; p < n; p += 1) {
            Application.Storage.deleteValue(_partKey(id, p));
        }
    }

    // One-time move of a v1 outbox into the v2 layout. v1 workouts carried
    // ids the phone rejects (it requires a UUID), so they never synced;
    // they get a fresh UUID here and go out with the next flush.
    function _migrateLegacy() as Void {
        var raw = Application.Storage.getValue(LEGACY_KEY);
        if (raw == null) { return; }
        Application.Storage.deleteValue(LEGACY_KEY);
        try {
            var legacy = raw as Array<Dictionary>;
            for (var i = 0; i < legacy.size(); i += 1) {
                var entry = legacy[i] as Dictionary;
                if (entry["synced"] as Boolean) { continue; }
                var payload = entry["payload"] as Dictionary;
                var id = payload["id"];
                if (!(id instanceof String) || (id as String).length() != 36) {
                    payload["id"] = WorkoutSegment.newId();
                }
                enqueue(payload);
            }
        } catch (ex) {
            System.println("outbox migration failed: " + ex.getErrorMessage());
        }
    }

    function _sliceExcluding(arr as Array, idx as Number) as Array {
        var out = [];
        for (var i = 0; i < arr.size(); i += 1) {
            if (i != idx) { out.add(arr[i]); }
        }
        return out;
    }
}
