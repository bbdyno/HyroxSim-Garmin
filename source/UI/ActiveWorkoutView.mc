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
// Layout (round display, positions in 1/200 of the diameter):
//
//       STATION 4 / 8        caption — blue run, gold station, white ROX
//        [BURPEE BJ]         station name / ROX destination / paused total
//           3:47             segment time — the hero
//          -0:12             delta against the cumulative goal
//       [80 M · 20 KG]       station target, or live pace on a run
//          ♥ 162
//
// The bezel carries the progress ring (one block per run / station) and
// two button hints: NEXT at START/STOP, MENU at BACK.
class ActiveWorkoutView extends WatchUi.View {

    public var engine;           // WorkoutEngine
    public var hrProvider;       // HeartRateProvider
    public var recorder;         // ActivityRecorder
    public var goal;             // resolved goal Dictionary or null when free-tier
    public var hasExplicitGoal;  // true only when phone-pushed goal is active
    public var hrOverride as Number?;   // fixed BPM for screenshots (debug builds)
    private var _tickTimer;      // Toybox.Timer.Timer
    private var _submitted = false;

    // Per-template lookups, built once.
    private var _blockMap as Array<Number>;
    private var _ordinals as Array<Number>;     // 1-based position within its type
    private var _runTotal as Number;
    private var _stationTotal as Number;

    // Everything below changes only when the segment changes — rebuilt by
    // _refreshCache() so onUpdate() stays cheap.
    private var _cacheKey as Number;
    private var _states as Array<Number>;
    private var _caption as String;
    private var _captionColor as Number;
    private var _name as String?;
    private var _nameIsTitle as Boolean;
    private var _foot as String?;
    private var _isRun as Boolean;
    private var _isLast as Boolean;
    private var _summary as ResultSummary?;

    function initialize(template as Dictionary) {
        View.initialize();
        engine = new WorkoutEngine(template);
        hrProvider = new HeartRateProvider(engine);
        recorder = new ActivityRecorder();
        hrOverride = null;
        // Goal resolution: use phone-pushed goal if division matches, else
        // fall back to PaceReference defaults so delta is always shown.
        var storedGoal = GoalStore.load();
        var division = template[WorkoutTemplate.DIVISION];
        hasExplicitGoal = (storedGoal != null && division != null
                && (storedGoal[GoalStore.DIVISION] as String).equals(division as String));
        goal = GoalStore.resolve(template);

        _blockMap = [] as Array<Number>;
        _ordinals = [] as Array<Number>;
        _runTotal = 0;
        _stationTotal = 0;
        _cacheKey = -1;
        _states = [] as Array<Number>;
        _caption = "";
        _captionColor = Styles.COLOR_TEXT;
        _name = null;
        _nameIsTitle = false;
        _foot = null;
        _isRun = false;
        _isLast = false;
        _summary = null;
        _indexTemplate();

        engine.start(ActiveWorkoutView.nowMs());
        hrProvider.enable();
        // Register so HyroxSimApp.onLocation can route GPS fixes into
        // engine.ingestLocation. Cleared in finalizeOnExit so a stale
        // engine reference never receives samples after the view is gone.
        getApp().activeEngine = engine;
        getApp().activeView = self;
        // Only write to the Garmin Activity/FIT pipeline when the user has
        // paired the companion app. Unpaired installs run as a private
        // stopwatch — data stays on the watch and never surfaces in Garmin
        // Connect.
        if (PairingStore.isPaired()) {
            recorder.start();
        }
    }

