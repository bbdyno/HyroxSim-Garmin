//
//  Styles.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;

// 2.0 design tokens — black + gold, mirroring the phone app.
//
// Two palettes, picked at build time by monkey.jungle annotations:
//   :amoled — the exact brand colours.
//   :mip    — fenix 7's 64-colour panel only has 00/55/AA/FF per channel, so
//             every token is snapped to a colour that panel can really show
//             (and dark greys are lifted: 0x2E2E2E would render as black).
(:amoled)
module Palette {
    const GOLD     = 0xFFD700;   // accent, ahead of goal
    const ORANGE   = 0xFF7A33;   // behind goal
    const BLUE     = 0x4C99FF;   // run label
    const GREY     = 0x8A8A8A;   // secondary text
    const DIM      = 0x5C5C5C;   // tertiary text
    const UPCOMING = 0x2E2E2E;   // ring segments not reached yet
    const HAIRLINE = 0x2A2A2A;
}

(:mip)
module Palette {
    const GOLD     = 0xFFFF00;
    const ORANGE   = 0xFF5500;
    const BLUE     = 0x55AAFF;
    const GREY     = 0xAAAAAA;
    const DIM      = 0xAAAAAA;
    const UPCOMING = 0x555555;
    const HAIRLINE = 0x555555;
}

module Styles {
    const COLOR_BACKGROUND = 0x000000;   // pure black
    const COLOR_TEXT       = 0xFFFFFF;

    // Label colour for a segment type. Only the caption is tinted — the
    // screen itself always stays black.
    function colorForSegmentType(type as String) as Number {
        if (type.equals(SegmentType.RUN))      { return Palette.BLUE; }
        if (type.equals(SegmentType.STATION))  { return Palette.GOLD; }
        return COLOR_TEXT;
    }

    // Ahead of (or on) goal = gold, behind = orange.
    function colorForDelta(deltaMs as Long) as Number {
        return deltaMs > 0l ? Palette.ORANGE : Palette.GOLD;
    }

    // MARK: - Time formatting

    // "4:12", "12:34", "1:02:15" — no leading zero on the first field.
    function formatClock(ms as Long) as String {
        if (ms < 0l) { ms = 0l; }
        var totalSec = (ms / 1000l).toNumber();
        var h = totalSec / 3600;
        var m = (totalSec % 3600) / 60;
        var s = totalSec % 60;
        if (h > 0) {
            return h.toString() + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.toString() + ":" + s.format("%02d");
    }

    // "+0:21" / "-0:12". Positive = over target (behind).
    function formatDelta(ms as Long) as String {
        if (ms > 0l) { return "+" + formatClock(ms); }
        return "-" + formatClock(-ms);
    }
}
