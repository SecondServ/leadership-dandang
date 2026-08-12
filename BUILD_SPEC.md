# BUILD SPEC（可执行构建文档）—— Sidekick (macOS 原生)

> 交付对象：Claude Code。目标：从零搭一个**原生 macOS** 菜单栏 App，实现 PRD 的 7 个划词功能。
> **本期只做 macOS（Swift 原生）。Windows 之后单独用 C#/.NET 原生实现——两端只共享《PRD.md》与本文件第 7 节 Prompt 规格，不共享代码。**
> 配套文档：《PRD.md》。

---

## 0. 关键决策（已敲定，勿再发散）

- **平台**：本期仅 macOS，个人自用，不分发。
- **技术栈**：**原生 Swift**（SwiftUI + AppKit）。
- **Windows**：之后单独的原生 App（C#/.NET，WinUI/WPF），复用规格不复用代码（见第 12 节）。
- **形态**：菜单栏常驻（`LSUIElement = true`，无 Dock 图标）。
- **触发**：PopClip 式**悬浮工具条**（划词自动弹出）+ 全局快捷键兜底。
- **模型**：Google **Gemini 付费 API**。API Key 存 Keychain。
- **签名**：自用不做 notarization / Developer ID；但需 **ad-hoc 签名**（`codesign -s -` + 固定 bundle id），否则重编译后"辅助功能"授权会掉。
- **文本抓取**：优先 Accessibility 读选区，失败回退"模拟 Cmd+C 读剪贴板 + 还原"。
- **人在环中**：所有功能只产出草稿，绝不自动发送。

---

## 1. 技术栈

- 语言：**Swift 5.9+**。UI 用 **SwiftUI + AppKit** 混合：菜单栏与设置用 SwiftUI；悬浮工具条 / 结果卡片用 AppKit `NSPanel`（需要非激活浮窗行为，SwiftUI 窗口做不到）。
- 构建：Xcode，macOS App target，最低 **macOS 13 Ventura**（用到较新 API 可提升）。
- 网络：`URLSession`（async/await）。
- 存储：API Key → **Keychain**；Profile / 设置 → `UserDefaults` 或 App Support 下 JSON。
- 全局事件：`CGEventTap` / `NSEvent.addGlobalMonitorForEvents`（鼠标抬起、快捷键）。
- 无第三方依赖为佳；全局快捷键可自封装 Carbon `RegisterEventHotKey`，或用轻量库 `KeyboardShortcuts`。

---

## 2. 系统权限

App 需以下权限，首启动引导用户在「系统设置 → 隐私与安全性」授予：

1. **辅助功能（Accessibility）**：读选区（AXUIElement）+ 模拟按键（Cmd+C / Cmd+V）。用 `AXIsProcessTrustedWithOptions` 检测并弹引导。
2. **输入监控（Input Monitoring）**：全局监听鼠标抬起 / 全局快捷键。

- `Info.plist` 按需加用途说明字符串。
- 首启动做「权限检查页」：逐项状态 + "去授权"按钮（`x-apple.systempreferences:` deep link 跳转）。
- **ad-hoc 签名**：完全未签名的 App 重编译后常从辅助功能列表掉出。构建脚本里对产物做 `codesign -s -`，并固定 `PRODUCT_BUNDLE_IDENTIFIER`，让授权保留。

---

## 3. 架构与目录

```
Sidekick/
├─ App/
│  ├─ SidekickApp.swift            # @main, LSUIElement, 菜单栏入口
│  └─ AppState.swift               # 全局状态、设置、Profile
├─ Trigger/
│  ├─ SelectionMonitor.swift       # 全局鼠标/选区监听，决定是否弹工具条
│  ├─ TextGrabber.swift            # 抓取选中文本（AX 优先，Cmd+C 回退）
│  ├─ TextReplacer.swift           # 结果写回（剪贴板 + 模拟 Cmd+V）
│  └─ HotKey.swift                 # 全局快捷键兜底
├─ UI/
│  ├─ ActionBarPanel.swift         # 悬浮工具条（NSPanel, 非激活）
│  ├─ ResultCardPanel.swift        # 结果卡片（复制/替换/重写/关闭）
│  ├─ ReplyComposer.swift          # "帮我回复" 输入框 + 立场预设
│  ├─ SettingsView.swift           # 设置（SwiftUI）
│  └─ ProfileView.swift            # 用户 Profile 编辑
├─ AI/
│  ├─ GeminiClient.swift           # 调 Gemini（快/强双档、研究模式）
│  ├─ Feature.swift                # 7 个功能枚举与元数据
│  └─ Prompts.swift                # 各功能 Prompt 模板（见第 7 节）
├─ Core/
│  ├─ Keychain.swift               # API Key 存取
│  └─ Settings.swift               # 目标语言、语言策略、开关、排序、模型档
└─ Resources/
   └─ Info.plist
```

