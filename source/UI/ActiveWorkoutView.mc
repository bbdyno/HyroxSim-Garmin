//
//  ActiveWorkoutView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
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
        // Idempotent cleanup. ActionMenu's End/Discard already disable
        // these, so we double-call here only to catch the natural-finish
        // path — segment-by-segment advance to completion + SELECT/BACK
        // pops the view without going through the menu. Without this
        // the FIT session and HR sensor stay active and crash the next
        // workout's createSession call.
        hrProvider.disable();
        if (recorder.isActive()) {
            recorder.stop();
            // Natural finish also needs to reach the phone outbox; the
            // menu's End path encodes there, but BACK after FINISHED
            // would otherwise drop the run on the floor.
            if (engine.isFinished()) {
                var encoded = CompletedWorkoutCodec.encode(engine, "garmin");
                var app = getApp();
                if (app.phoneHandler != null) {
                    app.phoneHandler.submitCompletedWorkout(encoded);
                } else {
                    WorkoutStorage.enqueue(encoded);
                }
            }
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
        var leftJust   = Graphics.TEXT_JUSTIFY_LEFT   | Graphics.TEXT_JUSTIFY_VCENTER;
        var rightJust  = Graphics.TEXT_JUSTIFY_RIGHT  | Graphics.TEXT_JUSTIFY_VCENTER;

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

        // HR + pace row. On Run segments we always show a pace slot (with
        // "--" while GPS is still acquiring). Otherwise HR centered.
        var info = Activity.getActivityInfo();
        var bpm = info != null ? info.currentHeartRate : null;
        var app = getApp();
        var speedMps = app.gpsSpeedMps;
        var isRun = type.equals(SegmentType.RUN);
        var showPace = isRun;
        var paceStr;
        if (isRun && speedMps != null && speedMps > 0.3 && app.gpsReady()) {
            paceStr = _formatPace(speedMps) + " /km";
        } else if (isRun) {
            paceStr = "-- /km";
        } else {
            paceStr = "";
        }

        var hrText = bpm != null ? bpm.toString() : "--";
        var hrColor = bpm != null ? Styles.COLOR_HEART : Styles.COLOR_TEXT_TERTIARY;

        if (showPace) {
            _drawHRWithIcon(dc, (w * 0.28).toNumber(), yHR,
                hrText, hrColor, Graphics.FONT_XTINY, leftJust);
            var paceColor = app.gpsReady()
                ? Styles.COLOR_TEXT_PRIMARY
                : Styles.COLOR_TEXT_TERTIARY;
            dc.setColor(paceColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText((w * 0.72).toNumber(), yHR, Graphics.FONT_XTINY,
                paceStr, rightJust);
        } else {
            _drawHRWithIcon(dc, cx, yHR,
                hrText, hrColor, Graphics.FONT_TINY, centerJust);
        }

        // GPS indicator — satellite icon above the delta, tinted by quality.
        var gpsColor = app.gpsReady()
            ? Styles.COLOR_UNDER                 // green when locked
            : (app.gpsQuality >= 2
                ? Styles.COLOR_ACCENT            // gold when poor
                : Styles.COLOR_TEXT_TERTIARY);   // grey when no signal
        dc.setColor(gpsColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w * 0.20).toNumber(), yDelta, IconFont.get(),
            IconFont.SATELLITE, centerJust);

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

    function _runCounter(targetSegment as Dictionary) as String {
        // Count run segments up to and including the segment we're
        // labelling — NOT the engine's current index. Using currentIndex
        // here breaks the "NEXT" preview, because it would label the
        // upcoming run with the previous run's number.
        var segs = engine.template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var targetId = targetSegment[WorkoutSegment.ID];
        var count = 0;
        for (var i = 0; i < segs.size(); i += 1) {
            var s = segs[i] as Dictionary;
            if ((s[WorkoutSegment.TYPE] as String).equals(SegmentType.RUN)) {
                count += 1;
            }
            if (s[WorkoutSegment.ID].equals(targetId)) {
                return count.toString();
            }
        }
        return "?";
    }

    static function nowMs() as Long {
        return Time.now().value().toLong() * 1000l;
    }

    // Converts instantaneous speed (m/s) into "M:SS" pace per km.
    // Caller is responsible for null / zero-speed filtering so this stays
    // pure arithmetic and never crashes on divide-by-zero.
    private function _formatPace(speedMps as Float) as String {
        var secPerKm = (1000.0 / speedMps).toNumber();
        var m = secPerKm / 60;
        var s = secPerKm % 60;
        return m.toString() + ":" + s.format("%02d");
    }

    // Draws "♥ 152" — heart icon + BPM value. The icon and the number
    // use different fonts so they render crisply at their native sizes
    // (icon font is rasterised at 28 px).
    private function _drawHRWithIcon(
            dc as Graphics.Dc,
            anchorX as Number,
            y as Number,
            hrText as String,
            hrColor as Number,
            textFont,
            just as Number) as Void {
        var iconFont = IconFont.get();
        var iconW = dc.getTextWidthInPixels(IconFont.HEART, iconFont);
        var textW = dc.getTextWidthInPixels(hrText, textFont);
        var gap = 6;
        var totalW = iconW + gap + textW;

        // Resolve left edge from caller justification.
        var leftX;
        if ((just & Graphics.TEXT_JUSTIFY_CENTER) != 0) {
            leftX = anchorX - totalW / 2;
        } else if ((just & Graphics.TEXT_JUSTIFY_RIGHT) != 0) {
            leftX = anchorX - totalW;
        } else {
            leftX = anchorX;
        }

        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX, y, iconFont, IconFont.HEART,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(leftX + iconW + gap, y, textFont, hrText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
