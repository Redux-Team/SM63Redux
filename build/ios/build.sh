#!/bin/bash
set -e

LOCAL_SCRIPT="_local/build.sh"

if [ -f "$LOCAL_SCRIPT" ]; then
  echo "Found local device build script, running it..."
  "$LOCAL_SCRIPT"
  exit 0
fi

echo "No local build script found, running default IPA build..."
PROJECT_NAME="SM63Redux"
SCHEME_NAME="SM63Redux"
LOCAL_CONFIG="_local/localbuild.txt"

CYAN="\033[1;36m"
GREEN="\033[1;32m"
RED="\033[1;31m"
GRAY="\033[0;37m"
RESET="\033[0m"

header() { echo -e "${CYAN}==============================\n>> $1\n==============================${RESET}"; }
fail() { echo -e "${RED}✘ $1${RESET}"; exit 1; }

if [ ! -f "$LOCAL_CONFIG" ]; then
  fail "Local config $LOCAL_CONFIG not found"
fi

source "$LOCAL_CONFIG"

[ -n "$APPLE_ID" ] || fail "APPLE_ID not set in $LOCAL_CONFIG"
[ -n "$TEAM_ID" ] || fail "TEAM_ID not set in $LOCAL_CONFIG"

header "Validating project"
[ -d "$PROJECT_NAME.xcodeproj" ] || fail "$PROJECT_NAME.xcodeproj not found"
SCHEME_EXISTS=$(xcodebuild -list -project "$PROJECT_NAME.xcodeproj" | grep "$SCHEME_NAME" || true)
[ -n "$SCHEME_EXISTS" ] || fail "Scheme '$SCHEME_NAME' not found"

header "Cleaning previous builds"
rm -rf build Payload "$PROJECT_NAME.ipa"

header "Starting Xcode build (signed for sideload)"
BUILD_OUTPUT=$(xcodebuild \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME_NAME" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE="Automatic" \
  PRODUCT_BUNDLE_IDENTIFIER="com.reduxteam.sm63redux" \
  BUILD_DIR=./build 2>&1) || true

if echo "$BUILD_OUTPUT" | grep -q "is not installed. Please download and install the platform"; then
  fail "iOS platform not installed. Open Xcode → Settings → Components"
fi

if echo "$BUILD_OUTPUT" | grep -q "error:"; then
  echo "$BUILD_OUTPUT"
  fail "Xcode build failed"
fi

APP_PATH="build/Release-iphoneos/$PROJECT_NAME.app"
[ -d "$APP_PATH" ] || fail ".app not found"

header "Packaging .app into .ipa"
mkdir -p Payload
cp -r "$APP_PATH" Payload/
zip -r "$PROJECT_NAME.ipa" Payload > /dev/null

header "Cleaning up"
rm -rf Payload build

echo -e "${GREEN}✔ Done! IPA generated: ${PROJECT_NAME}.ipa${RESET}"
