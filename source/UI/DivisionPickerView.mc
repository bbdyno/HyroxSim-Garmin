//
//  DivisionPickerView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Uses Connect IQ's Menu2 for a scrollable, touch+button compatible list.
// Selecting a division pushes the RoxZoneTogglePicker — the user picks
// ROX ZONE ON or OFF, then ActiveWorkoutView starts. The toggle is per-
// launch (not stored), mirroring how iOS treats `usesRoxZone` as part of
// the template choice rather than a global setting.
class DivisionPickerView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => "Division" });
        var all = HyroxDivision.all();
        for (var i = 0; i < all.size(); i += 1) {
            var d = all[i] as String;
            addItem(new MenuItem(
                HyroxDivision.shortName(d),
                HyroxDivision.displayName(d),
                d,
                null
            ));
        }
    }
}

class DivisionPickerDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) as Void {
        var division = item.getId() as String;
        WatchUi.pushView(
            new RoxZoneTogglePicker(division),
            new RoxZoneTogglePickerDelegate(division),
            WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// Two-row picker that decides whether the upcoming HYROX session keeps
// ROX zones (default, 31 segments) or strips them (16 segments). State
// is intentionally NOT persisted — the next entry to DivisionPicker
// always starts from ON, matching the official HYROX format.
class RoxZoneTogglePicker extends WatchUi.Menu2 {

    function initialize(division as String) {
        Menu2.initialize({ :title => "Rox Zone" });
        addItem(new MenuItem("Rox Zone ON",  "31 segments",        "on",  null));
        addItem(new MenuItem("Rox Zone OFF", "Skip transitions",   "off", null));
    }
}

class RoxZoneTogglePickerDelegate extends WatchUi.Menu2InputDelegate {

    private var _division as String;

    function initialize(division as String) {
        Menu2InputDelegate.initialize();
        _division = division;
    }

    function onSelect(item as MenuItem) as Void {
        var template = WorkoutTemplate.hyroxPreset(_division);
        if ((item.getId() as String).equals("off")) {
            // Drop the materialized ROX zones; engine + UI use SEGMENTS as
            // the only source of truth so flipping the flag without also
            // pruning the array would leave stale ROX entries running.
            template[WorkoutTemplate.SEGMENTS]      = WorkoutTemplate.logicalSegments(template);
            template[WorkoutTemplate.USES_ROX_ZONE] = false;
        }
        var view = new ActiveWorkoutView(template);
        var delegate = new ActiveWorkoutDelegate(view);
        WatchUi.switchToView(view, delegate, WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
