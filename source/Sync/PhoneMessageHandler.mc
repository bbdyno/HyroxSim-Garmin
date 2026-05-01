//
//  PhoneMessageHandler.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Bridges the Connect IQ phone-message channel to our domain layer.
//
// Phone → watch: handles hello/goal.set/template.upsert/cmd.* envelopes.
// Watch → phone: flushes the WorkoutStorage outbox as workout.completed
//                messages and tracks ack'd IDs.
//
// The singleton is registered in HyroxSimApp.onStart and stays alive for
// the app's lifetime so callbacks can fire even when the active view is
// different from the ActiveWorkoutView.
class PhoneMessageHandler {

    private var _registered;

    function initialize() {
        _registered = false;
    }

    function register() as Void {
        if (_registered) { return; }
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        _registered = true;
        _sendSyncRequest();
    }

    // Boot ping. Fires once on app start to ask the phone to re-emit every
    // template + goal it has. Without this, a session where the phone was
    // already foreground when the watch app opened would never receive a
    // hello (iOS only emits hello on sceneDidBecomeActive / BLE reconnect)
    // and the watch would fall back to PaceReference defaults instead of
    // the user's actual pace-planner targets. Transmit failures are
    // silently swallowed by PhoneTransmitListener — if BLE isn't ready
    // yet, the natural hello → hello.ack path will still cover it later.
    private function _sendSyncRequest() as Void {
        var env = MessageProtocol.envelope(
            MessageProtocol.T_SYNC_REQUEST,
            "watch-boot",
            null);
        _transmit(env);
    }

    // Toybox.Communications signature: callback(msg as Message)
    // Message#data holds the Dictionary payload exactly as the phone sent it.
    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data as Dictionary;
        if (data == null) { return; }
        var type = data[MessageProtocol.K_TYPE] as String;
        var id = data[MessageProtocol.K_ID] as String;

        if (type.equals(MessageProtocol.T_HELLO)) {
            // First successful hello unlocks the app (pairing gate). If the
            // watch was showing PairingRequiredView it will remain on screen
            // until the user presses SELECT to re-enter — we don't force-
            // switch views here because the user may be mid-read.
            PairingStore.recordHello();
            _sendHelloAck(id);
            flushOutbox();
            // Repaint home so the "PAIR PHONE APP" hint flips to the actual
            // paired state immediately. Without this the storage flag is set
            // but the visible card stays stale until the user navigates away
            // and back. Subsequent hellos are idempotent and a redundant
            // repaint is cheap.
            HomeViewRegistry.refreshIfVisible();
            return;
        }
        if (type.equals(MessageProtocol.T_GOAL_SET)) {
            _handleGoalSet(data[MessageProtocol.K_PAYLOAD] as Dictionary);
            return;
        }
        if (type.equals(MessageProtocol.T_TEMPLATE_UPSERT)) {
            _handleTemplateUpsert(data[MessageProtocol.K_PAYLOAD] as Dictionary);
            return;
        }
        if (type.equals(MessageProtocol.T_TEMPLATE_DELETE)) {
            _handleTemplateDelete(data[MessageProtocol.K_PAYLOAD] as Dictionary);
            return;
        }
        if (type.equals(MessageProtocol.T_ACK)) {
            WorkoutStorage.markSynced(id);
            WorkoutStorage.vacuum(60l * 60l * 1000l);    // 1 hour grace
            return;
        }
        // Commands (cmd.*) are handled in Phase 10 (mirroring). For MVP we
        // acknowledge and drop them.
    }

    // Enqueue a completed workout and try to send immediately. If the phone
    // is not reachable it will be re-sent from `flushOutbox` on next hello.
    function submitCompletedWorkout(completedWorkout as Dictionary) as Void {
        WorkoutStorage.enqueue(completedWorkout);
        flushOutbox();
    }

    function flushOutbox() as Void {
        var entries = WorkoutStorage.list();
        for (var i = 0; i < entries.size(); i += 1) {
            var entry = entries[i] as Dictionary;
            if ((entry["synced"] as Boolean)) { continue; }
            var payload = entry["payload"] as Dictionary;
            var env = MessageProtocol.envelope(
                MessageProtocol.T_WORKOUT_COMPLETED,
                payload["id"] as String,
                payload);
            _transmit(env);
        }
    }

    // Phone pushes a custom WorkoutTemplate. Payload *is* the template dict;
    // we upsert by template["id"]. Covers both brand-new templates and
    // updates (e.g. the user toggled `usesRoxZone` on iOS).
    function _handleTemplateUpsert(payload as Dictionary) as Void {
        if (payload == null) { return; }
        if (payload[WorkoutTemplate.ID] == null) { return; }
        TemplateStore.upsert(payload);
        HomeViewRegistry.refreshIfVisible();
    }

    function _handleTemplateDelete(payload as Dictionary) as Void {
        if (payload == null) { return; }
        var id = payload[WorkoutTemplate.ID] as String;
        if (id == null) { return; }
        TemplateStore.remove(id);
        HomeViewRegistry.refreshIfVisible();
    }

    function _handleGoalSet(payload as Dictionary) as Void {
        if (payload == null) { return; }
        var goal = {
            GoalStore.DIVISION => payload["division"] as String,
            GoalStore.TEMPLATE_NAME => payload["templateName"] as String,
            GoalStore.TARGET_TOTAL_MS => (payload["targetTotalMs"] as Long),
            GoalStore.TARGET_SEGMENTS_MS => payload["targetSegmentsMs"] as Array<Long>,
            GoalStore.RECEIVED_AT_MS => Toybox.Time.now().value().toLong() * 1000l
        };
        GoalStore.save(goal);
    }

    function _sendHelloAck(echoId as String) as Void {
        var env = MessageProtocol.envelope(
            MessageProtocol.T_HELLO_ACK,
            echoId,
            {
                "device" => System.getDeviceSettings().partNumber,
                "appVersion" => "1.0.0"
            });
        _transmit(env);
    }

    function _transmit(env as Dictionary) as Void {
        Communications.transmit(
            env,
            null,
            new PhoneTransmitListener());
    }
}

class PhoneTransmitListener extends Communications.ConnectionListener {
    function initialize() {
        ConnectionListener.initialize();
    }
    function onComplete() as Void {}
    function onError() as Void {
        // Swallow — entry remains in outbox and will retry on next hello.
    }
}
