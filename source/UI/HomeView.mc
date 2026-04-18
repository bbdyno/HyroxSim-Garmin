//
//  HomeView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Landing screen: branded title + "Start" hint. SELECT opens the division
// picker; from there the user chooses a preset which launches the engine.
class HomeView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Styles.COLOR_BACKGROUND);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 28, Graphics.FONT_LARGE,
            "HyroxSim", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Styles.COLOR_TEXT_SECOND, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 6, Graphics.FONT_SMALL,
            "HYROX Simulator", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 32, Graphics.FONT_XTINY,
            "Press START", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class HomeViewDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.pushView(
            new DivisionPickerView(),
            new DivisionPickerDelegate(),
            WatchUi.SLIDE_LEFT);
        return true;
    }
}
