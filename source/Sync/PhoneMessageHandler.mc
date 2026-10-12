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
    // Outbox parts waiting to go out: [ { "id", "i", "n" }, ... ]. Payloads
    // stay in storage until their turn so the queue itself costs nothing.
    private var _sendQueue;
    private var _sending;

    function initialize() {
        _registered = false;
        _sendQueue = [];
        _sending = false;
    }

    function register() as Void {
        if (_registered) { return; }
        // Debug / unit-test builds run in the simulator, which has no phone
        // and pops a "no data connection" alert on every transmit.
        if (!phoneLinkEnabled()) { return; }
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
        // 콜백 안에서 잡히지 않은 예외는 앱 전체를 죽인다. 운동 중에도 호출되므로 통째로 감싼다.
        try {
            _handlePhoneMessage(msg);
        } catch (ex) {
            System.println("phone message dropped: " + ex.getErrorMessage());
        }
    }

    function _handlePhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        if (!(msg.data instanceof Dictionary)) { return; }
        var data = msg.data as Dictionary;
        var type = data[MessageProtocol.K_TYPE] as String;
        var id = data[MessageProtocol.K_ID] as String;
        if (type == null) { return; }

        if (type.equals(MessageProtocol.T_HELLO)) {
            // First successful hello unlocks the app (pairing gate). If the
            // watch was showing PairingRequiredView it will remain on screen
            // until the user presses SELECT to re-enter — we don't force-
            // switch views here because the user may be mid-read.
            PairingStore.recordHello();
            _sendHelloAck(id);
            // 재연결마다 오는 hello 에서 outbox 전체를 읽어 보내면 운동 중 힙이 모자란다.
            if (!_workoutInProgress()) { flushOutbox(); }
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

    function _workoutInProgress() as Boolean {
        var engine = getApp().activeEngine;
        return engine != null && !engine.isFinished();
    }

    // Queues every unsynced part and starts sending. Parts go out one at a
    // time — the next is transmitted only when the previous one completes —
    // because the transmit queue is short and rejects a burst.
    function flushOutbox() as Void {
        if (_sending) { return; }
        // No phone link (debug build): leave everything in the outbox.
        if (!phoneLinkEnabled()) { return; }
        var entries = WorkoutStorage.list();
        _sendQueue = [];
        for (var i = 0; i < entries.size(); i += 1) {
            var entry = entries[i] as Dictionary;
            if ((entry["synced"] as Boolean)) { continue; }
            var n = entry["n"] as Number;
            for (var p = 0; p < n; p += 1) {
                _sendQueue.add({ "id" => entry["id"], "i" => p, "n" => n });
            }
        }
        _sendNextPart();
    }

    function _sendNextPart() as Void {
        if (_sendQueue.size() == 0) {
            _sending = false;
            return;
        }
        var head = _sendQueue[0] as Dictionary;
        _sendQueue = _sendQueue.slice(1, null);
        var id = head["id"] as String;
        var i = head["i"] as Number;
        var n = head["n"] as Number;
        var part = WorkoutStorage.loadPart(id, i);
        if (part == null) {
            // Already acked and cleaned up while queued.
            _sendNextPart();
            return;
        }
        var env;
        if (n == 1) {
            env = MessageProtocol.envelope(MessageProtocol.T_WORKOUT_COMPLETED, id, part);
        } else {
            env = MessageProtocol.envelope(MessageProtocol.T_WORKOUT_PART, id, part);
            env[MessageProtocol.K_CHUNK] = { "i" => i, "n" => n };
        }
        _sending = true;
        try {
            Communications.transmit(env, null, new OutboxTransmitListener(self));
        } catch (ex) {
            System.println("transmit failed: " + ex.getErrorMessage());
            onPartFailed();
        }
    }

    function onPartSent() as Void {
        _sendNextPart();
    }

    // Stop here; everything stays in storage and the next hello retries.
    function onPartFailed() as Void {
        _sendQueue = [];
        _sending = false;
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
        if (!phoneLinkEnabled()) { return; }
        try {
            Communications.transmit(
                env,
                null,
                new PhoneTransmitListener());
        } catch (ex) {
            // 페이로드가 너무 크거나 링크가 없을 때. outbox 에 남아 다음 hello 에서 다시 시도한다.
            System.println("transmit failed: " + ex.getErrorMessage());
        }
    }
}

// Drives the outbox: next part on success, stop on failure.
class OutboxTransmitListener extends Communications.ConnectionListener {
    private var _handler;
    function initialize(handler as PhoneMessageHandler) {
        ConnectionListener.initialize();
        _handler = handler;
    }
    function onComplete() as Void {
        _handler.onPartSent();
    }
    function onError() as Void {
        _handler.onPartFailed();
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

// Phone link switch. Release builds (store .iq, `RELEASE=1 scripts/build.sh`)
// always talk to the phone. Debug and unit-test builds never do: they run in
// the Connect IQ simulator, where every Communications.transmit raises a
// blocking "There is no data connection" alert.
(:release)
function phoneLinkEnabled() as Boolean {
    return true;
}

(:debug)
function phoneLinkEnabled() as Boolean {
    return false;
}
