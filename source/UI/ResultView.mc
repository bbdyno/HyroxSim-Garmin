//
//  ResultView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Post-workout summary. Two zones:
//   1. Sticky header — "FINISHED" + big total time (never scrolls)
//   2. Scrollable list — per-segment breakdown with colored type dots
// Scroll via UP/DOWN buttons or touch swipe. Row-height aligned so one
// press moves exactly one row; clamps to content bounds on both ends.
class ResultView extends WatchUi.View {

    public var engine;
    private var _goal;           // Dictionary (GoalStore shape) — always resolved
    private var _hasExplicitGoal;
    private var _scroll;         // current visual px offset
    private var _targetScroll;   // tween target px offset
    private var _rowH;           // cached row height (set during onUpdate)
    private var _maxScroll;      // cached upper clamp (set during onUpdate)
    private var _animTimer;

    function initialize(eng as WorkoutEngine) {
        View.initialize();
        engine = eng;
        var stored = GoalStore.load();
        var division = engine.template[WorkoutTemplate.DIVISION] as String;
        _hasExplicitGoal = (stored != null
                && (stored[GoalStore.DIVISION] as String).equals(division));
        _goal = GoalStore.resolve(engine.template);
        _scroll = 0;
        _targetScroll = 0;
        _rowH = 0;
        _maxScroll = 0;
        _animTimer = null;
    }

    function onHide() as Void {
        if (_animTimer != null) {
            _animTimer.stop();
            _animTimer = null;
        }
    }

    function scrollBy(deltaRows as Number) as Void {
        var step = _rowH > 0 ? _rowH : 60;
        _targetScroll += deltaRows * step;
        if (_targetScroll < 0) { _targetScroll = 0; }
        if (_targetScroll > _maxScroll) { _targetScroll = _maxScroll; }
        _startAnim();
    }

    private function _startAnim() as Void {
        if (_animTimer != null) { return; }
        _animTimer = new Timer.Timer();
        _animTimer.start(method(:_onAnimTick), 30, true);
    }

    // Tweens _scroll toward _targetScroll with 25% easing — settles in
    // ~6-7 frames (~200 ms at 30 ms interval).
    function _onAnimTick() as Void {
        var diff = _targetScroll - _scroll;
        if (diff > 3 || diff < -3) {
            _scroll += diff / 4;
            WatchUi.requestUpdate();
        } else {
            _scroll = _targetScroll;
            WatchUi.requestUpdate();
            if (_animTimer != null) {
                _animTimer.stop();
                _animTimer = null;
            }
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Styles.COLOR_BACKGROUND);
        dc.clear();
        dc.setAntiAlias(true);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var centerJust = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var leftVJust = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var rightVJust = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;

        // --- Sticky header (32% of screen) ---
        var headerH = (h * 0.32).toNumber();

        dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        var labelY = (headerH * 0.26).toNumber();
        dc.drawText(cx, labelY, Graphics.FONT_TINY, "FINISHED", centerJust);
        var labelHalf = dc.getFontHeight(Graphics.FONT_TINY) / 2;
        dc.fillRectangle(cx - 34, labelY + labelHalf + 2, 68, 2);

        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        var totalMs = engine.totalElapsedMs(ActiveWorkoutView.nowMs());
        dc.drawText(cx, (headerH * 0.58).toNumber(), Graphics.FONT_NUMBER_MEDIUM,
            Styles.formatElapsedMs(totalMs), centerJust);

        // Total delta — green (ahead) / red (behind), always shown.
        var totalTargetMs = _goal[GoalStore.TARGET_TOTAL_MS] as Long;
        var totalDeltaMs = totalMs - totalTargetMs;
        var totalDeltaColor = totalDeltaMs > 0 ? Styles.COLOR_OVER : Styles.COLOR_UNDER;
        dc.setColor(totalDeltaColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (headerH * 0.90).toNumber(), Graphics.FONT_XTINY,
            Styles.formatDeltaMs(totalDeltaMs), centerJust);

        // Thin divider between header & list
        dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(24, headerH, w - 48, 1);

        // --- Scroll list area ---
        var listTop = headerH + 4;
        var listBot = h - 4;
        var listVisH = listBot - listTop;
        var rowH = 68;
        _rowH = rowH;

        var records = engine.records;
        var contentH = records.size() * rowH;
        _maxScroll = contentH > listVisH ? contentH - listVisH : 0;
        if (_scroll > _maxScroll) { _scroll = _maxScroll; }

        dc.setClip(0, listTop, w, listVisH);

        for (var i = 0; i < records.size(); i += 1) {
            var rowY = listTop + i * rowH - _scroll;
            if (rowY + rowH < listTop || rowY > listBot) {
                continue;  // off-screen, skip draw
            }
            _drawRow(dc, records[i] as Dictionary, records, i, rowY, rowH, w);
        }

        dc.clearClip();

        // --- Scrollbar on right edge (only when scrollable) ---
        if (_maxScroll > 0) {
            var trackTop = listTop + 8;
            var trackH = listVisH - 16;
            var barH = (trackH.toFloat() * listVisH / contentH).toNumber();
            if (barH < 24) { barH = 24; }
            var barY = trackTop + ((trackH - barH).toFloat() * _scroll / _maxScroll).toNumber();
            dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(w - 6, barY, 3, barH, 2);
        }
    }

