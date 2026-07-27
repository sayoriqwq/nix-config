# Phase 4 macOS 软件所有权清单

- **采集日期：** 2026-07-27
- **目标机器：** `macbook`
- **父阶段：** [Issue #6](https://github.com/sayoriqwq/nix-config/issues/6)
- **决策来源：** [Issue #36](https://github.com/sayoriqwq/nix-config/issues/36)
- **文档实施：** [Issue #38](https://github.com/sayoriqwq/nix-config/issues/38)
- **Nix GUI 实施：** [Issue #45](https://github.com/sayoriqwq/nix-config/issues/45)
- **Homebrew / MAS 实施：** [Issue #46](https://github.com/sayoriqwq/nix-config/issues/46)
- **macOS defaults：** 独立由 [Issue #37](https://github.com/sayoriqwq/nix-config/issues/37) 处理

本文统一记录 macOS 软件的安装、稳定配置、版本更新和可变状态所有权。
它描述当前事实与已批准终态，但不代表所有终态声明已经实施或激活。

## 1. 所有权规则

| 层次 | 负责内容 | 不负责内容 |
| --- | --- | --- |
| Nix / Home Manager | 可复现的用户软件、桌面软件、稳定配置与用户环境 | 登录态、数据库、缓存、history、workspace/session |
| nix-darwin / Homebrew | macOS cask、必要 formula 与 Homebrew bootstrap | 应用账号、应用内自更新状态和业务数据 |
| nix-darwin / MAS | 通过稳定 App Store ID 恢复应用 | Apple 账号、购买记录、许可证接受和大型可选资源 |
| mise / uv | 项目运行时选择与语言环境 | 项目数据、虚拟环境备份和依赖源码 |
| 项目 dev shell | 只在项目上下文需要的开发依赖 | 全局用户工具和生产服务 |
| Setapp / 厂商安装器 / Steam / Chrome | 外部应用的安装、订阅或厂商更新 | nix-config 不接管其可变数据 |
| macOS | 核心内建应用与系统组件 | 不通过 Homebrew、MAS 或 Nix 重复声明 |

统一状态含义：

| 状态 | 含义 |
| --- | --- |
| 已声明并验收 | 已进入仓库、完成真实 Mac activation 和人工验证 |
| 已声明待验收 | 已进入仓库并通过离线构建，但尚未完成真实 Mac activation 和人工验证 |
| 已批准待实施 | 维护者已决定终态，但配置尚未落地或验收 |
| 外部所有 | 仓库只记录恢复入口和边界，不声明安装 |
| 有意试用 | 维护者明确保留的实验性应用，不按低使用频率清理 |
| 待独立迁移 | 涉及服务、容器、数据库或其他高风险状态，必须另建 Issue |
| 待清理 | 已决定弃用，但尚未获得定向卸载或删除批准 |
| 未决 | 事实已记录，但维护者尚未决定安装所有者或 disposition |

## 2. 当前非敏感快照

| 来源 | 当前事实 | 说明 |
| --- | ---: | --- |
| Homebrew 直接请求 formula | 35 | 依据 installed-on-request 元数据 |
| Homebrew 传递依赖 formula | 89 | 不作为 89 个独立用户软件声明 |
| Homebrew formula 总数 | 124 | #36 初始盘点为 126；这是采集时间点差异，不据此清理 |
| Homebrew Caskroom 登记 | 21 | 正常 cask 查询被不受信任的 `antigravity-tools` tap 阻断，改从 Caskroom 只读采集 |
| Homebrew taps | 6 | 仅 `lbjlaq/antigravity-manager` 已有退役决定 |
| `/System/Applications` 与 Utilities | 64 | macOS 核心内建应用 |
| `/Applications` 顶层应用 | 70 | 包含 MAS、Homebrew、Setapp、厂商和手工应用 |
| `~/Applications` 顶层应用 | 4 | 用户级手工/PWA/Steam/helper 应用 |
| Home Manager Apps | 13 | 既有编辑器/终端与 #45 的九个 Nix GUI 应用 |
| 已识别 MAS 应用 | 10 | App Store ID 与本机 receipt 已逐项确认；Xcode 已改为外部所有 |
| Setapp 保留应用 | 14 | 维护者清理后重新扫描的最终集合 |

本快照不包含账号、序列号、token、Cookie、私有主机、代理、数据库内容、
浏览器 profile、聊天记录、订阅信息或其他可变数据。

## 3. Homebrew formula

### 3.1 直接请求 formula：迁入或继续由 Nix 管理

| Formula | 当前 Homebrew 版本 | 目标安装所有者 | 状态 / 后续动作 |
| --- | --- | --- | --- |
| `bat` | 0.26.1 | Nix / Home Manager | 已声明并验收；Homebrew 副本待定向清理 |
| `btop` | 1.4.5 | Nix / Home Manager | 已声明并验收；Homebrew 副本待定向清理 |
| `eza` | 0.23.4 | Nix / Home Manager | 已声明并验收；Homebrew 副本待定向清理 |
| `fd` | 10.4.2 | Nix / Home Manager | 已声明并验收；Homebrew 副本待定向清理 |
| `fish` | 4.5.0 | Nix / Home Manager | 已声明并验收；登录 Shell 已切换，Homebrew 副本待清理 |
| `fzf` | 0.67.0 | Nix / Home Manager | 已声明并验收；Homebrew 副本待定向清理 |
| `gh` | 2.95.0 | Nix / Home Manager | 已声明并验收；认证状态继续可写 |
| `helix` | 25.07.1 | Nix / Home Manager | 已声明并验收 |
| `lazygit` | 0.60.0 | Nix / Home Manager | 已声明并验收 |
| `ripgrep` | 15.1.0 | Nix / Home Manager | 已声明并验收 |
| `starship` | 1.24.2 | Nix / Home Manager | 已声明并验收 |
| `tmux` | 3.6a | Nix / Home Manager | 已声明并验收 |
| `tree` | 2.2.1 | Nix / Home Manager | 已声明并验收 |
| `zoxide` | 0.9.8 | Nix / Home Manager | 已声明并验收 |
| `fastfetch` | 2.56.1 | Nix / Home Manager | 已批准待实施 |
| `git-delta` | 0.18.2_3 | Nix / Home Manager | 已批准待实施；首次只安装，不改变 Git pager |
| `gitleaks` | 8.30.1 | Nix / Home Manager | 已批准待实施 |
| `graphviz` | 14.1.3 | Nix / Home Manager | 已批准待实施 |
| `poppler` | 26.02.0_1 | Nix / Home Manager | 已批准以 Nix `poppler-utils` 能力迁移 |
| `rclone` | 1.73.5 | Nix / Home Manager | 已批准待实施；远端凭据与配置不入库 |
| `rtk` | 0.39.0 | Nix / Home Manager | 已批准待实施 |
| `yazi` | 26.1.22 | Nix / Home Manager | 已批准待实施 |

### 3.2 语言运行时、项目依赖和外部服务

| Formula | 当前版本 | 目标所有者 | 状态与边界 |
| --- | --- | --- | --- |
| `elixir` | 1.19.5 | mise | 已批准固定 `1.20.2-otp-29`；需窄 Issue 修订既有 mise 合同 |
| `erlang` | 28.5，当前为依赖 | mise | 已批准固定 `29.0.3`；Mix/Hex 继续管理项目依赖 |
| `python@3.12` | 3.12.13 | uv / 项目 | Nix 只提供 uv；项目选择 Python，Homebrew 副本待清理 |
| `nginx` | 1.29.8 | 项目 dev shell | 不进入全局 profile；已在实际项目用 ignored 本地 dev shell 验证 |
| `pkgconf` | 2.5.1 | 项目 dev shell | 按项目需要提供，不全局声明 |
| `xcodegen` | 2.46.0 | macbook 外部 Swift 工具链 | 与 Xcode Stable/Beta、CLT 一并由维护者和 Apple/Homebrew 手工管理，不进入声明 |
| `postgresql@16` | 16.11 | Homebrew 外部服务 | 当前运行并拥有数据；待独立迁移，须含备份、恢复、停机和回滚 |
| `chezmoi` | 2.70.0 | 临时外部所有 | 保留到最后一个活动 dotfiles 目标完成 handoff |

### 3.3 已决定退役

以下直接请求 formula 均为**待清理**，不迁入 Nix：

- `autossh`
- Homebrew `bash`
- `powerlevel10k`
- `rcm`
- `thefuck`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

定向卸载必须等替代路径验证并取得独立批准，不能扩大为 `brew autoremove`。

### 3.4 传递依赖 formula

当前 89 个非直接请求 formula 统一由 Homebrew 依赖解析器拥有，不在
`homebrew.brews` 中逐项声明。只有仍保留的直接 formula/cask 实际需要它们时才继续
存在；未来清理必须依据当时的反向依赖重新计算，不能按本清单机械删除。

<details>
<summary>2026-07-27 传递依赖名称快照</summary>

`aom`, `brotli`, `ca-certificates`, `cairo`, `dav1d`, `erlang`, `fontconfig`,
`freetype`, `fribidi`, `gd`, `gdk-pixbuf`, `gettext`, `giflib`, `glib`, `gmp`,
`gnupg`, `gnutls`, `gpgme`, `gpgmepp`, `graphite2`, `gts`, `harfbuzz`, `highway`,
`icu4c@78`, `imath`, `jasper`, `jpeg-turbo`, `jpeg-xl`, `krb5`, `libassuan`,
`libavif`, `libdatrie`, `libdeflate`, `libevent`, `libgcrypt`, `libgit2`,
`libgpg-error`, `libidn2`, `libksba`, `libnghttp2`, `libpng`, `librsvg`, `libssh2`,
`libtasn1`, `libthai`, `libtiff`, `libtool`, `libunistring`, `libusb`, `libvmaf`,
`libx11`, `libxau`, `libxcb`, `libxdmcp`, `libxext`, `libxrender`, `little-cms2`,
`lz4`, `lzo`, `m4`, `mpdecimal`, `ncurses`, `netpbm`, `nettle`, `npth`, `nspr`,
`nss`, `oniguruma`, `openexr`, `openjpeg`, `openjph`, `openssl@3`, `p11-kit`,
`pango`, `pcre2`, `pinentry`, `pixman`, `python@3.14`, `readline`, `sqlite`,
`unbound`, `unixodbc`, `utf8proc`, `webp`, `wxwidgets@3.2`, `xorgproto`, `xz`,
`yyjson`, `zstd`。

</details>

## 4. Homebrew cask 当前登记

| Cask | 当前登记版本 | 批准终态 | 状态 / 说明 |
| --- | --- | --- | --- |
| `claude-code` | 2.1.153 | Homebrew cask | 已声明待验收；账号、session 与 URL helper 状态可写 |
| `easyfind` | 5.0.2 | Homebrew cask | 已声明待验收 |
| `figma` | 125.11.6 | Homebrew cask | 已声明待验收；账号与项目缓存不入库 |
| `fuse-t` | 1.2.1 | Homebrew cask | 已声明待验收；依赖 macOS 文件系统集成 |
| `orbstack` | 2.0.5 / 19905 | Homebrew cask，待独立迁移 | 已声明 presence 待验收；不改变 VM、容器、镜像、volume、网络或 helper |
| `pearcleaner` | 5.4.3 | Homebrew cask | 已声明待验收 |
| `erictli/tap/scratch` | 0.10.0 | Homebrew cask | 已声明待验收；这是 `com.scratch.app` Markdown 应用，不是 Homebrew Core 的 MIT Scratch 3 |
| `topnotch` | 1.3.2 | Homebrew cask | 已声明待验收 |
| `localsend` | 1.17.0 | Nix / Home Manager | 已声明并验收；cask 待后续定向清理 |
| `xbar` | 2.1.7-beta | Nix / Home Manager | 已声明并验收；plugins 与缓存保持可写 |
| `visual-studio-code` | 1.107.1 | Nix / Home Manager | Nix 版已验收；旧 cask 与 `/Applications` 副本待清理 |
| `zed` | 0.219.4 | 官方 Zed Flake Nightly | Nightly 已验收；旧 cask与 Preview 待独立清理 |
| `aionui` | 1.8.17 | 退役 | 未发现应用实体；待清理登记 |
| `antigravity-tools` | 4.0.15 | 退役 | 第三方账号工具；应用实体不存在，不受信任 tap 一并待清理 |
| `cc-switch` | 3.9.0 | 退役 | 未发现应用实体；待清理登记 |
| `font-meslo-lg-nerd-font` | 3.4.0 | 退役 | 字体已统一为 Nix 管理的 Maple Mono |
| `jordanbaird-ice` | 0.11.12 | 退役 | 未发现应用实体；待清理登记 |
| `keycastr` | 0.10.5 | 退役 | 未发现应用实体；待清理登记 |
| `shottr` | 1.9.1 | 退役 | 未发现应用实体；待清理登记 |
| `typora` | 1.12.6 | 退役 | 应用与 cask 待清理 |
| `warp` | 0.2026.01.07.08.13.stable_01 | 退役 | 未发现应用实体；待清理登记 |

`Google Antigravity.app` 与 `antigravity-tools` 是不同产品；两者都已决定弃用，
但不得把一个产品的数据或清理命令应用到另一个产品。

## 5. 已声明待验收的 Homebrew cask

以下应用已由 #46 写入 nix-darwin `homebrew.casks`，等待离线构建与真实机器验收。
Homebrew 是受控的 macOS 应用 adapter；应用账号和可变数据仍由应用自身拥有。

| 应用 | Cask | 主要边界 |
| --- | --- | --- |
| Google Chrome | `google-chrome` | Chrome 自更新和 profile 保持外部 |
| Raycast | `raycast` | Nix 版本落后；账号、扩展和 history 外部 |
| Telegram | `telegram` | 保留官方 macOS 应用形态与账户状态 |
| Steam | `steam` | 游戏库、兼容状态和自更新外部 |
| Transmission | `transmission` | Nix 主程序形态不等价于原生 App |
| 百度网盘 | `baidunetdisk` | 账号、同步/下载目录和传输状态外部 |
| Linear | `linear` | 账号、workspace 和缓存外部 |
| MEGAsync | `megasync` | 账号、同步映射、目录和数据库外部 |
| 网易云音乐 | `neteasemusic` | 账号、下载、播放历史和缓存外部 |
| OBS Studio | `homebrew/cask/obs` | 使用完整 token 绕开旧 `yakitrak/yakitrak` 的 `obs` formula migration；profile、scene、插件和录制输出外部 |
| QQ | `qq` | 账号、聊天、文件和缓存外部 |
| WeChat | `wechat` | 账号、聊天、文件和缓存外部 |
| 腾讯会议 | `tencent-meeting` | 账号、会议状态与缓存外部 |
| Termius | `termius` | hosts、密钥、凭据和同步状态不入库 |
| Typeless | `typeless` | 账号、语音数据、历史和模型状态外部 |
| balenaEtcher | `balenaetcher` | 原始磁盘写入始终是人工动作 |
| iZip | `izip` | 归档内容和历史外部 |
| ChatGPT（原 Codex App） | `chatgpt` | 官方 cask 使用 `codex-app-prod`，bundle 为 `com.openai.codex`；不得覆盖 ChatGPT Classic |
| Clash Verge | `clash-verge-rev` | 订阅、代理、凭据和日志外部 |
| Docker Desktop | `docker-desktop` | VM、镜像、容器、volume、网络和 helper 外部 |
| Paseo | `paseo` | Agent session 与 workspace 外部 |
| Vorssaint | `vorssaint` | 菜单栏状态和偏好外部 |

已批准的 `easyfind`、`figma`、`fuse-t`、`pearcleaner`、`erictli/tap/scratch`、`topnotch`、
`claude-code` 已在当前 Caskroom 表中，不重复列出。

## 6. Mac App Store

macOS 核心内建应用不进入 `masApps`。以下可独立恢复的 Apple 与第三方应用已写入
nix-darwin 原生 `homebrew.masApps`，等待真实机器验收。

| 分类 | 应用 | App Store ID | 可变边界 |
| --- | --- | ---: | --- |
| Apple 可选应用 | GarageBand | 682658836 | 音色库和工程外部 |
| Apple 可选应用 | Keynote | 409183694 | 文稿和 iCloud 状态外部 |
| Apple 可选应用 | Numbers | 409203825 | 表格和 iCloud 状态外部 |
| Apple 可选应用 | Pages | 409201541 | 文稿和 iCloud 状态外部 |
| 第三方 | Amphetamine | 937984704 | 运行状态和本机偏好可写 |
| 第三方 | HazeOver | 430798174 | 本机偏好可写 |
| 第三方 | KeyScreen | 6753302381 | 本机状态和权限外部 |
| 第三方 | One Thing | 1604176982 | 本机内容和偏好外部 |
| 第三方 | Windows App | 1295203466 | 账号、远程连接和凭据外部 |

App Store 登录是人工前置条件。`mas` 仅由 nix-darwin 在 Homebrew activation 中临时
提供，不进入全局 PATH；普通 activation 不主动升级应用，cleanup 保持 `none`。

## 7. Nix / Home Manager 桌面应用

### 7.1 已声明并验收

| 应用 | 安装所有者 | 稳定配置所有者 | 可变状态边界 |
| --- | --- | --- | --- |
| Ghostty | Nix / Home Manager | Home Manager | history、session 和运行态可写 |
| WezTerm | Nix / Home Manager | Home Manager | history、session 和运行态可写 |
| Visual Studio Code | Nix / Home Manager | Git/Nix 基线 + 可写 live settings | 扩展、登录、History、workspaceStorage 外部 |
| Zed Nightly | 官方 Flake + Home Manager | Git/Nix 基线 + 可写 live settings | 扩展、登录、workspace/session 外部 |

### 7.2 已声明并验收

| 应用 | 目标安装所有者 | 说明 |
| --- | --- | --- |
| Atuin Desktop | Nix / Home Manager | 0.2.20；Runbook、workspace、Hub 登录和连接状态外部 |
| Discord | Nix / Home Manager | 登录态与缓存外部；使用精确 unfree allowlist |
| IINA | Nix / Home Manager | 播放历史和媒体文件外部 |
| LocalSend | Nix / Home Manager | 设备、历史与接收目录外部 |
| MonitorControl | Nix / Home Manager | 显示器设备状态与偏好可写 |
| Mos | Nix / Home Manager | 鼠标设备状态与偏好可写 |
| Obsidian | Nix / Home Manager | vault、插件和应用状态外部；使用精确 unfree allowlist |
| Upscayl | Nix / Home Manager | 模型、缓存和输出外部 |
| xbar | Nix / Home Manager | plugins、缓存和运行态外部 |

具体版本、应用身份、双安装验收与回滚步骤见
[`phase-4-nix-gui.md`](phase-4-nix-gui.md)。

## 8. Setapp

Setapp 客户端、订阅和自更新是唯一安装/版本所有者。nix-config 不新增 Homebrew
`setapp` cask，也不逐应用伪造 Nix 声明。新机器先安装 Setapp 客户端，再由维护者
人工登录恢复以下 14 个应用：

| 应用 | 盘点版本 | 重要可变边界 |
| --- | --- | --- |
| AirBuddy | 2.8.1 | 设备与偏好 |
| AlDente Pro | 1.38 | 电池策略与授权状态 |
| Bartender Pro | 6.5.2 | 菜单栏布局与授权状态 |
| CleanShot X | 4.8.8 | 录制、截图、云端和偏好 |
| CloudMounter | 4.18 | 云端账号、挂载与凭据 |
| Downie | 4.12.11 | 下载历史、媒体与偏好 |
| Paste | 6.6.2 | 剪贴板历史与同步状态 |
| Permute | 4.0.6 | 转码队列、输出和偏好 |
| PixelSnap | 2.6.4 | 偏好与运行状态 |
| Slidepad | 1.6.2 | 站点登录、Cookie 与布局 |
| Supercharge | 1.29.2 | 系统增强偏好与权限 |
| TablePlus | 26.7.9 | 数据库连接、凭据和 history |
| TextSniper | 1.12.1 | OCR history 与偏好 |
| Timing | 2026.4.1 | 时间记录、账号与同步状态 |

维护者已通过 Setapp 自行移除 Lungo、NotchNook、Sip 和 iStat Menus；它们不再维护。

## 9. 旧 dotfiles 与静态用户配置

| 对象 | 目标所有者 | 状态与边界 |
| --- | --- | --- |
| Atuin History CLI | Nix / Home Manager | CLI 已声明；Shell integration 继续由 Home Manager 管理 |
| Atuin 稳定配置 | Home Manager | 已批准待实施；不能覆盖 history、records 或 session 数据库 |
| Atuin key | 本机路径 `~/.local/share/atuin/key` | 仓库只声明路径边界，密钥内容不进入 Git 或 Nix Store |
| Atuin history / records / meta | Atuin 本机可变状态 | 不由 Nix 接管，依赖独立备份流程 |
| `.hushlogin` | Home Manager | 已批准创建空文件；不承载其他配置 |
| cmux 应用与配置 | 退役 | 不迁入 Nix；应用和 Chezmoi source 待独立清理批准 |
| `HOME.md` | 退役 | 当前目标已偏移，不迁移 |
| `rcm` | 退役 | 历史残留，不迁入 Nix |
| Chezmoi | 临时外部所有 | 保留到最后一个活动配置目标完成 handoff，再决定归档或卸载 |

Atuin Desktop 的安装与可变 Runbook 边界见前述 Nix GUI 表。Atuin key、数据库和
Desktop workspace 是三个不同状态域，不因 CLI/应用交给 Nix 就自动迁移。

## 10. 厂商、手工与有意试用应用

| 应用 | 当前安装/更新所有者 | 状态 | 恢复与数据边界 |
| --- | --- | --- | --- |
| AdsPower Global | SUNFLOWER TECH / 厂商安装器 | 外部所有，保留 | profile、Cookie、代理、凭据、团队、RPA/API 均为高敏感可变数据 |
| EVPlayer | 厂商安装器 / 自更新 | 外部所有，保留 | 待补官方恢复入口；媒体与历史外部 |
| 夸克网盘 | 厂商安装器 / 自更新 | 外部所有，保留 | 待补官方恢复入口；账号、同步与下载数据外部 |
| Collaborator | 手工/厂商，来源待确认 | 有意试用 | 待补恢复来源；账号、项目与 session 外部 |
| LiteEdit | 手工安装，来源待确认 | 有意试用 | 当前 app 为 ad-hoc/未确认签名；待补恢复来源 |
| Mole | tw93 厂商应用 / 内置更新 | 有意试用 | `com.tw93.MoleApp`；Nixpkgs 同名 `mole` 是 Darwin 上 broken 的 SSH tunnel CLI，不得替代；状态与偏好外部 |
| Multica | 厂商应用，adapter 待定 | 有意试用 | workspace、本地 daemon、账号和 Agent 状态外部 |
| Paseo | Homebrew `paseo` cask | 有意试用，已声明待验收 | Agent session 与 workspace 外部 |
| Syncless | LangGenius 签名应用，来源待确认 | 有意试用 | 待补恢复来源；账号、项目和运行态外部 |
| Vorssaint | Homebrew `vorssaint` cask | 有意试用，已声明待验收 | 菜单栏工具状态和偏好外部 |
| ChatGPT（原 Codex App，`com.openai.codex`） | Homebrew `chatgpt` cask | 已声明待验收 | 任务、账号与缓存外部 |
| ChatGPT Classic (`com.openai.chat`) | 当前厂商应用，恢复来源待确认 | 外部所有，保留 | 对话、账号与缓存外部 |
| Clash Verge | Homebrew `clash-verge-rev` cask | 已声明待验收 | 订阅、代理、凭据和日志外部 |
| Docker Desktop | Homebrew `docker-desktop` cask | 已声明 presence 待验收 | context、VM、镜像、容器、volume、网络和 helper 外部 |
| OrbStack | Homebrew cask | 待独立迁移 | 与 Docker 分开盘点；不假设二者数据可互换 |

OpenAI 两个应用必须按 bundle ID 区分。Homebrew `chatgpt` cask 已确认下载自 OpenAI
`codex-app-prod`，只对应 `com.openai.codex`；`com.openai.chat` 继续外部保留。

## 11. macOS 内建应用与用户级 helper

### 11.1 macOS 核心内建

`/System/Applications`、`/System/Applications/Utilities` 以及 bundle ID
`com.apple.Safari` 的 Safari 由 macOS 拥有。当前只记录 64 个系统应用的类别和来源，
不把它们加入 Nix、Homebrew 或 MAS，也不把系统版本携带的应用增删当作配置 drift。

GarageBand、Keynote、Numbers 和 Pages 虽由 Apple 提供，但可通过 App Store 独立恢复，
因此归入前述 MAS 表，不混入核心内建类别。Xcode Stable、Xcode Beta、Command Line
Tools 与 XcodeGen 共同构成 macbook 外部 Swift 工具链；仓库只记录事实与恢复入口，
不声明安装、版本选择、许可证、SDK/Simulator/组件或 `xcode-select`。

### 11.2 `~/Applications` 当前 helper

| 应用 | 当前事实 | 所有权 / disposition |
| --- | --- | --- |
| Claude Code URL Handler | bundle `com.anthropic.claude-code-url-handler` | Claude Code 生成的集成 helper，不单独声明安装 |
| Excalidraw | Chrome app bundle | 由 Chrome/PWA 环境拥有；浏览器 profile 不入库 |
| VTube Studio | 本地 wrapper 打开 Steam app ID 1325860 | 由 Steam 与本地游戏库拥有，不单独声明 package |

## 12. 已决定弃用或待清理的应用

以下决定只表示未来 disposition，不授权当前删除：

- cmux 应用与配置；
- `HOME.md` 与 `rcm`；
- Typora、Google Antigravity、`antigravity-tools`；
- Itsycal 与 Battery Buddy；原生菜单栏时钟和电池百分比已通过实机体验，
  两个第三方菜单栏应用后续定向清理；
- AltTab；原生 Command-Tab 与 Raycast 工作流已覆盖其用途；
- SideNotes；Apple Notes 作为苹果生态捕获箱，Obsidian 作为长期知识库；清理前先审查并迁移需要保留的笔记；
- Lark；不再声明 `lark` cask，现有 `Lark.app` 的账号、聊天、本地文件和缓存须在定向清理前单独审查；
- The Unarchiver；功能与保留的 iZip 高度重叠，不再声明 MAS 安装；
- Clash Nyanpasu 与 Clash Party；
- Zed Preview、旧 Zed cask和旧 Preview CLI；
- 旧 Homebrew VS Code cask与 `/Applications/Visual Studio Code.app`；
- cask 残留：`aionui`、`cc-switch`、`jordanbaird-ice`、`keycastr`、`shottr`、`warp`；
- `font-meslo-lg-nerd-font`；
- Setapp 已移除项：Lungo、NotchNook、Sip、iStat Menus；
- 前述退役 Homebrew formula。

Chezmoi 必须留到最后一个活动 dotfiles 目标完成 handoff；任何 cask、formula、应用、
tap 或文件删除必须使用独立 Issue、精确目标和当次人工批准。

## 13. Homebrew taps

| Tap | 当前 disposition |
| --- | --- |
| `lbjlaq/antigravity-manager` | 已批准待清理；当前不受信任，不能为盘点而 trust |
| `antoniorodr/memo` | 未决：待确认仍由哪个直接安装项使用 |
| `erictli/tap` | 已确认只为 `com.scratch.app` Markdown 应用提供 `erictli/tap/scratch`；#46 限定 trust |
| `farion1231/ccswitch` | 未决：`cc-switch` 已退役，但移除 tap 仍需依赖核对与批准 |
| `steipete/tap` | 未决：待确认仍由哪个直接安装项使用 |
| `yakitrak/yakitrak` | `obsidian-cli` / `notesmd-cli` 已退役；旧 tap 把 `obs` 错误迁移到 `notesmd-cli`，#46 使用 `homebrew/cask/obs` 绕开，tap 待后续定向清理 |

## 14. 明确未决项

以下项目阻止 #6 宣称“未分类项为零”，但不阻止本清单作为当前事实来源：

1. Collaborator、LiteEdit、Syncless 的可靠恢复来源。
2. Multica 的最终安装 adapter。
3. 四个尚未批准 disposition 的 Homebrew tap。
4. EVPlayer 与夸克网盘的官方恢复入口。
5. OrbStack 与 PostgreSQL 的独立迁移 Issue、数据备份和回滚计划。
6. Chezmoi 最后 handoff 与全部待清理项的精确卸载批次。
7. macOS defaults 由 #37 独立完成。

## 15. 建议实施批次

实施顺序以降低双重所有权和误删风险为目标：

1. **Nix CLI 与静态用户配置：** 新增批准的 CLI、Atuin 配置、`.hushlogin`，并为
   mise Elixir/Erlang 单独修订运行时合同。
2. **Nix GUI：** Atuin Desktop、Discord、IINA、LocalSend、MonitorControl、Mos、
   Obsidian、Upscayl、xbar 已由 #45 声明并完成基础实机验收；旧应用留到后续定向清理。
3. **Homebrew 与 MAS 声明：** #46 已写入批准的 casks 和 9 个 `masApps`；upgrade 关闭，
   cleanup 保持 `none`，Swift 工具链保持外部所有。
4. **外部应用恢复表：** 补齐厂商 URL、签名身份和人工恢复步骤，不接管可变状态。
5. **defaults：** 按 #37 逐组设计、实现与验证。
6. **定向清理：** 只有替代版本完成真实机器验收后，按 formula、cask、app、tap
   分批列出精确目标并再次批准。
7. **数据型迁移：** OrbStack 与 PostgreSQL 分别建 Issue，不与普通应用批次混合。
8. **最终 handoff：** Chezmoi 退出最后活动目标，更新 Mac runbook、激活前后差异和
   Phase 4 完成摘要。

## 16. 恢复与回滚原则

- Nix 管理的软件通过 Git、`flake.lock` 和上一代 nix-darwin generation 回滚。
- Homebrew/MAS 首次声明不启用升级或 cleanup；移除声明不等于已卸载应用。
- Setapp 通过客户端和人工登录恢复；订阅与应用数据不由 Git 恢复。
- 厂商应用通过清单中的官方入口恢复；来源未确认时必须先补证据。
- 可变状态、机密和业务数据使用各自备份/恢复流程，不能把 generation 回滚误报为
  数据回滚。
- 本清单自身是文档；回滚本清单只需 revert 文档 PR，不影响真实机器。
