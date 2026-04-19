#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Panini"
SCHEME="Panini"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg-staging"
DMG_OUTPUT="$BUILD_DIR/$APP_NAME.dmg"

echo "==> Cleaning previous build..."
rm -rf "$BUILD_DIR"

echo "==> Building $APP_NAME ($CONFIGURATION)..."
xcodebuild \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES \
    | tail -20

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_NAME.app not found at $APP_PATH"
    exit 1
fi

echo "==> Ad-hoc signing $APP_NAME.app..."
codesign --force --deep --sign - "$APP_PATH"

echo "==> Creating DMG..."
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

rm -rf "$DMG_DIR"

echo ""
echo "==> Done! DMG created at:"
echo "    $DMG_OUTPUT"
echo ""
echo "Note: Since this is not notarized, users will need to"
echo "right-click > Open on first launch to bypass Gatekeeper."
