#!/usr/bin/env bash
# Regenerates the launcher icons from a single source image.
#
# Usage:  tool/make_icons.sh [path-to-logo.png]
#
# Drop the logo at assets/branding/app_icon.png (or pass a path) and run this.
# It derives the padded adaptive-icon foreground, then hands both to
# flutter_launcher_icons, which writes the Android mipmaps and the iOS asset
# catalogue.
set -euo pipefail

cd "$(dirname "$0")/.."
SRC="${1:-assets/branding/app_icon.png}"
OUT_DIR="assets/branding"
ICON="$OUT_DIR/app_icon.png"
FOREGROUND="$OUT_DIR/app_icon_foreground.png"

if [ ! -f "$SRC" ]; then
  echo "No source image at $SRC" >&2
  echo "Save the logo there (a square PNG, 1024x1024 or larger) and re-run." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
[ "$SRC" != "$ICON" ] && cp "$SRC" "$ICON"

# Square it off at 1024 so every generated size scales cleanly.
sips -s format png -z 1024 1024 "$ICON" --out "$ICON" >/dev/null

# Android masks adaptive icons to the launcher's shape and crops roughly a
# quarter off each edge, so the logo is inset on a larger canvas. Scaling it to
# fill would shave the wallet's edges off on round-icon launchers.
sips -z 660 660 "$ICON" --out "$FOREGROUND" >/dev/null
sips -p 1024 1024 --padColor FFFFFF "$FOREGROUND" --out "$FOREGROUND" >/dev/null

echo "Source:     $ICON"
echo "Foreground: $FOREGROUND"

dart run flutter_launcher_icons
