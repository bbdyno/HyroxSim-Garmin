//
//  HyroxSimApp.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

class HyroxSimApp extends Application.AppBase {

    public var phoneHandler;          // PhoneMessageHandler singleton

    // App-wide GPS state. Enabled continuously from onStart so the home
    // screen already reflects acquisition by the time the user presses
    // START — first-tick GPS cold-start would otherwise leave pace blank
    // for the opening ~30 s of a Run segment.
    public var gpsQuality = 0;        // Position.QUALITY_* (0 = NOT_AVAILABLE)
    public var gpsSpeedMps = null;    // m/s or null

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        phoneHandler = new PhoneMessageHandler();
        phoneHandler.register();
        Position.enableLocationEvents(
            Position.LOCATION_CONTINUOUS, method(:onLocation));
    }

    function onStop(state as Dictionary?) as Void {
        Position.enableLocationEvents(
            Position.LOCATION_DISABLE, method(:onLocation));
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
