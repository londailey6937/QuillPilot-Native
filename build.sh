#!/bin/bash
# QuillPilot Build Script
# Always builds with Xcode and updates the app in build/Release

set -euo pipefail

cd "$(dirname "$0")/QuillPilot"

echo "🔨 Building QuillPilot with Xcode..."
xcodebuild -project QuillPilot.xcodeproj -scheme QuillPilot -configuration Release build 2>&1 | tail -5

echo "🔎 Locating built app..."
BUILD_DIR=$(xcodebuild -project QuillPilot.xcodeproj -scheme QuillPilot -configuration Release -showBuildSettings 2>/dev/null | awk -F' = ' '/TARGET_BUILD_DIR/ {print $2; exit}')
WRAPPER_NAME=$(xcodebuild -project QuillPilot.xcodeproj -scheme QuillPilot -configuration Release -showBuildSettings 2>/dev/null | awk -F' = ' '/WRAPPER_NAME/ {print $2; exit}')
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
rm -rf build/Release/QuillPilot.app
mkdir -p build/Release
cp -R "${APP_PATH}" build/Release/

echo "✅ Build complete! App updated at: QuillPilot/build/Release/QuillPilot.app"