> 小建议（不强制）：把 `AI/`（GeminiClient 契约、Prompts、Feature 定义）与产品逻辑写得尽量自成一块、少依赖 AppKit。Windows 原生版虽不复用代码，但对着这块照抄逻辑会省事。

### 数据流（单次动作）
```
选区 →(SelectionMonitor 触发)→ ActionBarPanel 显示
  → 用户点功能 → TextGrabber 抓文本
    → (功能4) ReplyComposer 收集主旨+立场
  → Prompts 组装 → GeminiClient 调用
  → ResultCardPanel 展示 → 用户复制 / TextReplacer 替换
```

---

## 4. 悬浮工具条（ActionBarPanel）

- 用 `NSPanel`：style `.nonactivatingPanel` + `.borderless`；`level = .floating`；`isFloatingPanel = true`；`hidesOnDeactivate = false`。
- **关键：不能抢焦点**（否则原 App 丢选区）。`becomesKeyOnlyIfNeeded = true`，工具条本身不成为 key window。
- 定位：显示在鼠标位置或选区附近（选区 bounds 可试 AX `kAXBoundsForRangeParameterizedAttribute`，取不到用鼠标坐标）。
- 内容：7 个功能按钮（图标 + 短标签），顺序/开关由 Settings 决定。
- 消失：点空白、Esc、或触发动作后隐藏（复用面板，别每次新建）。

### SelectionMonitor 触发策略
- 全局 `mouseUp`（左键）+ 防抖判断"可能发生了选择"。
- mouseUp 后，用 AX 读 focused element 的 `kAXSelectedTextAttribute`：
  - 非空 → 显示工具条。
  - 读不到（Electron 等）→ **不**在 mouseUp 阶段强行 Cmd+C（会破坏剪贴板）；仍显示工具条，真正抓取推迟到用户点动作时用 Cmd+C 回退。
- 设置项：可关"自动弹出"，仅用全局快捷键触发（对选区检测差的 App 更稳）。

---

## 5. 文本抓取与写回

### TextGrabber（点动作时）
```
func grabSelectedText() -> String? {
  1. 试 AX: focusedElement.kAXSelectedTextAttribute → 非空则返回
  2. 回退: 备份 NSPasteboard
           模拟 Cmd+C (CGEvent)
           等 ~80-120ms
           读 NSPasteboard.string
           还原原剪贴板
           返回
}
```
- Cmd+C 回退需"原 App 仍前台且选区仍在" → 工具条务必非激活。

### TextReplacer（润色/替换原文）
```
func replace(with text) { 写 NSPasteboard → 模拟 Cmd+V → (可选)还原剪贴板 }
```
- 只读功能（1/2/6）不提供替换，仅"复制"。

---

## 6. GeminiClient

- Endpoint：`POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={API_KEY}`
- 请求体：`{"systemInstruction":{"parts":[{"text":<system>}]}, "contents":[{"role":"user","parts":[{"text":<prompt>}]}], "generationConfig":{"temperature":..,"maxOutputTokens":..}}`
- **双档模型**（可配置，默认值供参考，以当前可用最新版为准）：
  - 快档（功能 1/2/3/4/5）：`gemini-2.5-flash`
  - 强档（功能 6/7 或开研究模式）：`gemini-2.5-pro`
- **研究模式**（7 可选、6 可选）：请求加 `"tools":[{"google_search":{}}]`；默认关闭。
- 温度：翻译/总结/分析（1/2/6）0.2；改写/生成（3/4/5/7）0.5~0.7。
- 错误：Key 缺失/无效 → 引导设置；429/网络 → 结果卡片"重试"；超时 30s。
- API Key 从 Keychain 读；日志中**绝不**打印 Key 或用户文本。

---

## 7. Prompt 模板（Prompts.swift）—— Windows 版也照此实现

> 占位符：`{{TARGET_LANG}}`（默认"中文"）、`{{TEXT}}`、`{{USER_INTENT}}`（功能4）、`{{STANCE}}`（功能4）、`{{PROFILE}}`、`{{LANG_POLICY}}`。
> 通用 system 前缀（共用）：
> `你是一个帮助用户应对职场沟通的助手。只输出用户需要的结果本身，不要加前言、解释或"以下是"之类的话。结果必须可以直接复制使用。`

