//
//  ResultView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Post-workout summary: total time + per-segment breakdown.
// Scroll with up/down buttons or swipe.
class ResultView extends WatchUi.View {

    public var engine;
    private var _scroll;    // Number — pixel offset

    function initialize(eng as WorkoutEngine) {
        View.initialize();
        engine = eng;
        _scroll = 0;
    }

    function scrollBy(delta as Number) as Void {
        _scroll += delta;
        if (_scroll < 0) { _scroll = 0; }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Styles.COLOR_BACKGROUND);
        dc.clear();

        var w = dc.getWidth();
        var cx = w / 2;
        var y = 16 - _scroll;

        // Header: total time
        var totalMs = engine.totalElapsedMs(ActiveWorkoutView.nowMs());
        dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, "Total", Graphics.TEXT_JUSTIFY_CENTER);
        y += 20;
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_NUMBER_MEDIUM,
            Styles.formatElapsedMs(totalMs), Graphics.TEXT_JUSTIFY_CENTER);
        y += 44;

        // Per-segment breakdown
        var records = engine.records;
        for (var i = 0; i < records.size(); i += 1) {
            var rec = records[i] as Dictionary;
            var type = rec[SegmentRecord.TYPE] as String;
            var label;
            var name = rec[SegmentRecord.STATION_DISPLAY_NAME];
            if (name != null) {
                label = name as String;
            } else if (type.equals(SegmentType.RUN)) {
                label = "Run";
            } else {
                label = "ROX";
            }
            dc.setColor(Styles.colorForSegmentType(type), Graphics.COLOR_TRANSPARENT);
            dc.drawText(20, y, Graphics.FONT_TINY, label,
                Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 20, y, Graphics.FONT_TINY,
                Styles.formatElapsedMs(SegmentRecord.activeDurationMs(rec)),
                Graphics.TEXT_JUSTIFY_RIGHT);
            y += 20;
        }
    }
}

class ResultViewDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0];
        if (view instanceof ResultView) {
            view.scrollBy(32);
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0];
        if (view instanceof ResultView) {
            view.scrollBy(-32);
        }
        return true;
    }

    function onBack() as Boolean {
        // Return to home (skip the ActiveWorkoutView that's been replaced).
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
