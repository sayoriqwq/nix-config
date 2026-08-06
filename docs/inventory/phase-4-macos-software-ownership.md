# Phase 4 macOS 软件所有权终态

- **机器：** `macbook`
- **收口日期：** 2026-07-28
- **维护修订：** 2026-08-03，Issue #74 恢复 Lark 数据，#81 将当前渠道更正为中国区
  Feishu，#67 增加 agent Python 基线并收口四个 AI CLI 所有权，#93 清理已验收替代的
  迁移残留
- **决策来源：** Issue #6、#36 及 Phase 4 各实施 Issue
- **边界：** 仓库声明可复现配置，并记录外部恢复入口；账号、机密、数据库、容器、历史、缓存和备份不进入 Git

## 1. 终态原则

1. 可由 Nix 稳定提供的软件优先归 Nix/Home Manager；语言运行时按已批准的 mise/uv
   分工管理。
2. macOS 专属、上游更新更快或依赖系统集成的应用由 nix-darwin 的 Homebrew/MAS
   adapter 声明；`cleanup = "none"`，删除始终使用独立批准的精确动作。
3. Setapp、厂商安装器、Apple 系统组件和手工应用保持外部所有，但必须有恢复入口和
   数据边界。
4. 一个安装目标只有一个所有者。应用 package 与其账号、数据库、容器、profile、
   workspace 等可变状态是不同对象。
5. 旧 dotfiles 仓库只作为冻结历史；`nix-config` 是唯一继续维护的配置源。

## 2. 最终来源概览

| 来源 | 最终职责 | 声明/恢复入口 |
| --- | --- | --- |
| Nix / Home Manager | 通用 CLI、Shell、终端、编辑器及可靠 GUI | 顶层 Flake 与 `modules/home/` |
| nix-darwin Homebrew | 28 个 cask、1 个限定 tap；无声明 formula | `modules/capabilities/macos-legacy-applications/darwin.nix` 及独立应用 capability |
| Mac App Store | 9 个可独立恢复的 Apple/第三方应用 | `homebrew.masApps` |
| Setapp | 14 个订阅应用与 Setapp 客户端 | Setapp 官方客户端、人工登录 |
| macOS / Apple | 核心系统应用、Command Line Tools | 系统更新或 Apple 官方安装流程 |
| 厂商/手工 | 不能可靠声明或有意试用的应用 | 本文的官方入口与签名身份 |
| Homebrew 外部 formula | PostgreSQL、XcodeGen 及其依赖 | 当前本机状态；不属于声明式基线 |

这个概览描述安装来源，不表示 Nix 能恢复应用数据。完整恢复顺序见
[`restore-macos-environment.md`](../runbooks/restore-macos-environment.md)。

## 3. Nix / Home Manager 所有权

### 3.1 通用 CLI 与运行时入口

Home Manager 声明 Atuin、Bat、Btop、Delta、Eza、fd、fastfetch、Fish、fzf、GitHub CLI、
Gitleaks、Helix、jq、Lazygit、mise、nh、pay-respects、Python 3.14、
rclone、ripgrep、rtk、Starship、tmux、tree、uv、yazi 和 zoxide 等用户工具。Zsh 的
autosuggestions 与 syntax highlighting 也来自 Nix，而不是 Homebrew formula。

运行时分工如下：

- mise 固定 Node、Bun、pnpm、Erlang 29.0.3 与 Elixir 1.20.2-otp-29；
- Nix 为 macbook AI 辅助运维提供一个裸 Python 3.14 agent 基线，不加入全局第三方包；
- Graphviz 因未能证明存在真实 caller，已从全局 profile 删除；Poppler 也不再由
  Home Manager 全局提供，Codex 的 PDF 工作流使用客户端自带 runtime，仓库不承诺其
  路径或版本；
