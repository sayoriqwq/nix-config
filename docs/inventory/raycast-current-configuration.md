# Raycast 配置盘点（2026-08-03 快照）

- **盘点日期：** 2026-08-03
- **目标应用：** Raycast `1.104.24`
- **自研源码：** [`sayoriqwq/raycast`](https://github.com/sayoriqwq/raycast/tree/48f7a10551f7ae2cada8f7bbe4243ce36ed656ee)，当前 `main` 干净，revision 为 `48f7a10551f7ae2cada8f7bbe4243ce36ed656ee`
- **部署状态：** 维护者已激活 Raycast capability，并通过官方 UI 选择 Home Manager 管理的 Script Directory；本仓库仍是开发源码 checkout
- **性质：** 只读、脱敏的现状证据；不是可直接 apply 的声明
- **维护者决策：** 当前配置视为稳定基线，不建立持续维护流程；Show only customized 是
  Raycast Settings 中所有已修改内容的权威边界；DB Tunnel 与 `autossh` 已废弃，Yume command
  已停用，三项相关源码文件均已删除
- **关联研究：** [Raycast 声明式配置研究](../plans/raycast-declarative-configuration-research.md)

> **后续偏移：** 本快照中的 Hyper 盘点已被 2026-08-14 的 exact plist readback 推翻：当前
> `raycast_hyperKey_state` 为 `enabled = true`、`keyCode = 57`、`includeShiftKey = false`，即
> Caps Lock 产生不含 Shift 的 `Control+Option+Command`。当前意图、system leaves、调控与回滚
> 以 [macOS 键盘导航手册](../runbooks/macos-keyboard-navigation.md) 和
> [副作用偏移讨论记录](../plans/macos-side-effect-drift-coordination.md) 为准。下文保留为当时快照，
> 不得再作为 live shortcut 前置事实或操作指令。

## 1. 摘要

当前 Raycast 的个人化程度很高，主要由五部分组成：

1. `⌘ Space` 启动、Compact 窗口、Caps Lock Hyper Key 等全局交互偏好；
2. 15 个已观察到的 Hyper 应用启动键，以及 6 个窗口管理快捷键；
3. `~/.local/share/raycast/script-commands` 中 7 个由 Home Manager 部署的 Script Commands；
4. 3 个本地 extension 和 6 个 Store extension；
5. Quicklinks、Apple Shortcuts、aliases 和 extension preferences 等 Raycast 数据库状态。

最重要的现状不是“配置没有入 Nix”，而是源码、安装 bundle 和 Raycast 数据库已经出现三类漂移：

- `Terminal Finder` 数据库仍登记两个已删除的 Cmux 命令，并保留快捷键；调用时出现缺少 executable JS 的错误；
- `Open in Editor` 当前源码只有 3 个命令，已安装 bundle 仍有 7 个；
- `Counter` 仍在运行，但源码已从当前 Git tree 删除，只能从历史提交恢复。

## 2. 证据边界

本次使用四类证据：

- **`[UI]`：** Raycast Settings 的只读观察；
- **`[FS]`：** 本机 plist、manifest、文件名、权限和尺寸；
- **`[SRC]`：** 固定 revision 的自研源码；
- **`[macOS]`：** `com.apple.symbolichotkeys` 等系统偏好。

维护者确认 Raycast Settings 的 **Show only customized** 视图完整覆盖其中所有已修改项。因此
本文直接将它视为 Settings 自定义边界的权威来源，包括其中显示的 command、alias 和 hotkey；
完整 `.rayconfig` 仍可用于加密备份，但不再是确认“哪些内容被修改”的前置条件。

为避免泄漏或误改，本次没有：

- 读取 `~/.config/raycast/config.json` 中任何 token 值；
- 解密或查询 Raycast 主数据库；
- 打开 AI chat、Clipboard、Notes 或 Snippet 正文；
- 查看账号、组织或 Cloud Sync 身份；
- 执行 Script Command、本地 extension、`ray develop`、导入、导出或发布；
- 修改 command、alias、hotkey、extension preference 或系统权限。

Raycast Settings 的列表筛选和展开状态曾用于观察，结束时 Settings 已关闭；
`commandsPreferencesShowOnlyCustomized` 仍为关闭状态。

## 3. 全局与高级偏好

### 3.1 通用设置

| 设置 | 当前值 | 证据 |
| --- | --- | --- |
| Launch at login | 开启 | `[UI]` General |
| Raycast Hotkey | `⌘ Space` | `[UI]`、`[FS] raycastGlobalHotkey = Command-49` |
| Raycast menu bar icon | 关闭 | `[UI]` General |
| Text Size | 左侧默认档 | `[UI]` General |
| Appearance | 跟随系统 | `[UI]`、`[FS] raycastShouldFollowSystemAppearance = 1` |
| Window Mode | Compact | `[UI]`、`[FS] raycastPreferredWindowMode = compact` |
| Compact Favorites | 开启 | `[UI]` General |
| Screenshot data source | 开启 | `[FS] screenshots_dataSourceEnabled = 1` |

Spotlight 的两个系统快捷键条目 `64` 和 `65` 都处于 disabled，因此当前 `⌘ Space`
已明确让给 Raycast，不存在同键竞争。证据来自
`~/Library/Preferences/com.apple.symbolichotkeys.plist` 的定向读取。

### 3.2 Advanced

| 设置 | 当前值 |
| --- | --- |
| Show Raycast on | Screen containing mouse |
| Pop to Root Search | After 90 seconds |
| Escape Key Behavior | Navigate back or close window |
| Auto-switch Input Source | 未配置 |
| Navigation Bindings | macOS Standard (`^N`、`^P`、`^F`、`^B`) |
| Page Navigation Keys | Square Brackets |
| Root Search Sensitivity | Medium |
| Hyper Key | Caps Lock；包含 Shift，等价于左侧 `⌃⌥⇧⌘` |
| Hyper Quick Press | Does Nothing |
| Hyper Key 显示 | 使用 `✦` |
| Favicon Provider | Raycast |
| Emoji Skin Tone | 默认黄色 |
| Custom Wallpaper | 未配置 |
| Certificates | Default |
| Web Proxy / Use System Network Settings | 关闭 |

Window Capture 没有绑定 hotkey；捕获后仅开启 Copy to clipboard，Show in Finder 和
Open quick access overlay 均关闭。

Developer Tools 当前为：

- Auto-reload on save：开启；
- Open Raycast in development mode：开启；
- Use Node production environment：关闭；
- Use file logging instead of OSLog：关闭；
- Disable pop to root search：关闭；
- Keep window always visible during development：关闭。

这组设置与本机长期开发本地 extension 的使用方式一致。

## 4. 快捷键与 aliases

### 4.1 Hyper 应用启动键

`✦` 表示 Caps Lock Hyper Key，即 `⌃⌥⇧⌘`。

| 应用 | Hotkey |
| --- | --- |
| ChatGPT | `✦ X` |
| ChatGPT Classic | `✦ A` |
| Clash Verge | `✦ N` |
| Ghostty | `✦ G` |
| Google Chrome | `✦ C` |
| Obsidian | `✦ O` |
| Scratch | `✦ P` |
| TablePlus | `✦ T` |
| Telegram | `✦ ,` |
| Termius | `✦ E` |
| Visual Studio Code | `✦ V` |
| Zed Nightly | `✦ Z` |
| 微信 | `✦ .` |
| 系统设置 | `✦ S` |
| 网易云音乐 | `✦ M` |

这是 `[UI]` Show only customized 边界中的应用级自定义项。维护者确认该视图可以直接信任；
官方导出只作为完整恢复材料，不是验证自定义项范围的必要条件。

### 4.2 Window Management

Raycast 是当前窗口管理主路径，配置形成一组 Vim 方位风格快捷键：

| 命令 | Hotkey |
| --- | --- |
| Top Half | `⌥ I` |
| Left Half | `⌥ J` |
| Bottom Half | `⌥ K` |
| Right Half | `⌥ L` |
| Center | `⌥ C` |
| Maximize | `⌥ M` |

没有观察到自定义 Window Layout Command；Settings 中只有创建 layout/management command
的内建入口。

### 4.3 非 Script Command aliases

| 命令 | Alias | 来源 |
| --- | --- | --- |
| Convert Color | `cvc` | Store extension |
| Define Word | `df` | 内建 Dictionary |
| Kill Process | `kp` | Store extension |
| Open Ports in Menu Bar | `pm` | Store extension |
| Search Screenshots | `ss` | 内建 Screenshots |
| Search Browser Tabs | `sbt` | Store extension |
| Search CSS Tricks | `sct` | Store extension |
| Search Emoji & Symbols | `semo` | 内建命令 |
| Search Files | `sf` | 内建 File Search |

## 5. Script Commands

Raycast 当前登记且实时监视的目录是：

```text
~/.local/share/raycast/script-commands
```

该目录由 Home Manager 从固定 Raycast source revision 生成；`~/Desktop/raycast` 继续作为 Git
源码与开发 checkout，不应删除或直接作为第二个 Script Directory 同时登记。

目录中有 7 个仍在使用的 Script Commands：

| 命令 | Mode | Alias | Hotkey |
| --- | --- | --- | --- |
| Bilibili (Switch or Open) | silent | `bil` | 无 |
| ChatGPT (Switch or Open) | silent | `cg` | 无 |
| Claude (Switch or Open) | silent | `cc` | 无 |
| Gemini (Switch or Open) | silent | `gm` | 无 |
| GitHub (Switch or Open) | silent | `gh` | 无 |
| Gemini Notebook (Switch or Open) | silent | `llm` | 无 |
| YouTube (Switch or Open) | silent | `yt` | 无 |

这 7 个导航命令是薄 wrapper，全部调用同一个
[`chrome-switch.sh`](https://github.com/sayoriqwq/raycast/blob/48f7a10551f7ae2cada8f7bbe4243ce36ed656ee/scripts/chrome-switch.sh)
和 JXA
[`chrome-switch.js`](https://github.com/sayoriqwq/raycast/blob/48f7a10551f7ae2cada8f7bbe4243ce36ed656ee/scripts/lib/chrome-switch.js)：

- 配置只包含 `defaultURL` 与 `targetList`；
- 匹配目标 host 或其子域名；
- 跳过 DevTools、Chrome 内部页、空白页、data URL 和本地开发地址；
- 已有目标 tab 时聚焦，否则在正常 Chrome 窗口创建 tab；没有窗口时用 `open -a`。

7 个命令均使用 source revision 内固定的本地品牌图标，不依赖运行时联网加载。Gemini Notebook
使用 light/dark 两套图标，默认打开 `https://notebook.google.com/`，并继续匹配旧域名
`notebooklm.google.com` 以兼容尚未重定向的既有标签页。入口路径仍是 `notebook-switch.sh`，
因此不主动改变应用内 alias `llm` 的命令身份。

这些导航脚本依赖系统 `/bin/bash`、`/usr/bin/osascript` 和 Google Chrome，不再要求
Raycast GUI 环境能找到 Node。

维护者确认截图中没有 alias/hotkey 的 `Toggle DB Tunnel` 与 `Yume (Switch or Open)` 均已
停用；前者及其 `autossh` 依赖已废弃。`toggle-db-tunnel.sh`、`yume-switch.sh` 与
`config/yume-switch.json` 已从源码删除，也不进入 manifest、Nix capability 或 activation。
DB tunnel 曾包含的生产连接事实不在本文记录，未来不得恢复相关源码、依赖或网络行为。

## 6. 本地 extensions

### 6.1 总览

| Extension | 当前源码 | live bundle manifest | Settings 数据库视图 | 自定义 hotkey |
| --- | --- | --- | --- | --- |
| Terminal Finder | 4 commands | 4 commands | 6 commands | `⌥G`、`⌥⇧G`，另有两个失效 Cmux hotkey |
| Open in Editor | 3 commands | 7 commands | 7 commands | `⌥X`、`⌥V`、`⌥Z` |
| Counter | 当前 tree 无源码 | 1 command | 1 command | 无 |

两个仍在源码树中的 extension 都固定 `@raycast/api = 1.104.23`，通过 `pnpm exec ray`
提供开发 CLI；`dev` 使用 `ray develop`，`lint` 使用 `ray lint`，构建使用
[`build-extension.mjs`](https://github.com/sayoriqwq/raycast/blob/48f7a10551f7ae2cada8f7bbe4243ce36ed656ee/scripts/build-extension.mjs)
在临时目录运行 `ray build`，再复制当前 manifest 声明的 JS 输出。

### 6.2 Terminal Finder

当前源码 manifest 声明：

- Finder → WezTerm；
- Finder → Ghostty；
- WezTerm → Finder；
- Ghostty → Finder。

Settings 数据库仍额外登记：

- Finder → Cmux：`⌥ W`；
- Cmux → Finder：`⌥ ⇧ W`。

这两个命令在当前 live bundle 与整个当前 Git 历史搜索中都没有对应源码。盘点期间 Raycast
实际显示 “Could not find command's executable JS file” 错误，因此这是已复现的坏引用，
不是理论风险。

另外，
[`ghostty.ts`](https://github.com/sayoriqwq/raycast/blob/48f7a10551f7ae2cada8f7bbe4243ce36ed656ee/extensions/terminal-finder/src/ghostty.ts#L4-L5)
仍硬编码 `/Applications/Ghostty.app`，但本机只有
`~/Applications/Home Manager Apps/Ghostty.app`。打开路径函数还会尝试应用名和 bundle ID，
但 Ghostty → Finder 的 AppleScript 路径直接依赖该硬编码 bundle，因此存在明确的 Nix 安装
兼容性缺口。

WezTerm 路径则通过登录 shell执行 `command -v wezterm`，当前解析为 Nix profile 中的
`/etc/profiles/per-user/sayori/bin/wezterm`，与本机 Fish/Nix 环境兼容。

### 6.3 Open in Editor

当前源码只保留：

- Open in VS Code：`⌥ V`；
- Open in Zed Nightly：`⌥ Z`；
- Open in Codex：`⌥ X`。

它通过 Raycast `getApplications()` 按 bundle ID 查找应用，再使用返回的实际 `app.path`，
因此可兼容 Home Manager Apps 路径。证据见
[`src/lib.ts`](https://github.com/sayoriqwq/raycast/blob/48f7a10551f7ae2cada8f7bbe4243ce36ed656ee/extensions/open-in-editor/src/lib.ts#L37-L45)。

live bundle 仍额外包含 AionUI、Antigravity、Kiro、OpenCode 四个命令。它们在提交
[`f5fbf38`](https://github.com/sayoriqwq/raycast/commit/f5fbf38) 中已从源码删除，当前没有
hotkey，但仍是安装态漂移。

### 6.4 Counter

Counter 当前仍启用 `Record Counter Event`，没有 hotkey，偏好为：

| Preference | 当前值 |
| --- | --- |
| Default Counter | `qq` |
| Counter Aliases | `qq=qq,wechat=wechat` |
| Data Directory | `~/.config/raycast/data/counter` |
| Time Zone | `Asia/Shanghai` |

源码在提交
[`4b75163`](https://github.com/sayoriqwq/raycast/commit/4b75163)
中从当前 tree 删除，但 live bundle 和数据仍保留。`~/.config/raycast/data/` 根目录还存在一组
更早的同名 counter 文件，而当前 preference 指向 `data/counter/`；本次只读取文件名、大小
和时间，没有读取计数或 audit 内容。根目录文件应视为待确认的旧状态，而不是直接删除对象。

## 7. Store extensions 与偏好

当前有 6 个 Store extension：

| Extension | Commands | 观察到的自定义配置 |
| --- | ---: | --- |
| CSS Tricks | 1 | alias `sct` |
| Port Manager | 4 | menu bar command alias `pm`；Kill Signal 为每次询问 |
| Zed | 3 | 整个 extension 当前禁用；Build=`Zed`、Show Git Branch=开、Icons、Show Open Status=关 |
| Convert Color | 1 | alias `cvc` |
| Kill Process | 1 | alias `kp`；见下方偏好 |
| Browser Tabs | 1 | alias `sbt` |

Kill Process 当前偏好：

- Auto-Refresh：`3000 ms`；
- Search Process Paths / PIDs / Prioritize Apps：均关闭；
- Show PID / Show Process Path：均关闭；
- Close Window、Clear Search Bar：开启；
- Go Back to Root Search：关闭；
- Never Ask for Confirmation：关闭。

Port Manager 的 menu bar command 已启用；这与 Raycast 自身 menu bar icon 关闭不冲突，
二者是不同 status item。

Zed Store extension 选择的是稳定版 `Zed`，而本机 Nix 管理的是 `Zed Nightly`；由于整个
Store extension 当前禁用，它不是即时故障，但属于应清理或重新定向的旧配置。

## 8. 其他个人化数据

### 8.1 Quicklinks

当前可见 4 个 Quicklinks，均无 alias/hotkey：

- Search DuckDuckGo；
- Search Google；
- `github`；
- `youtube`。

本次没有打开目标 URL。若要安全入库，应使用 Raycast 的独立 Quicklinks JSON 导出并人工
审阅，而不是读取加密数据库。

### 8.2 Apple Shortcuts

Raycast 当前索引 6 个 Shortcuts，均无 alias/hotkey：

- Koco Widgets；
- QQ；
- Toggle Do Not Disturb；
- 专注；
- 微信；
- 播放每日推荐（启动App）。

本次只记录名称，没有运行或读取 Shortcuts 动作内容。

### 8.3 AI Commands

Settings 中可见 13 个默认风格 AI Commands，均未绑定 alias/hotkey。盘点只确认名称层级，
没有打开 prompt、模型、历史或账号配置。

Snippets、Clipboard、Notes、favorites 和完整 command preference 仍由加密数据库拥有；
本次未将其作为普通文件读取。

## 9. 可变状态与敏感边界

| 路径 | 当前角色 | 处理原则 |
| --- | --- | --- |
| `~/.config/raycast/extensions/` | 9 个 live extension bundle | 不由 Home Manager 直接覆盖 |
| `~/.config/raycast/data/` | Counter 可变数据与旧状态 | 不入 Git，不自动删除 |
| `~/.config/raycast/config.json` | 3 个 token-like key | mode `0600`；值未读，禁止入 Git/Nix Store |
| `~/Library/Application Support/com.raycast.macos/` | 加密主库、activity 库、emoji 库与 WAL | Raycast 独占；不链接、不直接迁移 |
| `~/Library/Preferences/com.raycast.macos.plist` | 稳定偏好与大量运行态混合 | 只挑经验证的稳定键声明 |

`config.json` 的顶层 key 名为 `Token`、`accesstoken`、`token`，文件大小 257 bytes、权限
`0600`。这里只记录敏感边界，不安排迁移；任何值都没有进入终端输出或本文。

plist 记录 Desktop、Documents、Downloads、cloud storage 和 removable volumes 的 Raycast
内部读取开关均为开启。这不等同于已经验证 macOS TCC 授权；直接读取用户 TCC 数据库被系统
拒绝，因此 Accessibility、Automation、Full Disk Access 等实际授权仍需维护者在 System
Settings 中人工确认。

## 10. 已知差异与稳定基线

维护者认为当前配置相对稳定，以下项目是已知现状，不自动形成维护 backlog。只有发生实际
故障、新机器恢复需求或维护者重新提出变更时，才打开对应窄 Issue。

| 状态 | 发现 | 当前处理 |
| --- | --- | --- |
| 已完成清理 | DB tunnel 与 Yume command/config 已从源码删除 | Nix 消费者断言路径缺失；不迁移、不补依赖、不恢复 |
| 敏感边界 | `config.json` 含 token-like 值 | 保持 `0600`，不得提交；当前不迁移 |
| 已知漂移 | Terminal Finder 有两个失效的 Cmux 命令和 hotkey | 保留现状；实际影响使用时再通过官方流程收敛，不直接改数据库 |
| 已知漂移 | Open in Editor 已安装 7 commands，源码仅 3 | 保留现状；需要重建时再复核 |
| 已知漂移 | Counter 源码从当前 tree 删除但运行态仍在 | 保留运行态与数据，不恢复、不退役 |
| 已知兼容性 | Ghostty → Finder 依赖错误的 `/Applications` 路径 | 当前不维护；实际失败或迁机时再修正 |
| 已禁用 | Zed Store extension 仍选稳定版 Zed | 保持禁用，不清理 |

## 11. 未来复盘方法（当前不实施）

Raycast 没有官方的 `config list` 或 `extensions list --json` CLI，因此最省时的可靠流程应是：

1. 用一个仓库 helper 一次性读取 app version、plist 白名单键、manifest、Script Command
   metadata、文件权限和源码/runtime drift；
2. 直接把 “Show only customized” 作为所有已修改项的权威短清单，不再遍历全部内建命令；
3. Snippets 与 Quicklinks 分别使用官方 JSON export，经脱敏后作为 seed；
4. 加密 `.rayconfig` 只承担完整恢复/备份；文件留在仓库外，由维护者控制 passphrase，
   不把它当作判断自定义范围的前置条件，也不把整个 export 当作 Nix source；
5. 不通过读取 Keychain、破解数据库或把 token 传给 agent 来换取自动化。

当前不创建 `raycast-inventory` helper 或其他维护 Issue。若未来稳定基线发生变化，再考虑一个
只读 helper；它不应导入、删除、重建 extension 或修改 Raycast Settings。

## 12. 本次验证

- 自研仓库 `git status --short --branch`：clean；
- 对 source 与 live manifests 的 command name/count 做了字段级比较；
- 使用 `defaults read`、`plutil -extract`、`jq`、`stat`、`rg` 做定向只读检查；
- Spotlight 条目 `64`、`65` 均验证为 disabled；
- Raycast Settings 仅作读取，结束时已关闭；
- 没有执行 Nix evaluation，因为本次只有盘点文档，没有 Nix 实现。
