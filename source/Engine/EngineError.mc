//
//  EngineError.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on 4/18/26.
//

import Toybox.Lang;

// Monkey C has no Swift-style error enum. We expose an Exception subclass
// carrying a structured reason so callers can match on it.
class EngineError extends Lang.Exception {
    public var reason;        // One of the REASON_* constants
    public var fromState;     // State label (for INVALID_TRANSITION)
    public var action;        // Attempted action (for INVALID_TRANSITION)

    static const REASON_INVALID_TRANSITION = "invalidTransition";
    static const REASON_EMPTY_TEMPLATE     = "emptyTemplate";
    static const REASON_NOTHING_TO_UNDO    = "nothingToUndo";

    function initialize(
            reason as String,
            fromState as String?,
            action as String?) {
        Exception.initialize();
        self.reason = reason;
        self.fromState = fromState;
        self.action = action;
    }

    function toString() as String {
        if (reason.equals(REASON_INVALID_TRANSITION)) {
            return "EngineError: cannot " + action + " from " + fromState;
        }
        if (reason.equals(REASON_EMPTY_TEMPLATE)) {
            return "EngineError: template has no segments";
        }
        if (reason.equals(REASON_NOTHING_TO_UNDO)) {
            return "EngineError: nothing to undo";
        }
        return "EngineError: " + reason;
    }
}
