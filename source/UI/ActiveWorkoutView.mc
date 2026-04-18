//
//  ActiveWorkoutView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Main workout screen. Drives the WorkoutEngine and refreshes every tick
// via a 500 ms Timer — matches the cadence of the iOS watch app.
//
// Layout (round display assumed):
//   ┌─────────────┐
//   │  Run 1/8    │  segment label + counter (accent color)
//   │             │
//   │    00:42    │  segment elapsed (large)
//   │             │
//   │  Total 00:42│  total elapsed (secondary)
//   │             │
//   │  →  SkiErg  │  next segment preview
//   └─────────────┘
class ActiveWorkoutView extends WatchUi.View {

    public var engine;           // WorkoutEngine
    public var hrProvider;       // HeartRateProvider
    public var recorder;         // ActivityRecorder
    public var goal;             // resolved goal Dictionary
    private var _tickTimer;      // Toybox.Timer.Timer

    function initialize(template as Dictionary) {
        View.initialize();
        engine = new WorkoutEngine(template);
        hrProvider = new HeartRateProvider(engine);
        recorder = new ActivityRecorder();
        goal = GoalStore.resolve(template);
        engine.start(ActiveWorkoutView.nowMs());
        hrProvider.enable();
        recorder.start();
    }

    function onShow() as Void {
        if (_tickTimer == null) {
            _tickTimer = new Toybox.Timer.Timer();
            _tickTimer.start(method(:onTick), 500, true);
        }
    }

    function onHide() as Void {
        if (_tickTimer != null) {
            _tickTimer.stop();
            _tickTimer = null;
        }
    }

    function onTick() as Void {
        hrProvider.sampleOnce();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Styles.COLOR_BACKGROUND);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        if (engine.isFinished()) {
            _drawFinished(dc, cx, h);
            return;
        }

        var segment = engine.currentSegment();
        if (segment == null) { return; }
        var type = segment[WorkoutSegment.TYPE] as String;
        var accent = Styles.colorForSegmentType(type);

        var nowMs = ActiveWorkoutView.nowMs();
        var segElapsed = engine.segmentElapsedMs(nowMs);
        var totElapsed = engine.totalElapsedMs(nowMs);

        // Top: segment label
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 68, Graphics.FONT_SMALL,
            segmentLabel(segment), Graphics.TEXT_JUSTIFY_CENTER);

        // Middle: segment elapsed (large)
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 36, Graphics.FONT_NUMBER_MEDIUM,
            Styles.formatElapsedMs(segElapsed), Graphics.TEXT_JUSTIFY_CENTER);

        // Secondary: total time
        dc.setColor(Styles.COLOR_TEXT_SECOND, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 18, Graphics.FONT_SMALL,
            "Total " + Styles.formatElapsedMs(totElapsed),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Bottom: next segment preview
        var next = engine.nextSegment();
        if (next != null) {
            dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 46, Graphics.FONT_XTINY,
                "→ " + segmentLabel(next), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Delta badge (top-right): cumulative delta vs target.
        var delta = DeltaCalculator.totalDeltaMs(engine, goal, nowMs);
        var deltaColor = delta > 0 ? Styles.COLOR_OVER : Styles.COLOR_UNDER;
        dc.setColor(deltaColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 88, Graphics.FONT_XTINY,
            Styles.formatDeltaMs(delta), Graphics.TEXT_JUSTIFY_CENTER);

        // Paused overlay
        if (EngineState.is(engine.state, EngineState.KIND_PAUSED)) {
            dc.setColor(Styles.COLOR_OVER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 68, Graphics.FONT_TINY,
                "PAUSED", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function _drawFinished(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 24, Graphics.FONT_MEDIUM,
            "FINISHED", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        var total = engine.totalElapsedMs(ActiveWorkoutView.nowMs());
        dc.drawText(cx, h / 2 + 4, Graphics.FONT_NUMBER_MEDIUM,
            Styles.formatElapsedMs(total), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Styles.COLOR_TEXT_SECOND, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 40, Graphics.FONT_XTINY,
            "Press BACK", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function segmentLabel(segment as Dictionary) as String {
        var type = segment[WorkoutSegment.TYPE] as String;
        if (type.equals(SegmentType.STATION)) {
            var kind = segment[WorkoutSegment.STATION_KIND] as String;
            return StationKind.displayName(kind);
        }
        if (type.equals(SegmentType.ROX_ZONE)) {
            return "ROX Zone";
        }
        // Run: include index (1/8 based on run count so far)
        return "Run " + _runCounter(segment) + "/8";
    }

    function _runCounter(currentSegment as Dictionary) as String {
        var segs = engine.template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var idx = engine.currentSegmentIndex();
        if (idx == null) { return "?"; }
        var count = 0;
        for (var i = 0; i <= idx; i += 1) {
            var t = (segs[i] as Dictionary)[WorkoutSegment.TYPE] as String;
            if (t.equals(SegmentType.RUN)) { count += 1; }
        }
        return count.toString();
    }

    static function nowMs() as Long {
        return Time.now().value().toLong() * 1000l;
    }
}
