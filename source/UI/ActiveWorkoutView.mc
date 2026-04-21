//
//  ActiveWorkoutView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Activity;
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
    public var goal;             // resolved goal Dictionary or null when free-tier
    public var hasExplicitGoal;  // true only when phone-pushed goal is active
    private var _tickTimer;      // Toybox.Timer.Timer

    function initialize(template as Dictionary) {
        View.initialize();
        engine = new WorkoutEngine(template);
        hrProvider = new HeartRateProvider(engine);
        recorder = new ActivityRecorder();
        // Goal resolution: use phone-pushed goal if division matches, else
        // fall back to PaceReference defaults so delta is always shown.
        // `hasExplicitGoal` drives UI emphasis (bright red/green when paired
        // vs dim grey when estimated).
        var storedGoal = GoalStore.load();
        hasExplicitGoal = (storedGoal != null
                && (storedGoal[GoalStore.DIVISION] as String).equals(
                    template[WorkoutTemplate.DIVISION] as String));
        goal = GoalStore.resolve(template);
        engine.start(ActiveWorkoutView.nowMs());
        hrProvider.enable();
        // Only write to the Garmin Activity/FIT pipeline when the user has
        // paired the companion app. Unpaired installs run as a private
        // stopwatch — data stays on the watch and never surfaces in Garmin
        // Connect.
        if (PairingStore.isPaired()) {
            recorder.start();
        }
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
        dc.setAntiAlias(true);

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

        var centerJust = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Vertical positions — fractions of screen height so layout scales
        // across FR265 / FR965 without absolute offsets.
        var yDelta  = (h * 0.12).toNumber();
        var yLabel  = (h * 0.24).toNumber();
        var yTimer  = (h * 0.48).toNumber();
        var yHR     = (h * 0.68).toNumber();
        var yTotal  = (h * 0.78).toNumber();
        var yNext   = (h * 0.87).toNumber();
        var yBar    = (h * 0.93).toNumber();

        // Delta: always shown. Sign drives color — negative (ahead of target)
        // is green, positive (behind) is red. No dim-for-estimate variant;
        // whether the goal is phone-pushed or a PaceReference estimate is
        // conveyed elsewhere (history screen) not here.
        var delta = DeltaCalculator.totalDeltaMs(engine, goal, nowMs);
        var deltaColor = delta > 0 ? Styles.COLOR_OVER : Styles.COLOR_UNDER;
        dc.setColor(deltaColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, yDelta, Graphics.FONT_XTINY,
            Styles.formatDeltaMs(delta), centerJust);

        // Segment label — colored by type, with short accent underline.
        var label = segmentLabel(segment);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, yLabel, Graphics.FONT_MEDIUM, label, centerJust);
        var labelHalf = dc.getFontHeight(Graphics.FONT_MEDIUM) / 2;
        dc.fillRectangle(cx - 32, yLabel + labelHalf + 3, 64, 2);

        // Main elapsed timer — FONT_NUMBER_HOT instead of THAI_HOT to leave
        // vertical room for HR + total below on the round display.
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, yTimer, Graphics.FONT_NUMBER_HOT,
            Styles.formatElapsedMs(segElapsed), centerJust);

        // HR line — red heart glyph missing on default font, so use "BPM"
        // suffix + red color for visual distinctiveness.
        var info = Activity.getActivityInfo();
        var bpm = info != null ? info.currentHeartRate : null;
        if (bpm != null) {
            dc.setColor(Styles.COLOR_HEART, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yHR, Graphics.FONT_TINY,
                bpm.toString() + " BPM", centerJust);
        }

        // Total elapsed — secondary.
        dc.setColor(Styles.COLOR_TEXT_SECOND, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, yTotal, Graphics.FONT_XTINY,
            "TOTAL  " + Styles.formatElapsedMs(totElapsed), centerJust);

        // Next segment preview — faded.
        var next = engine.nextSegment();
        if (next != null) {
            dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, yNext, Graphics.FONT_XTINY,
                "NEXT  " + segmentLabel(next), centerJust);
        }

        _drawProgressBar(dc, w, yBar, accent);

        // Paused overlay — covers HR/total/next all at once with a clear
        // status so the user isn't confused by stale timers.
        if (EngineState.is(engine.state, EngineState.KIND_PAUSED)) {
            dc.setColor(Styles.COLOR_BACKGROUND, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, yHR - 20, w, yBar - yHR + 20);
            dc.setColor(Styles.COLOR_OVER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (yHR + yNext) / 2, Graphics.FONT_MEDIUM,
                "PAUSED", centerJust);
        }
    }

    // Horizontal progress bar — how many of the N segments are done (idx+0.5
    // contribution for the current segment to give visible motion even when
    // between completed boundaries). Uses the CURRENT segment's accent color
    // so the whole screen stays visually tied to the active phase.
    private function _drawProgressBar(
            dc as Graphics.Dc,
            w as Number,
            y as Number,
            accent as Number) as Void {
        var segs = engine.template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var n = segs.size();
        if (n == 0) { return; }

        var idx = engine.currentSegmentIndex();
        if (idx == null) { idx = 0; }
        var frac = (idx.toFloat() + 0.5) / n.toFloat();
        if (frac < 0.0) { frac = 0.0; }
        if (frac > 1.0) { frac = 1.0; }

        var barW = (w * 0.62).toNumber();
        var barH = 4;
        var barX = (w - barW) / 2;

        dc.setColor(Styles.COLOR_SURFACE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, y, barW, barH, 2);

        var fillW = (barW * frac).toNumber();
        if (fillW < 4) { fillW = 4; }
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, y, fillW, barH, 2);
    }

    function _drawFinished(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        var centerJust = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.26).toNumber(), Graphics.FONT_MEDIUM,
            "FINISHED", centerJust);
        // Gold underline for consistency with in-workout label.
        dc.fillRectangle(cx - 40, (h * 0.26).toNumber() + dc.getFontHeight(Graphics.FONT_MEDIUM) / 2 + 2, 80, 2);

        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        var total = engine.totalElapsedMs(ActiveWorkoutView.nowMs());
        dc.drawText(cx, (h * 0.54).toNumber(), Graphics.FONT_NUMBER_THAI_HOT,
            Styles.formatElapsedMs(total), centerJust);

        dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.84).toNumber(), Graphics.FONT_XTINY,
            "PRESS BACK", centerJust);
    }

    function segmentLabel(segment as Dictionary) as String {
        var type = segment[WorkoutSegment.TYPE] as String;
        if (type.equals(SegmentType.STATION)) {
            var kind = segment[WorkoutSegment.STATION_KIND] as String;
            return StationKind.displayName(kind).toUpper();
        }
        if (type.equals(SegmentType.ROX_ZONE)) {
            return "ROX ZONE";
        }
        // Run: include index (1/8 based on run count so far)
        return "RUN " + _runCounter(segment) + "/8";
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
