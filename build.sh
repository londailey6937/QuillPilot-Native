#!/bin/bash
# QuillPilot Build Script
# Always builds with Xcode and updates the app in build/Release

set -e

cd "$(dirname "$0")/QuillPilot"

echo "🔨 Building QuillPilot with Xcode..."
xcodebuild -project QuillPilot.xcodeproj -scheme QuillPilot -configuration Release build 2>&1 | tail -5

echo "📦 Copying app to build/Release..."
rm -rf build/Release/QuillPilot.app
cp -R ~/Library/Developer/Xcode/DerivedData/QuillPilot-ficxfafckslptydeifhigaepdugo/Build/Products/Release/QuillPilot.app build/Release/

echo "✅ Build complete! App updated at: QuillPilot/build/Release/QuillPilot.app"
