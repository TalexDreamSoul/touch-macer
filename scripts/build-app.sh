#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TouchMacer"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
APP_VERSION="0.1.3"
BUILD_NUMBER="4"
ICON_SOURCE="$ROOT_DIR/assets/AppIcon.png"
APP_DIR="$ROOT_DIR/.build/app/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
ICNS_PATH="$ROOT_DIR/.build/AppIcon.icns"

cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIG"

rm -rf "$APP_DIR" "$ICONSET_DIR" "$ICNS_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"
cp "$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ ! -f "$ICON_SOURCE" ]]; then
    echo "Missing icon source: $ICON_SOURCE" >&2
    exit 1
fi

make_icon() {
    local size="$1"
    local filename="$2"
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/$filename" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
cp "$ICNS_PATH" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
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


codesign --force --deep --sign - "$APP_DIR"
echo "Built $APP_DIR"
