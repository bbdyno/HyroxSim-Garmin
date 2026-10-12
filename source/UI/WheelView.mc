//
//  WheelView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 10/12/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Flat list used by every menu-like screen (home, division, ROX zone,
// workout actions, my workouts). The focused row sits in the middle between
// two hairlines with a gold bar; the rows above and below peek in grey.
//
//        DIVISION            header (gold caption)
//      MEN OPEN              previous row
//   ───────────────────
//   ▌ MEN PRO                focused row: title
//   ▌ SINGLES · REF 1:10:00               subtitle
//   ───────────────────
//      WOMEN OPEN            next row
//          3 / 9
//
// Rows are Dictionaries: { :id, :title, :sub, :peek (optional) }. Titles that the baked fonts
// cannot draw (user text) fall back to a system font automatically.
//
// Subclasses override activate() and back().
class WheelView extends WatchUi.View {

    public var header as String;
    public var header2 as String?;          // optional second header line
    public var header2Color as Number;
    public var items as Array<Dictionary>;
    public var selected as Number;
    public var hintLabel as String?;        // upper-right button hint
    public var showRing as Boolean;         // brand ring on the bezel (home)
    public var emptyTitle as String;
    public var emptySub as String;

    function initialize(headerText as String) {
        View.initialize();
        header = headerText;
        header2 = null;
        header2Color = Palette.GREY;
        items = [] as Array<Dictionary>;
        selected = 0;
        hintLabel = "OK";
        showRing = false;
        emptyTitle = "";
        emptySub = "";
    }

    // MARK: - Selection

    function setItems(list as Array<Dictionary>) as Void {
        items = list;
        if (selected >= items.size()) {
            selected = items.size() > 0 ? items.size() - 1 : 0;
        }
    }

    function selectedId() as String? {
        if (items.size() == 0) { return null; }
        return (items[selected] as Dictionary)[:id] as String;
    }

    function selectNext() as Void {
        if (selected < items.size() - 1) {
            selected += 1;
            WatchUi.requestUpdate();
        }
    }

    function selectPrev() as Void {
        if (selected > 0) {
            selected -= 1;
            WatchUi.requestUpdate();
        }
    }

    // Called on SELECT / tap on the focused row.
    function activate() as Void {
    }

    // Called on BACK. Return false to let the system pop the view.
    function back() as Boolean {
        return false;
    }

    // Which row a touch at pixel y landed on: -1 previous, 0 focused, 1 next.
    function rowAt(y as Number, height as Number) as Number {
        if (y < height * 70 / 200) { return -1; }
        if (y > height * 130 / 200) { return 1; }
        return 0;
    }

    // MARK: - Drawing

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var cap = Fonts.cap();
        if (showRing) {
            Ring.draw(dc, null, 16, Palette.GOLD);
        }

        Ui.text(dc, 100, 25, cap, Palette.GOLD, header, Ui.CENTER);
        if (header2 != null) {
            Ui.text(dc, 100, 39, cap, header2Color, header2 as String, Ui.CENTER);
        }

        var edge = showRing ? 16 : 10;
        Ui.hairline(dc, 70, edge, 200 - edge);
        Ui.hairline(dc, 130, edge, 200 - edge);

        var n = items.size();
        if (n == 0) {
            Ui.text(dc, 100, 92, Fonts.title(), Styles.COLOR_TEXT, emptyTitle, Ui.CENTER);
            Ui.text(dc, 100, 112, cap, Palette.GREY, emptySub, Ui.CENTER);
            return;
        }

        var x = 31;
        // Focused row.
        dc.setColor(Palette.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(Ui.px(dc, 21), Ui.px(dc, 81), Ui.px(dc, 3), Ui.px(dc, 39));
        var item = items[selected] as Dictionary;
        _drawTitle(dc, item[:title] as String, x, 92, Ui.px(dc, 186 - x));
        var sub = item[:sub];
        if (sub != null) {
            Ui.text(dc, x, 113, cap, Palette.GREY,
                Ui.fit(dc, sub as String, cap, Ui.px(dc, 186 - x)), Ui.LEFT);
        }

        // Button hint first: the previous row shares its height with the
        // tab, so that row is cut to whatever room is left beside it.
        var peekRight = Ui.px(dc, 164);
        if (hintLabel != null) {
            peekRight = Ui.hint(dc, true, hintLabel as String) - Ui.px(dc, 4);
        }
        if (selected > 0) {
            _drawPeek(dc, items[selected - 1] as Dictionary,
                x, 58, peekRight - Ui.px(dc, x));
        }
        if (selected < n - 1) {
            _drawPeek(dc, items[selected + 1] as Dictionary,
                x, 143, Ui.px(dc, 164 - x));
        }
        if (n > 1) {
            Ui.text(dc, 100, 170, cap, Palette.DIM,
                (selected + 1).toString() + " / " + n.toString(), Ui.CENTER);
        }
    }

    private function _drawTitle(
            dc as Graphics.Dc,
            title as String,
            xUnits as Number,
            yUnits as Number,
            maxWidth as Number) as Void {
        var font = Ui.isPlain(title) ? Fonts.title() : Graphics.FONT_SMALL;
        Ui.text(dc, xUnits, yUnits, font, Styles.COLOR_TEXT,
            Ui.fit(dc, title, font, maxWidth), Ui.LEFT);
    }

    // Neighbour rows show :peek (a longer, unambiguous label) when the row
    // has one and it fits, else the title.
    private function _drawPeek(
            dc as Graphics.Dc,
            item as Dictionary,
            xUnits as Number,
            yUnits as Number,
            maxWidth as Number) as Void {
        var title = item[:title] as String;
        var peek = item[:peek];
        if (peek != null
                && dc.getTextWidthInPixels(peek as String, Fonts.cap()) <= maxWidth) {
            title = peek as String;
        }
        var font = Ui.isPlain(title) ? Fonts.cap() : Graphics.FONT_XTINY;
        Ui.text(dc, xUnits, yUnits, font, Palette.DIM,
            Ui.fit(dc, title, font, maxWidth), Ui.LEFT);
    }
}

// Input for any WheelView: UP/DOWN or swipe moves the focus, SELECT or a
// tap on the focused row activates it, a tap on a neighbour scrolls to it.
class WheelDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WheelView;

    function initialize(view as WheelView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.activate();
        return true;
    }

    function onNextPage() as Boolean {
        _view.selectNext();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.selectPrev();
        return true;
    }

    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        var dir = event.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            _view.selectNext();
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            _view.selectPrev();
            return true;
        }
        // Left/right fall through (swipe right = BACK on touch watches).
        return false;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var row = _view.rowAt(event.getCoordinates()[1],
            System.getDeviceSettings().screenHeight);
        if (row < 0) {
            _view.selectPrev();
        } else if (row > 0) {
            _view.selectNext();
        } else {
            _view.activate();
        }
        return true;
    }

    function onBack() as Boolean {
        return _view.back();
    }
}
