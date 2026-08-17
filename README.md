# 担当 · Leadership — macOS

名字是反讽：招牌写着"扛责任"，其实是帮你把职场里的隐形情绪劳动，悄悄外包给 AI。  
*An ironic name: the sign says "take responsibility," but really it quietly outsources your invisible workplace emotional labor to AI.*

中文名 **担当**（App 显示名）；英文 / 内部代号 **Leadership**（可执行文件、`build/Leadership.app`、bundle id `com.leadership.dandang`、签名证书 `Leadership Dev`）。  
*Chinese name **担当** (the app's display name); English / internal codename **Leadership** (the binary, `build/Leadership.app`, bundle id `com.leadership.dandang`, signing cert `Leadership Dev`).*

---

## 你是否遇到过这些痛点？ · Sound familiar?

同事张口就是"对齐颗粒度、拉通抓手、赋能闭环、打法组合拳"，你全程点头，一个字没听懂。  
*A coworker fires off "let's align granularity and synergize the closed-loop," you nod along and understand exactly none of it.*

一条三百字的消息轰炸过来，看完三遍还是不知道到底要你干啥。  
*A 300-word message lands; you read it three times and still can't tell what they actually want from you.*

群里突然 @ 你，可那件事跟你八竿子打不着。  
*You suddenly get @'d in a thread about something that has nothing to do with you.*

有人阴阳怪气地"提醒"你，笑里藏刀，你血压飙升还得客客气气地回。  
*Someone "reminds" you with a passive-aggressive smile; your blood pressure spikes but you still have to reply politely.*

深夜十一点工作群还在响，不吭声显得你不积极，想回又不知道回啥。  
*The work group is still pinging at 11pm — stay silent and you look checked-out, but you've got nothing to say.*

明明想一口回绝，又怕显得没情商、得罪人。  
*You want to flat-out say no, but you're afraid of looking tactless and burning a bridge.*

## 现在有了「担当」 · Enter 担当

别慌。这些隐形的情绪劳动，划一下词就能交给「担当」。  
*Relax. All that invisible emotional labor is now one text-selection away from being handled.*

在任意 App 里**选中一段文字 → 光标旁自动弹出小工具条（或按 ⌥⌘P）→ AI 出结果 → 一键复制**，发不发、怎么发，永远你说了算。  
*In any app: **select some text → a little toolbar pops up next to your cursor (or press ⌥⌘P) → the AI does its thing → one-click copy.** Whether and how you send it is always your call.*

---

## 核心功能 · What it does

### 让ta说人话 · Speak English

把满嘴黑话缩写翻译成人话，并点破这句话真正的潜台词、附上缩写解释。  
*Translates corporate jargon and acronyms into plain language, spells out the real subtext, and explains the abbreviations.*

👉 专治"对齐颗粒度、赋能闭环"型同事。  
*👉 Cures the "let's synergize the granularity" coworker.*

### 叽里咕噜说啥呢 · TL;DR

把一大段啰嗦的消息浓缩成一句话重点。  
*Condenses a rambling wall of text into the one line that matters.*

👉 专治三百字看完还不知道要干啥。  
*👉 For the 300-word message that never gets to the point.*

### 关我毛事 · Not My Circus

判断这事到底关不关你、该不该接，帮你划清边界（会用到你填的个人资料）。  
*Tells you whether this actually concerns you and whether to engage, so you can draw the line (uses the profile you fill in).*

👉 专治莫名其妙被 @ 进不相干的事。  
*👉 For getting dragged into things that aren't yours.*

### 体面一点 · Make It Nice

把你的草稿改得体面得当，五种语气随选：正式 / 幽默 / 口语化 / 委婉 / 有条理。  
*Rewrites your draft so it lands well — pick from five tones: formal / witty / casual / tactful / structured.*

👉 专治想拒绝、想吐槽，又不能撕破脸。  
*👉 For when you want to decline or push back without burning the bridge.*

### 打发丫 · Brush 'Em Off

按你选的立场，替你起草一条回复：同意 / 婉拒 / 捧杀 / 质疑 / 共情 / 甩锅 / 阴阳。  
*Drafts a reply in whatever stance you choose: agree / decline / flatter / question / empathize / deflect / passive-aggressive.*

👉 专治不想认真回、但又必须回点什么。  
*👉 For when you don't want to really reply but have to say something.*

### 刷存在感 · Look Busy

生成一条显得你在线、在思考、在贡献的发言。  
*Generates a message that makes you look present, thoughtful, and contributing.*

👉 专治深夜工作群里"必须冒个泡"的时刻。  
*👉 For the "better make an appearance" moment in the late-night work chat.*

---

触发方式二选一：**划词自动弹条**（默认开，选中文字后光标旁自动冒出按钮）或**全局快捷键 ⌥⌘P**（始终可用）。  
*Two ways to trigger: **auto-popup toolbar** (on by default — appears by your cursor when you select text) or the **global hotkey ⌥⌘P** (always available).*

若自动弹条在某些 App 里不听话，可在菜单栏 ✦ →「划词自动弹条」关掉它，只用快捷键。  
*If the auto-popup misbehaves in some apps, turn it off via the menu-bar ✦ → "划词自动弹条" and just use the hotkey.*

---

## 给别人用（从源码一键安装） · One-command install from source

分发给会用终端的人：让对方 `git clone` 本仓库，在项目目录里跑一条命令，自动编译并装进 `/Applications`。  
*For anyone comfortable with a terminal: have them `git clone` this repo, run one command in the project folder, and it compiles and installs into `/Applications`.*

```bash
bash scripts/install.sh
```

它会：检查 Swift 工具链（没有会提示装 `xcode-select --install`）→ 编译签名 → 拷进 `/Applications` → 打开。  
*It will: check the Swift toolchain (prompts `xcode-select --install` if missing) → compile and sign → copy into `/Applications` → launch.*

之后对方各自：① 授权「辅助功能」；② 在设置里填自己的 API Key。  
*Then each person: ① grants Accessibility; ② enters their own API Key in Settings.*

本地编译出来的 App **不带隔离标记**，不会被 Gatekeeper 拦，也不需要 Apple 开发者账号。  
*A locally built app carries **no quarantine flag**, so Gatekeeper won't block it and no Apple Developer account is needed.*

若要做成"下载即用、零警告"的 `.dmg` 发给不特定的人，需要 Apple Developer ID + 公证（notarization），是另一套流程。  
*To ship a "download-and-run, zero-warning" `.dmg` to the general public, you'd need an Apple Developer ID + notarization — a separate process.*

## 环境要求 · Requirements

- macOS 13 (Ventura) 或更高。  
  *macOS 13 (Ventura) or later.*
- **Swift 工具链**：装了 Xcode 或 Command Line Tools 均可（`swift --version` 能跑即可）。本项目用 **SwiftPM** 构建再组装成 `.app`，**不需要 Xcode.app**。  
  ***Swift toolchain***: *either Xcode or the Command Line Tools works (`swift --version` must run). The project builds with **SwiftPM** and assembles a `.app` — **no Xcode.app required**.*
- 一把**主流大模型的 API Key**：支持 **Gemini / OpenAI / Claude**，推荐 **Gemini 付费 API Key**。  
  *One **API Key from a major model provider**: **Gemini / OpenAI / Claude** are supported; a **paid Gemini API Key** is recommended.*

## 构建 & 运行 · Build & run

```bash
# 一步到位：编译 + 组装 Leadership.app + 签名
# All in one: compile + assemble Leadership.app + sign
bash scripts/build-app.sh release

# 运行（首次会引导授权「辅助功能」）
# Run (first launch guides you through the Accessibility grant)
open build/Leadership.app
```

启动后**没有 Dock 图标**（菜单栏常驻）。在右上角菜单栏找到 ✦ 图标（`wand.and.stars`），点开有「设置」「退出」。  
*There's **no Dock icon** (it lives in the menu bar). Find the ✦ icon (`wand.and.stars`) top-right; it opens "设置" and "退出".*

开发调试也可 `swift run`，但那不是 `.app`、没有固定 bundle id 与签名，**辅助功能授权容易掉**。端到端测试请用上面的 `.app` 方式。  
*For dev you can `swift run`, but that isn't a `.app` — no fixed bundle id or signature, so **the Accessibility grant tends to drop**. Use the `.app` path above for end-to-end testing.*

## 三步跑通 · Three steps to first run

### 1. 填 API Key + 选模型 · Enter an API Key + pick a model

菜单栏 ✦ →「设置…」→ 选服务商（Gemini / OpenAI / Claude）→ 粘贴 API Key →「保存到 Keychain」。  
*Menu-bar ✦ → "设置…" → choose a provider (Gemini / OpenAI / Claude) → paste the API Key → "保存到 Keychain".*

- Key **只存本机 Keychain**，不写明文、不进 UserDefaults、不上传。  
  *The Key is **stored only in the local Keychain** — never in plaintext, never in UserDefaults, never uploaded.*
- ⚠️ Gemini 请用 **付费 API Key，勿用免费 AI Studio Key**（原因见隐私说明）。  
  *⚠️ For Gemini, use a **paid API Key, not a free AI Studio key** (see the privacy note for why).*

保存后点「**刷新可用模型**」，从下拉里选**快档 / 强档**模型。  
*After saving, click "**刷新可用模型**" and pick your **fast / strong** models from the dropdown.*

- 选项直接来自你这把 Key 实际可用的模型，避免用到已停用的名字。  
  *The options come straight from what your Key can actually access, so you won't hit a discontinued model name.*
- 也可用脚本查看（只打印模型名，不打印 Key）：`bash scripts/list-models.sh`  
  *Or use the script (prints model names only, never the Key): `bash scripts/list-models.sh`*

### 2. 授权「辅助功能」 · Grant Accessibility

第一次触发时若还没授权，会弹窗说明并提供「打开系统设置」。  
*The first time you trigger it without permission, a dialog explains and offers "Open System Settings."*

路径：**系统设置 → 隐私与安全性 → 辅助功能** → 勾选 **担当**。  
*Path: **System Settings → Privacy & Security → Accessibility** → check **担当**.*

为什么需要：用「模拟 Cmd+C 读剪贴板」抓取选中文本，合成按键需要此权限。  
*Why: it grabs your selection by synthesizing Cmd+C to read the clipboard, and synthetic keystrokes need this permission.*

### 3. 用起来 · Use it

在任意 App 选中一段文字 → 弹条点功能（或按 ⌥⌘P）→ 弹出结果卡片 → 点「复制」拿走，自己粘贴回去发送。  
*Select text in any app → click a toolbar action (or press ⌥⌘P) → a result card appears → hit "复制," then paste it back and send it yourself.*

## 友好提示覆盖 · Graceful fallbacks

- **没填 Key**：弹窗引导去「设置」。  
  ***No Key***: *a dialog sends you to Settings.*
- **没选中 / 没抓到文本**：卡片提示先选中文字再触发。  
  ***Nothing selected / grabbed***: *the card asks you to select text first.*
- **网络失败 / 超时 (30s) / 429 限流 / Key 无效**：卡片显示对应中文错误 + 「重试」。  
  ***Network error / timeout (30s) / 429 / invalid key***: *the card shows the matching error + "重试".*

## 固定签名证书（避免重编译后一直弹权限） · Fixed signing cert

「辅助功能」授权是按 App 的**签名指纹**记的。**ad-hoc 签名每次重编译指纹都变**，于是那行虽然勾着却对不上新 build，导致"明明勾了还一直弹"。  
*The Accessibility grant is keyed to the app's **code signature**. **Ad-hoc signing changes the fingerprint on every rebuild**, so the checkbox stays ticked but no longer matches the new build — hence "checked it, still prompting."*

正解：建一张**固定的自签名代码签名证书**，指纹稳定，重编译授权就不掉。**只需建一次：**  
*The fix: create one **fixed self-signed Code Signing certificate** — a stable fingerprint means the grant survives rebuilds. **You only do this once:***

1. 打开「钥匙串访问 (Keychain Access)」。  
   *Open **Keychain Access**.*
2. 菜单 →「证书助理 (Certificate Assistant)」→「创建证书… (Create a Certificate…)」。  
   *Menu → **Certificate Assistant → Create a Certificate…***
3. 名称填 `Leadership Dev`；身份类型选**自签名根证书**；证书类型选 **代码签名 (Code Signing)** ← 关键。  
   *Name it `Leadership Dev`; Identity Type **Self-Signed Root**; Certificate Type **Code Signing** ← the important one.*
4. 「创建」→ 过"自签名"提示 →「完成」。  
   ***Create** → accept the self-signed prompt → **Done**.*
5. 首次构建时弹"codesign 想用私钥签名"，点 **始终允许**。  
   *On the first build, when "codesign wants to sign with your key" appears, click **Always Allow**.*

证书名可用环境变量覆盖：`LEADERSHIP_SIGN_IDENTITY="你的证书名" bash scripts/build-app.sh`  
*Override the cert name via env var: `LEADERSHIP_SIGN_IDENTITY="Your Cert Name" bash scripts/build-app.sh`*

换签名方式后，需要**再重置并重新授权一次**，此后一劳永逸：  
*After switching signing methods, **reset and re-grant once** — then it's permanent:*

```bash
pkill -x Leadership
tccutil reset Accessibility com.leadership.dandang
open "build/Leadership.app"   # 触发一次 → 勾选 担当 → 退出重开
```

---

## 隐私说明（重要） · Privacy (important)

- **人在环中**：**绝不自动向任何 App 发送消息**。只做「读取选中文本」和「把结果放进剪贴板」，发不发都由你决定。  
  ***Human in the loop***: *it **never auto-sends anything to any app**. It only reads your selection and puts results on the clipboard — sending is always your choice.*
- **不做后台采集**：只在你**触发的那一刻**读取当前选中文本；不监听、不抓取、不存档。  
  ***No background collection***: *it reads the selection **only at the moment you trigger it** — no listening, scraping, or archiving.*
- **只在你触发时外发**：只有你主动触发，选中文本才会发往所选的 AI 服务商。  
  ***Sends only on trigger***: *your text goes to the chosen AI provider only when you actively invoke a feature.*
- **模型档位**：Gemini 请用**付费 API**（付费档声明不用于训练）；**严禁免费 AI Studio 档**（可能被用于产品改进/人工标注）。  
  ***Tier matters***: *for Gemini use the **paid API** (the paid tier states it isn't used for training); **never the free AI Studio tier** (it may be used for product improvement / human review).*
- **API Key**：仅存本机 Keychain，不上传。  
  ***API Key***: *stored only in the local Keychain, never uploaded.*
- **公司内容先确认公司政策**：「不被训练」**不等于**「合规允许外传」。  
  ***Check company policy for internal content***: *"not used for training" **does not equal** "cleared to send outside."*
- **日志安全**：任何日志都不会打印你的 API Key 或选中文本。  
  ***Log safety***: *no log ever prints your API Key or your selected text.*

---

## 目录结构 · Project layout

```
Sources/Leadership/
├─ App/
│  ├─ LeadershipApp.swift     # @main、菜单栏、快捷键接线 / entry, menu bar, hotkey wiring
│  └─ AppState.swift          # 各功能全链路编排 / end-to-end orchestration
├─ Trigger/
│  ├─ HotKey.swift            # 全局快捷键（Carbon）/ global hotkey
│  ├─ TextGrabber.swift       # 抓取选中文本（Cmd+C 回退）/ grab selection (Cmd+C fallback)
│  ├─ SelectionMonitor.swift  # 划词弹条的选区监听 / selection watcher for the toolbar
│  └─ TextReplacer.swift      # 替换原文（Cmd+V）/ replace in place — TODO
├─ UI/
│  ├─ SettingsView.swift      # 设置（服务商 / Key / 模型 / 语言）/ settings
│  ├─ ResultCardPanel.swift   # 结果卡片 / result card
│  ├─ PermissionPrompt.swift  # 辅助功能引导 / accessibility prompt
│  ├─ ActionBarPanel.swift    # 划词悬浮工具条 / floating toolbar
│  ├─ ReplyComposer.swift     # 「打发丫」输入面板 / reply composer
│  └─ ProfileView.swift       # 个人资料编辑 / profile editor
├─ AI/                        # 尽量自成一块、少依赖 AppKit，便于复用 / cohesive, AppKit-free
│  ├─ AIProvider.swift        # 多服务商抽象 (Gemini/OpenAI/Claude) / provider abstraction
│  ├─ GeminiClient.swift · OpenAIClient.swift · AnthropicClient.swift
│  ├─ Prompts.swift           # Prompt 模板 / prompt templates
│  └─ Feature.swift           # 功能枚举 + 弹条结构 / feature enum + bar layout
└─ Core/
   ├─ Keychain.swift          # 分服务商存 API Key / per-provider key storage
   ├─ Settings.swift          # 服务商/模型/语言/偏移等 / settings & prefs
   └─ Profile.swift           # 个人资料 / user profile
```

配套规格文档：`PRD.md`（产品需求）、`BUILD_SPEC.md`（技术方案）。  
*Companion specs: `PRD.md` (product) and `BUILD_SPEC.md` (technical).*
