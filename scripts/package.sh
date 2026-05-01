#!/usr/bin/env bash
# Build the Connect IQ Store submission package (.iq).
# Output bundles every device listed in manifest.xml, signed with the
# release key, with debug info stripped.
#
# Usage: ./scripts/package.sh
# Output: bin/HyroxSim.iq

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK_CFG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
KEY="$ROOT/developer_key_release.der"

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

if [[ ! -f "$KEY" ]]; then
    echo "❌ Release key not found at $KEY" >&2
    echo "   Generate with:" >&2
    echo "     openssl genrsa -out developer_key_release.pem 4096" >&2
    echo "     openssl pkcs8 -topk8 -inform PEM -outform DER \\" >&2
    echo "       -in developer_key_release.pem -out developer_key_release.der -nocrypt" >&2
    echo "   Then back up the .der file to a safe second location — losing it" >&2
    echo "   means the Connect IQ Store app entry can never be updated again." >&2
    exit 1
fi

SDK_PATH="$(cat "$SDK_CFG" | sed 's:/*$::')"
MONKEYC="$SDK_PATH/bin/monkeyc"
JUNGLE="$ROOT/monkey.jungle"
OUT_DIR="$ROOT/bin"
OUT_IQ="$OUT_DIR/HyroxSim.iq"

mkdir -p "$OUT_DIR"

echo "📦 Packaging Connect IQ Store .iq"
echo "   SDK:    $SDK_PATH"
echo "   Key:    $KEY"
echo "   Output: $OUT_IQ"

# -e packages all devices listed in manifest.xml into a single .iq bundle
# -r strips debug info for release builds (smaller, no symbol leakage)
"$MONKEYC" \
    --jungles "$JUNGLE" \
    --output "$OUT_IQ" \
    --private-key "$KEY" \
    --package-app \
    --release \
    --warn

echo "✅ Package built: $OUT_IQ"
echo
echo "Next: upload this .iq at https://apps.garmin.com/developer (My Apps)"
