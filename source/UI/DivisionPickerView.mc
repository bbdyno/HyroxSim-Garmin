//
//  DivisionPickerView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The nine HYROX divisions. Selecting one pushes the RoxZoneTogglePicker —
// the user picks ROX ZONE ON or OFF, then ActiveWorkoutView starts. The
// toggle is per-launch (not stored), mirroring how iOS treats `usesRoxZone`
// as part of the template choice rather than a global setting.
class DivisionPickerView extends WheelView {

    function initialize() {
        WheelView.initialize("DIVISION");
        hintLabel = "OK";
        var stored = GoalStore.load();
        var all = HyroxDivision.all();
        var list = [] as Array<Dictionary>;
        for (var i = 0; i < all.size(); i += 1) {
            var d = all[i] as String;
            // Phone-pushed goal when there is one for this division,
            // otherwise the reference finish time.
            var timeLabel;
            if (stored != null && (stored[GoalStore.DIVISION] as String).equals(d)) {
                timeLabel = "GOAL " + Styles.formatClock(
                    (stored[GoalStore.TARGET_TOTAL_MS] as Number or Long).toLong());
            } else {
                timeLabel = "REF " + Styles.formatClock(
                    PaceReference.referenceTotalSeconds(d).toLong() * 1000l);
            }
            list.add({
                :id => d,
                :title => HyroxDivision.categoryLabel(d),
                :peek => HyroxDivision.categoryLabel(d) + " " + HyroxDivision.formatLabel(d),
                :sub => HyroxDivision.formatLabel(d) + " " + timeLabel
            });
        }
        setItems(list);
    }

    function activate() as Void {
        var division = selectedId();
        if (division == null) { return; }
        var picker = new RoxZoneTogglePicker(division);
        WatchUi.pushView(picker, new WheelDelegate(picker), WatchUi.SLIDE_LEFT);
    }

    function back() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

// Two-row picker that decides whether the upcoming HYROX session keeps
// ROX zones (default, 31 segments) or strips them (16 segments). State
// is intentionally NOT persisted — the next entry to DivisionPicker
// always starts from ON, matching the official HYROX format.
class RoxZoneTogglePicker extends WheelView {

    private var _division as String;

    function initialize(division as String) {
        WheelView.initialize("ROX ZONE");
        _division = division;
        hintLabel = "START";
        setItems([
            { :id => "on",  :title => "ROX ZONE ON",  :sub => "OFFICIAL · 31 PARTS" },
            { :id => "off", :title => "ROX ZONE OFF", :sub => "NO ROX · 16 PARTS" }
        ] as Array<Dictionary>);
    }

    function activate() as Void {
        var id = selectedId();
        if (id == null) { return; }
        var template = WorkoutTemplate.hyroxPreset(_division);
        if (id.equals("off")) {
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

    function back() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
