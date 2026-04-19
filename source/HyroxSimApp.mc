//
//  HyroxSimApp.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class HyroxSimApp extends Application.AppBase {

    public var phoneHandler;    // PhoneMessageHandler singleton

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        phoneHandler = new PhoneMessageHandler();
        phoneHandler.register();
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        // Gate the app behind phone pairing. Watch users must install the
        // iOS or Android companion and complete a handshake before any
        // workout entry point becomes accessible — prevents the watch-only
        // free-tier leak where all HYROX presets would otherwise be usable
        // without the phone app.
        if (PairingStore.isPaired()) {
            return [new HomeView(), new HomeViewDelegate()];
        }
        return [new PairingRequiredView(), new PairingRequiredDelegate()];
    }
}

function getApp() as HyroxSimApp {
    return Application.getApp() as HyroxSimApp;
}
