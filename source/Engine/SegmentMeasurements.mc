//
//  SegmentMeasurements.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;
import Toybox.Math;

// Raw sensor buffers collected while a segment is active.
//
//   {
//     "heartRateSamples" => [ { "tMs" => Long, "bpm" => Number }, ... ],
//     "locationSamples"  => [ { "tMs" => Long, "lat" => Double, "lon" => Double,
//                               "alt" => Double?, "hAcc" => Double?, "speed" => Double? }, ... ]
//   }
//
// On memory-constrained devices (e.g. fr265 with ~128KB budget) callers
// should limit retained samples; see WorkoutEngine.kMaxHeartRateSamples.
module SegmentMeasurements {
    const HEART_RATE_SAMPLES = "heartRateSamples";
    const LOCATION_SAMPLES = "locationSamples";

    function empty() as Dictionary {
        return {
            HEART_RATE_SAMPLES => [],
            LOCATION_SAMPLES => []
        };
    }

    function makeHeartRateSample(tMs as Long, bpm as Number) as Dictionary {
        return { "tMs" => tMs, "bpm" => bpm };
    }

    function makeLocationSample(
            tMs as Long,
            lat as Double,
            lon as Double,
            alt as Double?,
            hAcc as Double?,
            speed as Double?) as Dictionary {
        return {
            "tMs" => tMs,
            "lat" => lat,
            "lon" => lon,
            "alt" => alt,
            "hAcc" => hAcc,
            "speed" => speed
        };
    }

    // MARK: - Derived helpers

    function averageHeartRate(measurements as Dictionary) as Number? {
        var samples = measurements[HEART_RATE_SAMPLES] as Array<Dictionary>;
        if (samples.size() == 0) { return null; }
        var sum = 0;
        for (var i = 0; i < samples.size(); i += 1) {
            sum += (samples[i]["bpm"] as Number);
        }
        return (sum / samples.size()).toNumber();
    }

    // Haversine great-circle distance in meters between two samples.
    function haversineMeters(a as Dictionary, b as Dictionary) as Double {
        var R = 6371000.0d;
        var lat1 = toRadians(a["lat"] as Double);
        var lat2 = toRadians(b["lat"] as Double);
        var dLat = lat2 - lat1;
        var dLon = toRadians((b["lon"] as Double) - (a["lon"] as Double));
        var h = Math.sin(dLat / 2.0d) * Math.sin(dLat / 2.0d)
              + Math.cos(lat1) * Math.cos(lat2)
              * Math.sin(dLon / 2.0d) * Math.sin(dLon / 2.0d);
        var c = 2.0d * Math.asin(Math.sqrt(h));
        return R * c;
    }

    // Total GPS distance in meters (matches iOS SegmentMeasurements.distanceMeters).
    function distanceMeters(measurements as Dictionary) as Double {
        var samples = measurements[LOCATION_SAMPLES] as Array<Dictionary>;
        if (samples.size() < 2) { return 0.0d; }
        var total = 0.0d;
        for (var i = 1; i < samples.size(); i += 1) {
            var prev = samples[i - 1] as Dictionary;
            var curr = samples[i] as Dictionary;
            // Skip samples with poor accuracy (matches iOS 30m threshold).
            var prevAcc = prev["hAcc"];
            var currAcc = curr["hAcc"];
            if (prevAcc != null && (prevAcc as Double) > 30.0d) { continue; }
            if (currAcc != null && (currAcc as Double) > 30.0d) { continue; }
            total += haversineMeters(prev, curr);
        }
        return total;
    }

    function toRadians(deg as Double) as Double {
        return deg * (Math.PI.toDouble() / 180.0d);
    }
}
