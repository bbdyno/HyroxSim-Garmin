//
//  ActiveWorkoutDelegate.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Attention;
import Toybox.Lang;
import Toybox.WatchUi;

// Input mapping:
//   SELECT (CIQ action button)  → advance to next segment (or finish if last)
//   MENU   (long-press / button) → open action menu (pause/resume/end)
//   BACK                         → exit to home (confirmation on active workout)
class ActiveWorkoutDelegate extends WatchUi.BehaviorDelegate {

    public var view;    // ActiveWorkoutView

    // Wall-clock ms of last physical SELECT (KEY_ENTER) press. onSelect()
    // refuses to advance unless this is recent — flips the previous tap-
    // blacklist into a key-whitelist so any touch dispatch path the
    // firmware happens to use (center, edges, bottom area) still can't
    // trigger advancement.
    private var _lastEnterMs as Long;

    function initialize(v as ActiveWorkoutView) {
        BehaviorDelegate.initialize();
        view = v;
        _lastEnterMs = 0l;
    }

    // InputDelegate hook fired when a physical key is first pressed —
    // before BehaviorDelegate maps the released event to onSelect. We do
    // NOT consume the event (return false) so BehaviorDelegate's normal
    // mapping still runs and onSelect fires. Touchscreen taps never come
    // through here, which is the entire point.
    function onKeyPressed(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() == WatchUi.KEY_ENTER) {
            _lastEnterMs = ActiveWorkoutView.nowMs();
        }
        return false;
    }

    function onSelect() as Boolean {
        var nowTs = ActiveWorkoutView.nowMs();
        // Whitelist: only advance if the physical SELECT button was just
        // pressed. If we got here without a recent KEY_ENTER, this onSelect
        // came from a touch dispatch (center tap, edge tap, bottom-area
        // tap, swipe-to-select on certain firmware) — block silently.
        if (_lastEnterMs == 0l || nowTs - _lastEnterMs > 500l) {
            return true;
        }
        _lastEnterMs = 0l;  // consume

        if (view.engine.isFinished()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        if (EngineState.is(view.engine.state, EngineState.KIND_RUNNING)) {
            view.engine.advance(nowTs);
            // NOTE: deliberately NOT calling view.recorder.lap() here.
            // Garmin OS speaks "Lap N" via TTS on every lap mark and CIQ
            // has no API to suppress just the number. We trade per-lap FIT
            // splits (still recoverable from our own SegmentRecord buffer)
            // for a quieter audio experience. Segment cue is delivered by
            // the tone + type-specific vibration below.
            Attention.playTone(Attention.TONE_INTERVAL_ALERT);
            _vibrateForCurrentSegment();
            WatchUi.requestUpdate();
        }
        return true;
    }

    // Consume every touchscreen click variant. Even though the whitelist
    // in onSelect already protects advancement, returning true here keeps
    // higher-level OS behaviors (focus rings, ripple feedback, edge-tap
    // glance shortcuts) from firing on any region of the screen.
    function onTap(event as WatchUi.ClickEvent) as Boolean { return true; }
    function onHold(event as WatchUi.ClickEvent) as Boolean { return true; }
    function onRelease(event as WatchUi.ClickEvent) as Boolean { return true; }

    private function _vibrateForCurrentSegment() as Void {
        var seg = view.engine.currentSegment();
        if (seg == null) { return; }
        var type = seg[WorkoutSegment.TYPE] as String;
        var pattern;
        if (type.equals(SegmentType.RUN)) {
            pattern = [
                new Attention.VibeProfile(100, 180),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(100, 180)
            ];
        } else if (type.equals(SegmentType.ROX_ZONE)) {
            pattern = [new Attention.VibeProfile(60, 250)];
        } else {
            pattern = [
                new Attention.VibeProfile(100, 140),
                new Attention.VibeProfile(0, 70),
                new Attention.VibeProfile(100, 140),
                new Attention.VibeProfile(0, 70),
                new Attention.VibeProfile(100, 140)
            ];
        }
        Attention.vibrate(pattern);
    }

    function onMenu() as Boolean {
        WatchUi.pushView(
            new ActionMenu(view.engine),
            new ActionMenuDelegate(view),
            WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() as Boolean {
        if (view.engine.isFinished()) {
            // Let the default back pop this view.
            return false;
        }
        // Block accidental exit during active workout — open the action menu.
        return onMenu();
    }

    // Block UP/DOWN buttons and touch swipes from falling through to the
    // watch OS widget chain. Without these the active workout view would
    // let the user "scroll away" mid-run (widget glances kick in on FR965).
    function onNextPage() as Boolean { return true; }
    function onPreviousPage() as Boolean { return true; }
    function onSwipe(event as WatchUi.SwipeEvent) as Boolean { return true; }
}
