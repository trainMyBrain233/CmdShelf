#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CmdShelf"
PRODUCT_NAME="CmdShelf"
CONFIGURATION="release"
OUTPUT_DIR="dist"
BUNDLE_ID="com.cmdshelf.app"
SIGN_IDENTITY="-"
DO_SIGN="1"
CLEAN_FIRST="0"

usage() {
  cat <<'EOF'
Build a macOS .app bundle from this SwiftPM project.

Usage:
  scripts/build_macos_app.sh [options]

Options:
  --configuration <release|debug>   Build configuration (default: release)
  --output-dir <path>               Output directory for .app (default: dist)
  --bundle-id <id>                  CFBundleIdentifier (default: com.cmdshelf.app)
  --sign <identity>                 Code sign identity (default: - for ad-hoc)
  --no-sign                         Skip code signing
  --clean                           Run 'swift package clean' before build
  -h, --help                        Show this help

Examples:
  scripts/build_macos_app.sh
  scripts/build_macos_app.sh --configuration debug --output-dir build
  scripts/build_macos_app.sh --sign "Developer ID Application: Your Name (TEAMID)"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --sign)
      SIGN_IDENTITY="$2"
      DO_SIGN="1"
      shift 2
      ;;
    --no-sign)
      DO_SIGN="0"
      shift
      ;;
    --clean)
      CLEAN_FIRST="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
  echo "--configuration must be 'release' or 'debug'" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p /tmp/clang-module-cache
export CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache

if [[ "$CLEAN_FIRST" == "1" ]]; then
  swift package clean
fi

echo "[1/6] Building product '$PRODUCT_NAME' ($CONFIGURATION)..."
swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"

BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE="$BIN_DIR/$PRODUCT_NAME"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Executable not found: $EXECUTABLE" >&2
  exit 1
fi

APP_DIR="$ROOT_DIR/$OUTPUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
PLIST_PATH="$CONTENTS_DIR/Info.plist"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

echo "[2/6] Assembling app bundle..."
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy SwiftPM resource bundles (target bundle + dependency bundles if present).
for bundle in "$BIN_DIR"/*.bundle; do
  [[ -d "$bundle" ]] || continue
  cp -R "$bundle" "$RESOURCES_DIR/"
done

# Generate .icns from AppIcon-1024.png if present.
ICON_PNG="$ROOT_DIR/Sources/CmdShelf/Resources/AppIcon-1024.png"
ICON_ICNS="$RESOURCES_DIR/AppIcon.icns"
if [[ -f "$ICON_PNG" ]]; then
  ICONSET_PARENT="$(mktemp -d /tmp/cmdshelf_iconset_parent.XXXXXX)"
  ICONSET_DIR="$ICONSET_PARENT/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"
  trap 'rm -rf "$ICONSET_PARENT"' EXIT

  sips -z 16 16 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  if iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS" 2>/dev/null; then
    ICON_FILE_VALUE="AppIcon"
  else
    echo "warning: failed to generate AppIcon.icns, app icon may fallback to default"
    ICON_FILE_VALUE=""
  fi
else
  ICON_FILE_VALUE=""
fi

echo "[3/6] Writing Info.plist..."
APP_VERSION="1.0.0"
BUILD_NUMBER="$(date +%Y%m%d%H%M)"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
EOF

if [[ -n "$ICON_FILE_VALUE" ]]; then
  cat >> "$PLIST_PATH" <<EOF
  <key>CFBundleIconFile</key>
  <string>$ICON_FILE_VALUE</string>
EOF
fi

cat >> "$PLIST_PATH" <<'EOF'
</dict>
</plist>
EOF

# Embed Swift runtime libraries if tool is available.
echo "[4/6] Embedding Swift runtime (if needed)..."
if command -v swift-stdlib-tool >/dev/null 2>&1; then
  swift-stdlib-tool \
    --copy \
    --scan-executable "$MACOS_DIR/$APP_NAME" \
    --platform macosx \
    --destination "$FRAMEWORKS_DIR" \
    --resource-destination "$RESOURCES_DIR" \
    --strip-bitcode \
    --strip-bitcode-tool "$(xcrun -f bitcode_strip 2>/dev/null || true)" \
    >/dev/null 2>&1 || true
fi

if [[ "$DO_SIGN" == "1" ]]; then
  echo "[5/6] Code signing app ($SIGN_IDENTITY)..."
  if [[ -d "$FRAMEWORKS_DIR" ]]; then
    find "$FRAMEWORKS_DIR" -type f -name "*.dylib" -print0 | while IFS= read -r -d '' dylib; do
      codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$dylib" || true
    done
  fi
  codesign --force --deep --sign "$SIGN_IDENTITY" --timestamp=none "$APP_DIR"
else
  echo "[5/6] Skipping code signing (--no-sign)."
fi

echo "[6/6] Verifying bundle..."
plutil -lint "$PLIST_PATH" >/dev/null
codesign --verify --deep --strict "$APP_DIR" >/dev/null 2>&1 || true

echo ""
echo "Done. App bundle created:"
echo "  $APP_DIR"
echo ""
echo "Run it with:"
echo "  open \"$APP_DIR\""
