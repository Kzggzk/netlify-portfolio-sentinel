#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Netlify Portfolio Sentinel"
PRODUCT="NetlifyPortfolioSentinel"
VERSION="${1:-0.2.0}"
BUNDLE="$ROOT/release/${APP_NAME}.app"
ZIP="$ROOT/release/netlify-portfolio-sentinel-${VERSION}-macos.zip"
ICON="$ROOT/assets/AppIcon.icns"

cd "$ROOT"
swift build -c release --product "$PRODUCT"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$ROOT/.build/release/$PRODUCT" "$BUNDLE/Contents/MacOS/$PRODUCT"
if [[ -f "$ICON" ]]; then
  cp "$ICON" "$BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${PRODUCT}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.kzg.netlify-portfolio-sentinel</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Strip iCloud/Finder detritus and ad-hoc sign so the unzipped app passes the
# code-signature check and can be launched (right-click → Open on first run,
# since the build is unsigned by a Developer ID).
xattr -cr "$BUNDLE" >/dev/null 2>&1 || true
codesign --force --sign - "$BUNDLE/Contents/MacOS/$PRODUCT" >/dev/null 2>&1 || true
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || true
codesign --verify --verbose "$BUNDLE" 2>&1 | tail -1 || true

rm -f "$ZIP"
ditto -c -k --keepParent "$BUNDLE" "$ZIP"
shasum -a 256 "$ZIP"
