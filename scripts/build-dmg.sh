#!/bin/bash
set -euo pipefail
# Build HookQA release, sign, notarize, and create a distributable DMG.
# Requires: brew install create-dmg
#
# Usage: ./scripts/build-dmg.sh [version]
#   version  Optional version tag for the DMG filename (default: reads from project)
#
# Environment variables:
#   SIGN_IDENTITY    Code signing identity (default: auto-detected Developer ID Application)
#   NOTARY_PROFILE   Keychain profile for notarization (default: hookqa-notary)
#   SKIP_NOTARIZE    Set to 1 to skip notarization
#
# First-time setup — store notarization credentials:
#   xcrun notarytool store-credentials "hookqa-notary" \
#       --apple-id YOUR_APPLE_ID \
#       --team-id M4RUJ7W6MP \
#       --password APP_SPECIFIC_PASSWORD

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
XCODEPROJ="$PROJECT_DIR/HookQA/HookQA.xcodeproj"
SCHEME="HookQA"
ARCHIVE_PATH="$BUILD_DIR/HookQA.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
APP_PATH="$EXPORT_PATH/HookQA.app"

NOTARY_PROFILE="${NOTARY_PROFILE:-hookqa-notary}"

# Auto-detect signing identity if not provided
if [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if [ -z "$SIGN_IDENTITY" ]; then
        echo "Error: No Developer ID Application signing identity found." >&2
        echo "Install one via Xcode > Settings > Accounts, or set SIGN_IDENTITY." >&2
        exit 1
    fi
fi

# Extract team ID from the signing identity
TEAM_ID=$(echo "$SIGN_IDENTITY" | grep -oE '\([A-Z0-9]+\)$' | tr -d '()')
if [ -z "$TEAM_ID" ]; then
    echo "Error: Could not extract Team ID from signing identity: $SIGN_IDENTITY" >&2
    exit 1
fi

# Resolve version: use argument, or read MARKETING_VERSION from the project
if [ "${1:-}" != "" ]; then
    VERSION="$1"
else
    VERSION=$(xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" \
        -showBuildSettings 2>/dev/null \
        | grep 'MARKETING_VERSION' | awk '{print $3}' | head -1)
fi

if [ -z "${VERSION:-}" ]; then
    echo "Error: Could not determine version. Pass it as an argument: ./scripts/build-dmg.sh 1.0" >&2
    exit 1
fi

DMG_NAME="HookQA-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "==> Building HookQA v${VERSION}"
echo "    Project : $XCODEPROJ"
echo "    Archive : $ARCHIVE_PATH"
echo "    Identity: $SIGN_IDENTITY"
echo "    Team ID : $TEAM_ID"
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

# Archive (signed with hardened runtime)
echo "==> Archiving…"
xcodebuild archive \
    -project "$XCODEPROJ" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    ENABLE_HARDENED_RUNTIME=YES

# Export the app bundle from the archive
echo "==> Exporting app bundle…"
mkdir -p "$EXPORT_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/HookQA.app" "$EXPORT_PATH/"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App bundle not found at $APP_PATH" >&2
    exit 1
fi

# Re-sign all nested binaries (Sparkle XPC services, Updater.app, etc.)
# Notarization requires every binary to be signed with Developer ID + secure timestamp
echo "==> Re-signing nested frameworks and bundles…"
ENTITLEMENTS="$PROJECT_DIR/HookQA/HookQA/HookQA.entitlements"

# Find all Mach-O binaries and sign them deepest-first
# This catches XPC services, helper apps, standalone executables, dylibs — everything
find "$APP_PATH/Contents/Frameworks" -type f | while read -r f; do
    if file "$f" | grep -q "Mach-O"; then
        echo "    Signing $f"
        codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$f"
    fi
done

# Sign bundle wrappers (XPC services, nested apps, frameworks) deepest-first
find "$APP_PATH/Contents/Frameworks" -name "*.xpc" -type d -depth | while read -r bundle; do
    echo "    Signing bundle $(basename "$bundle")"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$bundle"
done

find "$APP_PATH/Contents/Frameworks" -name "*.app" -type d -depth | while read -r bundle; do
    echo "    Signing bundle $(basename "$bundle")"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$bundle"
done

find "$APP_PATH/Contents/Frameworks" -name "*.framework" -type d -depth -maxdepth 1 | while read -r bundle; do
    echo "    Signing bundle $(basename "$bundle")"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$bundle"
done

# Sign the main app bundle last
echo "    Signing HookQA.app"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    --entitlements "$ENTITLEMENTS" "$APP_PATH"

# Verify code signature
echo "==> Verifying code signature…"
if ! codesign --verify --deep --strict "$APP_PATH" 2>&1; then
    echo "Error: Code signature verification failed for $APP_PATH" >&2
    exit 1
fi

SIGN_INFO=$(codesign -dv --verbose=2 "$APP_PATH" 2>&1)
echo "$SIGN_INFO" | grep -E 'Authority|TeamIdentifier|Signature' || true

if ! echo "$SIGN_INFO" | grep -q "Developer ID Application"; then
    echo "Error: App is not signed with a Developer ID Application identity" >&2
    exit 1
fi
echo ""

# Create DMG
echo "==> Creating DMG…"
VOLICON_FLAG=""
if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    VOLICON_FLAG="--volicon $APP_PATH/Contents/Resources/AppIcon.icns"
fi

create-dmg \
    --volname "HookQA ${VERSION}" \
    $VOLICON_FLAG \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "HookQA.app" 175 190 \
    --hide-extension "HookQA.app" \
    --app-drop-link 425 190 \
    "$DMG_PATH" \
    "$EXPORT_PATH"

# Sign the DMG itself
echo "==> Signing DMG…"
codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"

# Notarize
if [ "${SKIP_NOTARIZE:-0}" = "1" ]; then
    echo "==> Skipping notarization (SKIP_NOTARIZE=1)"
else
    echo "==> Submitting for notarization…"
    if ! xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait; then
        echo "Error: Notarization failed. Check the log with:" >&2
        echo "  xcrun notarytool log <submission-id> --keychain-profile $NOTARY_PROFILE" >&2
        exit 1
    fi

    echo "==> Stapling notarization ticket…"
    xcrun stapler staple "$DMG_PATH"
fi

echo ""
echo "==> Done: $DMG_PATH"
echo ""
echo "Verify with: spctl --assess --type open --context context:primary-signature -v \"$DMG_PATH\""