### 7.1 让 ta 说人话
```
system: <通用前缀>
user:
把下面这段职场对话/消息翻译成{{TARGET_LANG}}，要求：
- 用大白话、口语化，像同事私下跟我解释一样
- 尽量简洁，但不能漏掉任何关键信息（时间、数字、要求、结论都要保留）
- 去掉客套、废话和行话
只输出翻译后的内容。

原文：
{{TEXT}}
```

### 7.2 ta 们在讨论啥？
```
system: <通用前缀>
user:
下面是一段可能有多个人参与的对话。请用{{TARGET_LANG}}总结：
1. 逐个发言人，列出「谁 → 表达了什么（观点/诉求/情绪）」
2. 如果有已达成的结论或还没定的问题，最后用一行标注「结论/待决」
保持忠实，不要替他们下判断。

对话：
{{TEXT}}
```

### 7.3 润色
```
system: <通用前缀>
user:
润色下面这段我要发出去的职场消息。要求：
- 保持和原文相同的语言（原文是什么语言就用什么语言输出）
- 更清晰、更专业、语气自然得体
- 不改变原意，不夸大，不添加我没说过的信息
只输出润色后的版本。

原文：
{{TEXT}}
```

### 7.4 帮我回复
```
system: <通用前缀>
user:
我需要回复下面这段对话。请帮我写一条 professional、formal 的回复。
- 我的回复主旨：{{USER_INTENT}}   （若为空：请根据立场自行拟定合理主旨）
- 我的立场：{{STANCE}}
  # 立场释义：
  # 同意=明确接受/配合；婉拒=礼貌拒绝并给台阶；应付=表面回应、不做实质承诺、留有余地；
  # 共情=先照顾对方情绪再表达；甩锅=得体地澄清这不在我职责范围/把责任归位，但不攻击他人
- 语言：{{LANG_POLICY}}
写得得体、可直接发送。只输出回复正文。

对话：
{{TEXT}}
```

### 7.5 帮我阴阳 ta
```
system: <通用前缀 + 附加：输出必须表面礼貌、职场可发送、不使用脏话或人身攻击，讽刺要"可辩解的得体"。>
user:
针对下面这段内容，帮我写一条表面礼貌、但暗含讽刺/绵里藏针的回应。
- 要在职场里"能发得出去"，让人挑不出明显毛病
- 克制、绵里藏针，不要脏话、不要人身攻击
- 保持与原文相同语言
只输出回应正文。

原文：
{{TEXT}}
```

### 7.6 关我毛事？
```
system: <通用前缀>
user:
这是我在工作中看到的一段内容。我的个人资料如下：
{{PROFILE}}

请用{{TARGET_LANG}}帮我判断，输出以下结构：
1) 相关性：高 / 中 / 低 / 无关（一句话说明为什么）
2) 关键事项：提到的任务、计划、事件（有就列，没有就写"无"）
3) 对我的影响：直接或间接可能影响到我的地方
4) 建议动作：如果需要我做点什么，列出来；不需要就写"暂无需行动"
基于内容和我的资料判断，结论仅供参考。

内容：
{{TEXT}}
```

### 7.7 刷存在感
```
system: <通用前缀>
user:
下面是一段团队讨论。我的个人资料如下：
{{PROFILE}}

帮我组织一段有价值、专业的发言，让我能有质量地参与进去。要求：
- 贴合上下文，给出真正有信息量的见解 / 方案 / 想法（不要空喊口号或客套）
- 结构：1 段核心观点 + 2~3 条具体要点或建议
- 语气专业、自信但不咄咄逼人，符合我的角色
- 保持与讨论相同语言
只输出可发送的发言内容。

讨论：
{{TEXT}}
```
> 研究模式开启时，system 追加："你可以使用搜索工具补充事实与数据，确保观点准确、有依据。"并启用 google_search 工具。

---

## 8. 结果卡片行为矩阵（ResultCardPanel）

| 功能 | 复制 | 替换原文 | 重写 | 额外 |
|------|:---:|:---:|:---:|------|
| 1 让ta说人话 | ✅ | — | ✅ | — |
| 2 讨论啥 | ✅ | — | ✅ | — |
| 3 润色 | ✅ | ✅ | ✅ | 语气档（后续） |
| 4 帮我回复 | ✅ | ✅ | ✅ | 结果可编辑 |
| 5 阴阳 | ✅ | — | ✅ | "风险自负"提示；再阴/收敛（后续） |
| 6 关我毛事 | ✅ | — | ✅ | — |
| 7 刷存在感 | ✅ | ✅ | ✅ | 更短/更详细、研究模式开关 |

