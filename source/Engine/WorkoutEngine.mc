//
//  WorkoutEngine.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;

// Pure state machine managing workout progression.
//
// All time values are injected via epoch-millisecond Long parameters — the
// engine never reads the system clock directly, ensuring deterministic
// behaviour and full testability. Mirrors iOS HyroxCore.WorkoutEngine.
//
// Memory note: heart-rate samples are capped at kMaxHeartRateSamples per
// segment to survive on the ~128KB budget of Forerunner 265.
class WorkoutEngine {

    public var template;    // WorkoutTemplate dict
    public var state;       // EngineState dict
    public var records;     // Array<SegmentRecord dict>

    // Cap per-segment HR sample count to prevent OOM on tight devices.
    // At 1Hz sampling this covers ~30 min of a single segment which far
    // exceeds realistic HYROX segment lengths (<10 min).
    static const kMaxHeartRateSamples = 1800;

    private var _currentSegmentPausedMs;    // Long
    private var _liveMeasurements;          // SegmentMeasurements dict

    function initialize(template as Dictionary) {
        self.template = template;
        self.state = EngineState.idle();
        self.records = [];
        _currentSegmentPausedMs = 0l;
        _liveMeasurements = SegmentMeasurements.empty();
    }

    // MARK: - Queries

    function currentSegmentIndex() as Number? {
        if (EngineState.is(state, EngineState.KIND_RUNNING)
                || EngineState.is(state, EngineState.KIND_PAUSED)) {
            return state[EngineState.INDEX] as Number;
        }
        return null;
    }

    function currentSegment() as Dictionary? {
        var idx = currentSegmentIndex();
        if (idx == null) { return null; }
        var segs = template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        return segs[idx] as Dictionary;
    }

    function nextSegment() as Dictionary? {
        var idx = currentSegmentIndex();
        if (idx == null) { return null; }
        var segs = template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        if (idx + 1 >= segs.size()) { return null; }
        return segs[idx + 1] as Dictionary;
    }

    function isLastSegment() as Boolean {
        var idx = currentSegmentIndex();
        if (idx == null) { return false; }
        var segs = template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        return idx == segs.size() - 1;
    }

    function isFinished() as Boolean {
        return EngineState.is(state, EngineState.KIND_FINISHED);
    }

    function segmentElapsedMs(nowMs as Long) as Long {
        if (EngineState.is(state, EngineState.KIND_RUNNING)) {
            return nowMs - (state[EngineState.SEGMENT_STARTED_AT_MS] as Long);
        }
        if (EngineState.is(state, EngineState.KIND_PAUSED)) {
            return state[EngineState.SEGMENT_ELAPSED_MS] as Long;
        }
        return 0l;
    }

    function totalElapsedMs(nowMs as Long) as Long {
        if (EngineState.is(state, EngineState.KIND_RUNNING)) {
            return nowMs - (state[EngineState.WORKOUT_STARTED_AT_MS] as Long);
        }
        if (EngineState.is(state, EngineState.KIND_PAUSED)) {
            return state[EngineState.TOTAL_ELAPSED_MS] as Long;
        }
        if (EngineState.is(state, EngineState.KIND_FINISHED)) {
            return (state[EngineState.FINISHED_AT_MS] as Long)
                 - (state[EngineState.WORKOUT_STARTED_AT_MS] as Long);
        }
        return 0l;
    }

    // MARK: - Actions

    function start(nowMs as Long) as Void {
        if (!EngineState.is(state, EngineState.KIND_IDLE)) {
            throw new EngineError(
                EngineError.REASON_INVALID_TRANSITION,
                EngineState.label(state), "start");
        }
        var segs = template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        if (segs.size() == 0) {
            throw new EngineError(EngineError.REASON_EMPTY_TEMPLATE, null, null);
        }
        _currentSegmentPausedMs = 0l;
        _liveMeasurements = SegmentMeasurements.empty();
        state = EngineState.running(0, nowMs, nowMs);
    }

