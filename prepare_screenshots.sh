#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# prepare_screenshots.sh — Resize screenshots for macOS App Store Connect
# ─────────────────────────────────────────────────────────────────────────────
#
# Usage:
#   ./prepare_screenshots.sh [input_dir] [output_dir]
#
# Defaults:
#   input_dir  = ./screenshots_raw
#   output_dir = ./screenshots_appstore
#
# This script takes raw macOS screenshots (any resolution) and produces
# properly sized images for App Store Connect WITHOUT distortion.
#
# It generates TWO sizes per screenshot:
#   • 2880 × 1800  (required — fits 15"/16" Retina display slot)
#   • 2560 × 1600  (optional — fits 13" Retina display slot)
#
# Strategy: scale to fit, then pad with a background colour to exact dimensions.
# This avoids stretching/distortion entirely.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────

INPUT_DIR="${1:-./screenshots_raw}"
OUTPUT_DIR="${2:-./screenshots_appstore}"

# Background colour used for letterbox padding (hex). Change to match your app.
BG_COLOR="#1A1A2E"

# Target sizes  (width × height)
SIZES=("2880x1800" "2560x1600")

# ── Preflight ────────────────────────────────────────────────────────────────

if ! command -v sips &>/dev/null; then
  echo "Error: 'sips' not found. This script requires macOS."
  exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
  echo "Error: Input directory '$INPUT_DIR' does not exist."
  echo ""
  echo "Create it and drop your raw screenshots there:"
  echo "  mkdir -p $INPUT_DIR"
  echo ""
  exit 1
fi

