#!/bin/bash
# assets/AppIcon.svg → AppIcon.icns (macOS 앱 아이콘)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/assets/AppIcon.svg"
ICONSET="$ROOT/assets/AppIcon.iconset"
mkdir -p "$ICONSET"

render() { cairosvg "$SVG" -o "$2" --output-width "$1" --output-height "$1"; }

render 16   "$ICONSET/icon_16x16.png"
render 32   "$ICONSET/icon_16x16@2x.png"
render 32   "$ICONSET/icon_32x32.png"
render 64   "$ICONSET/icon_32x32@2x.png"
render 128  "$ICONSET/icon_128x128.png"
render 256  "$ICONSET/icon_128x128@2x.png"
render 256  "$ICONSET/icon_256x256.png"
render 512  "$ICONSET/icon_256x256@2x.png"
render 512  "$ICONSET/icon_512x512.png"
render 1024 "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ROOT/assets/AppIcon.icns"
echo "✅ $ROOT/assets/AppIcon.icns"
