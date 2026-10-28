#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-}"
BUILD_DIR="${DAYLIST_BUILD_DIR:-$ROOT/.build/device}"
if [[ -z "$DEVICE" ]]; then
  echo "用法：$0 <iPhone 设备标识>"
  echo "连接并解锁手机后，用 xcrun devicectl list devices 查看标识。"
  exit 2
fi
if [[ ! -f "$ROOT/Config/Local.xcconfig" ]]; then
  echo "请先配置 Config/Local.xcconfig 中的 Bundle ID、App Group 和开发团队。" >&2
  exit 1
fi
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
# A device build needs the iOS SDK, but PNG icon packaging does not need an
# iOS simulator runtime. Keep the normal asset catalog in the original project.
BUILD_DIR="$(mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR" && pwd)"
python3 "$ROOT/Scripts/prepare-device-project.py" "$BUILD_DIR/source"
xcodebuild -project "$BUILD_DIR/source/Daylist.xcodeproj" -target Daylist \
  -configuration Debug -sdk iphoneos -arch arm64 \
  SYMROOT="$BUILD_DIR/products" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
APP="$BUILD_DIR/products/Debug-iphoneos/Daylist.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID"
echo "每日清单已安装并启动。"
