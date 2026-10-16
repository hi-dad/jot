#!/bin/bash
# Builds Jot.app. Requires Xcode or the Xcode Command Line Tools.
# Calls swiftc directly (no Swift Package Manager) so a broken SwiftPM install can't block the build.
#
#   ./build.sh        build, install to /Applications (replacing the old copy) and relaunch
#   ./build.sh dist   build and make dist/Jot.dmg to share; doesn't install
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Jot.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal binary: Apple Silicon + Intel Macs.
SDK="$(xcrun --show-sdk-path)"
for arch in arm64 x86_64; do
    swiftc -O -parse-as-library \
        -target "$arch-apple-macos13.0" \
        -sdk "$SDK" \
        Sources/QuickNote/*.swift \
        -o "build/Jot-$arch"
done
lipo -create build/Jot-arm64 build/Jot-x86_64 -output "$APP/Contents/MacOS/Jot"
rm build/Jot-arm64 build/Jot-x86_64

cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will show the microphone / Notes permission prompts.
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "dist" ]]; then
    rm -rf dist && mkdir -p dist/stage
    cp -R "$APP" dist/stage/
    ln -s /Applications dist/stage/Applications
    cp "Resources/How to install.txt" dist/stage/
    hdiutil create -volname "Jot" -srcfolder dist/stage -ov -format UDZO dist/Jot.dmg >/dev/null
    rm -rf dist/stage
    echo "Made dist/Jot.dmg"
    exit 0
fi

# Install: move the app into /Applications so there's only ever one copy on this Mac.
pkill -x Jot || true
pkill -x QuickNote || true   # its name before Jot
rm -rf /Applications/QuickNote.app
sleep 1
rm -rf /Applications/Jot.app
mv "$APP" /Applications/
open /Applications/Jot.app
echo "Installed to /Applications and relaunched"
