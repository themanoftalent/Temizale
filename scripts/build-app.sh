#!/usr/bin/env bash
# Builds Temizale.app into ./dist.
#   ./scripts/build-app.sh            native architecture
#   ./scripts/build-app.sh universal  arm64 + x86_64 (needs full Xcode, not only Command Line Tools)
#   SIGN_IDENTITY="Developer ID Application: ..." ./scripts/build-app.sh universal
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="Temizale"
DIST="dist"
APP="$DIST/$APP_NAME.app"

if [[ ! -f Resources/AppIcon.icns ]]; then
    [[ -f Resources/AppIcon.png ]] || swift scripts/make-icon.swift Resources/AppIcon.png
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        d=$((s * 2))
        sips -z $d $d Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
fi

if [[ "${1:-}" == "universal" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    if [[ -d ".build/apple/Products/Release" ]]; then
        BIN_DIR=".build/apple/Products/Release"
    elif [[ -d ".build/out/Products/Release" ]]; then
        BIN_DIR=".build/out/Products/Release"
    else
        BIN_DIR="$(find .build -path "*/Products/Release" -type d | head -n 1)"
    fi
else
    swift build -c release
    BIN_DIR="$(swift build -c release --show-bin-path)"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
    # Ad-hoc signature: runs on this Mac. Other Macs will show a Gatekeeper warning.
    codesign --force --sign - "$APP"
fi

echo "Built $APP"
