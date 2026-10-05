#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/assets/icon-zlive.png"
OUT="$ROOT/ios/ZLiveRemote/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$OUT"

make_icon() {
  local px="$1"
  local name="$2"
  sips -z "$px" "$px" "$SRC" --out "$OUT/$name" >/dev/null
}

make_icon 40  "AppIcon-20@2x.png"
make_icon 60  "AppIcon-20@3x.png"
make_icon 58  "AppIcon-29@2x.png"
make_icon 87  "AppIcon-29@3x.png"
make_icon 80  "AppIcon-40@2x.png"
make_icon 120 "AppIcon-40@3x.png"
make_icon 120 "AppIcon-60@2x.png"
make_icon 180 "AppIcon-60@3x.png"

make_icon 20  "AppIcon-20@1x-ipad.png"
make_icon 40  "AppIcon-20@2x-ipad.png"
make_icon 29  "AppIcon-29@1x-ipad.png"
make_icon 58  "AppIcon-29@2x-ipad.png"
make_icon 40  "AppIcon-40@1x-ipad.png"
make_icon 80  "AppIcon-40@2x-ipad.png"
make_icon 76  "AppIcon-76@1x-ipad.png"
make_icon 152 "AppIcon-76@2x-ipad.png"
make_icon 167 "AppIcon-83.5@2x-ipad.png"
make_icon 1024 "AppIcon-1024.png"

echo "Generated Z Live Remote iOS/iPadOS app icons."
