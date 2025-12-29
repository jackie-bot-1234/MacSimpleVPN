#!/bin/bash
set -e

# Configuration
# Team ID for "Jacqueline Edoro" (from security find-identity)
# Use "C7KSRZC3Q9" for "Resistine GmbH" if preferred.
TEAM_ID="C7KSRZC3Q9" 
SCHEME="VPN"
PROJECT="VPN.xcodeproj"
DERIVED_DATA_PATH="build_antigravity"

# Helper: Check for Signing Identity
echo "🔍 Checking for Signing Identity: $TEAM_ID..."
if ! security find-identity -v -p codesigning | grep -q "$TEAM_ID"; then
    echo "⚠️  Warning: Signing identity for Team ID $TEAM_ID not found in keychain."
    echo "   Available identities:"
    security find-identity -v -p codesigning
    echo "   Please ensure you have the correct certificate installed."
else
    echo "✅ Signing identity found."
fi

# Helper: Check for Provisioning Profiles
PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
if [ ! -d "$PROFILES_DIR" ]; then
    echo "⚠️  Warning: Provisioning Profiles directory not found at $PROFILES_DIR"
    echo "   Xcode requires provisioning profiles to sign the Network Extension."
    echo "   Please ensure you are logged into Xcode (Settings > Accounts) and profiles are downloaded."
fi

# Clean and Build
echo "🚀 Building $SCHEME with Team ID $TEAM_ID... (Logs: build.log)"
# Note: -allowProvisioningUpdates requires Xcode to be logged in to the account.
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -allowProvisioningUpdates \
    clean build > build.log 2>&1 || {
        echo "❌ Build failed. Checking logs..."
        tail -n 20 build.log
        echo "---------------------------------------------------"
        echo "💡 Tip: If the error is 'No profiles for ... were found', ensure:"
        echo "   1. You are logged into Xcode with the account for Team $TEAM_ID."
        echo "   2. You have a valid Signing Certificate in your Keychain."
        exit 1
    }

# Run
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/$SCHEME.app"

if [ -d "$APP_PATH" ]; then
    echo "✅ Build successful!"
    echo "🚀 Launching $APP_PATH..."
    open "$APP_PATH"
else
    echo "❌ Error: App not found at $APP_PATH"
    exit 1
fi
