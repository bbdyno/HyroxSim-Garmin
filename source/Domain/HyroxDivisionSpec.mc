//
//  HyroxDivisionSpec.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;

// Station specifications per HYROX division.
// Ported 1:1 from iOS HyroxDivisionSpec.swift — verify against current rulebook.
//
// A "spec" dictionary has the shape:
//   {
//     "kind"       => <StationKind string>,
//     "target"     => <StationTarget dict>,
//     "weightKg"   => <Float or null>,
//     "weightNote" => <String or null>
//   }
module HyroxDivisionSpec {
    const KIND = "kind";
    const TARGET = "target";
    const WEIGHT_KG = "weightKg";
    const WEIGHT_NOTE = "weightNote";

    // Returns the 8 station specs for a given division, in official order:
    //   SkiErg → Sled Push → Sled Pull → Burpee Broad Jumps → Rowing
    //   → Farmers Carry → Sandbag Lunges → Wall Balls
    function stationsFor(division as String) as Array<Dictionary> {
        if (division.equals(HyroxDivision.MEN_OPEN_SINGLE)
                || division.equals(HyroxDivision.MEN_OPEN_DOUBLE)
                || division.equals(HyroxDivision.MIXED_DOUBLE)) {
            return menOpenSpecs();
        }
        if (division.equals(HyroxDivision.MEN_PRO_SINGLE)
                || division.equals(HyroxDivision.MEN_PRO_DOUBLE)) {
            return menProSpecs();
        }
        if (division.equals(HyroxDivision.WOMEN_OPEN_SINGLE)
                || division.equals(HyroxDivision.WOMEN_OPEN_DOUBLE)) {
            return womenOpenSpecs();
        }
        if (division.equals(HyroxDivision.WOMEN_PRO_SINGLE)
                || division.equals(HyroxDivision.WOMEN_PRO_DOUBLE)) {
            return womenProSpecs();
        }
        return menOpenSpecs();
    }

    // MARK: - Men's Open (Single & Double identical; Mixed also reuses)

    function menOpenSpecs() as Array<Dictionary> {
        return [
            spec(StationKind.SKI_ERG,            StationTarget.distance(1000), null, null),
            spec(StationKind.SLED_PUSH,          StationTarget.distance(50),   152, "sled total"),
            spec(StationKind.SLED_PULL,          StationTarget.distance(50),   103, "sled total"),
            spec(StationKind.BURPEE_BROAD_JUMPS, StationTarget.distance(80),   null, null),
            spec(StationKind.ROWING,             StationTarget.distance(1000), null, null),
            spec(StationKind.FARMERS_CARRY,      StationTarget.distance(200),  24,  "per hand"),
            spec(StationKind.SANDBAG_LUNGES,     StationTarget.distance(100),  20,  null),
            spec(StationKind.WALL_BALLS,         StationTarget.reps(100),      6,   null)
        ];
    }

    // MARK: - Men's Pro (Single & Double identical)

    function menProSpecs() as Array<Dictionary> {
        return [
            spec(StationKind.SKI_ERG,            StationTarget.distance(1000), null, null),
            spec(StationKind.SLED_PUSH,          StationTarget.distance(50),   202, "sled total"),
            spec(StationKind.SLED_PULL,          StationTarget.distance(50),   153, "sled total"),
            spec(StationKind.BURPEE_BROAD_JUMPS, StationTarget.distance(80),   null, null),
            spec(StationKind.ROWING,             StationTarget.distance(1000), null, null),
            spec(StationKind.FARMERS_CARRY,      StationTarget.distance(200),  32,  "per hand"),
            spec(StationKind.SANDBAG_LUNGES,     StationTarget.distance(100),  30,  null),
            spec(StationKind.WALL_BALLS,         StationTarget.reps(100),      9,   null)
        ];
    }

    // MARK: - Women's Open (Single & Double identical)

    function womenOpenSpecs() as Array<Dictionary> {
        return [
            spec(StationKind.SKI_ERG,            StationTarget.distance(1000), null, null),
            spec(StationKind.SLED_PUSH,          StationTarget.distance(50),   102, "sled total"),
            spec(StationKind.SLED_PULL,          StationTarget.distance(50),   78,  "sled total"),
            spec(StationKind.BURPEE_BROAD_JUMPS, StationTarget.distance(80),   null, null),
            spec(StationKind.ROWING,             StationTarget.distance(1000), null, null),
            spec(StationKind.FARMERS_CARRY,      StationTarget.distance(200),  16,  "per hand"),
            spec(StationKind.SANDBAG_LUNGES,     StationTarget.distance(100),  10,  null),
            spec(StationKind.WALL_BALLS,         StationTarget.reps(75),       4,   null)
        ];
    }

    // MARK: - Women's Pro (Single & Double identical; uses Men's Open weights)

    function womenProSpecs() as Array<Dictionary> {
        return [
            spec(StationKind.SKI_ERG,            StationTarget.distance(1000), null, null),
            spec(StationKind.SLED_PUSH,          StationTarget.distance(50),   152, "sled total"),
            spec(StationKind.SLED_PULL,          StationTarget.distance(50),   103, "sled total"),
            spec(StationKind.BURPEE_BROAD_JUMPS, StationTarget.distance(80),   null, null),
            spec(StationKind.ROWING,             StationTarget.distance(1000), null, null),
            spec(StationKind.FARMERS_CARRY,      StationTarget.distance(200),  24,  "per hand"),
            spec(StationKind.SANDBAG_LUNGES,     StationTarget.distance(100),  20,  null),
            spec(StationKind.WALL_BALLS,         StationTarget.reps(100),      6,   null)
        ];
    }

    // MARK: - Private helper (module functions are implicitly module-scoped)

    function spec(
            kind as String,
            target as Dictionary,
            weightKg as Number?,
            weightNote as String?) as Dictionary {
        return {
            KIND => kind,
            TARGET => target,
            WEIGHT_KG => weightKg,
            WEIGHT_NOTE => weightNote
        };
    }
}
