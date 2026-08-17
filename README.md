# 担当 (Ownership) · macOS

> 名字是反讽：招牌写着"扛责任"，其实是帮你把职场沟通里的隐形情绪劳动外包给 AI。
> 内部代号仍是 **Sidekick**（可执行文件、bundle id `com.sidekick.mac`、`build/Sidekick.app` 路径、签名证书名都不变——只改了对外显示名）。

一个常驻菜单栏的小工具：**在任意 App 里选中一段文字 → 划词自动弹出小工具条（或按快捷键）→ 用 Gemini 润色 → 弹出结果、一键复制。**

> 当前进度：**悬浮工具条 + 6 个功能**。工具条上一排按钮：
> 「说人话」「讨论啥」「润色」「阴阳」「关我事」「刷存在」。
> 尚未做：「帮我回复」（交互式输入面板，Batch B）、「替换原文」（模拟 ⌘V，Batch B）、
> AX 直读选区抓取、研究模式、以及各功能的"后续"微调项（见 `BUILD_SPEC.md` 第 9 节）。
>
> 「关我毛事？」需要先在菜单栏 ✦ →「个人资料…」填资料；「刷存在感」用到资料则可选。
>
> 触发方式有两种，二选一都行：
> - **划词自动弹条**（M1，默认开）：选中文字后光标旁自动冒出「润色」按钮，点它即可。
> - **全局快捷键 ⌥⌘P**（M0，始终可用）：选中文字后按快捷键。
> 若自动弹条在某些 App 里不听话，可在菜单栏 ✦ →「划词自动弹条」取消勾选关掉它，只用快捷键。

---

## 给别人用（从源码一键安装）

分发给会用终端的人：让对方 `git clone` 本仓库，然后在项目目录里跑一条命令，自动编译并装进 `/Applications`：

```bash
bash scripts/install.sh
```

它会：检查 Swift 工具链（没有会提示装 `xcode-select --install`）→ 编译签名 → 拷进 `/Applications` → 打开。之后对方各自：① 授权「辅助功能」；② 在设置里填自己的 API Key。

> 说明：本地编译出来的 App **不带隔离标记**，不会被 Gatekeeper 拦，也不需要 Apple 开发者账号。
> 若要做成"下载即用、零警告"的 `.dmg` 发给不特定的人，需要 Apple Developer ID + 公证（notarization），是另一套流程。

## 环境要求

- macOS 13 (Ventura) 或更高。
- **Swift 工具链**：本机装了 Xcode 或 Command Line Tools 均可（`swift --version` 能跑即可）。
  - 本项目用 **SwiftPM** 构建，再组装成标准 `.app`，**不需要 Xcode.app**（没装 Xcode 也能构建）。
- 一个 **Gemini 付费 API Key**。

## 构建 & 运行

```bash
# 一步到位：编译 + 组装 Sidekick.app + ad-hoc 签名
bash scripts/build-app.sh release

# 运行（首次会引导授权「辅助功能」）
open build/Sidekick.app
```

启动后**没有 Dock 图标**（菜单栏常驻）。在屏幕右上角菜单栏找到 ✦ 图标（`wand.and.stars`），点开有「设置」「退出」。

> 开发调试也可以直接 `swift run`，但那样不是 `.app` bundle、没有固定 bundle id 与签名，**辅助功能授权容易掉**。要测端到端请用上面的 `.app` 方式。

## 三步跑通

### 1. 填 API Key + 选模型
菜单栏 ✦ →「设置…」→ 粘贴你的 **Gemini 付费 API Key** →「保存到 Keychain」。

- Key **只存本机 Keychain**，不写明文、不进 UserDefaults、不上传。
- ⚠️ 请用 **付费 API Key，勿用免费 AI Studio Key**（原因见下方隐私说明）。

保存 Key 后，在同一页点「**刷新可用模型**」，从下拉里选**快档 / 强档**模型：
- 选项直接来自你这把 Key 实际可用的模型（避免用到已停用的名字，如某些账号的 `gemini-2.5-pro`）。
- 快档用于翻译/总结/改写；强档用于「关我毛事」「刷存在感」。默认都为 `gemini-2.5-flash`。
- 也可用脚本查看可用模型（只打印模型名，不打印 Key）：`bash scripts/list-models.sh`

### 2. 授权「辅助功能」
第一次按快捷键时，若还没授权，会弹窗说明并提供「打开系统设置」按钮。

路径：**系统设置 → 隐私与安全性 → 辅助功能** → 勾选 **担当**（列表里可能仍显示为 Sidekick）。

- 为什么需要：M0 用「模拟 Cmd+C 读剪贴板」的方式抓取选中文本，合成按键需要此权限。
- 授权后回到刚才的 App，重新按快捷键即可。

### 3. 用起来
在任意 App（如 Slack 桌面版）选中一段文字 → 按 **⌥⌘P** → 弹出「润色结果」卡片 → 点「复制」把结果拷走，自己粘贴回去发送。

