#!/bin/bash
set -e

echo "Building Release..."
xcodebuild -project gifsnap.xcodeproj -scheme gifsnap -configuration Release \
  -derivedDataPath build ONLY_ACTIVE_ARCH=NO build

APP_PATH="build/Build/Products/Release/gifsnap.app"
DMG_NAME="gifsnap-1.0.0.dmg"

echo "Creating DMG..."
hdiutil create -volname "gifsnap" -srcfolder "$APP_PATH" \
  -ov -format UDZO "$DMG_NAME"

echo "Done: $DMG_NAME"
