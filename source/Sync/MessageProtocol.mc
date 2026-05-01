//
//  MessageProtocol.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Lang;

// String constants for the v1 phone-watch protocol. Changes here require
// parallel changes in `docs/MESSAGE_PROTOCOL.md` and the iOS/Android
// codecs. Do not rename raw values.
module MessageProtocol {
    const VERSION = 1;

    // Top-level envelope keys
    const K_VERSION = "v";
    const K_TYPE = "t";
    const K_ID = "id";
    const K_PAYLOAD = "payload";
    const K_CHUNK = "chunk";

    // Types — phone → watch
    const T_HELLO           = "hello";
    const T_GOAL_SET        = "goal.set";
    const T_TEMPLATE_UPSERT = "template.upsert";
    const T_TEMPLATE_DELETE = "template.delete";
    const T_CMD_ADVANCE     = "cmd.advance";
    const T_CMD_PAUSE       = "cmd.pause";
    const T_CMD_RESUME      = "cmd.resume";
    const T_CMD_END         = "cmd.end";

    // Types — watch → phone
    const T_HELLO_ACK           = "hello.ack";
    const T_WORKOUT_COMPLETED   = "workout.completed";
    const T_LIVE_STATE          = "live.state";
    const T_ACK                 = "ack";
    // Watch app boot ping. Equivalent to hello.ack semantically — tells the
    // phone "I'm running, push templates and goals". Needed because iOS may
    // never emit `hello` if it was already foreground+BLE-connected when
    // the watch app opened, leaving the watch with stale Application.Storage.
    const T_SYNC_REQUEST        = "sync.request";

    function envelope(
            type as String,
            id as String,
            payload as Dictionary?) as Dictionary {
        var out = {
            K_VERSION => VERSION,
            K_TYPE => type,
            K_ID => id
        };
        if (payload != null) {
            out[K_PAYLOAD] = payload;
        }
        return out;
    }
}
