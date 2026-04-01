#!/bin/bash
set -euo pipefail
# Build HookQA release and create a distributable DMG.
# Requires: brew install create-dmg
#
# Usage: ./scripts/build-dmg.sh [version]
#   version  Optional version tag for the DMG filename (default: reads from project)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
XCODEPROJ="$PROJECT_DIR/HookQA/HookQA.xcodeproj"
SCHEME="HookQA"
ARCHIVE_PATH="$BUILD_DIR/HookQA.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
APP_PATH="$EXPORT_PATH/HookQA.app"

# Resolve version: use argument, or read MARKETING_VERSION from the project
if [ "${1:-}" != "" ]; then
    VERSION="$1"
else
    VERSION=$(xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" \
        -showBuildSettings 2>/dev/null \
        | grep 'MARKETING_VERSION' | awk '{print $3}' | head -1)
    VERSION="${VERSION:-1.0}"
fi

DMG_NAME="HookQA-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "==> Building HookQA v${VERSION}"
echo "    Project : $XCODEPROJ"
echo "    Archive : $ARCHIVE_PATH"
echo "    DMG     : $DMG_PATH"
echo ""

# Ensure create-dmg is available
if ! command -v create-dmg &>/dev/null; then
    echo "Error: create-dmg not found. Install it with: brew install create-dmg" >&2
    exit 1
fi

# Clean previous build artefacts
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Archive
echo "==> Archiving…"
xcodebuild archive \
    -project "$XCODEPROJ" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Export (no signing — developer can add their own ExportOptions.plist)
echo "==> Exporting app bundle…"
mkdir -p "$EXPORT_PATH"

# Copy the .app directly from the archive
cp -R "$ARCHIVE_PATH/Products/Applications/HookQA.app" "$EXPORT_PATH/"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App bundle not found at $APP_PATH" >&2
    exit 1
fi

# Create DMG
echo "==> Creating DMG…"
create-dmg \
    --volname "HookQA ${VERSION}" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "HookQA.app" 175 190 \
    --hide-extension "HookQA.app" \
    --app-drop-link 425 190 \
    "$DMG_PATH" \
    "$EXPORT_PATH"

echo ""
echo "==> Done: $DMG_PATH"
