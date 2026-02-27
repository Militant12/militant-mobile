#!/bin/bash
# Build and package Militant for macOS (.zip + optional .dmg)
# Usage:
#   ./package_macos.sh            # version from pubspec.yaml
#   ./package_macos.sh 1.0.5      # explicit version

set -euo pipefail

cd "$(dirname "$0")"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Error: this script must run on macOS."
    exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
    echo "Error: flutter is not installed or not in PATH."
    exit 1
fi

PLIST_BUDDY="/usr/libexec/PlistBuddy"
MACOS_ALLOW_HTTP="${MACOS_ALLOW_HTTP:-1}"

set_plist_bool() {
    local plist="$1"
    local key="$2"
    local value="$3"
    if [ ! -f "$plist" ] || [ ! -x "$PLIST_BUDDY" ]; then
        return 1
    fi
    if "$PLIST_BUDDY" -c "Print :$key" "$plist" >/dev/null 2>&1; then
        "$PLIST_BUDDY" -c "Set :$key $value" "$plist" >/dev/null
    else
        "$PLIST_BUDDY" -c "Add :$key bool $value" "$plist" >/dev/null
    fi
}

ensure_plist_dict() {
    local plist="$1"
    local key="$2"
    if [ ! -f "$plist" ] || [ ! -x "$PLIST_BUDDY" ]; then
        return 1
    fi
    if ! "$PLIST_BUDDY" -c "Print :$key" "$plist" >/dev/null 2>&1; then
        "$PLIST_BUDDY" -c "Add :$key dict" "$plist" >/dev/null
    fi
}

ensure_macos_network_config() {
    local debug_ent="macos/Runner/DebugProfile.entitlements"
    local release_ent="macos/Runner/Release.entitlements"
    local info_plist="macos/Runner/Info.plist"

    # Ensure outbound networking entitlement is always present.
    if [ -f "$debug_ent" ]; then
        set_plist_bool "$debug_ent" "com.apple.security.app-sandbox" "true" || true
        set_plist_bool "$debug_ent" "com.apple.security.network.client" "true" || true
        set_plist_bool "$debug_ent" "com.apple.security.network.server" "true" || true
    fi
    if [ -f "$release_ent" ]; then
        set_plist_bool "$release_ent" "com.apple.security.app-sandbox" "true" || true
        set_plist_bool "$release_ent" "com.apple.security.network.client" "true" || true
    fi

    # Allow HTTP/self-hosted endpoints on macOS when needed.
    if [ "$MACOS_ALLOW_HTTP" = "1" ] && [ -f "$info_plist" ]; then
        ensure_plist_dict "$info_plist" "NSAppTransportSecurity" || true
        set_plist_bool "$info_plist" "NSAppTransportSecurity:NSAllowsArbitraryLoads" "true" || true
        set_plist_bool "$info_plist" "NSAppTransportSecurity:NSAllowsLocalNetworking" "true" || true
    fi
}

verify_macos_network_entitlement() {
    local app_path="$1"
    if ! command -v codesign >/dev/null 2>&1; then
        echo "Warning: codesign not found, cannot verify entitlements."
        return 0
    fi

    local ents
    ents="$(codesign -d --entitlements :- "$app_path" 2>/dev/null || true)"
    if [ -z "$ents" ]; then
        echo "Warning: unable to read app entitlements from $app_path"
        return 0
    fi

    if ! printf '%s\n' "$ents" | grep -q "com.apple.security.network.client"; then
        echo "Error: com.apple.security.network.client missing in built app entitlements."
        echo "The app may fail all outbound network requests on macOS."
        return 1
    fi
}

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: invalid version '$VERSION'. Expected X.Y.Z"
    exit 1
fi

BUILD_DIR="build/macos/Build/Products/Release"
DIST_DIR="build/macos/dist"
ZIP_VERSIONED="militant-macos-v${VERSION}.zip"
ZIP_LATEST="militant-macos-latest.zip"
DMG_VERSIONED="militant-macos-v${VERSION}.dmg"
DMG_LATEST="militant-macos-latest.dmg"

