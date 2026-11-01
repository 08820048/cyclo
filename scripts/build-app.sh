#!/bin/bash
# Builds Cyclo.app into build/. Usage: scripts/build-app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${CYCLO_APP_OUT:-$ROOT/build/Cyclo.app}"
SIGN_IDENTITY="${CYCLO_SIGN_IDENTITY:--}"
# Notarization needs a secure timestamp on every Developer ID signature; an ad-hoc signature cannot have one.
TIMESTAMP="--timestamp=none"
[ "$SIGN_IDENTITY" != "-" ] && TIMESTAMP="--timestamp"

cd "$ROOT"
# SwiftUI's macros (@State etc.) ship with Xcode, not the Command Line Tools.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode-beta.app ]; then export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer; fi
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; fi
swift build -c "$CONFIG" --product Cyclo
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN/Cyclo" "$APP/Contents/MacOS/Cyclo"
cp "$ROOT/Resources/Brand/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
[ -n "${CYCLO_VERSION:-}" ] && /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $CYCLO_VERSION" "$APP/Contents/Info.plist"
[ -n "${CYCLO_BUILD:-}" ] && /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CYCLO_BUILD" "$APP/Contents/Info.plist"

codesign --force --options runtime $TIMESTAMP -s "$SIGN_IDENTITY" --entitlements "$ROOT/Resources/Cyclo.entitlements" "$APP"

echo "Built $APP"
