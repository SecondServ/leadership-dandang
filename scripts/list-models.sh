#!/usr/bin/env bash
#
# 列出当前 Keychain 里那把 Gemini Key **实际可用、且支持 generateContent** 的模型名。
# 用于排查"某档模型 404（模型不存在）"。
#
# 安全：Key 从 Keychain 读出后只用于请求，**绝不打印**；输出只有模型名。
set -euo pipefail

KEY="$(security find-generic-password -s com.sidekick.mac -a gemini-api-key -w 2>/dev/null || true)"
if [[ -z "$KEY" ]]; then
  echo "没在 Keychain 里找到 API Key。请先在 App 的「设置」里保存。" >&2
  exit 1
fi

echo "支持 generateContent 的可用模型："
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$KEY" \
  | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    print("  （返回不是有效 JSON，可能 Key 无效或网络问题）"); sys.exit(0)
if "error" in data:
    print("  API 错误：", data["error"].get("message", "")); sys.exit(0)
models = [m for m in data.get("models", []) if "generateContent" in m.get("supportedGenerationMethods", [])]
if not models:
    print("  （没有可用模型）")
for m in models:
    print("  -", m["name"].replace("models/", ""))
'
