//
//  SegmentType.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;

module SegmentType {
    const RUN = "run";
    const ROX_ZONE = "roxZone";
    const STATION = "station";

    function isValid(type as String) as Boolean {
        return type.equals(RUN) || type.equals(ROX_ZONE) || type.equals(STATION);
    }

    function tracksLocation(type as String) as Boolean {
        return type.equals(RUN) || type.equals(ROX_ZONE);
    }

    function tracksHeartRate(type as String) as Boolean {
        return true;
    }
}
