#!/bin/bash
# Builds QuickNote.app. Requires Xcode or the Xcode Command Line Tools.
# Calls swiftc directly (no Swift Package Manager) so a broken SwiftPM install can't block the build.
#
#   ./build.sh        build, install to /Applications (replacing the old copy) and relaunch
#   ./build.sh dist   build and make dist/QuickNote.dmg to share; doesn't install
set -euo pipefail
cd "$(dirname "$0")"

APP=build/QuickNote.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal binary: Apple Silicon + Intel Macs.
SDK="$(xcrun --show-sdk-path)"
for arch in arm64 x86_64; do
    swiftc -O -parse-as-library \
        -target "$arch-apple-macos13.0" \
        -sdk "$SDK" \
        Sources/QuickNote/*.swift \
        -o "build/QuickNote-$arch"
done
lipo -create build/QuickNote-arm64 build/QuickNote-x86_64 -output "$APP/Contents/MacOS/QuickNote"
rm build/QuickNote-arm64 build/QuickNote-x86_64

cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will show the microphone / Notes permission prompts.
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "dist" ]]; then
    rm -rf dist && mkdir -p dist/stage
    cp -R "$APP" dist/stage/
    ln -s /Applications dist/stage/Applications
    cp "Resources/How to install.txt" dist/stage/
    hdiutil create -volname "QuickNote" -srcfolder dist/stage -ov -format UDZO dist/QuickNote.dmg >/dev/null
    rm -rf dist/stage
    echo "Made dist/QuickNote.dmg"
    exit 0
fi

# Install: move the app into /Applications so there's only ever one copy on this Mac.
pkill -x QuickNote || true
sleep 1
rm -rf /Applications/QuickNote.app
mv "$APP" /Applications/
open /Applications/QuickNote.app
echo "Installed to /Applications and relaunched"
