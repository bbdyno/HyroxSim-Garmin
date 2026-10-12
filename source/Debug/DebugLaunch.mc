//
//  DebugLaunch.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 10/12/26.
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Screenshot hook — debug builds only. Everything in this file carries the
// (:debug) annotation, which monkeyc strips from release (-r) builds, so
// none of it ships to the store.
//
// A normal debug build gets DebugScreen.id() == null and starts on the
// home screen as usual. tools/screenshots/shoot.sh builds with its own
// jungle that swaps DebugScreen for one naming a screen; the app then
// launches straight into that screen with canned race data, which is the
// only way to see mid-workout screens in the simulator without pressing
// buttons by hand.
(:debug, :noShot)
module DebugScreen {
    function id() as String? { return null; }
}

(:debug)
module DebugLaunch {

    const TOUR = [
        "home", "home_searching", "home_unpaired", "division", "roxzone",
        "custom", "custom_empty", "run", "run_long", "roxzone_active",
        "station", "station_heavy", "last", "paused", "menu", "menu_paused",
        "finished", "result", "splits", "result_early"
    ];

    var _tour as DebugTour?;

    // The view to launch into, or null for the normal home screen.
    // "tour" walks through every screen, a few seconds each, printing
    // "SHOT <screen>" so a script can capture them from a single launch.
    function initialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        var id = DebugScreen.id();
        if (id == null) { return null; }
        if (id.equals("tour")) {
            _tour = new DebugTour();
            (_tour as DebugTour).start();
            id = TOUR[0] as String;
        }
        System.println("SHOT " + id);
        return viewFor(id);
    }

    function viewFor(id as String) as [WatchUi.Views, WatchUi.InputDelegates] {

        if (id.equals("home_unpaired")) {
            PairingStore.reset();
            Application.Storage.deleteValue(TemplateStore.KEY);
            Application.Storage.deleteValue(GoalStore.KEY);
            var unpaired = new HomeView();
            unpaired.selected = 1;
            return [unpaired, new WheelDelegate(unpaired)];
        }

        // Every other screen assumes a paired watch with phone data.
        _seedPhoneData(!id.equals("custom_empty"));
        getApp().gpsQuality = 0;

        if (id.equals("home")) {
            getApp().gpsQuality = 4;   // QUALITY_GOOD
            var home = new HomeView();
            return [home, new WheelDelegate(home)];
        }
        if (id.equals("home_searching")) {
            var searching = new HomeView();
            searching.selected = 1;
            return [searching, new WheelDelegate(searching)];
        }
        if (id.equals("division")) {
            var picker = new DivisionPickerView();
            picker.selected = 2;
            return [picker, new WheelDelegate(picker)];
        }
        if (id.equals("roxzone")) {
            var rox = new RoxZoneTogglePicker(HyroxDivision.MEN_OPEN_SINGLE);
            return [rox, new WheelDelegate(rox)];
        }
        if (id.equals("custom") || id.equals("custom_empty")) {
            var custom = new CustomWorkoutsView();
            custom.selected = 1;
            return [custom, new WheelDelegate(custom)];
        }
        if (id.equals("result") || id.equals("splits") || id.equals("result_early")) {
            var early = id.equals("result_early");
            var result = new ResultView(_race(early ? 14 : 31, 0, !early));
            if (id.equals("splits")) { result.scrollBy(1); }
            return [result, new ResultViewDelegate()];
        }

        // Workout screens.
        var template = WorkoutTemplate.hyroxPreset(HyroxDivision.MEN_OPEN_SINGLE);
        var view = new ActiveWorkoutView(template);
        view.hrOverride = 162;
        var engine;
        if (id.equals("station")) {
            engine = _race(14, 227, false);         // Burpee Broad Jumps, 3:47 in
        } else if (id.equals("station_heavy")) {
            engine = _race(6, 95, false);           // Sled Push — has a weight
        } else if (id.equals("roxzone_active")) {
            engine = _race(13, 12, false);
        } else if (id.equals("run_long")) {
            engine = _race(12, 754, false);         // 12:34 — five-digit hero
        } else if (id.equals("last")) {
            engine = _race(30, 200, false);         // Wall Balls — FINISH hint
        } else if (id.equals("finished")) {
            engine = _race(31, 0, false);
        } else {
            engine = _race(12, 252, false);         // Run 4, 4:12 in
        }
        view.adoptEngine(engine);
        if (id.equals("paused") || id.equals("menu_paused")) {
            engine.pause(Clock.nowMs());
        }
        if (id.equals("menu") || id.equals("menu_paused")) {
            var menu = new ActionMenu(view);
            return [menu, new WheelDelegate(menu)];
        }
        return [view, new ActiveWorkoutDelegate(view)];
    }

    // A race that has already covered `done` segments and is `elapsedSec`
    // into the next one. Some blocks beat their goal and some do not, so
    // the ring shows both colours. `finishNow` ends the workout early.
    function _race(done as Number, elapsedSec as Number, finishNow as Boolean) as WorkoutEngine {
        var template = WorkoutTemplate.hyroxPreset(HyroxDivision.MEN_OPEN_SINGLE);
        var segs = template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var goal = GoalStore.resolve(template);
        var targets = goal[GoalStore.TARGET_SEGMENTS_MS] as Array;
        if (done > segs.size()) { done = segs.size(); }

        // Percent of goal per segment; index 6/7 (Sled Push block), 14
        // (Burpees) and 24 (run 7) run over.
        var durations = new Array<Long>[done];
        var total = 0l;
        for (var i = 0; i < done; i += 1) {
            var pct = 94 + (i * 7) % 5;
            if (i == 6 || i == 14 || i == 24) { pct = 113; }
            durations[i] = (targets[i] as Number or Long).toLong() * pct / 100;
            total += durations[i];
        }

        var engine = new WorkoutEngine(template);
        var t = Clock.nowMs() - total - elapsedSec.toLong() * 1000l;
        engine.start(t);
        for (var i = 0; i < done; i += 1) {
            t += durations[i];
            engine.advance(t);
        }
        if (finishNow && !engine.isFinished()) {
            engine.finish(Clock.nowMs());
        }
        return engine;
    }

    // What the phone app would have pushed: pairing, a goal, two workouts.
    function _seedPhoneData(withTemplates as Boolean) as Void {
        PairingStore.recordHello();
        Application.Storage.deleteValue(GoalStore.KEY);
        Application.Storage.deleteValue(TemplateStore.KEY);
        if (!withTemplates) { return; }
        var names = ["Engine Builder", "Sled Day", "주말 하이록스"];
        for (var i = 0; i < names.size(); i += 1) {
            var segs = [
                WorkoutSegment.run(1000),
                WorkoutSegment.station(StationKind.SLED_PUSH, StationTarget.distance(50), 152, null),
                WorkoutSegment.run(1000),
                WorkoutSegment.station(StationKind.WALL_BALLS, StationTarget.reps(100), 6, null)
            ] as Array<Dictionary>;
            TemplateStore.upsert(WorkoutTemplate.make(names[i], null, segs, i == 0, false));
        }
    }
}

// Steps through DebugLaunch.TOUR on a timer.
(:debug)
class DebugTour {
    private var _index as Number;
    private var _timer as Timer.Timer;

    function initialize() {
        _index = 0;
        _timer = new Timer.Timer();
    }

    function start() as Void {
        _timer.start(method(:next), 4000, true);
    }

    function next() as Void {
        _index += 1;
        if (_index >= DebugLaunch.TOUR.size()) {
            _timer.stop();
            System.println("SHOT end");
            return;
        }
        var id = DebugLaunch.TOUR[_index] as String;
        var pair = DebugLaunch.viewFor(id);
        WatchUi.switchToView(pair[0], pair[1], WatchUi.SLIDE_IMMEDIATE);
        System.println("SHOT " + id);
    }
}
