//
//  HomeView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Lang;
import Toybox.WatchUi;

// Menu2-based home. Shows:
//   1. Saved templates pushed from phone (TemplateStore)
//   2. "HYROX Presets" entry → DivisionPickerView
//
// Labels are English — fenix7 default fonts render CJK as missing-glyph
// diamonds. If/when a CJK-capable font is bundled, revisit per-language
// strings.
class HomeView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => "HyroxSim" });
        _populate();
    }

    function _populate() as Void {
        addItem(new MenuItem(
            "HYROX Presets",
            "9 divisions",
            "presets",
            null
        ));
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
        // No custom templates and no prior phone handshake → show a
        // gentle hint to drive users toward the companion app.
        if (templates.size() == 0 && !PairingStore.isPaired()) {
            addItem(new MenuItem(
                "Install phone app",
                "Custom workouts + goals",
                "info:phone",
                null
            ));
        }
    }

    function _subLabelFor(template as Dictionary) as String {
        var stations = WorkoutTemplate.stationCount(template);
        var rox = (template[WorkoutTemplate.USES_ROX_ZONE] as Boolean) ? "ROX on" : "ROX off";
        return stations.toString() + " stations / " + rox;
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
        if (id.equals("info:phone")) {
            // Info-only entry; no action. Future: push a dedicated view
            // with pairing instructions + QR-like guidance.
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