# Optional signing / notarization settings
MACOS_SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:-}"
MACOS_REQUIRE_SIGNED="${MACOS_REQUIRE_SIGNED:-0}"
MACOS_REQUIRE_NOTARIZED="${MACOS_REQUIRE_NOTARIZED:-0}"
MACOS_NOTARY_KEYCHAIN_PROFILE="${MACOS_NOTARY_KEYCHAIN_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"

SIGN_ENABLED=0
NOTARY_ENABLED=0

if [ -n "$MACOS_SIGN_IDENTITY" ]; then
    SIGN_ENABLED=1
fi

if [ -n "$MACOS_NOTARY_KEYCHAIN_PROFILE" ] || { [ -n "$APPLE_ID" ] && [ -n "$APPLE_APP_PASSWORD" ] && [ -n "$APPLE_TEAM_ID" ]; }; then
    NOTARY_ENABLED=1
fi

if [ "$MACOS_REQUIRE_SIGNED" = "1" ] && [ "$SIGN_ENABLED" -ne 1 ]; then
    echo "Error: MACOS_REQUIRE_SIGNED=1 but MACOS_SIGN_IDENTITY is not set."
    exit 1
fi

if [ "$MACOS_REQUIRE_NOTARIZED" = "1" ] && [ "$NOTARY_ENABLED" -ne 1 ]; then
    echo "Error: MACOS_REQUIRE_NOTARIZED=1 but notarization credentials are missing."
    exit 1
fi

if [ "$NOTARY_ENABLED" -eq 1 ] && [ "$SIGN_ENABLED" -ne 1 ]; then
    echo "Error: notarization requires signing. Set MACOS_SIGN_IDENTITY."
    exit 1
fi

if [ "$NOTARY_ENABLED" -eq 1 ] && ! command -v xcrun >/dev/null 2>&1; then
    echo "Error: xcrun is required for notarization."
    exit 1
fi

submit_notary() {
    local file="$1"
    if [ -n "$MACOS_NOTARY_KEYCHAIN_PROFILE" ]; then
        xcrun notarytool submit "$file" --keychain-profile "$MACOS_NOTARY_KEYCHAIN_PROFILE" --wait
    else
        xcrun notarytool submit "$file" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
    fi
}

# macOS scaffolding can be missing if the project was not initialized for macOS.
if [ ! -f "macos/Runner.xcodeproj/project.pbxproj" ]; then
    echo "macOS project files missing. Running: flutter create --platforms=macos ."
    flutter create --platforms=macos .
fi

ensure_macos_network_config

# Apply Militant logo as native macOS app icon.
APPICON_DIR="macos/Runner/Assets.xcassets/AppIcon.appiconset"
ICON_SOURCE=""
if [ -f "assets/icon-512.png" ]; then
    ICON_SOURCE="assets/icon-512.png"
elif [ -f "play-store-icon-512.png" ]; then
    ICON_SOURCE="play-store-icon-512.png"
fi

if [ -n "$ICON_SOURCE" ] && [ -d "$APPICON_DIR" ] && command -v sips >/dev/null 2>&1; then
    echo "Applying Militant icon from $ICON_SOURCE..."
    sips -z 16 16 "$ICON_SOURCE" --out "$APPICON_DIR/app_icon_16.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$APPICON_DIR/app_icon_32.png" >/dev/null
    sips -z 64 64 "$ICON_SOURCE" --out "$APPICON_DIR/app_icon_64.png" >/dev/null
    sips -z 128 128 "$ICON_SOURCE" --out "$APPICON_DIR/app_icon_128.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$APPICON_DIR/app_icon_256.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$APPICON_DIR/app_icon_512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$APPICON_DIR/app_icon_1024.png" >/dev/null
else
    echo "Warning: could not apply custom icon (missing source icon or AppIcon directory)."
fi

flutter config --enable-macos-desktop >/dev/null
flutter pub get
flutter build macos --release

APP_PATH=""
if [ -d "${BUILD_DIR}/militant.app" ]; then
    APP_PATH="${BUILD_DIR}/militant.app"
else
    APP_PATH=$(find "$BUILD_DIR" -maxdepth 1 -name '*.app' | head -n 1 || true)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: macOS app bundle not found in $BUILD_DIR"
    exit 1
fi

