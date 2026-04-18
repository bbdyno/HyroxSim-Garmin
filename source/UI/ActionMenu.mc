//
//  ActionMenu.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Lang;
import Toybox.WatchUi;

// Modal menu for pause/resume/end during a workout. Built from Menu2 so it
// works across touch + button devices.
class ActionMenu extends WatchUi.Menu2 {

    public var engine;

    function initialize(eng as WorkoutEngine) {
        Menu2.initialize({ :title => "Actions" });
        engine = eng;
        if (EngineState.is(eng.state, EngineState.KIND_RUNNING)) {
            addItem(new MenuItem("Pause", null, "pause", null));
        } else if (EngineState.is(eng.state, EngineState.KIND_PAUSED)) {
            addItem(new MenuItem("Resume", null, "resume", null));
        }
        addItem(new MenuItem("End workout", "Save & exit", "end", null));
        addItem(new MenuItem("Cancel", null, "cancel", null));
    }
}

class ActionMenuDelegate extends WatchUi.Menu2InputDelegate {

    public var view;

    function initialize(v as ActiveWorkoutView) {
        Menu2InputDelegate.initialize();
        view = v;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId() as String;
        var nowMs = ActiveWorkoutView.nowMs();
        var engine = view.engine;

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
            engine.finish(nowMs);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.switchToView(
                new ResultView(engine),
                new ResultViewDelegate(),
                WatchUi.SLIDE_LEFT);
            return;
        }
        // cancel
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
