//
//  Fonts.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 10/12/26.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Baked UI fonts (tools/numfont/build.swift). One set per display size —
// the resource ids are the same, monkey.jungle picks the folder.
//
//   hero / heroSm / big / mid — heavy italic digits ("0-9 : + -")
//   title / cap               — heavy uppercase text; cap is letter-spaced
//
// Text fonts only cover A-Z, digits and basic punctuation. Anything that
// can carry user text (workout names from the phone) must go through
// Ui.isPlain() and fall back to a system font.
module Fonts {
    var _hero as FontResource?;
    var _heroSm as FontResource?;
    var _big as FontResource?;
    var _mid as FontResource?;
    var _title as FontResource?;
    var _cap as FontResource?;

    function hero() as FontResource {
        if (_hero == null) { _hero = WatchUi.loadResource(Rez.Fonts.numHero) as FontResource; }
        return _hero as FontResource;
    }

    function heroSm() as FontResource {
        if (_heroSm == null) { _heroSm = WatchUi.loadResource(Rez.Fonts.numHeroSm) as FontResource; }
        return _heroSm as FontResource;
    }

    function big() as FontResource {
        if (_big == null) { _big = WatchUi.loadResource(Rez.Fonts.numBig) as FontResource; }
        return _big as FontResource;
    }

    function mid() as FontResource {
        if (_mid == null) { _mid = WatchUi.loadResource(Rez.Fonts.numMid) as FontResource; }
        return _mid as FontResource;
    }

    function title() as FontResource {
        if (_title == null) { _title = WatchUi.loadResource(Rez.Fonts.txtTitle) as FontResource; }
        return _title as FontResource;
    }

    function cap() as FontResource {
        if (_cap == null) { _cap = WatchUi.loadResource(Rez.Fonts.txtCap) as FontResource; }
        return _cap as FontResource;
    }
}
