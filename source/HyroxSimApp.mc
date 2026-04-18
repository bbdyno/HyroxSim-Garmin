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

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new HomeView()];
    }
}

function getApp() as HyroxSimApp {
    return Application.getApp() as HyroxSimApp;
}
