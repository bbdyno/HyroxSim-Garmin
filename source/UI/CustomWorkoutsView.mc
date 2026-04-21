//
//  CustomWorkoutsView.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/22/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Scrollable list of user-pushed WorkoutTemplates. Pushed from HomeView
// when the user selects "MY WORKOUTS". Mirrors the ResultView scroll
// pattern — sticky header, clipped list area, right-side scrollbar.
class CustomWorkoutsView extends WatchUi.View {

    private var _templates as Array<Dictionary>;
    private var _selected as Number;
    private var _scroll as Number;
    private var _rowH as Number;
    private var _maxScroll as Number;
    private var _visibleH as Number;
    private var _listTop as Number;

    function initialize() {
        View.initialize();
        _templates = TemplateStore.list();
        _selected = 0;
        _scroll = 0;
        _rowH = 0;
        _maxScroll = 0;
        _visibleH = 0;
        _listTop = 0;
    }

    function onShow() as Void {
        CustomWorkoutsViewRegistry.setActive(self);
        _templates = TemplateStore.list();
        if (_selected >= _templates.size()) {
            _selected = _templates.size() > 0 ? _templates.size() - 1 : 0;
        }
    }

    function onHide() as Void {
        CustomWorkoutsViewRegistry.clearIfActive(self);
    }

    function refresh() as Void {
        _templates = TemplateStore.list();
        if (_selected >= _templates.size()) {
            _selected = _templates.size() > 0 ? _templates.size() - 1 : 0;
        }
        WatchUi.requestUpdate();
    }

    function selectNext() as Void {
        if (_selected < _templates.size() - 1) {
            _selected += 1;
            _ensureVisible();
            WatchUi.requestUpdate();
        }
    }

    function selectPrev() as Void {
        if (_selected > 0) {
            _selected -= 1;
            _ensureVisible();
            WatchUi.requestUpdate();
        }
    }

    function activateSelected() as Void {
        if (_templates.size() == 0) { return; }
        var t = _templates[_selected] as Dictionary;
        var view = new ActiveWorkoutView(t);
        var delegate = new ActiveWorkoutDelegate(view);
        WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT);
    }

    // Scroll so the focused row is within the visible list area.
    private function _ensureVisible() as Void {
        if (_rowH == 0) { return; }
        var rowTop = _selected * _rowH;
        var rowBot = rowTop + _rowH;
        if (rowTop < _scroll) {
            _scroll = rowTop;
        } else if (rowBot > _scroll + _visibleH) {
            _scroll = rowBot - _visibleH;
        }
        if (_scroll < 0) { _scroll = 0; }
        if (_scroll > _maxScroll) { _scroll = _maxScroll; }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Styles.COLOR_BACKGROUND);
        dc.clear();
        dc.setAntiAlias(true);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var centerJust = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Sticky header (20% of screen)
        var headerH = (h * 0.20).toNumber();
        dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (headerH * 0.58).toNumber(), Graphics.FONT_SMALL,
            "MY WORKOUTS", centerJust);
        var lh = dc.getFontHeight(Graphics.FONT_SMALL) / 2;
        dc.fillRectangle(cx - 48, (headerH * 0.58).toNumber() + lh + 3, 96, 2);

        dc.setColor(Styles.COLOR_TEXT_TERTIARY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(24, headerH, w - 48, 1);

        // List area
        var listTop = headerH + 4;
        var listBot = h - 6;
        var visibleH = listBot - listTop;
        _listTop = listTop;
        _visibleH = visibleH;

        if (_templates.size() == 0) {
            dc.setColor(Styles.COLOR_TEXT_SECOND, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, listTop + visibleH / 2, Graphics.FONT_XTINY,
                "PUSH FROM PHONE APP", centerJust);
            return;
        }

        var rowH = 56;
        _rowH = rowH;
        var contentH = _templates.size() * rowH;
        _maxScroll = contentH > visibleH ? contentH - visibleH : 0;
        if (_scroll > _maxScroll) { _scroll = _maxScroll; }

        dc.setClip(0, listTop, w, visibleH);

        for (var i = 0; i < _templates.size(); i += 1) {
            var rowY = listTop + i * rowH - _scroll;
            if (rowY + rowH < listTop || rowY > listBot) {
                continue;
            }
            _drawRow(dc, _templates[i] as Dictionary, i, rowY, rowH, w);
        }

        dc.clearClip();

        // Scrollbar on right
        if (_maxScroll > 0) {
            var trackTop = listTop + 6;
            var trackH = visibleH - 12;
            var barH = (trackH.toFloat() * visibleH / contentH).toNumber();
            if (barH < 24) { barH = 24; }
            var barY = trackTop + ((trackH - barH).toFloat() * _scroll / _maxScroll).toNumber();
            dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(w - 6, barY, 3, barH, 2);
        }
    }

    private function _drawRow(
            dc as Graphics.Dc,
            t as Dictionary,
            idx as Number,
            rowY as Number,
            rowH as Number,
            w as Number) as Void {
        var isSelected = (idx == _selected);

        // Highlight background for selected row
        if (isSelected) {
            dc.setColor(Styles.COLOR_SURFACE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(12, rowY + 4, w - 24, rowH - 8, 10);
            dc.setPenWidth(2);
            dc.setColor(Styles.COLOR_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(12, rowY + 4, w - 24, rowH - 8, 10);
            dc.setPenWidth(1);
        }

        var y1 = rowY + rowH * 0.34;
        var y2 = rowY + rowH * 0.72;
        var leftJust = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        var name = (t[WorkoutTemplate.NAME] as String).toUpper();
        var stations = WorkoutTemplate.stationCount(t);
        var rox = (t[WorkoutTemplate.USES_ROX_ZONE] as Boolean) ? "ROX ON" : "ROX OFF";
        var sub = stations.toString() + " STATIONS  ·  " + rox;

        dc.setColor(Styles.COLOR_TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(26, y1, Graphics.FONT_XTINY, name, leftJust);
        dc.setColor(Styles.COLOR_TEXT_SECOND, Graphics.COLOR_TRANSPARENT);
        dc.drawText(26, y2, Graphics.FONT_XTINY, sub, leftJust);
    }
}

class CustomWorkoutsViewDelegate extends WatchUi.BehaviorDelegate {
    private var _view as CustomWorkoutsView;

    function initialize(v as CustomWorkoutsView) {
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
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

module CustomWorkoutsViewRegistry {
    var _active as CustomWorkoutsView? = null;

    function setActive(v as CustomWorkoutsView) as Void { _active = v; }

    function clearIfActive(v as CustomWorkoutsView) as Void {
        if (_active == v) { _active = null; }
    }

    function refreshIfVisible() as Void {
        if (_active != null) { _active.refresh(); }
    }
}