    function advance(nowMs as Long) as Void {
        if (!EngineState.is(state, EngineState.KIND_RUNNING)) {
            throw new EngineError(
                EngineError.REASON_INVALID_TRANSITION,
                EngineState.label(state), "advance");
        }
        var index = state[EngineState.INDEX] as Number;
        var segStart = state[EngineState.SEGMENT_STARTED_AT_MS] as Long;
        var wkStart = state[EngineState.WORKOUT_STARTED_AT_MS] as Long;

        _flushRecord(index, segStart, nowMs, _currentSegmentPausedMs);

        var segs = template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var nextIdx = index + 1;
        _currentSegmentPausedMs = 0l;
        _liveMeasurements = SegmentMeasurements.empty();

        if (nextIdx < segs.size()) {
            state = EngineState.running(nextIdx, nowMs, wkStart);
        } else {
            state = EngineState.finished(wkStart, nowMs);
        }
    }

    function pause(nowMs as Long) as Void {
        if (!EngineState.is(state, EngineState.KIND_RUNNING)) {
            throw new EngineError(
                EngineError.REASON_INVALID_TRANSITION,
                EngineState.label(state), "pause");
        }
        var index = state[EngineState.INDEX] as Number;
        var segStart = state[EngineState.SEGMENT_STARTED_AT_MS] as Long;
        var wkStart = state[EngineState.WORKOUT_STARTED_AT_MS] as Long;
        state = EngineState.paused(index, nowMs - segStart, nowMs - wkStart);
    }

    // Resume re-computes effective start timestamps by back-dating them from
    // `nowMs` using the frozen elapsed values, excluding paused time from all
    // subsequent elapsed queries. Matches iOS semantics.
    function resume(nowMs as Long) as Void {
        if (!EngineState.is(state, EngineState.KIND_PAUSED)) {
            throw new EngineError(
                EngineError.REASON_INVALID_TRANSITION,
                EngineState.label(state), "resume");
        }
        var index = state[EngineState.INDEX] as Number;
        var segEl = state[EngineState.SEGMENT_ELAPSED_MS] as Long;
        var totEl = state[EngineState.TOTAL_ELAPSED_MS] as Long;
        _currentSegmentPausedMs = 0l;
        state = EngineState.running(index, nowMs - segEl, nowMs - totEl);
    }

    function finish(nowMs as Long) as Void {
        if (EngineState.is(state, EngineState.KIND_RUNNING)) {
            var index = state[EngineState.INDEX] as Number;
            var segStart = state[EngineState.SEGMENT_STARTED_AT_MS] as Long;
            var wkStart = state[EngineState.WORKOUT_STARTED_AT_MS] as Long;
            _flushRecord(index, segStart, nowMs, _currentSegmentPausedMs);
            _currentSegmentPausedMs = 0l;
            _liveMeasurements = SegmentMeasurements.empty();
            state = EngineState.finished(wkStart, nowMs);
            return;
        }
        if (EngineState.is(state, EngineState.KIND_PAUSED)) {
            var index = state[EngineState.INDEX] as Number;
            var segEl = state[EngineState.SEGMENT_ELAPSED_MS] as Long;
            var totEl = state[EngineState.TOTAL_ELAPSED_MS] as Long;
            var effectiveStart = nowMs - segEl;
            var wkStart = nowMs - totEl;
            _flushRecord(index, effectiveStart, nowMs, 0l);
            _currentSegmentPausedMs = 0l;
            _liveMeasurements = SegmentMeasurements.empty();
            state = EngineState.finished(wkStart, nowMs);
            return;
        }
        throw new EngineError(
            EngineError.REASON_INVALID_TRANSITION,
            EngineState.label(state), "finish");
    }