    // Screenshot hook: swap in an engine that is already mid-race.
    (:debug)
    function adoptEngine(eng as WorkoutEngine) as Void {
        // Canned data must never reach Garmin Connect or the phone outbox
        // (the simulator also blocks on a FIT save dialog at app exit).
        if (recorder.isActive()) { recorder.discard(); }
        _submitted = true;
        engine = eng;
        hrProvider = new HeartRateProvider(eng);
        getApp().activeEngine = eng;
        _cacheKey = -1;
        _summary = null;
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
        // NOTE: HR sensor and FIT recorder are intentionally NOT torn down
        // here. Per the CIQ View lifecycle, onHide() also fires when a
        // sub-view is pushed on top (e.g. ActionMenu). Disabling sensors or
        // calling recorder.stop() at that point would kill the live HR feed
        // and finalize the FIT session mid-workout, dropping the run from
        // Garmin Connect and (combined with accumulated HR samples) caused
        // the 10–20 min OOM crash. Cleanup runs from explicit exit paths:
        // ActionMenuDelegate (End/Discard) and finalizeOnExit() below for
        // the natural-finish + BACK/SELECT path.
    }

    // Explicit teardown for paths that genuinely leave the workout view —
    // not for transient covered-by-sub-view transitions. Idempotent.
    function finalizeOnExit() as Void {
        hrProvider.disable();
        var app = getApp();
        if (app.activeEngine == engine) { app.activeEngine = null; }
        if (app.activeView == self) { app.activeView = null; }
        if (recorder.isActive()) { recorder.stop(); }
        submitIfFinished();
    }

    // Hands the finished workout to the phone outbox exactly once. Every
    // exit path (End menu, natural finish, app shutdown) funnels through
    // here, so a workout is neither queued twice nor skipped — it used to
    // be skipped entirely on a natural finish when the FIT recorder was
    // not running.
    function submitIfFinished() as Void {
        if (_submitted || !engine.isFinished()) { return; }
        _submitted = true;
        try {
            var encoded = CompletedWorkoutCodec.encode(engine, "garmin");
            var app = getApp();
            if (app.phoneHandler != null) {
                app.phoneHandler.submitCompletedWorkout(encoded);
            } else {
                WorkoutStorage.enqueue(encoded);
            }
        } catch (ex) {
            System.println("submit failed: " + ex.getErrorMessage());
        }
    }

    // App is being torn down mid-workout (system kill, low battery, user
    // quitting from the system menu). Close out what was recorded so the
    // session is not lost.
    function saveOnAppStop() as Void {
        try {
            if (!engine.isFinished()) { engine.finish(ActiveWorkoutView.nowMs()); }
        } catch (ex) {
            // Idle engine — nothing recorded.
        }
        finalizeOnExit();
    }

    function onTick() as Void {
        hrProvider.sampleOnce();
        WatchUi.requestUpdate();
    }

    // Stops GPS fixes and the app-shutdown safety net from reaching this
    // view once the workout has been ended from the menu.
    function detachFromApp() as Void {
        var app = getApp();
        if (app.activeEngine == engine) { app.activeEngine = null; }
        if (app.activeView == self) { app.activeView = null; }
    }

    // A discarded workout must never be queued for the phone.
    function markDiscarded() as Void {
        _submitted = true;
    }

    // MARK: - Drawing

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var eng = engine as WorkoutEngine;

        if (eng.isFinished()) {
            // Natural finish: the summary stays up until SELECT/BACK saves.
            if (_summary == null) {
                _summary = new ResultSummary(eng, goal as Dictionary);
            }
            (_summary as ResultSummary).draw(dc);
            Ui.hint(dc, true, "SAVE");
            return;
        }

        var index = eng.currentSegmentIndex();
        if (index == null) { return; }
        _refreshCache(dc, eng, index);

        var nowMs = ActiveWorkoutView.nowMs();
        var paused = EngineState.is(eng.state, EngineState.KIND_PAUSED);
        var cap = Fonts.cap();

        Ring.draw(dc, _states, _states.size(), null);

        // Button hints. SELECT does nothing while paused, so no NEXT then.
        if (!paused) {
            Ui.hint(dc, true, _isLast ? "DONE" : "NEXT");
        }
        var menuLeft = Ui.hint(dc, false, "MENU");

