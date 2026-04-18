//
//  HomeView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class HomeView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            height / 2 - 24,
            Graphics.FONT_LARGE,
            WatchUi.loadResource(Rez.Strings.HelloHyrox) as String,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            height / 2 + 8,
            Graphics.FONT_SMALL,
            WatchUi.loadResource(Rez.Strings.Subtitle) as String,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function onHide() as Void {
    }
}
