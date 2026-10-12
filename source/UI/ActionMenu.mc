//
//  ActionMenu.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Pause / resume / end menu shown over a running workout (BACK button).
class ActionMenu extends WheelView {

    public var view as ActiveWorkoutView;

    function initialize(v as ActiveWorkoutView) {
        WheelView.initialize("WORKOUT");
        view = v;
        hintLabel = "OK";
        var list = [] as Array<Dictionary>;
        var eng = v.engine as WorkoutEngine;
        // The workout screen has no room for the running total — it is
        // one press away here (and on the paused screen).
        header2 = "TOTAL " + Styles.formatClock(eng.totalElapsedMs(ActiveWorkoutView.nowMs()));
        if (EngineState.is(eng.state, EngineState.KIND_RUNNING)) {
            list.add({ :id => "pause", :title => "PAUSE", :sub => "STOP THE CLOCK" });
        } else if (EngineState.is(eng.state, EngineState.KIND_PAUSED)) {
            list.add({ :id => "resume", :title => "RESUME", :sub => "RESTART THE CLOCK" });
        }
        list.add({ :id => "end", :title => "END WORKOUT", :sub => "SAVE & EXIT" });
        list.add({ :id => "discard", :title => "DISCARD", :sub => "EXIT, DON'T SAVE" });
        list.add({ :id => "cancel", :title => "CANCEL", :sub => "BACK TO WORKOUT" });
        setItems(list);
    }

    function activate() as Void {
        var id = selectedId();
        if (id == null) { return; }
        var nowMs = ActiveWorkoutView.nowMs();
        var engine = view.engine as WorkoutEngine;

        if (id.equals("pause")) {
            engine.pause(nowMs);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.requestUpdate();
            return;
        }
        if (id.equals("resume")) {
            engine.resume(nowMs);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.requestUpdate();
            return;
        }
        if (id.equals("end")) {
            if (!engine.isFinished()) { engine.finish(nowMs); }
            view.hrProvider.disable();
            view.recorder.stop();
            // Serialize & queue for phone transmission.
            view.submitIfFinished();
            view.detachFromApp();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.switchToView(
                new ResultView(engine),
                new ResultViewDelegate(),
                WatchUi.SLIDE_LEFT);
            return;
        }
        if (id.equals("discard")) {
            // Abort path: drop the FIT session, skip codec/storage entirely
            // so neither Garmin Connect nor the phone outbox sees this run.
            if (!engine.isFinished()) { engine.finish(nowMs); }
            view.hrProvider.disable();
            view.recorder.discard();
            // Without this the app-shutdown safety net would still find
            // the finished engine and queue the discarded workout.
            view.markDiscarded();
            view.detachFromApp();
            WatchUi.popView(WatchUi.SLIDE_DOWN);  // close ActionMenu
            WatchUi.popView(WatchUi.SLIDE_RIGHT); // close ActiveWorkoutView → home
            return;
        }
        // cancel
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function back() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
