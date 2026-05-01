//
//  HyroxSimApp.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Activity;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.Timer;
import Toybox.WatchUi;

class HyroxSimApp extends Application.AppBase {

    public var phoneHandler;          // PhoneMessageHandler singleton

    // App-wide GPS state. Enabled continuously from onStart so the home
    // screen already reflects acquisition by the time the user presses
    // START — first-tick GPS cold-start would otherwise leave pace blank
    // for the opening ~30 s of a Run segment.
    public var gpsQuality = 0;        // Position.QUALITY_* (0 = NOT_AVAILABLE)
    public var gpsSpeedMps = null;    // m/s or null

    private var _gpsPollTimer;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        phoneHandler = new PhoneMessageHandler();
        phoneHandler.register();
        _enableHighAccuracyGps();
        // Belt-and-suspenders polling. The Position listener can fall
        // silent on glance/AOD transitions or when the OS briefly throttles
        // GPS for power; Activity.getActivityInfo() is refreshed by the OS
        // independently and gives us a backstop. 2 s cadence is fast enough
        // for "ACQUIRING → READY" to feel snappy, slow enough to be free.
        _gpsPollTimer = new Timer.Timer();
        _gpsPollTimer.start(method(:_pollGps), 2000, true);
    }

    function onStop(state as Dictionary?) as Void {
        Position.enableLocationEvents(
            Position.LOCATION_DISABLE, method(:onLocation));
        if (_gpsPollTimer != null) {
            _gpsPollTimer.stop();
            _gpsPollTimer = null;
        }
        // Defensive sensor teardown. ActiveWorkoutView.onHide is the
        // primary cleanup site, but force-kill / low-bat shutdown can
        // skip it. A leaked HR sensor subscription keeps the watch in
        // "in workout" state past app exit and contributes to the
        // system activity menu feeling unresponsive.
        Sensor.setEnabledSensors([] as Array<SensorType>);
    }

    // Spell out the constellation set rather than passing the bare
    // LOCATION_CONTINUOUS constant. Modern Forerunners default to a
    // constellation mix the firmware picks for battery — which can be
    // GPS-only on some power profiles, costing us 30+ s of cold-start
    // time. Naming the constellations forces every visible satellite
    // (GPS + GLONASS + Galileo) into the first-fix calculation.
    private function _enableHighAccuracyGps() as Void {
        try {
            var opts = {
                :acquisitionType => Position.LOCATION_CONTINUOUS,
                :constellations => [
                    Position.CONSTELLATION_GPS,
                    Position.CONSTELLATION_GLONASS,
                    Position.CONSTELLATION_GALILEO
                ]
            };
            Position.enableLocationEvents(opts, method(:onLocation));
        } catch (ex) {
            // Older firmware / non-multi-GNSS devices may reject the
            // options dict. Fall back to the simpler form so we still
            // get a single-constellation fix.
            Position.enableLocationEvents(
                Position.LOCATION_CONTINUOUS, method(:onLocation));
        }
    }

    function onLocation(info as Position.Info) as Void {
        if (info has :accuracy && info.accuracy != null) {
            gpsQuality = info.accuracy;
        }
        if (info has :speed && info.speed != null) {
            gpsSpeedMps = info.speed;
        }
        WatchUi.requestUpdate();
    }

    // Periodic re-read of the OS-shared activity info. Same data the
    // workout screen pulls for HR — touching it here just keeps the
    // home screen's GPS indicator alive when onLocation is quiet.
    function _pollGps() as Void {
        var info = Activity.getActivityInfo();
        if (info == null) { return; }
        var changed = false;
        if (info has :currentLocationAccuracy
                && info.currentLocationAccuracy != null
                && info.currentLocationAccuracy != gpsQuality) {
            gpsQuality = info.currentLocationAccuracy;
            changed = true;
        }
        if (info has :currentSpeed && info.currentSpeed != null) {
            // Always store latest speed; only the workout view paints
            // it and that view ticks at 500 ms on its own.
            gpsSpeedMps = info.currentSpeed;
        }
        if (changed) {
            WatchUi.requestUpdate();
        }
    }

    function gpsReady() as Boolean {
        return gpsQuality >= Position.QUALITY_USABLE;
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        // Always land on HomeView. Paid/premium features (custom templates,
        // goal deltas, phone history sync) are naturally gated by whether
        // the phone has pushed data — the watch never fakes a goal or template.
        // See PairingStore / GoalStore / TemplateStore for individual checks.
        var home = new HomeView();
        return [home, new HomeViewDelegate(home)];
    }
}

function getApp() as HyroxSimApp {
    return Application.getApp() as HyroxSimApp;
}
