#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TouchMacer"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
APP_DIR="$ROOT_DIR/.build/app/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TouchMacer</string>
    <key>CFBundleIdentifier</key>
    <string>com.touchmacer.clock</string>
    <key>CFBundleName</key>
    <string>TouchMacer</string>
    <key>CFBundleDisplayName</key>
    <string>TouchMacer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>TouchMacer shows upcoming events from the calendars you select.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>TouchMacer shows upcoming events from the calendars you select.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>TouchMacer can switch macOS Light/Dark appearance when you enable system appearance automation.</string>
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
