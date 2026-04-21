//
//  HomeView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Custom HYROX home screen. Vertical carousel of big cards — each card is
// one workout entry (HYROX presets or a user template). UP/DOWN changes
// the focused card; SELECT activates it.
//
// Visual structure (round 454×454):
//   ┌──────────────────────┐
//   │       HYROX          │  gold wordmark
//   │       ─────          │  accent underline
//   │      SIMULATOR       │  tertiary subtitle
//   │ ┌──────────────────┐ │  focused card — surface bg, colored trim
//   │ │   HYROX PRESETS  │ │  title
//   │ │   9 DIVISIONS    │ │  subtitle
//   │ └──────────────────┘ │
//   │      START ▸         │  action hint
//   │      • ○ ○ ○         │  dot indicators
//   └──────────────────────┘
class HomeView extends WatchUi.View {

    private var _items as Array<Dictionary>;
    private var _selected as Number;

    function initialize() {
        View.initialize();
        _items = [] as Array<Dictionary>;
        _selected = 0;
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

    function selectNext() as Void {
        if (_selected < _items.size() - 1) {
            _selected += 1;
            WatchUi.requestUpdate();
        }
    }

    function selectPrev() as Void {
        if (_selected > 0) {
            _selected -= 1;
            WatchUi.requestUpdate();
        }
    }

    function activateSelected() as Void {
        if (_items.size() == 0) { return; }
        var item = _items[_selected] as Dictionary;
        var id = item[:id] as String;
        if (id.equals("presets")) {
            WatchUi.pushView(
                new DivisionPickerView(),
                new DivisionPickerDelegate(),
                WatchUi.SLIDE_LEFT);
            return;
        }
        if (id.equals("custom")) {
            var cw = new CustomWorkoutsView();
            WatchUi.pushView(cw, new CustomWorkoutsViewDelegate(cw), WatchUi.SLIDE_LEFT);
            return;
        }
        // "info:phone" is a non-interactive hint — no-op on select.
    }

    function _rebuild() as Void {
        _items = [
            {
                :id => "presets",
                :title => "HYROX PRESETS",
                :subtitle => "9 DIVISIONS",
                :color => Styles.COLOR_ACCENT
            }
        ] as Array<Dictionary>;
        var templates = TemplateStore.list();
        if (templates.size() > 0) {
            _items.add({
                :id => "custom",
                :title => "MY WORKOUTS",
                :subtitle => templates.size().toString() + " CUSTOM",
                :color => Styles.COLOR_RUN
            });
        } else if (!PairingStore.isPaired()) {
            _items.add({
                :id => "info:phone",
                :title => "PAIR PHONE APP",
                :subtitle => "FOR CUSTOM WORKOUTS",
                :color => Styles.COLOR_TEXT_SECOND
            });
        }
        if (_selected >= _items.size()) {
            _selected = _items.size() > 0 ? _items.size() - 1 : 0;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Styles.COLOR_BACKGROUND);
        dc.clear();
        dc.setAntiAlias(true);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var centerJust = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // HYROX wordmark + underline + subtitle
        dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.17).toNumber(), Graphics.FONT_LARGE, "HYROX", centerJust);
        var lbh = dc.getFontHeight(Graphics.FONT_LARGE) / 2;
        dc.fillRectangle(cx - 42, (h * 0.17).toNumber() + lbh + 3, 84, 2);
        dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.29).toNumber(), Graphics.FONT_XTINY, "SIMULATOR", centerJust);

        // Focused card
        if (_items.size() > 0) {
            var item = _items[_selected] as Dictionary;
            var cardX = (w * 0.10).toNumber();
            var cardY = (h * 0.38).toNumber();
            var cardW = w - 2 * cardX;
            var cardH = (h * 0.28).toNumber();

            dc.setColor(Styles.COLOR_SURFACE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, 16);
            dc.setPenWidth(2);
            dc.setColor(item[:color] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, 16);
            dc.setPenWidth(1);

            dc.setColor(item[:color] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cardY + (cardH * 0.36).toNumber(), Graphics.FONT_SMALL,
                item[:title] as String, centerJust);

            dc.setColor(Styles.COLOR_TEXT_SECOND, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cardY + (cardH * 0.72).toNumber(), Graphics.FONT_XTINY,
                item[:subtitle] as String, centerJust);
        }

        // START hint
        dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.76).toNumber(), Graphics.FONT_XTINY, "START ▸", centerJust);

        // Dot indicators
        _drawDots(dc, cx, (h * 0.88).toNumber());
    }

    private function _drawDots(dc as Graphics.Dc, cx as Number, y as Number) as Void {
        var n = _items.size();
        if (n <= 1) { return; }

        // Cap visible dots at 9; show "X / N" if more.
        if (n > 9) {
            dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y,
                Graphics.FONT_XTINY,
                (_selected + 1).toString() + " / " + n.toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var gap = 14;
        var totalW = (n - 1) * gap;
        var startX = cx - totalW / 2;
        for (var i = 0; i < n; i += 1) {
            var x = startX + i * gap;
            if (i == _selected) {
                dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 4);
            } else {
                dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 2);
            }
        }
    }
}

class HomeViewDelegate extends WatchUi.BehaviorDelegate {

    private var _view as HomeView;

    function initialize(v as HomeView) {
        BehaviorDelegate.initialize();
        _view = v;
    }

    function onSelect() as Boolean {
        _view.activateSelected();
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
        } else if (dir == WatchUi.SWIPE_DOWN) {
            _view.selectPrev();
        }
        return true;
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
