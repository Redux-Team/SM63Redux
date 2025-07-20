#!/bin/bash
cd "$(dirname "$0")"

PROJECT_NAME="SM63Redux"
SCHEME_NAME="SM63Redux"

# Colors
CYAN="\033[1;36m"
GREEN="\033[1;32m"
GRAY="\033[0;37m"
RESET="\033[0m"

# Banner function
function header() {
  echo -e "${CYAN}"
  echo "=============================="
  echo ">> $1"
  echo "=============================="
  echo -e "${RESET}"
}

header "Cleaning previous builds"
rm -rf build Payload "$PROJECT_NAME.ipa"

header "Starting Xcode build"
echo -e "${GRAY}(this may take a moment)${RESET}"
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME_NAME" \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  BUILD_DIR=./build > /dev/null

header "Packaging .app into .ipa"
mkdir -p Payload
cp -r "build/Release-iphoneos/$PROJECT_NAME.app" Payload/
zip -r "$PROJECT_NAME.ipa" Payload > /dev/null

header "Cleaning up temporary files"
rm -rf Payload build

echo -e "${GREEN}✔ Done! IPA generated: ${PROJECT_NAME}.ipa${RESET}"
