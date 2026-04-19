//
//  PairingRequiredView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Gate view shown when the watch has never received a `hello` envelope
// from the companion app. Blocks all workout entry points so Garmin
// users cannot use the app standalone.
//
// English-only copy because fenix7 default fonts don't include CJK
// glyphs; Korean/JA/ZH strings render as missing-glyph diamonds.
class PairingRequiredView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Styles.COLOR_BACKGROUND);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        // Title
        dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 82, Graphics.FONT_SMALL,
            "HyroxSim", Graphics.TEXT_JUSTIFY_CENTER);

        // Status
        dc.setColor(Styles.COLOR_OVER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 52, Graphics.FONT_TINY,
            "Not paired", Graphics.TEXT_JUSTIFY_CENTER);

        // Instructions (split into multiple lines for round displays)
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 20, Graphics.FONT_XTINY,
            "Install HyroxSim", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 - 2, Graphics.FONT_XTINY,
            "on iPhone or Android", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Styles.COLOR_TEXT_SECOND, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 22, Graphics.FONT_XTINY,
            "then open the app", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 + 40, Graphics.FONT_XTINY,
            "to link this watch", Graphics.TEXT_JUSTIFY_CENTER);

        // Retry hint
        dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 68, Graphics.FONT_XTINY,
            "SELECT to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class PairingRequiredDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Re-check pairing status — if phone pushed a hello while this view
    // was up, unlock and switch to HomeView.
    function onSelect() as Boolean {
        if (PairingStore.isPaired()) {
            WatchUi.switchToView(
                new HomeView(),
                new HomeViewDelegate(),
                WatchUi.SLIDE_LEFT);
        } else {
            // Subtle shake: redraw current view.
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onBack() as Boolean {
        // Allow exit to watch face.
        return false;
    }
}
