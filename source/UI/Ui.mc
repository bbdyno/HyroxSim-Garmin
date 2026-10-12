//
//  Ui.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 10/12/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Shared drawing helpers. Every position is given in "units": 1/200 of the
// display diameter, so one layout serves 260 px … 454 px round screens.
module Ui {
    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    const LEFT   = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
    const RIGHT  = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;

    // Units → pixels.
    function px(dc as Graphics.Dc, units as Numeric) as Number {
        return (dc.getWidth() * units / 200.0 + 0.5).toNumber();
    }

    function clear(dc as Graphics.Dc) as Void {
        dc.setColor(Styles.COLOR_TEXT, Styles.COLOR_BACKGROUND);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
    }

    function text(
            dc as Graphics.Dc,
            xUnits as Numeric,
            yUnits as Numeric,
            font as Graphics.FontType,
            color as Number,
            str as String,
            just as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px(dc, xUnits), px(dc, yUnits), font, str, just);
    }

    // 1 pt divider (2 px on the dense AMOLED panels).
    function hairline(
            dc as Graphics.Dc,
            yUnits as Numeric,
            x0Units as Numeric,
            x1Units as Numeric) as Void {
        var x0 = px(dc, x0Units);
        dc.setColor(Palette.HAIRLINE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0, px(dc, yUnits), px(dc, x1Units) - x0,
            dc.getWidth() >= 360 ? 2 : 1);
    }

    // Half-width (in units) of the round screen at height yUnits, measured
    // on a circle of the given radius. Used to keep rows inside the bezel.
    function halfChord(radiusUnits as Numeric, yUnits as Numeric) as Float {
        var dy = yUnits - 100.0;
        var sq = radiusUnits * radiusUnits - dy * dy;
        if (sq <= 0.0) { return 0.0; }
        return Math.sqrt(sq).toFloat();
    }

    // Button hint: a small white tab with black text sitting on the bezel
    // next to a physical button. All five supported watches have START/STOP
    // at the upper right (−30°) and BACK at the lower right (+30°), so those
    // are the only two positions. Returns the tab's left edge in pixels so
    // callers can keep their own text clear of it.
    function hint(dc as Graphics.Dc, upper as Boolean, label as String) as Number {
        var font = Fonts.cap();
        var boxH = px(dc, 13);
        var padX = px(dc, 3);
        var boxW = dc.getTextWidthInPixels(label, font) + 2 * padX;
        var cy = px(dc, upper ? 62 : 138);
        var top = cy - boxH / 2;
        // The corner farthest from the centre must stay on the glass.
        var farY = upper ? 55.5 : 144.5;
        var right = px(dc, 100 + halfChord(98, farY));
        dc.setColor(Styles.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(right - boxW, top, boxW, boxH);
        dc.setColor(Styles.COLOR_BACKGROUND, Graphics.COLOR_TRANSPARENT);
        // + half the trailing letter-spacing so the word looks centred.
        dc.drawText(right - boxW / 2 + px(dc, 0.7), cy, font, label, CENTER);
        return right - boxW;
    }

    // True when the baked text fonts can draw every character of `str`
    // (they hold A-Z, digits and basic punctuation only).
    function isPlain(str as String) as Boolean {
        var chars = str.toCharArray();
        for (var i = 0; i < chars.size(); i += 1) {
            var c = chars[i].toNumber();
            if (c == 0x00B7 || c == 0x2665) { continue; }
            if (c < 0x20 || c > 0x5A) { return false; }
            // Punctuation in 0x20-0x5A that the fonts do not carry.
            if (c == 0x22 || c == 0x24 || c == 0x2A || c == 0x3B || c == 0x3C
                    || c == 0x3D || c == 0x3E || c == 0x40) {
                return false;
            }
        }
        return true;
    }

    // Shortens `str` until it fits maxWidth pixels, ending in "." when cut.
    function fit(
            dc as Graphics.Dc,
            str as String,
            font as Graphics.FontType,
            maxWidth as Number) as String {
        if (dc.getTextWidthInPixels(str, font) <= maxWidth) { return str; }
        var len = str.length();
        while (len > 1) {
            len -= 1;
            var cut = str.substring(0, len) as String;
            // Never leave a space in front of the ellipsis dot.
            if (cut.substring(len - 1, len).equals(" ")) { continue; }
            cut = cut + ".";
            if (dc.getTextWidthInPixels(cut, font) <= maxWidth) { return cut; }
        }
        return str.substring(0, 1) as String;
    }
}
