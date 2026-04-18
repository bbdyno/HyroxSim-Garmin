//
//  Styles.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Graphics;
import Toybox.Lang;

// Design tokens mirroring iOS DesignTokens.swift (black + gold scheme).
// All colors 0xRRGGBB; used via dc.setColor(fg, bg).
module Styles {
    const COLOR_BACKGROUND   = 0x000000;   // pure black
    const COLOR_ACCENT       = 0xFFD700;   // gold
    const COLOR_TEXT_PRIMARY = 0xFFFFFF;
    const COLOR_TEXT_SECOND  = 0xAAAAAA;
    const COLOR_TEXT_TERTIARY = 0x666666;

    const COLOR_RUN          = 0x007AFF;   // systemBlue
    const COLOR_ROX_ZONE     = 0xFF9500;   // systemOrange
    const COLOR_STATION      = 0xFFD700;   // gold
    const COLOR_OVER         = 0xFF3B30;   // delta over target
    const COLOR_UNDER        = 0xFFD700;   // delta under target (ahead)

    function colorForSegmentType(type as String) as Number {
        if (type.equals(SegmentType.RUN))       { return COLOR_RUN; }
        if (type.equals(SegmentType.ROX_ZONE))  { return COLOR_ROX_ZONE; }
        return COLOR_STATION;
    }

    // MARK: - Time formatting

    // Formats milliseconds as "MM:SS" or "H:MM:SS" when over an hour.
    function formatElapsedMs(ms as Long) as String {
        var totalSec = (ms / 1000l).toNumber();
        var h = totalSec / 3600;
        var m = (totalSec % 3600) / 60;
        var s = totalSec % 60;
        if (h > 0) {
            return Lang.format("$1$:$2$:$3$",
                [h.format("%d"), m.format("%02d"), s.format("%02d")]);
        }
        return Lang.format("$1$:$2$",
            [m.format("%02d"), s.format("%02d")]);
    }

    // Formats a delta as "+MM:SS" or "-MM:SS". Positive = over target (behind).
    function formatDeltaMs(ms as Long) as String {
        var sign = ms >= 0 ? "+" : "-";
        var absMs = ms >= 0 ? ms : -ms;
        return sign + formatElapsedMs(absMs);
    }
}
