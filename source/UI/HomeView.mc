//
//  HomeView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Home screen. A WheelView inside the gold 16-block brand ring:
//
//        HYROX SIM           wordmark
//        GPS READY           the one pre-workout state that matters
//   ───────────────────
//   ▌ HYROX RACE             entry: 9 official divisions
//   ▌ 9 DIVISIONS
//   ───────────────────
//      MY WORKOUTS           entry: templates pushed from the phone
//          1 / 2
//
// Until the phone app has paired, the second row is a "PAIR PHONE APP"
// notice instead — it is informational and does nothing on SELECT.
class HomeView extends WheelView {

    function initialize() {
        WheelView.initialize("HYROX SIM");
        showRing = true;
        _rebuild();
    }

    function onShow() as Void {
        HomeViewRegistry.setActive(self);
    }

    function onHide() as Void {
        HomeViewRegistry.clearIfActive(self);
    }

    // Called from PhoneMessageHandler when a template arrives while this
    // view is visible. Rebuilds the item list and repaints.
    function refresh() as Void {
        _rebuild();
        WatchUi.requestUpdate();
    }

    function activateSelected() as Void {
        activate();
    }

    function activate() as Void {
        var id = selectedId();
        if (id == null) { return; }
        if (id.equals("presets")) {
            var picker = new DivisionPickerView();
            WatchUi.pushView(picker, new WheelDelegate(picker), WatchUi.SLIDE_LEFT);
            return;
        }
        if (id.equals("custom")) {
            var cw = new CustomWorkoutsView();
            WatchUi.pushView(cw, new WheelDelegate(cw), WatchUi.SLIDE_LEFT);
            return;
        }
        // "info:phone" is a non-interactive notice — no-op on select.
    }

    function _rebuild() as Void {
        var list = [
            { :id => "presets", :title => "HYROX RACE", :sub => "9 DIVISIONS" }
        ] as Array<Dictionary>;
        var count = TemplateStore.list().size();
        if (count > 0) {
            list.add({
                :id => "custom",
                :title => "MY WORKOUTS",
                :sub => count.toString() + " FROM PHONE"
            });
        } else if (!PairingStore.isPaired()) {
            list.add({
                :id => "info:phone",
                :title => "PAIR PHONE APP",
                :sub => "GOALS & WORKOUTS"
            });
        }
        setItems(list);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        // GPS readiness: white once locked, grey while still looking.
        var app = getApp();
        if (app.gpsReady()) {
            header2 = "GPS READY";
            header2Color = Styles.COLOR_TEXT;
        } else if (app.gpsQuality >= 2) {
            header2 = "GPS ACQUIRING";
            header2Color = Palette.GREY;
        } else {
            header2 = "GPS SEARCHING";
            header2Color = Palette.GREY;
        }
        // The pairing notice cannot be opened — no button hint for it.
        var id = selectedId();
        hintLabel = (id != null && id.equals("info:phone")) ? null : "OPEN";
        WheelView.onUpdate(dc);
    }
}

// Weak-ish reference to the currently visible HomeView, set in onShow/onHide.
// PhoneMessageHandler hits this after a template.upsert/delete so the home
// refreshes while the user is looking at it.
module HomeViewRegistry {
    var _active as HomeView? = null;

    function setActive(view as HomeView) as Void { _active = view; }

    function clearIfActive(view as HomeView) as Void {
        if (_active == view) { _active = null; }
    }

    function refreshIfVisible() as Void {
        if (_active != null) { _active.refresh(); }
    }
}
