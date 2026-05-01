#!/usr/bin/env bash
# Build and launch HyroxSim in the Connect IQ Simulator.
# Usage: ./scripts/run-sim.sh [device_id]

set -euo pipefail

DEVICE="${1:-fr265}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_CFG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
SDK_PATH="$(cat "$SDK_CFG" | sed 's:/*$::')"
SIM_APP="$SDK_PATH/bin/ConnectIQ.app"
MONKEYDO="$SDK_PATH/bin/monkeydo"

# Resolve Java for monkeydo. build.sh does this for monkeyc but its env
# stays in that subshell, so we have to repeat the lookup here.
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

# Build first
"$ROOT/scripts/build.sh" "$DEVICE"

# Launch simulator app if not already running
if ! pgrep -f "ConnectIQ.app/Contents/MacOS/ConnectIQ" > /dev/null 2>&1; then
    echo "▶️  Launching Connect IQ Simulator..."
    open "$SIM_APP"
    sleep 3
fi

PRG="$ROOT/bin/HyroxSim-$DEVICE.prg"
echo "📲 Deploying $PRG to $DEVICE simulator..."
"$MONKEYDO" "$PRG" "$DEVICE"
