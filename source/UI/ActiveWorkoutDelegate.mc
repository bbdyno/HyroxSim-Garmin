//
//  ActiveWorkoutDelegate.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

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
            WatchUi.requestUpdate();
        }
        return true;
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
}
