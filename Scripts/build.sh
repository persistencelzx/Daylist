#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-simulator}"
BUILD_DIR="${DAYLIST_BUILD_DIR:-$ROOT/.build/xcode}"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "需要完整 Xcode。安装并首次启动后，运行：sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi
case "$MODE" in
  simulator)
    xcodebuild -project "$ROOT/Daylist.xcodeproj" -scheme Daylist \
      -configuration Debug -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$BUILD_DIR/DerivedData" CODE_SIGNING_ALLOWED=NO build
    ;;
  archive)
    if [[ ! -f "$ROOT/Config/Local.xcconfig" ]]; then
      echo "请先复制 Config/Local.xcconfig.example 为 Config/Local.xcconfig，并填写 Bundle ID、App Group 与 Team ID。" >&2
      exit 1
    fi
    xcodebuild -project "$ROOT/Daylist.xcodeproj" -scheme Daylist \
      -configuration Release -destination 'generic/platform=iOS' \
      -archivePath "$BUILD_DIR/Daylist.xcarchive" -allowProvisioningUpdates archive
    ;;
  export)
    xcodebuild -exportArchive -archivePath "$BUILD_DIR/Daylist.xcarchive" \
      -exportOptionsPlist "$ROOT/Config/ExportOptions.plist" \
      -exportPath "$BUILD_DIR/Export" -allowProvisioningUpdates
    ;;
  *) echo "用法：$0 [simulator|archive|export]" >&2; exit 2 ;;
esac
