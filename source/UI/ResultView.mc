//
//  ResultView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Finish summary, shared by ResultView and the natural-finish state of
// ActiveWorkoutView. Everything is computed once — a finished engine no
// longer changes.
//
//          FINISH            caption ("ENDED EARLY" when cut short)
//         1:14:32            total time — the hero
//          -0:28             against the goal
//      BURPEE BJ +0:34       the station that cost the most time
//
// The ring shows every block gold (beat its goal) or orange (did not).
class ResultSummary {

    public var states as Array<Number>;
    public var totalMs as Long;
    public var deltaMs as Long;
    public var complete as Boolean;
    public var worstLine as String?;
    public var worstBehind as Boolean;

    function initialize(engine as WorkoutEngine, goal as Dictionary) {
        var segs = (engine.template as Dictionary)[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var records = engine.records as Array;
        var targets = goal[GoalStore.TARGET_SEGMENTS_MS] as Array?;

        states = RingModel.blockStates(
            RingModel.blockMap(segs), RingModel.durations(records), targets, null);
        totalMs = engine.totalElapsedMs(ActiveWorkoutView.nowMs());
        complete = records.size() >= segs.size();
        deltaMs = RingModel.finishDeltaMs(
            totalMs, records.size(), segs.size(), targets,
            (goal[GoalStore.TARGET_TOTAL_MS] as Number or Long).toLong());

        worstLine = null;
        worstBehind = false;
        var worst = RingModel.worstStation(records, targets);
        if (worst >= 0 && worst < segs.size()) {
            var kind = (segs[worst] as Dictionary)[WorkoutSegment.STATION_KIND];
            var delta = SegmentRecord.activeDurationMs(records[worst] as Dictionary)
                - ((targets as Array)[worst] as Number or Long).toLong();
            worstLine = (kind != null ? StationKind.shortName(kind as String) : "STATION")
                + " " + Styles.formatDelta(delta);
            worstBehind = delta > 0l;
        }
    }

    function draw(dc as Graphics.Dc) as Void {
        var cap = Fonts.cap();
        Ring.draw(dc, states, states.size(), null);
        Ui.text(dc, 100, 46, cap, Palette.GREY,
            complete ? "FINISH" : "ENDED EARLY", Ui.CENTER);
        Ui.text(dc, 100, 84, Fonts.big(), Styles.COLOR_TEXT,
            Styles.formatClock(totalMs), Ui.CENTER);
        Ui.text(dc, 100, 117, Fonts.mid(), Styles.colorForDelta(deltaMs),
            Styles.formatDelta(deltaMs), Ui.CENTER);
        if (worstLine != null) {
            Ui.text(dc, 100, 153, cap,
                worstBehind ? Palette.ORANGE : Palette.GOLD,
                worstLine as String, Ui.CENTER);
        }
    }
}

// Post-workout screen (End workout → here). Page 0 is the summary; DOWN
// pages through the splits, four segments per page:
//
//   ▌ RUN 1            4:10      label + time
//   ▌ GOAL 4:24       -0:14      goal + delta (gold ahead / orange behind)
//
// All rows share one column, inset to clear the round bezel.
class ResultView extends WatchUi.View {

    static const ROWS_PER_PAGE = 4;

    public var engine;
    private var _goal as Dictionary;
    private var _summary as ResultSummary;
    private var _page as Number;

    function initialize(eng as WorkoutEngine) {
        View.initialize();
        engine = eng;
        _goal = GoalStore.resolve(eng.template);
        _summary = new ResultSummary(eng, _goal);
        _page = 0;
    }

    function pageCount() as Number {
        var rows = ((engine as WorkoutEngine).records as Array).size();
        return 1 + (rows + ROWS_PER_PAGE - 1) / ROWS_PER_PAGE;
    }

