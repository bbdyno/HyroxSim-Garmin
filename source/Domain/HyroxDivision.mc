//
//  HyroxDivision.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;

module HyroxDivision {
    const MEN_OPEN_SINGLE = "menOpenSingle";
    const MEN_OPEN_DOUBLE = "menOpenDouble";
    const MEN_PRO_SINGLE = "menProSingle";
    const MEN_PRO_DOUBLE = "menProDouble";
    const WOMEN_OPEN_SINGLE = "womenOpenSingle";
    const WOMEN_OPEN_DOUBLE = "womenOpenDouble";
    const WOMEN_PRO_SINGLE = "womenProSingle";
    const WOMEN_PRO_DOUBLE = "womenProDouble";
    const MIXED_DOUBLE = "mixedDouble";

    function all() as Array<String> {
        return [
            MEN_OPEN_SINGLE, MEN_OPEN_DOUBLE,
            MEN_PRO_SINGLE, MEN_PRO_DOUBLE,
            WOMEN_OPEN_SINGLE, WOMEN_OPEN_DOUBLE,
            WOMEN_PRO_SINGLE, WOMEN_PRO_DOUBLE,
            MIXED_DOUBLE
        ];
    }

    function displayName(division as String) as String {
        if (division.equals(MEN_OPEN_SINGLE))    { return "Men's Open — Singles"; }
        if (division.equals(MEN_OPEN_DOUBLE))    { return "Men's Open — Doubles"; }
        if (division.equals(MEN_PRO_SINGLE))     { return "Men's Pro — Singles"; }
        if (division.equals(MEN_PRO_DOUBLE))     { return "Men's Pro — Doubles"; }
        if (division.equals(WOMEN_OPEN_SINGLE))  { return "Women's Open — Singles"; }
        if (division.equals(WOMEN_OPEN_DOUBLE))  { return "Women's Open — Doubles"; }
        if (division.equals(WOMEN_PRO_SINGLE))   { return "Women's Pro — Singles"; }
        if (division.equals(WOMEN_PRO_DOUBLE))   { return "Women's Pro — Doubles"; }
        if (division.equals(MIXED_DOUBLE))       { return "Mixed — Doubles"; }
        return "Unknown";
    }

    function shortName(division as String) as String {
        if (division.equals(MEN_OPEN_SINGLE))    { return "M Open"; }
        if (division.equals(MEN_OPEN_DOUBLE))    { return "M Open 2x"; }
        if (division.equals(MEN_PRO_SINGLE))     { return "M Pro"; }
        if (division.equals(MEN_PRO_DOUBLE))     { return "M Pro 2x"; }
        if (division.equals(WOMEN_OPEN_SINGLE))  { return "W Open"; }
        if (division.equals(WOMEN_OPEN_DOUBLE))  { return "W Open 2x"; }
        if (division.equals(WOMEN_PRO_SINGLE))   { return "W Pro"; }
        if (division.equals(WOMEN_PRO_DOUBLE))   { return "W Pro 2x"; }
        if (division.equals(MIXED_DOUBLE))       { return "Mixed 2x"; }
        return "?";
    }
}
