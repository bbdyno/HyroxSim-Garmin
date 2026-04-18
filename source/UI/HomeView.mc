//
//  HomeView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Lang;
import Toybox.WatchUi;

// Menu2-based landing. Shows (in order):
//   1. User-pushed custom templates from iOS/Android (phone → TemplateStore)
//   2. A "HYROX 프리셋" entry that drills into the 9-division picker
//
// Selecting any saved template launches ActiveWorkoutView with that
// template (including `usesRoxZone=false` variants). Selecting the preset
// entry pushes DivisionPickerView which builds `WorkoutTemplate.hyroxPreset`
// on demand.
class HomeView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => "HyroxSim" });
        _populate();
    }

    function _populate() as Void {
        var templates = TemplateStore.list();
        for (var i = 0; i < templates.size(); i += 1) {
            var t = templates[i] as Dictionary;
            var name = t[WorkoutTemplate.NAME] as String;
            var sub = _subLabelFor(t);
            addItem(new MenuItem(
                name,
                sub,
                "tpl:" + (t[WorkoutTemplate.ID] as String),
                null
            ));
        }
        addItem(new MenuItem(
            "HYROX 프리셋",
            "9 디비전 중 선택",
            "presets",
            null
        ));
    }

    function _subLabelFor(template as Dictionary) as String {
        var stations = WorkoutTemplate.stationCount(template);
        var rox = (template[WorkoutTemplate.USES_ROX_ZONE] as Boolean) ? "ROX on" : "ROX off";
        return stations.toString() + " stations · " + rox;
    }
}

class HomeViewDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("presets")) {
            WatchUi.pushView(
                new DivisionPickerView(),
                new DivisionPickerDelegate(),
                WatchUi.SLIDE_LEFT);
            return;
        }
        if (id.find("tpl:") == 0) {
            var rawId = id.substring(4, id.length());
            var template = TemplateStore.findById(rawId);
            if (template != null) {
                var view = new ActiveWorkoutView(template);
                var delegate = new ActiveWorkoutDelegate(view);
                WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT);
            }
        }
    }

    function onBack() as Void {
        // Default behavior — close app on back from home.
    }
}
