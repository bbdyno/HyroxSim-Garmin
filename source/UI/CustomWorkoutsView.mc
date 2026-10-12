//
//  CustomWorkoutsView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/22/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Workouts built in the phone app and pushed to the watch. Pushed from
// HomeView when the user selects "MY WORKOUTS".
class CustomWorkoutsView extends WheelView {

    private var _templates as Array<Dictionary>;

    function initialize() {
        WheelView.initialize("MY WORKOUTS");
        hintLabel = "START";
        emptyTitle = "NO WORKOUTS";
        emptySub = "SEND FROM PHONE APP";
        _templates = [] as Array<Dictionary>;
        _reload();
    }

    function onShow() as Void {
        CustomWorkoutsViewRegistry.setActive(self);
        _reload();
    }

    function onHide() as Void {
        CustomWorkoutsViewRegistry.clearIfActive(self);
    }

    function refresh() as Void {
        _reload();
        WatchUi.requestUpdate();
    }

    function activateSelected() as Void {
        activate();
    }

    function activate() as Void {
        if (_templates.size() == 0) { return; }
        var t = _templates[selected] as Dictionary;
        var view = new ActiveWorkoutView(t);
        var delegate = new ActiveWorkoutDelegate(view);
        WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT);
    }

    function back() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    private function _reload() as Void {
        _templates = TemplateStore.list();
        var list = [] as Array<Dictionary>;
        for (var i = 0; i < _templates.size(); i += 1) {
            var t = _templates[i] as Dictionary;
            var rox = (t[WorkoutTemplate.USES_ROX_ZONE] as Boolean) ? " + ROX" : "";
            list.add({
                :id => t[WorkoutTemplate.ID] as String,
                :title => (t[WorkoutTemplate.NAME] as String).toUpper(),
                :sub => WorkoutTemplate.stationCount(t).toString() + " STATIONS" + rox
            });
        }
        setItems(list);
    }
}

module CustomWorkoutsViewRegistry {
    var _active as CustomWorkoutsView? = null;

    function setActive(v as CustomWorkoutsView) as Void { _active = v; }

    function clearIfActive(v as CustomWorkoutsView) as Void {
        if (_active == v) { _active = null; }
    }

    function refreshIfVisible() as Void {
        if (_active != null) { _active.refresh(); }
    }
}
