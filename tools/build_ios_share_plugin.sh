#!/usr/bin/env bash
# Build the ShareSheet static xcframework with the iOS SDK already on the
# runner. No Godot headers and no extra secrets. Godot export then links it.
#
# Bash 3.2 compatible (the bash that ships with macOS).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/ios/plugins/share_sheet/share_sheet.mm"
OUT="$ROOT/ios/plugins/share_sheet/share_sheet.xcframework"
WORK="${TMPDIR:-/tmp}/share-sheet-$$"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is missing. This script runs on the macOS TestFlight runner or a Mac with Xcode."
  exit 1
fi
test -f "$SRC"

rm -rf "$WORK" "$OUT"
mkdir -p "$WORK/iphoneos" "$WORK/sim"

SDK_DEVICE="$(xcrun --sdk iphoneos --show-sdk-path)"
clang++ -arch arm64 -isysroot "$SDK_DEVICE" -miphoneos-version-min=15.0 \
  -fobjc-arc -std=c++17 -c "$SRC" -o "$WORK/iphoneos/share_sheet.o"
libtool -static -o "$WORK/iphoneos/libshare_sheet.a" "$WORK/iphoneos/share_sheet.o"

SDK_SIM="$(xcrun --sdk iphonesimulator --show-sdk-path)"
clang++ -arch arm64 -isysroot "$SDK_SIM" -mios-simulator-version-min=15.0 \
  -fobjc-arc -std=c++17 -c "$SRC" -o "$WORK/sim/share_sheet_arm64.o"
SIM_OBJS=("$WORK/sim/share_sheet_arm64.o")
if clang++ -arch x86_64 -isysroot "$SDK_SIM" -mios-simulator-version-min=15.0 \
  -fobjc-arc -std=c++17 -c "$SRC" -o "$WORK/sim/share_sheet_x64.o"; then
  SIM_OBJS+=("$WORK/sim/share_sheet_x64.o")
fi
libtool -static -o "$WORK/sim/libshare_sheet.a" "${SIM_OBJS[@]}"

xcodebuild -create-xcframework \
  -library "$WORK/iphoneos/libshare_sheet.a" \
  -library "$WORK/sim/libshare_sheet.a" \
  -output "$OUT"
rm -rf "$WORK"
test -d "$OUT"
echo "Built $OUT"
