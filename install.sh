#!/bin/bash
set -euo pipefail

REPO="02YashRajput/vector"
APP_NAME="Vector"
INSTALL_DIR="$HOME/Applications"

mkdir -p "$INSTALL_DIR"

echo "→ Fetching latest release..."
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url.*\.zip" \
    | head -1 \
    | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "✗ No release found. Check https://github.com/$REPO/releases"
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "→ Downloading $APP_NAME..."
curl -fsSL -o "$TMPDIR/$APP_NAME.zip" "$DOWNLOAD_URL"

echo "→ Extracting..."
unzip -q "$TMPDIR/$APP_NAME.zip" -d "$TMPDIR"

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "→ Removing existing installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

echo "→ Installing to $INSTALL_DIR..."
mv "$TMPDIR/$APP_NAME.app" "$INSTALL_DIR/"

echo "→ Clearing quarantine..."
xattr -cr "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

echo ""
echo "✓ $APP_NAME installed to $INSTALL_DIR/$APP_NAME.app"
echo "  Run it from Spotlight or: open -a $APP_NAME"
