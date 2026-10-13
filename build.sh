#!/bin/bash
# Builds QuickNote.app into ./build. Requires Xcode or the Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/QuickNote.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/QuickNote "$APP/Contents/MacOS/QuickNote"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will show the microphone / Notes permission prompts.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with:  open $APP"
echo "Or install:   cp -R $APP /Applications/"
