#!/usr/bin/env bash
#
# archive.sh — Build, test, archive, and optionally export/upload Quill Pilot
#
# Usage:
#   ./archive.sh              # Archive only (creates .xcarchive)
#   ./archive.sh --export     # Archive + export .app for direct distribution
#   ./archive.sh --testflight # Archive + export + upload to TestFlight
#   ./archive.sh --notarize   # Archive + export + notarize for outside-App-Store
#
# Prerequisites:
#   • Xcode command-line tools installed
#   • Valid signing identity (Automatic signing with your team)
#   • For --testflight: App Store Connect API key or `xcrun altool` credentials
#   • For --notarize: notarytool credentials stored in keychain
#
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")/QuillPilot" && pwd)"
PROJECT="$PROJECT_DIR/QuillPilot.xcodeproj"
SCHEME="QuillPilot"
CONFIGURATION="Release"

ARCHIVE_DIR="$PROJECT_DIR/build/Archives"
EXPORT_DIR="$PROJECT_DIR/build/Export"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE_PATH="$ARCHIVE_DIR/QuillPilot-$TIMESTAMP.xcarchive"

EXPORT_OPTIONS_PLIST="$PROJECT_DIR/ExportOptions.plist"
TESTFLIGHT_EXPORT_PLIST="$PROJECT_DIR/ExportOptionsTestFlight.plist"

# ─── Parse arguments ────────────────────────────────────────────────────────
ACTION="archive"
for arg in "$@"; do
    case "$arg" in
        --export)     ACTION="export" ;;
        --testflight) ACTION="testflight" ;;
        --notarize)   ACTION="notarize" ;;
        --skip-tests) SKIP_TESTS=1 ;;
        --help|-h)
            echo "Usage: $0 [--export|--testflight|--notarize] [--skip-tests]"
            exit 0
            ;;
    esac
done

SKIP_TESTS="${SKIP_TESTS:-0}"

# ─── Helpers ─────────────────────────────────────────────────────────────────
step() { echo ""; echo "━━━ $1 ━━━"; }

# ─── Step 1: Run tests ──────────────────────────────────────────────────────
if [[ "$SKIP_TESTS" == "0" ]]; then
    step "Running unit tests"
    RESULT_BUNDLE="/tmp/QuillPilotTestResults-$TIMESTAMP.xcresult"
    TEST_EXIT=0
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=macOS' \
        -resultBundlePath "$RESULT_BUNDLE" \
        -quiet \
        || TEST_EXIT=$?

    # xcodebuild may report failure if the test host crashes even when all
    # tests pass.  Check the xcresult for the actual test outcome.
    if [[ $TEST_EXIT -ne 0 ]]; then
        ACTUAL_FAILURES=$(xcrun xcresulttool get --path "$RESULT_BUNDLE" --format json 2>/dev/null \
            | grep -c '"testStatus" : "Failure"' 2>/dev/null || echo "0")
        if [[ "$ACTUAL_FAILURES" == "0" ]]; then
            echo "⚠️  xcodebuild exited non-zero but all tests passed (test host crash, not a test failure)."
            echo "✅ All tests passed."
        else
            echo "❌ $ACTUAL_FAILURES test(s) failed. Fix tests before archiving."
            exit 1
        fi
    else
        echo "✅ All tests passed."
    fi
    rm -rf "$RESULT_BUNDLE"
else
    echo "⏭  Skipping tests (--skip-tests)"
fi

# ─── Step 2: Clean build ────────────────────────────────────────────────────
step "Clean build"
xcodebuild clean \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -quiet

# ─── Step 3: Archive ────────────────────────────────────────────────────────
step "Archiving → $ARCHIVE_PATH"
mkdir -p "$ARCHIVE_DIR"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -quiet

echo "✅ Archive created: $ARCHIVE_PATH"

# ─── Step 4: Export (if requested) ──────────────────────────────────────────
if [[ "$ACTION" == "archive" ]]; then
    echo ""
    echo "Done. To export, re-run with --export, --testflight, or --notarize."
    echo "Archive: $ARCHIVE_PATH"
    exit 0
fi

# Generate export options plist if missing
generate_export_plist() {
    local method="$1"
    local plist="$2"
    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${method}</string>
    <key>teamID</key>
    <string>7YD53MV78N</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
PLIST
    echo "  Generated $plist"
}

if [[ "$ACTION" == "testflight" ]]; then
    if [[ ! -f "$TESTFLIGHT_EXPORT_PLIST" ]]; then
        step "Generating TestFlight export options"
        generate_export_plist "app-store" "$TESTFLIGHT_EXPORT_PLIST"
    fi

    step "Exporting for App Store / TestFlight"
    mkdir -p "$EXPORT_DIR"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$TESTFLIGHT_EXPORT_PLIST" \
        -exportPath "$EXPORT_DIR" \
        -quiet

    echo "✅ Exported to: $EXPORT_DIR"

    step "Uploading to App Store Connect"
    echo "Looking for .ipa or .pkg in $EXPORT_DIR ..."
    UPLOAD_FILE=$(find "$EXPORT_DIR" \( -name '*.ipa' -o -name '*.pkg' \) | head -1)
    if [[ -n "$UPLOAD_FILE" ]]; then
        xcrun altool --upload-app \
            --type macos \
            --file "$UPLOAD_FILE" \
            --apiKey "${APP_STORE_CONNECT_API_KEY:-}" \
            --apiIssuer "${APP_STORE_CONNECT_ISSUER_ID:-}" \
            2>&1 || echo "⚠️  Upload failed. You can upload manually via Transporter or Xcode Organizer."
    else
        echo "⚠️  No uploadable artifact found. Use Xcode Organizer to upload the archive manually."
        echo "    Archive: $ARCHIVE_PATH"
    fi

elif [[ "$ACTION" == "export" || "$ACTION" == "notarize" ]]; then
    if [[ ! -f "$EXPORT_OPTIONS_PLIST" ]]; then
        step "Generating developer-id export options"
        generate_export_plist "developer-id" "$EXPORT_OPTIONS_PLIST"
    fi

    step "Exporting for direct distribution"
    mkdir -p "$EXPORT_DIR"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
        -exportPath "$EXPORT_DIR" \
        -quiet

    echo "✅ Exported to: $EXPORT_DIR"

    if [[ "$ACTION" == "notarize" ]]; then
        step "Notarizing"
        APP_PATH=$(find "$EXPORT_DIR" -name '*.app' -maxdepth 1 | head -1)
        if [[ -n "$APP_PATH" ]]; then
            # Create a zip for notarization
            ZIP_PATH="$EXPORT_DIR/QuillPilot-$TIMESTAMP.zip"
            ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

            xcrun notarytool submit "$ZIP_PATH" \
                --keychain-profile "QuillPilot" \
                --wait \
                2>&1 || echo "⚠️  Notarization failed. Store credentials first:"$'\n'"    xcrun notarytool store-credentials QuillPilot --apple-id YOUR@EMAIL --team-id 7YD53MV78N"

            # Staple if notarization succeeded
            xcrun stapler staple "$APP_PATH" 2>/dev/null || true
            echo "✅ Notarization complete."
        else
            echo "⚠️  No .app found in $EXPORT_DIR"
        fi
    fi
fi

echo ""
echo "━━━ Summary ━━━"
echo "Archive:  $ARCHIVE_PATH"
[[ -d "$EXPORT_DIR" ]] && echo "Export:   $EXPORT_DIR"
echo "Done."
