//
//  StationTarget.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;

// Tagged-union-style dictionary:
//   { "kind" => "distance", "meters" => 1000 }
//   { "kind" => "reps",     "count"  => 100 }
//   { "kind" => "duration", "seconds" => 60 }
//   { "kind" => "none" }
module StationTarget {
    const KIND = "kind";
    const METERS = "meters";
    const COUNT = "count";
    const SECONDS = "seconds";

    const KIND_DISTANCE = "distance";
    const KIND_REPS = "reps";
    const KIND_DURATION = "duration";
    const KIND_NONE = "none";

    function distance(meters as Number) as Dictionary {
        return { KIND => KIND_DISTANCE, METERS => meters };
    }

    function reps(count as Number) as Dictionary {
        return { KIND => KIND_REPS, COUNT => count };
    }

    function duration(seconds as Number) as Dictionary {
        return { KIND => KIND_DURATION, SECONDS => seconds };
    }

    function none() as Dictionary {
        return { KIND => KIND_NONE };
    }

    function formatted(target as Dictionary) as String {
        var kind = target[KIND] as String;
        if (kind.equals(KIND_DISTANCE)) {
            return (target[METERS] as Number).toString() + " m";
        }
        if (kind.equals(KIND_REPS)) {
            return (target[COUNT] as Number).toString() + " reps";
        }
        if (kind.equals(KIND_DURATION)) {
            var sec = target[SECONDS] as Number;
            var m = (sec / 60).toNumber();
            var s = sec % 60;
            return Lang.format("$1$:$2$", [m.format("%02d"), s.format("%02d")]);
        }
        return "—";
    }
}