- `ai-assisted-operations` capability 由 Nix/Home Manager 唯一提供 `codex` 0.146.0、
  `claude` 2.1.220、`agy` 1.1.9 和 `omp` 17.2.4；Oh My Pi 使用固定官方
  `darwin-arm64` 发布物，四个可执行文件的更新由 Nix 控制，`~/.omp` 状态与凭据保持
  可写且不进入 Store。完整版本、重复副本和人工关卡见
  [`macOS AI CLI 所有权`](macos-ai-cli-ownership.md)；
- uv 负责项目 Python 选择，`.venv`、依赖与 lock file 属于项目；
- nginx、pkgconf 等项目依赖进入项目 dev shell，不进入全局用户 profile；
- PostgreSQL 16 数据服务不与普通 CLI 混合迁移，延期到 Issue #60。

### 3.2 GUI、终端与编辑器

| 应用 | Nix 所有权 | 可变状态边界 |
| --- | --- | --- |
| Atuin Desktop | package | key、history、records、session 与 workspace 外部 |
| Discord | package | 登录态、缓存与更新状态外部 |
| Ghostty | package 与核心配置 | scrollback、窗口和运行态外部 |
| IINA | package | history、播放列表和偏好外部 |
| LocalSend | package | 设备、历史与接收目录外部 |
| MonitorControl | package | 显示器设备状态与偏好外部 |
| Mos | package | 鼠标设备状态与偏好外部 |
| Obsidian | package | vault、插件、同步与应用状态外部 |
| Upscayl | package | 模型、缓存与输出外部 |
| Visual Studio Code | package与 seed-only settings baseline | 扩展、登录态、history、workspace 与 live settings 可写 |
| WezTerm | package 与核心配置 | scrollback、窗口和运行态外部 |
| xbar | package | plugins、缓存与运行态外部 |
| Zed Nightly | 上游 Flake 固定 package 与 seed-only baseline | 扩展、登录态、workspace/session 与 live settings 可写 |

Nix 应用在 macOS 上由 Home Manager 复制到 `~/Applications/Home Manager Apps`。编辑器
只在 live 配置缺失时初始化 baseline，之后通过人工审查回流，不做双向自动同步。

最终审计发现 Atuin、Discord、IINA、MonitorControl、Mos、Obsidian 与 Upscayl 曾各有
一份 activation 前保留的 `/Applications` rollback bundle。Issue #61 已在不删除共享
配置、账号、vault、history 或缓存的前提下把七个旧 bundle 移入可恢复 Trash；对应 Nix
应用与数据路径均通过验证。LocalSend 与 xbar 的旧 Homebrew 副本此前已由 #56 清理。
#93 在这些 Nix 应用继续通过 presence 验收后永久删除了 #61 的精确 Trash rollback
目录；应用配置、账号、vault、history 和缓存仍保持外部。

## 4. Homebrew 所有权

### 4.1 nix-darwin 声明

唯一允许的第三方 tap 是 `erictli/tap`，只为 Markdown 应用 Scratch 提供
`erictli/tap/scratch`。声明的 28 个 cask 为：

| 分类 | cask |
| --- | --- |
| 网络与通信 | `baidunetdisk`、`clash-verge-rev`、`feishu`、`megasync`、`qq`、`telegram`、`tencent-meeting`、`termius`、`transmission`、`wechat` |
| 创作与媒体 | `balenaetcher`、`figma`、`neteasemusic`、`homebrew/cask/obs` |
| 开发与 AI | `chatgpt`、`linear`、`orbstack`、`paseo`、`erictli/tap/scratch` |
| 系统与效率 | `easyfind`、`fuse-t`、`google-chrome`、`izip`、`pearcleaner`、`raycast`、`steam`、`topnotch`、`vorssaint` |

`autoUpdate = false`、`upgrade = false`、`cleanup = "none"`。普通 activation 只校验/恢复
已声明应用，不批量升级或卸载未声明软件。

特殊身份：

- `chatgpt` 对应 `com.openai.codex`（现 `ChatGPT.app`）；`ChatGPT Classic.app`
  是单独的 `com.openai.chat`，保持外部所有；
