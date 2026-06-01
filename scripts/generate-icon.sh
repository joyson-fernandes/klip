#!/bin/bash
set -e
cd /Users/joyson/klip
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"

SVG=$(mktemp).svg
cat > "$SVG" << 'SVG_END'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#6366f1"/>
      <stop offset="50%" stop-color="#4f46e5"/>
      <stop offset="100%" stop-color="#312e81"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="1024" height="1024" rx="230" ry="230" fill="url(#bg)"/>
  <g stroke="white" stroke-width="48" stroke-linecap="round" fill="none">
    <path d="M 224 224 L 224 360 M 224 224 L 360 224"/>
    <path d="M 800 224 L 800 360 M 800 224 L 664 224"/>
    <path d="M 224 800 L 224 664 M 224 800 L 360 800"/>
    <path d="M 800 800 L 800 664 M 800 800 L 664 800"/>
  </g>
  <circle cx="512" cy="512" r="120" fill="white"/>
  <circle cx="512" cy="512" r="48" fill="#4f46e5"/>
</svg>
SVG_END

for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w $size -h $size "$SVG" -o "$ICONSET/icon_${size}x${size}.png"
done
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns -o Resources/AppIcon.icns "$ICONSET"
rm -f "$SVG"
echo "Wrote Resources/AppIcon.icns"
