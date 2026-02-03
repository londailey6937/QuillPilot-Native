#!/bin/bash
# QuillPilot Build Script
# Always builds with Xcode and updates the app in build/Release

set -euo pipefail

cd "$(dirname "$0")/QuillPilot"

echo "🔨 Building QuillPilot with Xcode..."
xcodebuild -project QuillPilot.xcodeproj -scheme QuillPilot -configuration Release -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5

echo "🔎 Locating built app..."
BUILD_DIR=$(xcodebuild -project QuillPilot.xcodeproj -scheme QuillPilot -configuration Release -destination 'platform=macOS,arch=arm64' -showBuildSettings 2>/dev/null | awk -F' = ' '/TARGET_BUILD_DIR/ {print $2; exit}')
WRAPPER_NAME=$(xcodebuild -project QuillPilot.xcodeproj -scheme QuillPilot -configuration Release -destination 'platform=macOS,arch=arm64' -showBuildSettings 2>/dev/null | awk -F' = ' '/WRAPPER_NAME/ {print $2; exit}')
APP_PATH="${BUILD_DIR}/${WRAPPER_NAME}"

if [ -z "${BUILD_DIR}" ] || [ -z "${WRAPPER_NAME}" ]; then
	echo "❌ Failed to determine build output path."
	exit 1
fi

if [ ! -d "${APP_PATH}" ]; then
	echo "❌ Built app not found at: ${APP_PATH}"
	exit 1
fi

echo "📦 Copying app to build/Release..."
mkdir -p build/Release
# Remove any previous app bundles (name may change based on PRODUCT_NAME)
rm -rf build/Release/*.app
cp -R "${APP_PATH}" build/Release/

echo "✅ Build complete! App updated at: QuillPilot/build/Release/${WRAPPER_NAME}"