- `claude-code` 不再是声明的 Homebrew cask；迁移前 `/opt/homebrew` 中的 Claude
  2.1.153 已在 Nix 版本验收和 #93 批准后定向卸载。ChatGPT.app 的 embedded Codex
  是 app-private helper，不是 `codex` PATH 来源或清理目标；
- `erictli/tap/scratch` 对应 Markdown 应用 `com.scratch.app`。Issue #64 已把 Homebrew
  receipt 与实际 bundle 定向对齐到 1.0.0；裸 `scratch` 会解析到同名 MIT 应用，安装、
  升级和 outdated 验证必须使用完整 token；
- `homebrew/cask/obs` 强制选择官方 OBS Studio，避免旧第三方 tap 的同名迁移；
- `feishu` 是当前声明的中国区渠道，官方 cask 把 DMG 内 `Lark.app` 安装为
  `/Applications/Feishu.app`。Homebrew 只拥有应用 presence。#93 在核验 Feishu
  receipt、bundle 与签名并确认三种应用进程均未运行后，按维护者明确批准定向卸载全球
  版 `lark` cask 并删除手工旧 `Lark.app`；当前只保留 `/Applications/Feishu.app` 和
  `feishu` receipt。
  Lark/Feishu 的账号、聊天、数据库与 `~/Library` 可变数据未被清理；
- OrbStack 是唯一容器运行时。Nix/Homebrew 只声明应用 presence，VM、镜像、容器、
  volume、网络、context 与凭据不由仓库接管。

### 4.2 当前外部 formula

nix-darwin 不声明任何 Homebrew formula。#93 收口后，当前实机的 14 个 formula 均属 Homebrew
外部状态：

| 类型 | formula | disposition |
| --- | --- | --- |
| 数据服务 | `postgresql@16` | 保留现有服务与数据；Issue #60 单独迁移，不阻塞 Phase 4 |
| Swift 工具链 | `xcodegen` | 当前 Swift 项目依赖；与 Xcode Beta 一起保持 macbook 外部所有 |
| 传递依赖 | `ca-certificates`、`gettext`、`icu4c@78`、`krb5`、`libunistring`、`lz4`、`mpdecimal`、`openssl@3`、`readline`、`sqlite`、`xz`、`zstd` | 由上述外部 formula 的 Homebrew 依赖图拥有，不逐项声明 |

Phase 4 已定向删除 35 个旧 formula，并接受 Homebrew 对无消费者依赖的自动回收结果。
后续卸载命令必须设置 `HOMEBREW_NO_AUTOREMOVE=1`，除非维护者再次明确批准依赖回收。

## 5. Mac App Store 与 Apple 所有权

### 5.1 `masApps`

| 分类 | 应用 | App Store ID |
| --- | --- | ---: |
| Apple 可选应用 | GarageBand | 682658836 |
| Apple 可选应用 | Keynote | 409183694 |
| Apple 可选应用 | Numbers | 409203825 |
| Apple 可选应用 | Pages | 409201541 |
| 第三方 | Amphetamine | 937984704 |
| 第三方 | HazeOver | 430798174 |
| 第三方 | KeyScreen | 6753302381 |
| 第三方 | One Thing | 1604176982 |
| 第三方 | Windows App | 1295203466 |

App Store 登录、购买记录、许可证、文档和应用数据不进入仓库。`mas` 只由 nix-darwin
在 activation 中临时使用，不加入全局用户 PATH。

### 5.2 macOS 内建与 Swift 工具链

`/System/Applications`、`/System/Applications/Utilities` 和 Safari 由 macOS 自身拥有，
不加入 Nix/Homebrew/MAS inventory，也不把系统升级带来的应用变化视为 drift。

Xcode Beta 是唯一保留的完整 Xcode 渠道；Xcode Stable 已退役。Xcode Beta、Command
Line Tools、SDK/Simulator、许可证、`xcode-select` 与 Homebrew XcodeGen 一起构成
macbook 专属外部 Swift 工具链，仓库只记录边界，不声明版本或安装。