    private function _drawRow(
            dc as Graphics.Dc,
            rec as Dictionary,
            records as Array,
            idx as Number,
            rowY as Number,
            rowH as Number,
            w as Number) as Void {
        var type = rec[SegmentRecord.TYPE] as String;
        var typeColor = Styles.colorForSegmentType(type);

        // Two-line row: top line = label + duration, bottom line = delta.
        // Split the row with ~14 px breathing room between lines so FONT_XTINY
        // (height ~20 px on fr965) never overlaps.
        var y1 = rowY + rowH * 0.30;   // label/time line (center)
        var y2 = rowY + rowH * 0.74;   // delta line (center)
        var leftJust = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var rightJust = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;

        // Colored type pill at left, spans both rows.
        dc.setColor(typeColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(14, rowY + 6, 4, rowH - 12, 2);

        // Top-left: label
        var label = _rowLabel(rec, records, idx);
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(26, y1, Graphics.FONT_XTINY, label, leftJust);

        // Top-right: actual duration
        var durMs = SegmentRecord.activeDurationMs(rec);
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 16, y1, Graphics.FONT_XTINY,
            Styles.formatElapsedMs(durMs), rightJust);

        // Bottom-right: delta vs target for this segment, if index is in range.
        var targets = _goal[GoalStore.TARGET_SEGMENTS_MS] as Array<Long>;
        if (targets != null && idx < targets.size()) {
            var targetMs = targets[idx] as Long;
            var deltaMs = durMs - targetMs;
            var deltaColor = deltaMs > 0 ? Styles.COLOR_OVER : Styles.COLOR_UNDER;
            dc.setColor(deltaColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 16, y2, Graphics.FONT_XTINY,
                Styles.formatDeltaMs(deltaMs), rightJust);
        }
    }

    private function _rowLabel(rec as Dictionary, records as Array, idx as Number) as String {
        var type = rec[SegmentRecord.TYPE] as String;
        var name = rec[SegmentRecord.STATION_DISPLAY_NAME];
        if (name != null) {
            return (name as String).toUpper();
        }
        if (type.equals(SegmentType.RUN)) {
            var runIdx = 0;
            for (var i = 0; i <= idx; i += 1) {
                var r = records[i] as Dictionary;
                if ((r[SegmentRecord.TYPE] as String).equals(SegmentType.RUN)) {
                    runIdx += 1;
                }
            }
            return "RUN " + runIdx.toString();
        }
        return "ROX";
    }
}

class ResultViewDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0];
        if (view instanceof ResultView) {
            view.scrollBy(1);
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0];
        if (view instanceof ResultView) {
            view.scrollBy(-1);
        }
        return true;
    }

    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        var view = WatchUi.getCurrentView()[0];
        if (!(view instanceof ResultView)) { return true; }
        var dir = event.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            view.scrollBy(2);
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.scrollBy(-2);
        }
        return true;
    }

    function onBack() as Boolean {
        // Return to home (skip the ActiveWorkoutView that's been replaced).
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
