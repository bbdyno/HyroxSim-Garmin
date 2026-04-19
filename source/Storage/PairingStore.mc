//
//  PairingStore.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Application;
import Toybox.Lang;

// Tracks whether the watch has ever been paired with the iOS/Android
// companion. Used as an entitlement gate — without pairing the watch
// shows instructions only and blocks all workout entry points.
//
// Flag is set on the first successful `hello` handshake and never
// un-set automatically (persists across app restarts / device reboots).
// Only a manual reset (future Settings action) clears it.
//
// Storage layout:
//   "paired_v1" → { "paired" => Boolean, "firstPairedMs" => Long, "lastHelloMs" => Long }
module PairingStore {
    const KEY = "paired_v1";
    const PAIRED = "paired";
    const FIRST_PAIRED_MS = "firstPairedMs";
    const LAST_HELLO_MS = "lastHelloMs";

    function isPaired() as Boolean {
        var raw = Application.Storage.getValue(KEY);
        if (raw == null) { return false; }
        var dict = raw as Dictionary;
        var paired = dict[PAIRED];
        return paired != null && (paired as Boolean);
    }

    function recordHello() as Void {
        var nowMs = Toybox.Time.now().value().toLong() * 1000l;
        var existing = Application.Storage.getValue(KEY);
        var firstMs = nowMs;
        if (existing != null) {
            var d = existing as Dictionary;
            var f = d[FIRST_PAIRED_MS];
            if (f != null) { firstMs = f as Long; }
        }
        Application.Storage.setValue(KEY, {
            PAIRED => true,
            FIRST_PAIRED_MS => firstMs,
            LAST_HELLO_MS => nowMs
        });
    }

    function reset() as Void {
        Application.Storage.deleteValue(KEY);
    }
}
