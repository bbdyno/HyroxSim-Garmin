//
//  StationKind.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;

module StationKind {
    const SKI_ERG = "skiErg";
    const SLED_PUSH = "sledPush";
    const SLED_PULL = "sledPull";
    const BURPEE_BROAD_JUMPS = "burpeeBroadJumps";
    const ROWING = "rowing";
    const FARMERS_CARRY = "farmersCarry";
    const SANDBAG_LUNGES = "sandbagLunges";
    const WALL_BALLS = "wallBalls";
    const CUSTOM = "custom";

    function standardOrder() as Array<String> {
        return [
            SKI_ERG,
            SLED_PUSH,
            SLED_PULL,
            BURPEE_BROAD_JUMPS,
            ROWING,
            FARMERS_CARRY,
            SANDBAG_LUNGES,
            WALL_BALLS
        ];
    }

    function displayName(kind as String) as String {
        if (kind.equals(SKI_ERG))             { return "SkiErg"; }
        if (kind.equals(SLED_PUSH))           { return "Sled Push"; }
        if (kind.equals(SLED_PULL))           { return "Sled Pull"; }
        if (kind.equals(BURPEE_BROAD_JUMPS))  { return "Burpee Broad Jumps"; }
        if (kind.equals(ROWING))              { return "Rowing"; }
        if (kind.equals(FARMERS_CARRY))       { return "Farmers Carry"; }
        if (kind.equals(SANDBAG_LUNGES))      { return "Sandbag Lunges"; }
        if (kind.equals(WALL_BALLS))          { return "Wall Balls"; }
        return "Custom";
    }

    // Compact uppercase label for the watch UI — every name fits one line
    // of a 260 px round display.
    function shortName(kind as String) as String {
        if (kind.equals(SKI_ERG))             { return "SKIERG"; }
        if (kind.equals(SLED_PUSH))           { return "SLED PUSH"; }
        if (kind.equals(SLED_PULL))           { return "SLED PULL"; }
        if (kind.equals(BURPEE_BROAD_JUMPS))  { return "BURPEE BJ"; }
        if (kind.equals(ROWING))              { return "ROWING"; }
        if (kind.equals(FARMERS_CARRY))       { return "FARMERS"; }
        if (kind.equals(SANDBAG_LUNGES))      { return "LUNGES"; }
        if (kind.equals(WALL_BALLS))          { return "WALL BALLS"; }
        return "STATION";
    }

    function defaultTarget(kind as String) as Dictionary {
        if (kind.equals(SKI_ERG))            { return StationTarget.distance(1000); }
        if (kind.equals(SLED_PUSH))          { return StationTarget.distance(50); }
        if (kind.equals(SLED_PULL))          { return StationTarget.distance(50); }
        if (kind.equals(BURPEE_BROAD_JUMPS)) { return StationTarget.distance(80); }
        if (kind.equals(ROWING))             { return StationTarget.distance(1000); }
        if (kind.equals(FARMERS_CARRY))      { return StationTarget.distance(200); }
        if (kind.equals(SANDBAG_LUNGES))     { return StationTarget.distance(100); }
        if (kind.equals(WALL_BALLS))         { return StationTarget.reps(100); }
        return StationTarget.none();
    }
}
