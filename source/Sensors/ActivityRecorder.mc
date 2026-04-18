//
//  ActivityRecorder.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/19/26.
//

import Toybox.ActivityRecording;
import Toybox.Lang;

// Hosts a Garmin Activity so the workout is recorded in Garmin Connect
// (FIT file, Training Status contribution, etc.) in addition to our own
// SegmentRecord buffer.
//
// We map the whole HYROX session to SPORT_TRAINING since Garmin has no
// native 31-segment sport. Lap markers are pushed at each segment boundary
// to approximate the per-segment breakdown on Garmin Connect.
class ActivityRecorder {

    private var _session;
    private var _active;

    function initialize() {
        _session = null;
        _active = false;
    }

    function start() as Void {
        if (_active) { return; }
        var opts = {
            :name => "HYROX",
            :sport => ActivityRecording.SPORT_TRAINING,
            :subSport => ActivityRecording.SUB_SPORT_GENERIC
        };
        _session = ActivityRecording.createSession(opts);
        _session.start();
        _active = true;
    }

    // Record a lap boundary. Safe to call between segments.
    function lap() as Void {
        if (!_active || _session == null) { return; }
        _session.addLap();
    }

    function stop() as Void {
        if (!_active || _session == null) { return; }
        _session.stop();
        _session.save();
        _active = false;
        _session = null;
    }

    // Discard without saving — used on user-abort paths.
    function discard() as Void {
        if (!_active || _session == null) { return; }
        _session.stop();
        _session.discard();
        _active = false;
        _session = null;
    }

    function isActive() as Boolean {
        return _active;
    }
}