    // Moves by whole pages; clamps at both ends.
    function scrollBy(deltaPages as Number) as Void {
        var target = _page + deltaPages;
        var last = pageCount() - 1;
        if (target < 0) { target = 0; }
        if (target > last) { target = last; }
        if (target != _page) {
            _page = target;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var cap = Fonts.cap();
        var pages = pageCount();

        if (_page == 0) {
            _summary.draw(dc);
            if (pages > 1) {
                // More below: caption + a small down arrow.
                Ui.text(dc, 100, 169, cap, Palette.DIM, "SPLITS", Ui.CENTER);
                var ax = Ui.px(dc, 100);
                var ay = Ui.px(dc, 177.5);
                var s = Ui.px(dc, 3.5);
                dc.setColor(Palette.DIM, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[ax - s, ay], [ax + s, ay], [ax, ay + s]] as Array<Graphics.Point2D>);
            }
            Ui.hint(dc, false, "DONE");
            return;
        }

        var records = (engine as WorkoutEngine).records as Array;
        Ui.text(dc, 100, 27, cap, Palette.GOLD, "SPLITS", Ui.CENTER);
        var first = (_page - 1) * ROWS_PER_PAGE;
        for (var row = 0; row < ROWS_PER_PAGE; row += 1) {
            var idx = first + row;
            if (idx >= records.size()) { break; }
            _drawRow(dc, records, idx, 41 + row * 29, 29, row > 0);
        }
        Ui.text(dc, 100, 172, cap, Palette.DIM,
            _page.toString() + " / " + (pages - 1).toString(), Ui.CENTER);
    }

    private function _drawRow(
            dc as Graphics.Dc,
            records as Array,
            idx as Number,
            top as Number,
            height as Number,
            divider as Boolean) as Void {
        var rec = records[idx] as Dictionary;
        var type = rec[SegmentRecord.TYPE] as String;
        var cap = Fonts.cap();

        // One column for every row: as wide as the first row's top edge,
        // the narrowest point of the list on a round screen.
        var half = Ui.halfChord(97, 41);
        var left = 100 - half + 5;
        var right = 100 + half - 5;

        if (divider) { Ui.hairline(dc, top, left, right); }

        var barColor = Palette.GREY;
        if (type.equals(SegmentType.RUN)) { barColor = Palette.BLUE; }
        if (type.equals(SegmentType.STATION)) { barColor = Palette.GOLD; }
        dc.setColor(barColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(Ui.px(dc, left), Ui.px(dc, top + 5), Ui.px(dc, 2.5), Ui.px(dc, height - 10));

        var textLeft = left + 7;
        var y1 = top + 9;
        var y2 = top + 21;
        var durMs = SegmentRecord.activeDurationMs(rec);
        Ui.text(dc, textLeft, y1, cap, Styles.COLOR_TEXT, _rowLabel(rec, records, idx), Ui.LEFT);
        Ui.text(dc, right, y1, cap, Styles.COLOR_TEXT, Styles.formatClock(durMs), Ui.RIGHT);

        var targets = _goal[GoalStore.TARGET_SEGMENTS_MS] as Array?;
        if (targets != null && idx < targets.size() && targets[idx] != null) {
            var targetMs = (targets[idx] as Number or Long).toLong();
            var deltaMs = durMs - targetMs;
            Ui.text(dc, textLeft, y2, cap, Palette.DIM,
                "GOAL " + Styles.formatClock(targetMs), Ui.LEFT);
            Ui.text(dc, right, y2, cap, Styles.colorForDelta(deltaMs),
                Styles.formatDelta(deltaMs), Ui.RIGHT);
        }
    }

    private function _rowLabel(rec as Dictionary, records as Array, idx as Number) as String {
        var type = rec[SegmentRecord.TYPE] as String;
        if (type.equals(SegmentType.STATION)) {
            var segs = ((engine as WorkoutEngine).template as Dictionary)[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
            var segIndex = rec[SegmentRecord.INDEX] as Number;
            if (segIndex >= 0 && segIndex < segs.size()) {
                var kind = (segs[segIndex] as Dictionary)[WorkoutSegment.STATION_KIND];
                if (kind != null) { return StationKind.shortName(kind as String); }
            }
            return "STATION";
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
        return "ROX ZONE";
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
            view.scrollBy(1);
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.scrollBy(-1);
        }
        return true;
    }

    function onBack() as Boolean {
        // Return to home (skip the ActiveWorkoutView that's been replaced).
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