# Count input images
shopt -s nullglob
INPUT_FILES=("$INPUT_DIR"/*.{png,PNG,jpg,JPG,jpeg,JPEG,tiff,TIFF})
shopt -u nullglob

if [ ${#INPUT_FILES[@]} -eq 0 ]; then
  echo "Error: No image files found in '$INPUT_DIR'."
  echo "Supported formats: PNG, JPG, JPEG, TIFF"
  exit 1
fi

echo "Found ${#INPUT_FILES[@]} screenshot(s) in '$INPUT_DIR'"
echo ""

# ── Processing ───────────────────────────────────────────────────────────────

for size in "${SIZES[@]}"; do
  TARGET_W="${size%x*}"
  TARGET_H="${size#*x}"
  SIZE_DIR="$OUTPUT_DIR/${size}"
  mkdir -p "$SIZE_DIR"

  echo "━━━ Generating ${TARGET_W}×${TARGET_H} screenshots ━━━"

  for src in "${INPUT_FILES[@]}"; do
    filename=$(basename "$src")
    name="${filename%.*}"
    output="$SIZE_DIR/${name}.png"

    # Get source dimensions
    SRC_W=$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')
    SRC_H=$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')

    echo "  Processing: $filename (${SRC_W}×${SRC_H})"

    # Calculate scale factor to fit within target while preserving aspect ratio
    SCALE_W=$(echo "scale=10; $TARGET_W / $SRC_W" | bc)
    SCALE_H=$(echo "scale=10; $TARGET_H / $SRC_H" | bc)

    # Use the smaller scale factor so the image fits entirely
    if (( $(echo "$SCALE_W < $SCALE_H" | bc -l) )); then
      SCALE="$SCALE_W"
    else
      SCALE="$SCALE_H"
    fi

    NEW_W=$(echo "$SRC_W * $SCALE" | bc | awk '{printf "%d", $1}')
    NEW_H=$(echo "$SRC_H * $SCALE" | bc | awk '{printf "%d", $1}')

    # Ensure we don't exceed target
    if [ "$NEW_W" -gt "$TARGET_W" ]; then NEW_W=$TARGET_W; fi
    if [ "$NEW_H" -gt "$TARGET_H" ]; then NEW_H=$TARGET_H; fi

    # Step 1: Create the background canvas at exact target size
    CANVAS=$(mktemp /tmp/canvas_XXXXXX.png)
    # Create a 1×1 pixel of the background colour and scale it up
    python3 -c "
import struct, zlib
def create_png(w, h, r, g, b):
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    raw = b''
    for _ in range(h):
        raw += b'\x00' + bytes([r, g, b]) * w
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(raw)) +
            chunk(b'IEND', b''))
# Parse hex colour
color = '$BG_COLOR'.lstrip('#')
r, g, b = int(color[0:2],16), int(color[2:4],16), int(color[4:6],16)
with open('$CANVAS', 'wb') as f:
    f.write(create_png($TARGET_W, $TARGET_H, r, g, b))
"

    # Step 2: Resize the source image (preserving aspect ratio)
    RESIZED=$(mktemp /tmp/resized_XXXXXX.png)
    cp "$src" "$RESIZED"
    sips --resampleHeightWidth "$NEW_H" "$NEW_W" "$RESIZED" --out "$RESIZED" &>/dev/null

    # Step 3: Calculate padding offsets to centre the image
    PAD_X=$(( (TARGET_W - NEW_W) / 2 ))
    PAD_Y=$(( (TARGET_H - NEW_H) / 2 ))

    # Step 4: Composite resized image onto canvas using Python
    python3 -c "
import subprocess, sys

# Use CoreGraphics via PyObjC or fall back to manual compositing
try:
    from Quartz import (
        CGImageSourceCreateWithURL, CGImageSourceCreateImageAtIndex,
        CGBitmapContextCreate, CGContextDrawImage, CGRectMake,
        CGBitmapContextCreateImage, CGImageDestinationCreateWithURL,
        CGImageDestinationAddImage, CGImageDestinationFinalize,
        kCGImageAlphaPremultipliedLast
    )
    from CoreFoundation import CFURLCreateWithFileSystemPath, kCFURLPOSIXPathStyle

    def load_image(path):
        url = CFURLCreateWithFileSystemPath(None, path, kCFURLPOSIXPathStyle, False)
        src = CGImageSourceCreateWithURL(url, None)
        return CGImageSourceCreateImageAtIndex(src, 0, None)

    def save_image(cgimage, path):
        url = CFURLCreateWithFileSystemPath(None, path, kCFURLPOSIXPathStyle, False)
        dest = CGImageDestinationCreateWithURL(url, 'public.png', 1, None)
        CGImageDestinationAddImage(dest, cgimage, None)
        CGImageDestinationFinalize(dest)

    canvas = load_image('$CANVAS')
    overlay = load_image('$RESIZED')

    w = $TARGET_W
    h = $TARGET_H
    ctx = CGBitmapContextCreate(None, w, h, 8, w * 4,
        CGImageGetColorSpace(canvas) if hasattr(canvas, 'CGImageGetColorSpace') else None,
        kCGImageAlphaPremultipliedLast)

    # Draw canvas
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), canvas)
    # Draw overlay centred (CoreGraphics origin is bottom-left)
    pad_y_cg = h - $NEW_H - $PAD_Y
    CGContextDrawImage(ctx, CGRectMake($PAD_X, pad_y_cg, $NEW_W, $NEW_H), overlay)

    result = CGBitmapContextCreateImage(ctx)
    save_image(result, '$output')

except ImportError:
    # Fallback: use sips crop approach
    import shutil
    shutil.copy('$RESIZED', '$output')
    subprocess.run(['sips', '--padToHeightWidth', '$TARGET_H', '$TARGET_W',
                    '--padColor', '${BG_COLOR#\#}', '$output'],
                   capture_output=True)
"

    # Cleanup temp files
    rm -f "$CANVAS" "$RESIZED"

    # Verify output
    OUT_W=$(sips -g pixelWidth "$output" | awk '/pixelWidth/{print $2}')
    OUT_H=$(sips -g pixelHeight "$output" | awk '/pixelHeight/{print $2}')
    if [ "$OUT_W" -eq "$TARGET_W" ] && [ "$OUT_H" -eq "$TARGET_H" ]; then
      echo "    ✓ ${name}.png → ${OUT_W}×${OUT_H}"
    else
      echo "    ⚠ ${name}.png → ${OUT_W}×${OUT_H} (expected ${TARGET_W}×${TARGET_H})"
    fi
  done

  echo ""
done

echo "━━━ Done! ━━━"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Upload these to App Store Connect:"
for size in "${SIZES[@]}"; do
  COUNT=$(ls "$OUTPUT_DIR/$size"/*.png 2>/dev/null | wc -l | tr -d ' ')
  echo "  • $OUTPUT_DIR/$size/ — $COUNT screenshot(s)"
done
echo ""
echo "Tip: App Store Connect requires 1–10 screenshots per size."
