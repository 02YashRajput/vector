#!/bin/bash
set -euo pipefail

APP_NAME="Vector"
SCHEME="vector"
BUILD_DIR=".build/release"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"

echo "→ Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "→ Archiving..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    -quiet

echo "→ Exporting app..."
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$APP_PATH"

echo "→ Creating zip..."
cd "$BUILD_DIR"
zip -r -q "$APP_NAME.zip" "$APP_NAME.app"
cd - > /dev/null

ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1 | xargs)
echo ""
echo "✓ Build complete: $ZIP_PATH ($ZIP_SIZE)"
echo ""
echo "Next steps:"
echo "  1. Create a GitHub release: gh release create v1.0.0 $ZIP_PATH --title 'v1.0.0'"
echo "  2. Or upload manually at https://github.com/02YashRajput/vector/releases/new"