        // Header: caption, plus one line under it for everything but a run
        // (station name, ROX destination, or the total while paused).
        var second = _name;
        var secondIsTitle = _nameIsTitle;
        if (paused) {
            second = "TOTAL " + Styles.formatClock(eng.totalElapsedMs(nowMs));
            secondIsTitle = false;
        }
        var heroY = 96;
        if (second != null) {
            heroY = 101;
            Ui.text(dc, 100, 31, cap, paused ? Palette.GOLD : _captionColor,
                paused ? "PAUSED" : _caption, Ui.CENTER);
            Ui.text(dc, 100, 46.5, secondIsTitle ? Fonts.title() : cap,
                secondIsTitle ? Styles.COLOR_TEXT : Palette.GREY,
                second as String, Ui.CENTER);
        } else {
            Ui.text(dc, 100, 42, cap, _captionColor, _caption, Ui.CENTER);
        }

        // Hero: segment time. Longer strings step down a size so the
        // digits never reach the ring.
        var clock = Styles.formatClock(eng.segmentElapsedMs(nowMs));
        var len = clock.length();
        var heroFont = len <= 4 ? Fonts.hero() : (len == 5 ? Fonts.heroSm() : Fonts.big());
        Ui.text(dc, 100, heroY, heroFont,
            paused ? Palette.GREY : Styles.COLOR_TEXT, clock, Ui.CENTER);

        // Delta against the cumulative goal — gold ahead, orange behind.
        // A very long delta slides left rather than run under the MENU tab.
        var delta = DeltaCalculator.totalDeltaMs(eng, goal as Dictionary, nowMs);
        var deltaText = Styles.formatDelta(delta);
        var mid = Fonts.mid();
        var deltaX = Ui.px(dc, 100);
        var deltaHalf = dc.getTextWidthInPixels(deltaText, mid) / 2;
        var deltaLimit = menuLeft - Ui.px(dc, 3);
        if (deltaX + deltaHalf > deltaLimit) { deltaX = deltaLimit - deltaHalf; }
        dc.setColor(Styles.colorForDelta(delta), Graphics.COLOR_TRANSPARENT);
        dc.drawText(deltaX, Ui.px(dc, heroY + 45), mid, deltaText, Ui.CENTER);