APP_BASENAME=$(basename "$APP_PATH")

if [ "$SIGN_ENABLED" -eq 1 ]; then
    echo "Signing app with identity: $MACOS_SIGN_IDENTITY"
    codesign --force --deep --timestamp --options runtime --sign "$MACOS_SIGN_IDENTITY" "$APP_PATH"
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
else
    echo "Warning: app is not signed (MACOS_SIGN_IDENTITY not set)."
fi

verify_macos_network_entitlement "$APP_PATH"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "$APP_PATH" "$DIST_DIR/$APP_BASENAME"
DIST_APP_PATH="$DIST_DIR/$APP_BASENAME"

if [ "$NOTARY_ENABLED" -eq 1 ]; then
    echo "Notarizing app bundle..."
    NOTARY_APP_ZIP="$DIST_DIR/notary-app.zip"
    rm -f "$NOTARY_APP_ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$DIST_APP_PATH" "$NOTARY_APP_ZIP"
    submit_notary "$NOTARY_APP_ZIP"
    xcrun stapler staple -v "$DIST_APP_PATH"
    xcrun stapler validate "$DIST_APP_PATH" || true
    rm -f "$NOTARY_APP_ZIP"
else
    echo "Warning: app is not notarized (notary credentials not set)."
fi

pushd "$DIST_DIR" >/dev/null

# Keep the app bundle parent in the archive for a drag-and-drop install flow.
ditto -c -k --sequesterRsrc --keepParent "$APP_BASENAME" "$ZIP_VERSIONED"
cp -f "$ZIP_VERSIONED" "$ZIP_LATEST"

if command -v hdiutil >/dev/null 2>&1; then
    # Cleanup any previously mounted volume with the same name.
    while read -r dev; do
        if [ -n "$dev" ]; then
            hdiutil detach "$dev" -force >/dev/null 2>&1 || true
        fi
    done < <(hdiutil info | awk '/\/Volumes\/Militant$/ {print $1}')

    rm -f "$DMG_VERSIONED" "$DMG_LATEST"

    DMG_STAGE=$(mktemp -d)
    cp -R "$APP_BASENAME" "$DMG_STAGE/"
    if ! hdiutil create -volname "Militant" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_VERSIONED" >/dev/null 2>&1; then
        # One retry after a broader detach pass.
        while read -r dev; do
            if [ -n "$dev" ]; then
                hdiutil detach "$dev" -force >/dev/null 2>&1 || true
            fi
        done < <(hdiutil info | awk '/\/Volumes\/Militant/ {print $1}')
        sleep 1
        hdiutil create -volname "Militant" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_VERSIONED" >/dev/null
    fi
    rm -rf "$DMG_STAGE"

    if [ "$NOTARY_ENABLED" -eq 1 ]; then
        echo "Notarizing DMG..."
        submit_notary "$DMG_VERSIONED"
        xcrun stapler staple -v "$DMG_VERSIONED"
        xcrun stapler validate "$DMG_VERSIONED" || true
    fi

    cp -f "$DMG_VERSIONED" "$DMG_LATEST"
fi

popd >/dev/null

# Optional: copy artifacts to the joinmilitant website repository if present.
if [ -d "../jointomilitant" ]; then
    cp -f "$DIST_DIR/$ZIP_VERSIONED" "../jointomilitant/$ZIP_VERSIONED"
    cp -f "$DIST_DIR/$ZIP_LATEST" "../jointomilitant/$ZIP_LATEST"

    if [ -f "$DIST_DIR/$DMG_VERSIONED" ]; then
        cp -f "$DIST_DIR/$DMG_VERSIONED" "../jointomilitant/$DMG_VERSIONED"
        cp -f "$DIST_DIR/$DMG_LATEST" "../jointomilitant/$DMG_LATEST"
    fi
fi

echo "Done. macOS artifacts:"
echo "  $DIST_DIR/$ZIP_VERSIONED"
echo "  $DIST_DIR/$ZIP_LATEST"
if [ -f "$DIST_DIR/$DMG_VERSIONED" ]; then
    echo "  $DIST_DIR/$DMG_VERSIONED"
    echo "  $DIST_DIR/$DMG_LATEST"
fi