- 结果卡片同样用非激活/浮动面板；生成中显示 loading；失败显示错误 + 重试。

---

## 9. 里程碑（每步可独立验证）

**M0 — 打通链路（最小可行）**
- 菜单栏 App 骨架 + 设置页（填 API Key → Keychain）。
- 全局快捷键 → TextGrabber（先只 Cmd+C 回退）→ GeminiClient → ResultCardPanel。
- 只接「润色」一个功能端到端。
- ✅ 验收：Slack 桌面选中文字，按快捷键，弹出润色结果并可复制。

**M1 — 悬浮工具条 + 只读类功能**
- SelectionMonitor + ActionBarPanel（AX 检测 + 鼠标监听 + **NSPanel 非激活行为，本期最大技术风险，优先攻克**）。
- 功能 1、2、6（6 先做 Profile 页）。
- ✅ 验收：划词自动弹条且不丢选区；三个只读功能结构正确。

**M2 — 交互与生成类功能**
- ReplyComposer（功能 4：输入框 + 5 立场预设）。功能 5、7（含研究模式开关）。TextReplacer 接 3/4/7。
- ✅ 验收：7 个功能全部可用。

**M3 — 打磨**
- Profile 完整化、功能开关/排序、语言策略、双档模型、权限引导页、错误/限流、ad-hoc 签名脚本、README（含隐私说明）。
- ✅ 验收：冷启动顺畅；敏感功能默认克制稳定。

---

## 10. 验证清单（交付前自测）

- [ ] 划词到工具条弹出 < 300ms；工具条**不抢焦点、不丢选区**。
- [ ] Slack 桌面 / 飞书 / Chrome 网页 三类 App 抓取成功。
- [ ] Cmd+C 回退后能正确还原用户原剪贴板。
- [ ] 7 功能 prompt 输出符合规格（1 不加建议、3 保持语言、5 不越界、6 结构完整）。
- [ ] API Key 存 Keychain；日志不泄露 Key 与用户文本。
- [ ] 未配置 Key / 网络失败 / 429 均有友好提示与重试。
- [ ] 重编译后辅助功能授权仍在（ad-hoc 签名生效）。

---

## 11. 给 Claude Code 的注意事项

- **先攻克 NSPanel 非激活浮窗**（M1）：这是 mac 上做划词工具最容易翻车的点——要"既置顶又不抢焦点、不丢原 App 选区"。建议先用它做验证，别等功能堆完才发现工具条抢焦点。
- 严守"人在环中"：任何功能都不得直接发消息，只做剪贴板/粘贴。
- 不做后台采集；只在用户点动作时读取选中文本。
- 默认付费 Gemini；README 与设置页明确提示"勿用免费 AI Studio Key""公司内容请先确认公司政策"。
- 先交付可运行的 M0，再逐里程碑推进，每个里程碑给出手动验证步骤。

---

## 12. Windows 原生版复用什么（之后一期，先备忘）

Windows 版将是**独立的 C#/.NET 原生 App**（WinUI 3 或 WPF），**不复用 Swift 代码**，但复用下列"规格"，照着重写一遍：

- **完全复用**：本文件第 7 节全部 Prompt 模板、第 6 节 Gemini API 契约（endpoint / 请求体 / 双档模型 / 研究模式）、第 8 节结果卡片行为矩阵、《PRD.md》全部产品规格。
- **对应重写（Windows 等价物）**：
  - 选区读取：macOS AX → **UI Automation**（`TextPattern`）。
  - 抓取/写回回退：Cmd+C/V → **Ctrl+C/V**（`SendInput`）。
  - 全局快捷键 / 鼠标钩子：CGEventTap → **低级键盘/鼠标钩子**（`SetWindowsHookEx`）。
  - 非激活浮窗：NSPanel → 置顶 + `WS_EX_NOACTIVATE` 的无边框窗口。
  - 凭据存储：Keychain → **Windows Credential Manager**（DPAPI）。
  - 权限：mac 的辅助功能/输入监控 → Windows 一般无需系统授权（留意杀软/UAC 对全局钩子的拦截）。
- 建议：mac 版把 `AI/`（Prompts / GeminiClient 契约 / Feature 定义）写得干净内聚，Windows 版照抄逻辑最省事。
