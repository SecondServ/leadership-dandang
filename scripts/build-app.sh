#!/usr/bin/env bash
#
# 用 SwiftPM 构建可执行文件，再组装成标准 .app bundle 并 ad-hoc 签名。
# （本机只有 Command Line Tools、无 Xcode.app，所以不走 xcodebuild。）
#
# 用法：scripts/build-app.sh [debug|release]（默认 release）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Leadership"
CONFIG="${1:-release}"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="$ROOT/build/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

echo "==> 组装 ${APP_NAME}.app"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_PATH/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

echo "==> 代码签名"
"$ROOT/scripts/sign-macos.sh" "$APP_DIR"

echo ""
echo "完成：$APP_DIR"
echo "运行：open \"$APP_DIR\"   （首次会请求「辅助功能」权限）"
