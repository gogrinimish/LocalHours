#!/bin/bash

# Icon Generation Script for LocalHours
# Uses macOS built-in 'sips' command - no external dependencies required
#
# Usage: ./Scripts/generate-icons.sh [path/to/source-icon-1024.png]

set -e

SOURCE_ICON="${1:-Assets/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png}"
OUTPUT_DIR="Assets/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SOURCE_ICON" ]; then
    echo "Error: Source icon not found at $SOURCE_ICON"
    echo "Usage: $0 <path-to-1024x1024-icon.png>"
    exit 1
fi

echo "Generating app icons from $SOURCE_ICON..."

# Function to resize icon using sips (macOS built-in)
resize_icon() {
    local size=$1
    local output=$2
    
    cp "$SOURCE_ICON" "$output"
    sips -z "$size" "$size" "$output" --out "$output" > /dev/null 2>&1
}

# iOS iPhone icons
echo "Generating iOS iPhone icons..."
resize_icon 40 "$OUTPUT_DIR/AppIcon-20@2x.png"
resize_icon 60 "$OUTPUT_DIR/AppIcon-20@3x.png"
resize_icon 58 "$OUTPUT_DIR/AppIcon-29@2x.png"
resize_icon 87 "$OUTPUT_DIR/AppIcon-29@3x.png"
resize_icon 80 "$OUTPUT_DIR/AppIcon-40@2x.png"
resize_icon 120 "$OUTPUT_DIR/AppIcon-40@3x.png"
resize_icon 120 "$OUTPUT_DIR/AppIcon-60@2x.png"
resize_icon 180 "$OUTPUT_DIR/AppIcon-60@3x.png"

# iOS iPad icons
echo "Generating iOS iPad icons..."
resize_icon 20 "$OUTPUT_DIR/AppIcon-20.png"
resize_icon 40 "$OUTPUT_DIR/AppIcon-20@2x-ipad.png"
resize_icon 29 "$OUTPUT_DIR/AppIcon-29.png"
resize_icon 58 "$OUTPUT_DIR/AppIcon-29@2x-ipad.png"
resize_icon 40 "$OUTPUT_DIR/AppIcon-40.png"
resize_icon 80 "$OUTPUT_DIR/AppIcon-40@2x-ipad.png"
resize_icon 76 "$OUTPUT_DIR/AppIcon-76.png"
resize_icon 152 "$OUTPUT_DIR/AppIcon-76@2x.png"
resize_icon 167 "$OUTPUT_DIR/AppIcon-83.5@2x.png"

# macOS icons
echo "Generating macOS icons..."
resize_icon 16 "$OUTPUT_DIR/AppIcon-16.png"
resize_icon 32 "$OUTPUT_DIR/AppIcon-16@2x.png"
resize_icon 32 "$OUTPUT_DIR/AppIcon-32.png"
resize_icon 64 "$OUTPUT_DIR/AppIcon-32@2x.png"
resize_icon 128 "$OUTPUT_DIR/AppIcon-128.png"
resize_icon 256 "$OUTPUT_DIR/AppIcon-128@2x.png"
resize_icon 256 "$OUTPUT_DIR/AppIcon-256.png"
resize_icon 512 "$OUTPUT_DIR/AppIcon-256@2x.png"
resize_icon 512 "$OUTPUT_DIR/AppIcon-512.png"
resize_icon 1024 "$OUTPUT_DIR/AppIcon-512@2x.png"

# Marketing icon (1024x1024) - just copy
echo "Copying marketing icon..."
cp "$SOURCE_ICON" "$OUTPUT_DIR/AppIcon-1024.png"

echo ""
echo "✓ Icon generation complete!"
echo "  Generated icons in $OUTPUT_DIR"
echo ""
echo "Icon sizes generated:"
echo "  - iOS iPhone: 40, 58, 60, 80, 87, 120, 180"
echo "  - iOS iPad: 20, 29, 40, 58, 76, 80, 152, 167"
echo "  - macOS: 16, 32, 64, 128, 256, 512, 1024"
