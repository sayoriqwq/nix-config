# Phase 4 macOS 软件所有权终态

- **机器：** `macbook`
- **收口日期：** 2026-07-28
- **维护修订：** 2026-08-03，Issue #74 恢复 Lark 数据，#81 将当前渠道更正为中国区
  Feishu，#67 增加 agent Python 基线并收口四个 AI CLI 所有权，#93 清理已验收替代的
  迁移残留；2026-08-10，Issue #127 增加并验收 macOS 中文输入能力的首次静态所有权交接，
  Issue #131 退役该次交接的写入型 helper；2026-08-11，Issue #139 完成中文输入维护边界
  研究，Issue #140 采用静态 data-view 终态并退役 Fcitx runtime provider，Issue #143 完成
  Shift ownership 调整，Issue #145 取代其 fallback 决策，目标是移除用户可见的恢复通道；
  2026-08-12，Issue #147 的 Gate A 证明候选 app 身份，Gate B/C 完成 owner-only backup 与
  四个精确 Squirrel 遗留对象的 live retirement；真人输入 smoke 仍等待 Gate D
- **决策来源：** Issue #6、#36、#127、#131、#139、#140、#143、#145、#147 及 Phase 4 各实施 Issue
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
| Fcitx5 官方 installer/updater | `Fcitx5.app`、Rime plugin payload 与应用更新 | [Fcitx5 macOS installer](https://github.com/fcitx-contrib/fcitx5-macos-installer)、人工输入源注册 |
| 厂商/手工 | 不能可靠声明或有意试用的应用 | 本文的官方入口与签名身份 |
| Homebrew 外部 formula | XcodeGen 与两个遗留 leaf formula | 当前本机状态；不属于声明式基线 |

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
- 数据库工具链和运行态由实际消费方声明，不进入全局用户 profile；旧 PostgreSQL 16 已由
  Issue #60 完成退役。

### 3.2 GUI、终端与编辑器

| 应用 | Nix 所有权 | 可变状态边界 |
| --- | --- | --- |
| Atuin Desktop | package | key、history、records、session 与 workspace 外部 |
| Discord | package | 登录态、缓存与更新状态外部 |
| Ghostty | package 与核心配置 | scrollback、窗口和运行态外部 |
| IINA | package | history、播放列表和偏好外部 |
| LocalSend | package | 设备、历史与接收目录外部 |
| MonitorControl | package | 显示器设备状态与偏好外部 |
| Mos | package 与一次性登录 LaunchAgent | 鼠标设备状态与偏好外部 |
| Obsidian | package | vault、插件、同步与应用状态外部 |
| Upscayl | package | 模型、缓存与输出外部 |
| Visual Studio Code | package与 seed-only settings baseline | 扩展、登录态、history、workspace 与 live settings 可写 |
| WezTerm | package 与核心配置 | scrollback、窗口和运行态外部 |
| xbar | package | plugins、缓存与运行态外部 |
| Zed Nightly | 上游 Flake 固定 package 与 seed-only baseline | 扩展、登录态、workspace/session 与 live settings 可写 |

Nix 应用在 macOS 上由 Home Manager 复制到 `~/Applications/Home Manager Apps`。编辑器
只在 live 配置缺失时初始化 baseline，之后通过人工审查回流，不做双向自动同步。
Issue #124 为 Mos 增加 `org.nix-community.home.mos` GUI LaunchAgent：登录时只打开
Home Manager Apps 中的当前 bundle，不保活 GUI 进程，也不接管 Mos 的可变偏好或 TCC
授权。完整启动项边界见 [`macOS 登录项与 launchd 盘点`](macos-startup-items.md)。

最终审计发现 Atuin、Discord、IINA、MonitorControl、Mos、Obsidian 与 Upscayl 曾各有
一份 activation 前保留的 `/Applications` rollback bundle。Issue #61 已在不删除共享
配置、账号、vault、history 或缓存的前提下把七个旧 bundle 移入可恢复 Trash；对应 Nix
应用与数据路径均通过验证。LocalSend 与 xbar 的旧 Homebrew 副本此前已由 #56 清理。
#93 在这些 Nix 应用继续通过 presence 验收后永久删除了 #61 的精确 Trash rollback
目录；应用配置、账号、vault、history 和缓存仍保持外部。

### 3.3 macOS 中文输入能力

`macbook` 通过一次显式 import 选择纯 Home Manager 的 macOS 中文输入能力。其声明目标
是消费当前 Darwin nixpkgs 锁定的 `pkgs.rime-ice` 2026.06.30。能力从
`$out/share/rime-data` 构造薄 data view：排除整个 `build` 子树，拒绝 userdb、sync、
`installation.yaml`、`user.yaml` 等可变名称，并在上游同名冲突时失败关闭地合入本地
`default.custom.yaml`。单一合并结果以 recursive leaf semantics 投影到用户目录；仓库不
vendor 上游源码、不建立个人 Rime 仓库，也不管理 `~/.local/share/fcitx5/rime` 根节点。

`macbook-rime-data-layout` 中对 `2026.06.30` 的单一静态 policy check 是刻意的
update-policy gate，不是对 nixpkgs channel 可用性的假设或故障兜底。未来 Darwin nixpkgs lock
带来新的 `pkgs.rime-ice` 版本时，该 check 应先失败，要求维护者审阅版本、package
output/data-view 边界、overlay 兼容性以及是否需要独立 Rime deploy，再在获批更新中同步推进
该 gate；这不表示单独的 macbook system build 必然失败，也不应被误诊为 channel breakage。

安装与运行时所有权保持分离：

- `/Library/Input Methods/Fcitx5.app`、其 Rime plugin/shared payload 与应用内更新由
  Fcitx5 官方 macOS installer/updater 外部拥有；当前 bundle ID 为
  `org.fcitx.inputmethod.Fcitx5`，但 installer 的精确语义版本尚无法由 bundle metadata
  证明；
- macOS 输入源注册与当前选择由 macOS/runtime 和维护者拥有；Home Manager 不修改输入源
  数据库、不 kill 或更新 Fcitx5，也不在 activation 中触发 Rime deploy；
- `pkgs.rime-ice`、过滤/合并 data view 和本地 overlay 的静态内容由 Home Manager 拥有；
  能力不再维护上游 leaf allowlist，也不把 raw package output 递归投影到用户目录。data view
  必须保留 `pkgs.rime-ice` 随发行提供的静态 `squirrel.yaml`；它只是 Rime 静态兼容内容，
  不安装、启用或接管 Squirrel app；
- 本地 overlay 通过 `__include: rime_ice_suggestion:/` 接入 nixpkgs 重命名后的上游建议，
  只启用 `rime_ice`，并显式把左右 Shift 都声明为 Rime 内部中文/ASCII 切换键；它不改变
  简繁、标点或用户数据；
- `~/.config/fcitx5` 及其中 regular files 继续由 Fcitx5 外部拥有并保持可写。能力不得 raw
  patch INI、接管整文件、建立 Store symlink、调用配置 API 或审计运行时字段；
- `ShareInputState=All`、有效 `AppDefaultIM` 为空、`StatusBar=Hidden`、`Default` group 唯一
  item 为 `rime`、`DefaultIM=rime`、`Default Layout=us`，以及 Fcitx `TriggerKeys` 与
  `AltTriggerKeys` 均为空，是维护者通过 Fcitx GUI/官方 API 维护的推荐体验，不是 Nix
  Desired/Keep；普通左右 Shift 属于 Rime，不保留完整 Fcitx trigger 或菜单 fallback；
- Issue #147 只允许退役 `/Applications/Disabled Input Methods/Squirrel.app`、receipt
  `im.rime.inputmethod.Squirrel`、`~/Library/Preferences/im.rime.inputmethod.Squirrel.plist`
  与 `~/Library/Caches/im.rime.inputmethod.Squirrel` 四个精确对象。Gate A 已用 digest 与签名
  均验证通过的官方 1.1.2 installer 证明候选 app 的签名主体及共同文件与原始 bundle 一致；
  live bundle 仅增加 installer 在 `SharedSupport` 执行 build 产生的 `build`、
  `installation.yaml` 与 `user.yaml`，未在 bundle 内单独清理。2026-08-12 获批的 Gate B
  在仓库外建立 mode `0700` 的
  `~/Library/Application Support/nix-config/rollback/issue-147-squirrel-1.1.2-20260812`；
  mode `0600` 的 app archive SHA-256 为
  `0ccba1984a065506bd8ae200e1d3d6875eafe50b8110fea68112ab36ca310f45`，preference copy
  与源逐字节一致，SHA-256 均为
  `c8e8ed391c597ae928440f14e4b4d3eaa6e9ffe5f462452f5c397e85f5fdba71`；
- 同一当前窗口获批的 Gate C 在首次 mutation 前重新核验无 Squirrel consumer、input-source
  与 Fcitx 正向基线，并在每个 filesystem mutation 紧邻前重新核验对应 source token；跨越
  receipt boundary 前又完整回读三个 destination、consumer、input-source、Fcitx 与 receipt。
  app、preference 与 cache 随后以原 inode 同卷移动到
  `~/.Trash/Squirrel-retirement-issue-147-20260812` 下三个精确对象，receipt 最后仅通过
  `pkgutil --forget im.rime.inputmethod.Squirrel` 忘记。独立回读确认三个原路径不存在、
  receipt 不存在、Squirrel process 及 enabled/selected source 均不存在，Fcitx5 的 zhHans
  selected source、唯一精确进程与签名仍正常。未 kill `cfprefsd` 或调用 `defaults delete`，
  preference absence 是本次回读事实；临时 helper 已删除且未进入 Git。Gate D 真人输入 smoke
  完成前不得关闭 Issue 或把整项维护称为完成。Squirrel 专属 `squirrel.custom.yaml` 不在
  清理范围；
- `~/Library/Rime` 是本次与未来同类 cleanup 的永久 opaque 排除树：不得遍历、列举、读取、
  stat、hash、copy、move 或 delete，也不得用 glob 或猜测路径间接触碰。

2026-08-11 已确认的故障链路是：macOS frontend 的 Terminal `AppDefaultIM` 主动选择
`keyboard-us`，随后全局 `ShareInputState=All` 把 inactive 状态传播到其他 input context。
运行时 red/green 探针从 `2 → 1 → 1` 变为 `2 → 2 → 2`；维护者批准窗口内已用官方
`fcitx5-curl` 清空 live `AppDefaultIM`，未 raw patch、restart、deploy 或 activation。
该 live mitigation 已验证，但它属于历史事故处理证据，不是 #140 终态的声明式合同。

Issue #143 已完成左右 Shift ownership 调整：普通左右 Shift 只在 Rime 内部切换中文/ASCII
mode。Issue #145 又取代 #143 保留 fallback 的决策，目标是让 `Default` group 只含 `rime`，
并清空 `TriggerKeys` 与 `AltTriggerKeys`；菜单不再显示“键盘 - 英语（美国）”，也不保留
`Control+Shift_L` 等人工切出 Rime 的通道。`DefaultIM=rime` 与 `Default Layout=us` 保持不变。
本 PR 只建立文档目标；live profile/API mutation 与真人 smoke 尚未完成，不能描述为机器终态。

从 group 移除 `keyboard-us` 不删除 keyboard addon 或系统 keyboard resources。密码/安全输入在
`AllowInputMethodForPassword=False` 时仍可由 Fcitx core 使用底层 `keyboard-us`，且配置无效时
core 可能重建默认 group；这些属于安全与自愈机制，不是用户菜单 fallback，也不是恢复通道。

维护者随后确认，live `StatusBar=Hidden` 来自本人在 Fcitx5 UI 点击“隐藏输入法名称”，并在
Issue #134 中曾批准把这个已验收结果升级为 adapter-owned Desired。Issue #140 采用新的维护
边界后，仓库仍不拥有 `macosfrontend.conf` 文件，也不再拥有该标量、另外两个字段或其
API/journal/rollback 生命周期；这些值只作为人工推荐值保留。

可变状态只登记路径、内容 owner 与备份边界，不读取词条正文、不链接到 Nix Store：

| 路径 | 内容所有者 | 备份边界 | 说明 |
| --- | --- | --- | --- |
| `~/.local/share/fcitx5/rime/build` | Rime | excluded | 可从静态方案重新生成的部署缓存。 |
| `~/.local/share/fcitx5/rime/luna_pinyin.userdb` | Rime | required | 用户学习数据，禁止读取正文或无条件覆盖。 |
| `~/.local/share/fcitx5/rime/rime_ice.userdb` | Rime | required | 用户学习数据，禁止读取正文或无条件覆盖。 |
| `~/.local/share/fcitx5/rime/sync` | Rime | separate-policy | 同步导出状态；仓库不实现同步或备份。 |
| `~/.local/share/fcitx5/rime/installation.yaml` | Rime | required | 可写 installation identity。 |
| `~/.local/share/fcitx5/rime/user.yaml` | Rime | required | 可写用户运行与部署状态。 |
| `~/.config/fcitx5` | Fcitx5 | required | Fcitx profile、GUI 偏好与用户配置，整棵目录及配置文件保持应用可写；Nix 不调用配置 API，也不取得字段或文件所有权。 |
| `~/Library/fcitx5` | Fcitx5/plugin | separate-policy | plugin/shared payload 与应用状态，继续外部所有。 |
| `~/Library/Caches/org.fcitx.inputmethod.Fcitx5` | Fcitx5 | excluded | 可重建 cache，不属于备份承诺。 |

Issue #127 已建立 65 个上游 leaf 的声明、policy check、只读 preflight 和恢复合同，并在
配置提交 `87d801c85bc3f6f1b5334a00aefccfbe3ecefe73` 完成首次实机交接：system generation
42→43，65/65 个静态 leaf 均为有效 Store symlink，9/9 个可变状态边界保持可写且不在
Store，Fcitx5 仍为 selected input source，Rime 重新部署与真实输入均为 PASS。接管前 65 项
checksum 与 `RELEASED` 清单已经核验；仓库外 owner-only rollback evidence 继续保留且不由
仓库读取、移动、重新打包或管理。#131 只退役服务该次 regular-file 交接的写入型 helper；
这些历史数字与 evidence 不再构成当前逐 leaf manifest 或 runtime preflight 合同。未来新机器若
再次需要 unmanaged-file handoff，必须另开 Issue，根据当时 live facts 与 exact commit 重新
提供窄入口并取得人工批准。

Issue #132 和 #134 曾引入本地 overlay 与三个 Fcitx 行为 Desired。Issue #140 已把静态来源
收敛为 `pkgs.rime-ice` 2026.06.30 + 薄 data view，并删除行为 Desired/Keep、runtime preflight、
journal 与 rollback helper；Issue #143 完成 Nix-owned Rime Shift overlay 与 external
`AltTriggerKeys` 调整，#145 只进一步修改 external group/trigger 目标，不恢复 Nix provider。
文档声明不表示 #145 已修改 live profile/API 或完成真人 smoke。已完成的历史 live 应急副本
不能被描述为 generation rollback。详细顺序见
[`restore-macos-environment.md`](../runbooks/restore-macos-environment.md)。

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

nix-darwin 不声明任何 Homebrew formula。#60 收口后，当前实机的 3 个 formula 均属 Homebrew
外部状态：

| 类型 | formula | disposition |
| --- | --- | --- |
| Swift 工具链 | `xcodegen` | 当前 Swift 项目依赖；与 Xcode Beta 一起保持 macbook 外部所有 |
| 遗留 leaf | `icu4c@78`、`sqlite` | 不属于全局声明，也不再归 PostgreSQL 所有；是否删除需后续独立证据与批准 |

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
Issue #124 按维护者要求移除了 AlDente Pro 与 Bartender 的登录启动记录；应用及数据保持
不变。Bartender 只在携带 Mac 外出、使用内建屏幕时可能需要，可通过 Raycast 按需启动。

## 7. 厂商、手工与有意试用应用

| 应用 | 恢复入口 / 身份 | disposition 与数据边界 |
| --- | --- | --- |
| AdsPower Global | [官方站点](https://www.adspower.com/)，bundle `com.adspower.global`，Team ID `Y28UF294S5` | 保留；profile、Cookie、代理、凭据和团队状态外部 |
| Alice in Cradle | 当前手工应用 | 明确保留；游戏数据与更新流程外部 |
| ChatGPT Classic | [OpenAI](https://openai.com/chatgpt/desktop/)，bundle `com.openai.chat` | 保留，与 Homebrew ChatGPT/Codex 身份分离；账号和对话外部 |
| Collaborator | [官网](https://collab.computer/)、[GitHub releases](https://github.com/collabs-inc/collab-public/releases)，Team ID `93MDU2WLAD` | 保留；账号、项目与 session 外部 |
| EVPlayer | [Mac App Store 1190222875](https://apps.apple.com/app/id1190222875)，bundle `cn.ieway.EVPlayer` | 保留；媒体和 history 外部 |
| Fcitx5 | [官方 macOS installer](https://github.com/fcitx-contrib/fcitx5-macos-installer)，bundle `org.fcitx.inputmethod.Fcitx5` | `/Library/Input Methods/Fcitx5.app`、Rime plugin、updater、输入源注册与全部 GUI/runtime 偏好保持外部；bundle metadata 无法证明 installer 精确语义版本。Home Manager 只拥有 3.3 节列出的 `pkgs.rime-ice` 薄静态 data view 与 overlay，不拥有应用或混合用户树。 |
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
| Docker Desktop 与 OrbStack helper 冲突 | OrbStack 是唯一容器运行时；#124 已卸载并备份旧 Docker Desktop socket/vmnetd helper |
| 大量旧 formula、cask、tap 与退役应用残留 | #55–#57 已精确定向清理；未运行全局 cleanup 或 zap |
| macOS defaults 多数依赖现场手调 | 只声明维护者逐项体验批准的 Dock、Finder、输入、手势、窗口、时钟和电池行为 |
| 旧 dotfiles/Chezmoi 仍可能被误认为活动配置源 | `nix-config` 是唯一活动配置源；旧仓库冻结归档 |

已退役的软件包括 AltTab、Battery Buddy、cmux、Docker Desktop、旧 Google Antigravity GUI、
Itsycal、SideNotes、The Unarchiver、Typeless、Typora、旧 VS Code、Zed Preview、
Warp 及 #55/#56 中列出的旧 formula/cask。删除均通过窄 Issue 和明确批准完成。#93
又在核对精确路径后永久删除 #57/#61 的两个 Trash rollback 目录；仓库外私有备份及
应用 live 数据不在清理范围内。

#124 又清理了 iStat Menus、cDock、Nyanpasu、Mihomo Party 与 Docker Desktop 留下的
8 个孤儿 launchd label，并移除了 6 个已经无法解析目标的旧登录项。MEGAsync、
AlDente Pro、FigmaAgent 与 Bartender 应用继续由原 owner 管理，只是不再登录启动；该
清理不删除它们的应用或数据。

Lark 曾在 #57 中按当时决定退役，旧 `Lark.app` 与专属数据被移动到可恢复 Trash。#74
恢复并人工验收了旧应用与数据，随后全球版 `lark` cask 安装了 `LarkSuite.app`。维护者
在 #81 明确把当前产品要求更正为中国区 Feishu，因此声明改为 `feishu`。#93 核验当前
Feishu 的 receipt、bundle 与签名并取得明确清理批准后，删除两份旧 Lark 应用、`lark`
receipt 和两个已批准的 Trash rollback 目录；当前只保留声明的 Feishu 应用。聊天、
登录态、数据库及其他 live 数据仍不交给 Nix，也未随应用清理删除。

## 10. 已知延期与回滚边界

- PostgreSQL 16 的 package、service 与已批准数据目录已由 Issue #60 删除；本仓库不提供
  替代的全局数据库服务，也不把消费方配置提升为基础设施要求。
- OrbStack 的应用由 Homebrew cask声明；其可变容器数据永远需要独立备份/恢复流程。
- Nix generation 回滚只恢复声明和 Nix-owned package 链接；不能回滚 Homebrew adoption、
  MAS receipt、Setapp 登录、厂商应用数据、数据库或容器。
- macOS 中文输入在 #140 及其后续 generation 中只恢复 Nix-owned 的 Rime 静态 data view 与
  overlay，不恢复 Rime `build`、userdb、sync、installation/user state、Fcitx plugin/config
  或任何 GUI 偏好，且仓库不再提供字段级 rollback helper。但切回 #140 之前的旧 generation
  可能重新带回旧 activation-time Fcitx behavior provider，并在 activation 时通过官方 API POST
  旧 Desired 值；执行这种旧 generation 前必须人工审阅该 closure 的行为语义并单独批准，不能
  把“当前终态不拥有偏好”误认为旧 generation 也不会修改偏好。2026-08-11 的 live 应急副本只
  可用于对应事故缓解的定向回退，不是通用 generation rollback。若目标上有 unmanaged regular
  files，必须按独立 Issue 的窄流程处理，保留全部 mutable state，再由维护者人工 deploy Rime
  并完成输入 smoke test。
- Homebrew/MAS/Setapp/厂商应用的具体恢复和故障顺序见 Mac 总体 runbook。
- #93 还发现并精确删除六个指向已删除 Docker、WARP 与 Zed Preview 应用的 root-owned
  `/usr/local/bin` 悬空链接。删除后 `docker`/`kubectl` 继续由 OrbStack 提供，`zed` 只
  命中 Nix profile，WARP 与 `cagent` 不再有命令入口。
