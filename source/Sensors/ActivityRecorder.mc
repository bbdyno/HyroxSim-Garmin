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
// Sport choice: SPORT_RUNNING + SUB_SPORT_GENERIC. Garmin has no native
// 31-segment sport, but the dominant phase of a HYROX session is the 8
// running segments and the firmware's running profile is what unlocks the
// pace/distance smoothing, corner-cut compensation, and accelerometer
// fusion that make GPS feel as good as the native running activity. The
// previous SPORT_TRAINING choice put us on the firmware's "indoor /
// generic" GPS profile and was visibly worse in head-to-head comparisons.
//
// Trade-off: the session will surface in Garmin Connect as a "Run" rather
// than a generic training session. This is the right default for a HYROX
// race-style workout (which is mostly running) and is consistent with how
// most HYROX athletes log on other platforms.
//
// Lap markers are not pushed at segment boundaries — see ActiveWorkoutDelegate
// for the rationale (TTS "Lap N" cannot be suppressed via CIQ).
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
            :sport => ActivityRecording.SPORT_RUNNING,
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
    //
    // IMPORTANT: do NOT call _session.stop() before discard(). On Garmin
    // firmware, stop() finalizes the FIT buffer for the Connect sync queue;
    // a subsequent discard() can no-op and the run still surfaces in
    // Garmin Connect. Discard the live session directly.
    function discard() as Void {
        if (!_active || _session == null) { return; }
        _session.discard();
        _active = false;
        _session = null;
    }

    function isActive() as Boolean {
        return _active;
    }
}
