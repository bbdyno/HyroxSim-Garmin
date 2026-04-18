#!/usr/bin/env bash
# Build with -t unit-test flag and run against the Connect IQ Simulator.
# Usage: ./scripts/test.sh [device_id]

set -euo pipefail

DEVICE="${1:-fenix7}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_CFG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
SDK_PATH="$(cat "$SDK_CFG" | sed 's:/*$::')"
MONKEYDO="$SDK_PATH/bin/monkeydo"
SIM_APP="$SDK_PATH/bin/ConnectIQ.app"

# Java resolution (mirrors build.sh)
if ! /usr/libexec/java_home >/dev/null 2>&1; then
    for candidate in \
        /opt/homebrew/opt/openjdk@17 \
        /opt/homebrew/opt/openjdk \
        /usr/local/opt/openjdk@17 \
        /usr/local/opt/openjdk; do
        if [[ -x "$candidate/bin/java" ]]; then
            export JAVA_HOME="$candidate/libexec/openjdk.jdk/Contents/Home"
            export PATH="$candidate/bin:$PATH"
            break
        fi
    done
fi

# Compile with unit test flag
UNIT_TEST=1 "$ROOT/scripts/build.sh" "$DEVICE"

# Launch simulator if not running
if ! pgrep -f "ConnectIQ.app/Contents/MacOS/ConnectIQ" > /dev/null 2>&1; then
    open "$SIM_APP"
    sleep 3
fi

PRG="$ROOT/bin/HyroxSim-$DEVICE.prg"
echo "🧪 Running unit tests on $DEVICE"
"$MONKEYDO" "$PRG" "$DEVICE" -t