    // Undo: pop last record, rewind index to that segment. Wall-clock time is
    // not rewound — iOS behaviour. Measurement data for the undone window is
    // discarded (not recoverable).
    function undo(nowMs as Long) as Void {
        if (EngineState.is(state, EngineState.KIND_RUNNING)) {
            if (records.size() == 0) {
                throw new EngineError(EngineError.REASON_NOTHING_TO_UNDO, null, null);
            }
            var last = records[records.size() - 1] as Dictionary;
            records = records.slice(0, records.size() - 1);
            var wkStart = state[EngineState.WORKOUT_STARTED_AT_MS] as Long;
            _currentSegmentPausedMs = 0l;
            _liveMeasurements = SegmentMeasurements.empty();
            state = EngineState.running(
                last[SegmentRecord.INDEX] as Number,
                last[SegmentRecord.STARTED_AT_MS] as Long,
                wkStart);
            return;
        }
        if (EngineState.is(state, EngineState.KIND_FINISHED)) {
            if (records.size() == 0) {
                throw new EngineError(EngineError.REASON_NOTHING_TO_UNDO, null, null);
            }
            var last = records[records.size() - 1] as Dictionary;
            records = records.slice(0, records.size() - 1);
            var wkStart = state[EngineState.WORKOUT_STARTED_AT_MS] as Long;
            _currentSegmentPausedMs = 0l;
            _liveMeasurements = SegmentMeasurements.empty();
            state = EngineState.running(
                last[SegmentRecord.INDEX] as Number,
                last[SegmentRecord.STARTED_AT_MS] as Long,
                wkStart);
            return;
        }
        throw new EngineError(
            EngineError.REASON_INVALID_TRANSITION,
            EngineState.label(state), "undo");
    }

    // MARK: - Sample ingestion

    function ingestHeartRate(tMs as Long, bpm as Number) as Void {
        if (!EngineState.is(state, EngineState.KIND_RUNNING)) { return; }
        var arr = _liveMeasurements[SegmentMeasurements.HEART_RATE_SAMPLES] as Array<Dictionary>;
        if (arr.size() >= kMaxHeartRateSamples) { return; }
        arr.add(SegmentMeasurements.makeHeartRateSample(tMs, bpm));
    }

    function ingestLocation(
            tMs as Long,
            lat as Double,
            lon as Double,
            alt as Double?,
            hAcc as Double?,
            speed as Double?) as Void {
        if (!EngineState.is(state, EngineState.KIND_RUNNING)) { return; }
        var seg = currentSegment();
        if (seg == null) { return; }
        if (!SegmentType.tracksLocation(seg[WorkoutSegment.TYPE] as String)) { return; }
        var arr = _liveMeasurements[SegmentMeasurements.LOCATION_SAMPLES] as Array<Dictionary>;
        arr.add(SegmentMeasurements.makeLocationSample(tMs, lat, lon, alt, hAcc, speed));
    }

    function liveMeasurementsSnapshot() as Dictionary {
        return _liveMeasurements;
    }

    // MARK: - Private

    function _flushRecord(
            index as Number,
            segStartMs as Long,
            endedAtMs as Long,
            pausedMs as Long) as Void {
        var segs = template[WorkoutTemplate.SEGMENTS] as Array<Dictionary>;
        var segment = segs[index] as Dictionary;
        var stationKind = segment[WorkoutSegment.STATION_KIND];
        var displayName = null;
        if (stationKind != null) {
            displayName = StationKind.displayName(stationKind as String);
        }
        var record = SegmentRecord.make(
            segment[WorkoutSegment.ID] as String,
            index,
            segment[WorkoutSegment.TYPE] as String,
            segStartMs,
            endedAtMs,
            pausedMs,
            _liveMeasurements,
            displayName,
            segment[WorkoutSegment.DISTANCE_METERS] as Number?,
            segment[WorkoutSegment.GOAL_DURATION_SECONDS] as Number?);
        records.add(record);
    }
}