        // Footer: station target (or live pace on a run) above heart rate.
        var foot = _foot;
        if (_isRun) { foot = _paceText(); }
        var bpm = hrOverride;
        if (bpm == null) {
            var info = Activity.getActivityInfo();
            if (info != null) { bpm = info.currentHeartRate; }
        }
        var hrText = "\u2665 " + (bpm != null ? bpm.toString() : "--");
        if (foot != null) {
            Ui.text(dc, 100, heroY + 65, cap, Palette.GREY, foot, Ui.CENTER);
            Ui.text(dc, 100, heroY + 78.5, cap, Styles.COLOR_TEXT, hrText, Ui.CENTER);
        } else {
            Ui.text(dc, 100, heroY + 73, cap, Styles.COLOR_TEXT, hrText, Ui.CENTER);
        }
    }

    // Counts runs / stations once so captions can say "RUN 4 / 8".
    private function _indexTemplate() as Void {
        var segs = ((engine as WorkoutEngine).template as Dictionary)[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        _blockMap = RingModel.blockMap(segs);
        _ordinals = new Array<Number>[segs.size()];
        _runTotal = 0;
        _stationTotal = 0;
        for (var i = 0; i < segs.size(); i += 1) {
            var type = (segs[i] as Dictionary)[WorkoutSegment.TYPE] as String;
            if (type.equals(SegmentType.RUN)) {
                _runTotal += 1;
                _ordinals[i] = _runTotal;
            } else if (type.equals(SegmentType.STATION)) {
                _stationTotal += 1;
                _ordinals[i] = _stationTotal;
            } else {
                _ordinals[i] = 0;
            }
        }
    }

    // Rebuilds ring states and static labels when the segment changed.
    private function _refreshCache(dc as Graphics.Dc, eng as WorkoutEngine, index as Number) as Void {
        var key = index * 1000 + eng.records.size();
        if (key == _cacheKey) { return; }
        _cacheKey = key;

        var segs = (eng.template as Dictionary)[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var seg = segs[index] as Dictionary;
        var type = seg[WorkoutSegment.TYPE] as String;
        var targets = (goal as Dictionary)[GoalStore.TARGET_SEGMENTS_MS] as Array?;
        _states = RingModel.blockStates(
            _blockMap, RingModel.durations(eng.records as Array), targets, index);

        _captionColor = Styles.colorForSegmentType(type);
        _isRun = type.equals(SegmentType.RUN);
        _isLast = index >= segs.size() - 1;
        _name = null;
        _nameIsTitle = false;
        _foot = null;

        if (_isRun) {
            _caption = _countCaption("RUN", _ordinals[index], _runTotal);
        } else if (type.equals(SegmentType.STATION)) {
            _caption = _countCaption("STATION", _ordinals[index], _stationTotal);
            _name = Ui.fit(dc, shortLabel(seg), Fonts.title(), Ui.px(dc, 128));
            _nameIsTitle = true;
            _foot = _targetText(dc, seg);
        } else {
            _caption = "ROX ZONE";
            if (index + 1 < segs.size()) {
                var next = segs[index + 1] as Dictionary;
                var nextType = next[WorkoutSegment.TYPE] as String;
                if (nextType.equals(SegmentType.RUN)) {
                    _name = "TO RUN " + _ordinals[index + 1].toString();
                } else if (nextType.equals(SegmentType.STATION)) {
                    _name = Ui.fit(dc, "TO " + shortLabel(next), Fonts.cap(), Ui.px(dc, 128));
                }
            }
        }
    }

    // "STATION 4 / 8". Two-digit counts (long custom workouts) lose the
    // spaces so the caption still clears the ring.
    private function _countCaption(word as String, ordinal as Number, total as Number) as String {
        var sep = total >= 10 ? "/" : " / ";
        return word + " " + ordinal.toString() + sep + total.toString();
    }

    // "80 M · 20 KG" — the weight is dropped when the line would not fit
    // the narrow bottom of the round screen.
    private function _targetText(dc as Graphics.Dc, seg as Dictionary) as String? {
        var target = seg[WorkoutSegment.STATION_TARGET];
        if (target == null) { return null; }
        var kind = (target as Dictionary)[StationTarget.KIND] as String;
        if (kind.equals(StationTarget.KIND_NONE)) { return null; }
        var text = StationTarget.formatted(target as Dictionary).toUpper();
        var weight = seg[WorkoutSegment.WEIGHT_KG];
        if (weight != null) {
            var full = text + " · " + (weight as Numeric).format("%d") + " KG";
            if (dc.getTextWidthInPixels(full, Fonts.cap()) <= Ui.px(dc, 108)) {
                return full;
            }
        }
        return text;
    }

    // Live pace on a run, null until GPS has a usable fix.
    private function _paceText() as String? {
        var app = getApp();
        var speed = app.gpsSpeedMps;
        if (speed == null || !app.gpsReady() || (speed as Float) <= 0.3) { return null; }
        var secPerKm = (1000.0 / (speed as Float)).toNumber();
        return (secPerKm / 60).toString() + ":" + (secPerKm % 60).format("%02d") + " /KM";
    }

    // Short uppercase label for a station segment.
    function shortLabel(segment as Dictionary) as String {
        var kind = segment[WorkoutSegment.STATION_KIND];
        if (kind == null) { return "STATION"; }
        return StationKind.shortName(kind as String);
    }

    function segmentLabel(segment as Dictionary) as String {
        var type = segment[WorkoutSegment.TYPE] as String;
        if (type.equals(SegmentType.STATION)) { return shortLabel(segment); }
        if (type.equals(SegmentType.ROX_ZONE)) { return "ROX ZONE"; }
        return "RUN";
    }

    static function nowMs() as Long {
        return Clock.nowMs();
    }
}
