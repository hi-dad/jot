#!/bin/bash
# Builds QuickNote.app into ./build. Requires Xcode or the Xcode Command Line Tools.
# Calls swiftc directly (no Swift Package Manager) so a broken SwiftPM install can't block the build.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/QuickNote.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library \
    -target "$(uname -m)-apple-macos13.0" \
    -sdk "$(xcrun --show-sdk-path)" \
    Sources/QuickNote/*.swift \
    -o "$APP/Contents/MacOS/QuickNote"

cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will show the microphone / Notes permission prompts.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with:  open $APP"
echo "Or install:   cp -R $APP /Applications/"
