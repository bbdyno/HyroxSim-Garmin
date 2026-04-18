//
//  HeartRateProvider.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.Activity;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.Time;

// Wraps the Toybox.Sensor HR feed and pipes samples into a WorkoutEngine.
//
// Sampling strategy:
//   - enableHeartRate enables the HR sensor at the device's native rate (~1Hz).
//   - Every 250 ms the UI tick invokes `sampleOnce()` which reads
//     Activity.getActivityInfo().currentHeartRate — cheaper than subscribing
//     to Sensor listener callbacks and avoids duplicate samples.
class HeartRateProvider {

    public var engine;
    private var _enabled;

    function initialize(eng as WorkoutEngine) {
        engine = eng;
        _enabled = false;
    }

    function enable() as Void {
        if (_enabled) { return; }
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE] as Array<SensorType>);
        _enabled = true;
    }

    function disable() as Void {
        if (!_enabled) { return; }
        Sensor.setEnabledSensors([] as Array<SensorType>);
        _enabled = false;
    }

    // Call from the UI tick timer to forward the current HR reading.
    // Silently no-ops if no reading is available (first ~5s after enable).
    function sampleOnce() as Void {
        var info = Activity.getActivityInfo();
        if (info == null) { return; }
        var bpm = info.currentHeartRate;
        if (bpm == null) { return; }
        var t = Time.now().value().toLong() * 1000l;
        engine.ingestHeartRate(t, bpm);
    }
}
