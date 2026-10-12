//
//  Clock.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 10/12/26.
//

import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Epoch milliseconds with real sub-second resolution.
//
// Time.now() only ticks once per second, so timestamps derived from it
// (`value() * 1000`) made the 500 ms double-press window, HR throttling and
// split times jump in whole seconds. System.getTimer() is a millisecond
// uptime counter; anchoring it to the wall clock once gives both.
module Clock {
    var _epochBaseMs = null;
    var _timerBase = 0;

    function nowMs() as Long {
        var timer = System.getTimer();
        // Re-anchor on first use and if the uptime counter wrapped.
        if (_epochBaseMs == null || timer < _timerBase) {
            _epochBaseMs = Time.now().value().toLong() * 1000l;
            _timerBase = timer;
        }
        return (_epochBaseMs as Long) + (timer - _timerBase).toLong();
    }
}
