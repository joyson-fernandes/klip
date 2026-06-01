#!/bin/bash
set -e

echo "Building Release..."
xcodebuild -project klip.xcodeproj -scheme klip -configuration Release \
  -derivedDataPath build ONLY_ACTIVE_ARCH=NO build

APP_PATH="build/Build/Products/Release/klip.app"
DMG_NAME="klip-1.1.0.dmg"

echo "Creating DMG..."
hdiutil create -volname "klip" -srcfolder "$APP_PATH" \
  -ov -format UDZO "$DMG_NAME"

echo "Done: $DMG_NAME"
