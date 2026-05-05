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
    public var gpsSpeedMps = null;    // EMA-smoothed m/s, null until first fix

    // EMA smoothing factor for gpsSpeedMps. 0.3 = 30 % weight on the
    // freshest sample, 70 % on the running estimate — equivalent to a ~3 s
    // window at our 1 Hz GPS callback rate. Removes the per-sample jitter
    // that previously caused /km pace to bounce 4:00 ↔ 6:00 each second.
    private const _GPS_SPEED_ALPHA = 0.3;

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

    // Pick the highest-accuracy GNSS configuration the device supports.
    //
    // Garmin's :configuration option is the modern replacement for the
    // manual :constellations selection. On multi-band hardware (FR265,
    // FR965 — the MVP targets) it enables GPS L1+L5 / Galileo L1+L5 /
    // BeiDou L1+L5 which is what Garmin's own running profile uses to
    // close the accuracy gap with bare L1 GPS. The previous code only
    // requested L1 GPS+GLONASS+Galileo and was visibly worse than the
    // native running activity in the same conditions.
    //
    // Fallback chain: best multi-band → best single-band → SatIQ
    // (firmware-managed) → bare LOCATION_CONTINUOUS. The try/catch
    // covers older firmware that rejects an unknown configuration value.
    private function _enableHighAccuracyGps() as Void {
        var listener = method(:onLocation);
        var opts = { :acquisitionType => Position.LOCATION_CONTINUOUS };
        if (Position has :hasConfigurationSupport) {
            if (Position has :CONFIGURATION_GPS_GLONASS_GALILEO_BEIDOU_L1_L5
                    && Position.hasConfigurationSupport(
                        Position.CONFIGURATION_GPS_GLONASS_GALILEO_BEIDOU_L1_L5)) {
                opts[:configuration] =
                    Position.CONFIGURATION_GPS_GLONASS_GALILEO_BEIDOU_L1_L5;
            } else if (Position has :CONFIGURATION_GPS_GLONASS_GALILEO_BEIDOU_L1
                    && Position.hasConfigurationSupport(
                        Position.CONFIGURATION_GPS_GLONASS_GALILEO_BEIDOU_L1)) {
                opts[:configuration] =
                    Position.CONFIGURATION_GPS_GLONASS_GALILEO_BEIDOU_L1;
            } else if (Position has :CONFIGURATION_SAT_IQ
                    && Position.hasConfigurationSupport(Position.CONFIGURATION_SAT_IQ)) {
                opts[:configuration] = Position.CONFIGURATION_SAT_IQ;
            }
        }
        try {
            Position.enableLocationEvents(opts, listener);
        } catch (ex) {
            Position.enableLocationEvents(
                Position.LOCATION_CONTINUOUS, listener);
        }
    }

    function onLocation(info as Position.Info) as Void {
        var qualityChanged = false;
        if (info has :accuracy && info.accuracy != null
                && info.accuracy != gpsQuality) {
            gpsQuality = info.accuracy;
            qualityChanged = true;
        }
        if (info has :speed && info.speed != null) {
            _updateGpsSpeed(info.speed);
        }
        // Only repaint when the visible quality bucket changed. The active
        // workout view ticks every 500 ms on its own; HomeView only cares
        // about the GPS indicator transitioning READY/ACQUIRING/SEARCHING
        // — repainting per location callback (≈1 Hz) just burns battery.
        if (qualityChanged) {
            WatchUi.requestUpdate();
        }
    }

    // Periodic re-read of the OS-shared activity info. Acts as a backstop
    // for accuracy when the Position listener falls silent on AOD/glance
    // transitions or under firmware power throttling. Speed is intentionally
    // left to onLocation so we have a single authoritative source for the
    // EMA — having both update the smoothed value caused the polled and
    // listener readings to fight each other and produced visible flicker.
    function _pollGps() as Void {
        var info = Activity.getActivityInfo();
        if (info == null) { return; }
        if (info has :currentLocationAccuracy
                && info.currentLocationAccuracy != null
                && info.currentLocationAccuracy != gpsQuality) {
            gpsQuality = info.currentLocationAccuracy;
            WatchUi.requestUpdate();
        }
    }

    private function _updateGpsSpeed(rawMps as Float) as Void {
        if (gpsSpeedMps == null) {
            gpsSpeedMps = rawMps;
            return;
        }
        var prev = gpsSpeedMps as Float;
        gpsSpeedMps = _GPS_SPEED_ALPHA * rawMps
                    + (1.0 - _GPS_SPEED_ALPHA) * prev;
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
