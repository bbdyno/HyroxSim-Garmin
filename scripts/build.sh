#!/usr/bin/env bash
# Build HyroxSim Garmin app for a specific device.
# Usage: ./scripts/build.sh [device_id]
#   device_id: fr265 (default), fr965

set -euo pipefail

DEVICE="${1:-fr265}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_CFG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"

# Resolve Java: prefer system, fall back to Homebrew keg-only openjdk
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
    if ! command -v java >/dev/null 2>&1; then
        echo "❌ Java not found. Install with: brew install --cask temurin@17" >&2
        exit 1
    fi
fi

if [[ ! -f "$SDK_CFG" ]]; then
    echo "❌ Connect IQ SDK not found. Install via SDK Manager." >&2
    exit 1
fi

SDK_PATH="$(cat "$SDK_CFG" | sed 's:/*$::')"
MONKEYC="$SDK_PATH/bin/monkeyc"
JUNGLE="$ROOT/monkey.jungle"
KEY="$ROOT/developer_key.der"
OUT_DIR="$ROOT/bin"
OUT_PRG="$OUT_DIR/HyroxSim-$DEVICE.prg"

mkdir -p "$OUT_DIR"

echo "🔨 Building for $DEVICE"
echo "   SDK: $SDK_PATH"
echo "   Output: $OUT_PRG"

MONKEYC_ARGS=(
    --jungles "$JUNGLE"
    --device "$DEVICE"
    --output "$OUT_PRG"
    --private-key "$KEY"
    --warn
)
if [[ "${UNIT_TEST:-0}" == "1" ]]; then
    MONKEYC_ARGS+=(--unit-test)
fi

"$MONKEYC" "${MONKEYC_ARGS[@]}"

echo "✅ Build succeeded: $OUT_PRG"