菜单里的「润色选中文本」也能触发（但用快捷键更可靠，能保证源 App 仍是前台、选区仍在）。

## 友好提示覆盖

- **没填 Key**：弹窗引导去「设置」。
- **没选中文本 / 没抓到**：结果卡片提示先选中文字再按快捷键。
- **网络失败 / 超时（30s）/ 429 限流 / Key 无效**：结果卡片显示对应中文错误 + 「重试」。

## 固定签名证书（避免重编译后一直弹权限）

「辅助功能」授权是按 App 的**签名指纹**记的。**ad-hoc 签名每次重编译指纹都变**，于是系统设置里那行虽然还勾着，却对不上新 build，导致"明明勾了还一直弹权限"。

正解：建一张**固定的自签名代码签名证书**，用它签名后指纹稳定，重编译授权就不掉。**只需建一次：**

1. 打开「钥匙串访问 (Keychain Access)」。
2. 菜单栏 →「钥匙串访问」→「证书助理 (Certificate Assistant)」→「创建证书… (Create a Certificate…)」。
3. 填：
   - **名称 (Name)**：`Sidekick Dev`（要和签名脚本里的名字一致；用别的名就设环境变量 `SIDEKICK_SIGN_IDENTITY`）。
   - **身份类型 (Identity Type)**：自签名根证书 (Self-Signed Root)。
   - **证书类型 (Certificate Type)**：**代码签名 (Code Signing)** ← 关键，别用默认的。
4. 「创建」→ 遇到"自签名"提示继续 →「完成」。
5. 之后第一次构建时，会弹"codesign 想用钥匙串里的私钥签名"，点 **始终允许 (Always Allow)**。

建好后重新构建即可（`bash scripts/build-app.sh release` 会自动改用这张证书；找不到才回退 ad-hoc）。
换签名方式后，需要**再重置并重新授权一次**（下面命令），此后就一劳永逸：

```bash
pkill -x Sidekick
tccutil reset Accessibility com.sidekick.mac
open "build/Sidekick.app"   # 触发一次 → 勾选 担当 → 再退出重开一次
```

---

## 隐私说明（重要）

- **人在环中**：本工具**绝不自动向任何 App 发送消息**。它只做「读取你选中的文本」和「把结果放进剪贴板」，发不发、怎么发都由你自己决定。
- **不做后台采集**：只在你**按下快捷键的那一刻**读取当前选中文本；不监听、不抓取、不存档你的对话。
- **只在你触发时外发**：只有你主动触发润色时，选中文本才会发往 Google Gemini。
- **模型档位**：请使用 **Gemini 付费 API**（Google 声明付费档不用于训练）；**严禁使用免费 AI Studio 档**（免费档可能被用于产品改进/人工标注）。
- **API Key**：仅存本机 Keychain，不上传。
- **公司内容请先确认公司政策**：若在公司账号/内部内容下使用，请自行确认公司是否允许把内部通讯发往外部 AI 服务——「不被训练」**不等于**「合规允许外传」。
- **日志安全**：程序任何日志都不会打印你的 API Key 或选中文本。

---

## 目录结构（M0 已实现 vs. 占位）

```
Sources/Sidekick/
├─ App/
│  ├─ SidekickApp.swift      # @main、菜单栏、快捷键接线                [M0]
│  └─ AppState.swift         # 「润色」全链路编排                        [M0]
├─ Trigger/
│  ├─ HotKey.swift           # 全局快捷键（Carbon RegisterEventHotKey） [M0]
│  ├─ TextGrabber.swift      # 抓取选中文本（Cmd+C 回退）              [M0]
│  ├─ SelectionMonitor.swift # 悬浮工具条的选区监听                     [占位·M1]
│  └─ TextReplacer.swift     # 替换原文（Cmd+V）                        [占位·M2]
├─ UI/
│  ├─ SettingsView.swift     # 设置页（填 Key → Keychain）             [M0]
│  ├─ ResultCardPanel.swift  # 结果卡片（loading/复制/关闭/重试）      [M0]
│  ├─ PermissionPrompt.swift # 辅助功能权限引导                         [M0]
│  ├─ ActionBarPanel.swift   # 悬浮工具条                               [占位·M1]
│  ├─ ReplyComposer.swift    # 「帮我回复」输入框                        [占位·M2]
│  └─ ProfileView.swift      # 用户 Profile 编辑                        [占位·M1]
├─ AI/                        # 尽量自成一块、少依赖 AppKit，便于复用
│  ├─ GeminiClient.swift     # 调 Gemini generateContent               [M0]
│  ├─ Prompts.swift          # Prompt 模板（BUILD_SPEC §7）            [M0]
│  └─ Feature.swift          # 7 个功能枚举（M0 只 .polish）           [M0]
└─ Core/
   ├─ Keychain.swift         # API Key 存取                            [M0]
   └─ Settings.swift         # 模型/温度/超时等常量                     [M0]
```

配套规格文档：`PRD.md`（产品需求）、`BUILD_SPEC.md`（技术方案）。
