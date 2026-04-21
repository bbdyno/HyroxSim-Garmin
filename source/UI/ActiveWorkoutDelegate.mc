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

    function initialize(v as ActiveWorkoutView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() as Boolean {
        if (view.engine.isFinished()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        if (EngineState.is(view.engine.state, EngineState.KIND_RUNNING)) {
            view.engine.advance(ActiveWorkoutView.nowMs());
            // Mirror segment boundaries to Garmin Activity laps. The watch
            // OS announces these as "Lap N" (TTS string is not Connect IQ
            // configurable as of SDK 9.1), so we layer a type-specific
            // vibration pattern below for tactile distinction between
            // Run / ROX Zone / Station.
            view.recorder.lap();
            _vibrateForCurrentSegment();
            WatchUi.requestUpdate();
        }
        return true;
    }

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
