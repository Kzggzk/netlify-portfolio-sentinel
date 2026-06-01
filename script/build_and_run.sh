#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Netlify Portfolio Sentinel"
PRODUCT="NetlifyPortfolioSentinel"
BUNDLE="$ROOT/dist/${APP_NAME}.app"
BINARY="$ROOT/.build/debug/${PRODUCT}"
ICON="$ROOT/assets/AppIcon.icns"

cd "$ROOT"

if [[ "${1:-}" == "--icon" ]]; then
  swift "$ROOT/script/generate_icon.swift"
  exit 0
fi

/usr/bin/pkill -x "$PRODUCT" >/dev/null 2>&1 || true

swift build --product "$PRODUCT"

mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/$PRODUCT"
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
  <string>0.2.0</string>
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

# iCloud Drive tags files with extended attributes that invalidate a code
# signature, and swapping in a freshly built binary breaks the bundle seal.
# Strip the detritus and ad-hoc re-sign so launchd will actually spawn the app
# (otherwise: RBSRequestErrorDomain Code=5 / POSIX 162 "Launchd job spawn failed").
/usr/bin/xattr -cr "$BUNDLE" >/dev/null 2>&1 || true
/usr/bin/codesign --force --sign - "$BUNDLE/Contents/MacOS/$PRODUCT" >/dev/null 2>&1 || true
/usr/bin/codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || true

if [[ "${1:-}" == "--no-launch" ]]; then
  echo "$BUNDLE"
  exit 0
fi

/usr/bin/open "$BUNDLE"

if [[ "${1:-}" == "--verify" ]]; then
  sleep 2
  if /usr/bin/pgrep -x "$PRODUCT" >/dev/null; then
    echo "verified: $PRODUCT is running"
  else
    echo "not running: $PRODUCT" >&2
    exit 1
  fi
fi

if [[ "${1:-}" == "--logs" ]]; then
  /usr/bin/log stream --style compact --predicate "process == '$PRODUCT'"
fi
