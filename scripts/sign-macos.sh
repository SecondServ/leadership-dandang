#!/usr/bin/env bash
#
# 代码签名（BUILD_SPEC §2）。
#
# 首选：用一张**固定的自签名代码签名证书**（默认名 "Sidekick Dev"）。它的签名指纹稳定，
# 重编译后「辅助功能」授权不会掉 —— 这是解决"勾了还一直弹权限"的正解。
# 回退：找不到该证书时用 ad-hoc（`codesign -s -`）—— 能跑，但每次重编译授权会掉。
#
# 建证书方法见 README「固定签名证书」。证书名可用环境变量覆盖：
#   SIDEKICK_SIGN_IDENTITY="你的证书名" bash scripts/sign-macos.sh
#
# 用法：scripts/sign-macos.sh [App 路径]（默认 build/Sidekick.app）
set -euo pipefail

APP_PATH="${1:-build/Sidekick.app}"
BUNDLE_ID="com.sidekick.mac"                       # 固定 bundle id，须与 Info.plist 一致
SIGN_IDENTITY="${SIDEKICK_SIGN_IDENTITY:-Sidekick Dev}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "错误：找不到 App：$APP_PATH" >&2
  exit 1
fi

# 先试固定证书；失败（证书不存在/被拒）再回退 ad-hoc。
if codesign --force --deep --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_PATH" 2>/dev/null; then
  echo "已用固定证书签名（$SIGN_IDENTITY）：$APP_PATH"
  echo "  → 重编译后辅助功能授权应保持不掉。"
else
  codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_PATH"
  echo "⚠️  未找到代码签名证书「$SIGN_IDENTITY」，已回退 ad-hoc 签名：$APP_PATH"
  echo "   重编译后辅助功能授权可能会掉。建证书方法见 README「固定签名证书」。"
fi

codesign -dv "$APP_PATH" 2>&1 | sed -n '1,6p' || true
