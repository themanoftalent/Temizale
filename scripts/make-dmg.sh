#!/usr/bin/env bash
# Packages dist/Temizale.app into dist/Temizale-<version>.dmg with an Applications shortcut.
set -euo pipefail

cd "$(dirname "$0")/.."
APP="dist/Temizale.app"
[[ -d "$APP" ]] || { echo "Run scripts/build-app.sh first"; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="dist/Temizale-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "Temizale" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" "$DMG"
fi

echo "Built $DMG"
