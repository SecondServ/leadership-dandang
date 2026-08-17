#!/usr/bin/env bash
#
# 一键安装：编译 → 装进 /Applications → 打开。给"会用终端"的人。
# 用法：git clone 本仓库后，在项目目录里跑：
#   bash scripts/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> 1/4 检查 Swift 工具链"
if ! command -v swift >/dev/null 2>&1; then
  echo "" >&2
  echo "没找到 Swift 工具链。请先安装命令行工具：" >&2
  echo "    xcode-select --install" >&2
  echo "装完（会弹窗，点安装，等几分钟）再重跑本脚本。" >&2
  exit 1
fi

echo "==> 2/4 编译 + 组装 + 签名"
bash scripts/build-app.sh release

APP="$ROOT/build/Leadership.app"
DEST="/Applications/Leadership.app"
echo "==> 3/4 安装到 /Applications"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "==> 4/4 启动"
open "$DEST"

cat <<'EOF'

✅ 装好了。App 在菜单栏右上角（✦ 魔法棒图标，叫「担当」，没有 Dock 图标）。

还差两步（每台机各自做一次）：
  1) 首次触发（划词或按 ⌥⌘P）会弹「辅助功能」授权 →
     系统设置 → 隐私与安全性 → 辅助功能 → 勾选「担当」→ 回来再触发一次。
  2) 菜单栏 ✦ →「设置…」→ 选模型厂商、填你自己的 API Key。

想让重编译后授权不掉：见 README「固定签名证书」建一次证书（可选）。
EOF