## 6. Setapp

Setapp 客户端、订阅与自更新是唯一所有者。新机器安装 Setapp 客户端并人工登录后，
恢复以下 14 个应用：

`AirBuddy`、`AlDente Pro`、`Bartender Pro`、`CleanShot X`、`CloudMounter`、`Downie`、
`Paste`、`Permute`、`PixelSnap`、`Slidepad`、`Supercharge`、`TablePlus`、`TextSniper`、
`Timing`。

账号、订阅、授权、电池策略、菜单栏布局、截图/录制、云端挂载、数据库连接、剪贴板
历史和其他运行数据不进入 Git。SideNotes、Lungo、NotchNook、Sip 与 iStat Menus 已退役。

## 7. 厂商、手工与有意试用应用

| 应用 | 恢复入口 / 身份 | disposition 与数据边界 |
| --- | --- | --- |
| AdsPower Global | [官方站点](https://www.adspower.com/)，bundle `com.adspower.global`，Team ID `Y28UF294S5` | 保留；profile、Cookie、代理、凭据和团队状态外部 |
| Alice in Cradle | 当前手工应用 | 明确保留；游戏数据与更新流程外部 |
| ChatGPT Classic | [OpenAI](https://openai.com/chatgpt/desktop/)，bundle `com.openai.chat` | 保留，与 Homebrew ChatGPT/Codex 身份分离；账号和对话外部 |
| Collaborator | [官网](https://collab.computer/)、[GitHub releases](https://github.com/collabs-inc/collab-public/releases)，Team ID `93MDU2WLAD` | 保留；账号、项目与 session 外部 |
| EVPlayer | [Mac App Store 1190222875](https://apps.apple.com/app/id1190222875)，bundle `cn.ieway.EVPlayer` | 保留；媒体和 history 外部 |
| iLoader | 当前签名应用，bundle `me.nabdev.iloader`，Team ID `42Q7QX86GV` | 保留；更新来源和应用数据由厂商渠道拥有 |
| LiteEdit | [官网](https://arietan.github.io/lite-edit/)、[GitHub releases](https://github.com/arietan/lite-edit/releases)，bundle `com.liteedit.app` | 保留；当前 1.0.0 为 ad-hoc 签名，下载后需人工核验 |
| Mole | [官网](https://mole.fit/)，bundle `com.tw93.MoleApp`，Team ID `5EH69Y5X38` | 保留；偏好外部；不得用 Nixpkgs 同名 SSH CLI 替代 |
| Multica | [官网下载](https://multica.ai/download)、[GitHub releases](https://github.com/multica-ai/multica/releases)，Team ID `Q85ULLN279` | 保留；workspace、daemon、账号和 Agent 状态外部 |
| Syncless | 应用内源码/updater 身份 `langgenius/echo`，bundle `com.langgenius.echo.client`，Team ID `9U6WW5A528` | 保留；公开 releases URL 在收口时返回 404，新机须从厂商渠道取得并核验签名；账号、项目和运行态外部 |
| 夸克网盘 | [官网下载](https://quarkapp.cn/download.html)，bundle `com.alibaba.quark.clouddrive`，Team ID `ZQTE7CLYL9` | 保留；官网在部分网络环境不可达，下载时人工核验签名；账号、同步与下载数据外部 |

用户级 helper 不单独声明：Claude Code URL Handler 由 Claude Code 生成，Excalidraw
由 Chrome/PWA profile 拥有，VTube Studio wrapper 由 Steam app ID 1325860 与本地游戏库
拥有。

## 8. 旧 dotfiles 与可变配置

- Atuin 稳定配置与空 `.hushlogin` 已交给 Home Manager；Atuin key 只声明本机路径，
  key、history、records、session 与数据库内容不入库。
- Chezmoi 已卸载。`~/.local/share/chezmoi` 与旧 dotfiles Git 仓库只作为冻结历史，
  不再 apply、不再修改，也不再作为配置事实来源。
- cmux、`HOME.md`、rcm、memo、obsidian-cli 和全部旧 Impeccable skills 不迁移。
- 应用设置如 Raycast、Bartender、CleanShot X、编辑器 live settings 通过各自可写状态
  或定期人工回流维护，不伪装成 Nix 可回滚数据。

## 9. Phase 4 前后差异

| 迁移前 | Phase 4 终态 |
| --- | --- |
| Nix、Homebrew、Chezmoi、手工文件对 CLI/Shell 存在重复所有权 | Nix/Home Manager 是 CLI、Shell 与静态用户配置主所有者；项目依赖进入 dev shell |
| VS Code、Zed、Ghostty、WezTerm 等存在 Homebrew/手工/Nix 重复副本 | Nix 是唯一声明与安装所有者；旧 cask和七个 GUI rollback bundle 已由 #56/#61 清理 |
| GUI 来源散落且缺少统一恢复说明 | 28 cask、9 MAS、14 Setapp、Nix GUI、系统内建和厂商应用均有明确 owner；四个 AI CLI 另由 Nix/Home Manager 唯一提供 |
| Docker Desktop 与 OrbStack helper 冲突 | OrbStack 是唯一容器运行时，旧 Docker Desktop helper 已清理 |
| 大量旧 formula、cask、tap 与退役应用残留 | #55–#57 已精确定向清理；未运行全局 cleanup 或 zap |
| macOS defaults 多数依赖现场手调 | 只声明维护者逐项体验批准的 Dock、Finder、输入、手势、窗口、时钟和电池行为 |
| 旧 dotfiles/Chezmoi 仍可能被误认为活动配置源 | `nix-config` 是唯一活动配置源；旧仓库冻结归档 |

已退役的软件包括 AltTab、Battery Buddy、cmux、Docker Desktop、旧 Google Antigravity GUI、
Itsycal、SideNotes、The Unarchiver、Typeless、Typora、旧 VS Code、Zed Preview、
Warp 及 #55/#56 中列出的旧 formula/cask。删除均通过窄 Issue 和明确批准完成。#93
又在核对精确路径后永久删除 #57/#61 的两个 Trash rollback 目录；仓库外私有备份及
应用 live 数据不在清理范围内。

Lark 曾在 #57 中按当时决定退役，旧 `Lark.app` 与专属数据被移动到可恢复 Trash。#74
恢复并人工验收了旧应用与数据，随后全球版 `lark` cask 安装了 `LarkSuite.app`。维护者
在 #81 明确把当前产品要求更正为中国区 Feishu，因此声明改为 `feishu`。#93 核验当前
Feishu 的 receipt、bundle 与签名并取得明确清理批准后，删除两份旧 Lark 应用、`lark`
receipt 和两个已批准的 Trash rollback 目录；当前只保留声明的 Feishu 应用。聊天、
登录态、数据库及其他 live 数据仍不交给 Nix，也未随应用清理删除。

## 10. 已知延期与回滚边界

- PostgreSQL 16 的 package、service 与数据迁移由 Issue #60 负责。明确延期不会使其变成
  “未分类软件”，也不授权 Phase 5 自动迁移数据库。
- OrbStack 的应用由 Homebrew cask声明；其可变容器数据永远需要独立备份/恢复流程。
- Nix generation 回滚只恢复声明和 Nix-owned package 链接；不能回滚 Homebrew adoption、
  MAS receipt、Setapp 登录、厂商应用数据、数据库或容器。
- Homebrew/MAS/Setapp/厂商应用的具体恢复和故障顺序见 Mac 总体 runbook。
- #93 还发现并精确删除六个指向已删除 Docker、WARP 与 Zed Preview 应用的 root-owned
  `/usr/local/bin` 悬空链接。删除后 `docker`/`kubectl` 继续由 OrbStack 提供，`zed` 只
  命中 Nix profile，WARP 与 `cagent` 不再有命令入口。
