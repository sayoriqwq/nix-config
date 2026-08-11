# macOS 环境恢复与回滚手册

本文是 `macbook` 的总体软件恢复入口。它恢复声明和应用来源，不是用户数据备份手册。
执行前先阅读 [`phase-4-macos-software-ownership.md`](../inventory/phase-4-macos-software-ownership.md)。

## 1. 恢复目标与禁止事项

恢复目标是让一台兼容 macOS 工作站重新获得：

- Lix、nix-darwin 与 Home Manager 管理的系统/用户声明；
- 已声明的 Homebrew cask 与 Mac App Store 应用；
- 外部应用的清晰人工恢复入口；
- 经批准的 macOS defaults；
- 可验证但不被 Git 接管的可变数据边界。

不要把以下内容提交到仓库或误认为 generation 能恢复：Apple/Setapp/应用账号、Atuin
key/history、浏览器 profile、编辑器登录态与 workspace、数据库、OrbStack VM/容器/volume、
云盘数据、许可证、SecretStorage、TCC 授权和任何私有备份。

## 2. 推荐恢复顺序

### 2.1 盘点与数据保护

1. 按 [`host-inventory.md`](host-inventory.md) 重新采集机器事实，不复用旧主机猜测。
2. 确认重要数据库、OrbStack、浏览器、编辑器和云盘数据已有独立可恢复备份。
3. 记录现有 `/Applications`、Homebrew/MAS receipts、当前 Nix generation 和外部应用身份。
4. 不运行 `brew cleanup`、`brew autoremove`、`brew uninstall --zap` 或批量删除应用。

### 2.2 Feishu 渠道与数据边界

Issue #74 曾从 Trash 恢复并人工验收旧 `Lark.app` 与核心数据，#81 随后明确当前目标
是中国区 `feishu` cask 与 `/Applications/Feishu.app`。#93 核验当前 Feishu 的 receipt、
bundle 与签名并取得维护者明确清理批准后，定向删除旧 `Lark.app`、全球版 `lark`
receipt/`LarkSuite.app` 和两个已批准的 Trash rollback 目录。当前恢复时：

1. 只从当前声明恢复 `feishu`，不要重新安装全球版 `lark` 作为并行来源；
2. `cleanup = "none"` 意味着 activation 不会替用户判断或删除现场已有应用；若目标路径
   冲突，先停止并盘点；
3. 安装后核验 Feishu 的 Homebrew receipt、bundle、Team ID 与签名，再由维护者验证
   中国区账号、工作区、聊天、本地文件和同步；
4. live `~/Library` 数据和仓库外私有备份属于用户数据恢复范围，不由 Nix generation
   创建、覆盖或删除。

Nix build 只能证明声明可构建，不能证明 Lark/Feishu 可变数据逻辑完整。若任何目标路径
已存在，停止并先建立私有备份/比较，不覆盖。

### 2.3 安装 Nix 系统层

1. 按 [`bootstrap-macos.md`](bootstrap-macos.md) 安装 Lix，并只构建目标
   `darwinConfigurations.macbook.system`。
2. Agent 完成私有 preflight 备份和 build；维护者单独批准并执行精确 commit 的
   `darwin-rebuild switch`。
3. 若首次启用 Zed Cachix，使用编辑器 runbook 中记录的精确 URL 与公钥完成 bootstrap，
   不全局开启 `accept-flake-config`。

首次 activation 将同时恢复 Nix/Home Manager 应用、CLI、静态配置、Homebrew cask、
MAS 声明和 defaults。它不会自动恢复外部数据。

### 2.4 AI CLI 激活顺序与验收

Issue #67 的四个命令只属于 macbook 的 `ai-assisted-operations` capability：
`codex` 0.146.0、`claude` 2.1.220、`agy` 1.1.9、`omp` 17.2.4。它们由
Nix/Home Manager 提供唯一的声明式 PATH 来源；Oh My Pi 使用固定官方 `darwin-arm64`
发布物，`claude-code` 不再是 Homebrew cask。
构建通过不代表已安装或已激活，且 activation 不清理现场未知副本。

维护者在审阅精确 commit 后按以下顺序操作：

1. 先完成本节 2.3 的 Nix build，确认版本和 lock file；
2. 另行批准并执行 nix-darwin/Home Manager activation；
3. 运行一次 RTK 的官方 Codex init，恢复由 RTK CLI 拥有的 `~/.codex/RTK.md`；Nix
   管理的 `AGENTS.md` 已包含绝对路径引用，因此当前版本应只创建或更新 RTK 自己的产物：

```fish
rtk init -g --codex
```

4. 完全退出并重新打开 Fish，在不继承 Codex 进程 PATH 的干净会话中执行：

```fish
type -a codex claude agy omp
command -s codex
command -s claude
command -s agy
command -s omp
codex --version
claude --version
agy --version
omp --version
rtk --version
rtk init -g --codex --show
```

四个 `command -s` 必须命中 Home Manager profile，版本分别符合上述锁定值。#93 已
删除旧 Homebrew Claude、手工 `agy` 和停用 mise Node 25 树；恢复流程不应重新创建这些
兼容副本。`ChatGPT.app` 及其 embedded Codex helper 继续保留为应用私有组成。

RTK 本体必须同样命中 Home Manager profile；`--show` 必须把 global `RTK.md` 与
`AGENTS.md` reference 都报告为 `[ok]`。不要把 `RTK.md` 复制进仓库或链接到 Nix Store；
后续 RTK package 升级后仍由维护者重新运行 `rtk init -g --codex` 刷新上游模板。

凭据、登录态、token、session、history、skills/hooks、cache、数据库以及 `~/.omp` 和
项目 Oh My Pi 状态继续保持可写且不进入 Nix Store；路径边界详见
[`macOS AI CLI 所有权`](../inventory/macos-ai-cli-ownership.md)。
本节只适用于 macbook；nixbox/server 不安装这些客户端，也不改变其迁移与恢复流程。

### 2.5 恢复 macOS 中文输入能力

该能力声明 Home Manager 可安全拥有的 Rime 静态数据：消费锁定 Darwin nixpkgs 中的
`pkgs.rime-ice` 2026.06.30，经薄 data view 排除整个 `build` 子树和所有已知可变名称，再合入
本地 `default.custom.yaml`。overlay 通过 `rime_ice_suggestion:/` 接入上游建议，只启用
`rime_ice`，并把左右 Shift 都声明为 Rime 内部中文/ASCII 切换键；合并结果以 recursive leaf
semantics 投影，用户目录根节点保持可写。恢复 Fcitx5 时，
从 [Fcitx5 macOS 官方 installer](https://github.com/fcitx-contrib/fcitx5-macos-installer)
人工安装 `/Library/Input Methods/Fcitx5.app` 及其 Rime plugin；应用 bundle、plugin payload
和 macOS 输入源不由 Nix 安装或修改。installer 的精确语义版本若仍无法由 bundle metadata
证明，应如实记录未知，不用猜测值填补。不要安装、启用、清理或迁移遗留 Squirrel。

`macbook-rime-data-layout` 中对 `2026.06.30` 的单一静态 policy check 是刻意的
update-policy gate：Darwin nixpkgs lock 将来提供不同 `pkgs.rime-ice` 版本时，该 check 失败
表示需要先审阅新版本、package output/data-view、overlay 兼容性与 deploy 需求，不表示 nixpkgs
channel 本身损坏，也不表示单独的 macbook system build 必然失败。只有在独立获批的依赖更新中
完成这些审阅后，才同步更新版本 gate；不要为了让 check 继续通过而静默放宽策略。

`~/.config/fcitx5` 和其中配置文件始终是 Fcitx-owned、可写的外部状态。能力不得 raw patch
INI、用 Store symlink 接管整文件、调用配置 API 或阻塞 activation 审计运行时字段。为保持
目标体验，维护者在 Fcitx GUI 中人工复核以下推荐值：全局共享输入状态、清空 Terminal 应用
默认输入法、隐藏输入法名称，并把 `AltTriggerKeys` 设为空。Fcitx 不再用普通左右 Shift 在
`rime` 与 `keyboard-us` 之间临时切换；`Control+Shift_L` 保留为显式的完整恢复键。这些值是
external reference，不是 Nix Desired/Keep；菜单栏“小企鹅”、MacVim、剪贴板、Beast 和其他
偏好也都由 Fcitx/用户拥有。

排障时必须区分三层状态：macOS 输入源菜单顶层的“小企鹅”表示系统仍选择 Fcitx；其下的
“中州韵 / 键盘 - 英语（美国）”勾选表示 Fcitx 当前引擎；只有勾选“中州韵”时，普通左右
Shift 才由 Rime 在中文与 ASCII mode 之间切换，且勾选不会移动。若勾选落到“键盘 - 英语
（美国）”，这是 Fcitx 切到了 fallback engine，不是 Rime 英文模式；应使用保留的
`Control+Shift_L` 恢复到 Rime，再检查 `AltTriggerKeys` 是否为空。

2026-08-11 已确认 Terminal `AppDefaultIM → keyboard-us` 与 `ShareInputState=All` 的组合会把
English 状态传播到其他应用。维护者批准窗口内已用官方 API 清空 live `AppDefaultIM`，
运行时探针由 `2 → 1 → 1` 变为 `2 → 2 → 2`；未 raw patch、restart、deploy 或 activation。
这只是已验证的历史 live mitigation，不是当前 Nix 合同。对应 owner-only 应急副本只用于
回退该次操作，不是 Nix generation rollback。

当前 `macbook` 的首次静态所有权交接已经完成。Issue #127 记录的终态证据为：配置提交
`87d801c85bc3f6f1b5334a00aefccfbe3ecefe73` 已 activation，system generation 从 42 切换到
43；65/65 个静态叶子均为有效 Store symlink；9/9 个可变状态边界保持可写且不在 Store；
Fcitx5 仍为 selected input source；Rime 重新部署与真实输入验收均为 PASS。接管前 65 项
checksum 与 `RELEASED` 清单已验证，owner-only rollback evidence 继续保留在仓库外且不由
仓库读取、移动、重新打包或管理。Squirrel、userdb、sync 与 Fcitx5 外部状态未被该次
activation 接管或清理。

#131 已退役仅服务首次 regular-file 交接的写入型 helper。#140 同时退役逐 leaf manifest、公开
runtime preflight、Fcitx behavior adapter/journal/rollback helper；长期检查只证明 package output、
data-view 过滤、overlay 冲突和投影布局，不读取 live Fcitx 偏好或 userdb 正文。

未来新机器若目标路径存在 unmanaged regular files，不得直接覆盖或复用历史 helper。必须另开
Issue，记录目标机器、exact commit、执行窗口和 mutable-state 保护证据，再按当时 live facts
设计窄交接。`luna_pinyin.userdb`、`rime_ice.userdb`、`installation.yaml`、`user.yaml` 与
`~/.config/fcitx5` 按 required 边界保护；`sync` 与 `~/Library/fcitx5` 按 separate-policy 处理；
Rime `build` 和 Fcitx cache 可重建且排除备份；`~/Library/Rime` 与 Squirrel 全部保持不变。

获批的 activation 只应用 Nix/Home Manager 静态 declaration，不修改 Fcitx 输入源、配置字段，
不停止或重启 Fcitx5，也不触发 Rime deploy。#143 的 Shift overlay 变更在获得 exact
commit/current-window 批准前不得 activation；build 或文档完成不表示真实机器已经应用。

仅在首次引入、恢复或实际变更 local overlay 时，维护者才在可观察、可回滚的窗口人工重新部署
Rime。需要 deploy 时，当前 bundle
已确认存在官方 `fcitx5-curl`，使用官方 Rime deploy 端点：

```fish
/Library/Input\ Methods/Fcitx5.app/Contents/bin/fcitx5-curl /config/addon/rime/deploy -X POST -d '{}'
```

⌨️ 通过 Fcitx5 官方本地 API 重新部署 Rime，使新的 data view 与本地 overlay 生效；执行前仍需当前窗口人工批准。

完成适用的 activation，以及仅在需要时完成 deploy 后，至少完成以下实机验收：

1. macOS selected input source 仍为 Fcitx5 简体输入模式，Fcitx profile 默认输入法仍为
   Rime，可选 schema 只有 `rime_ice`；
2. 在飞书日报、Terminal、一个 macOS 原生应用和一个浏览器输入框验证中文输入；切入
   Terminal 再返回时保持 Rime，不再出现 `2 → 1 → 1`；
3. Fcitx `AltTriggerKeys` 为空；左右 Shift 都只在 Rime 内部执行中文/ASCII 切换，菜单勾选始终
   保持“中州韵”；`Control+Shift_L` 仍能作为完整 Fcitx 恢复键，状态栏保持隐藏且菜单栏只
   显示“小企鹅”；
4. 新输入仍能更新 userdb，既有 userdb、sync、installation/user state 均保留；
5. Fcitx5 bundle/plugin、Squirrel、nixbox/server、launchd/service、network 与 firewall
   均未被该能力改变。

在维护者把当前 Issue 要求的 activation 与输入结果记录到 Issue/PR 前，文档只能称本次增量的
“声明目标已建立”；activation 与 deploy 必须分别批准和记录。

### 2.6 验证声明式层

在全新登录 shell 中检查：

```fish
command -s fish
command -s git
command -s uv
command -s code
command -s zed
echo $EDITOR
echo $VISUAL
```

然后验证 Ghostty/WezTerm、VS Code/Zed、Nix GUI、Dock/Finder、键盘、Trackpad、右下角
Quick Note、菜单栏时钟和电池。应用设置与 Shell PATH 必须在真实终端会话验证，不能用
Codex 进程继承的 PATH 代替。

### 2.7 恢复外部软件

按所有权逐层恢复，避免同一路径出现两个写入者：

1. **Mac App Store：** 人工登录，确认 9 个 receipt；Xcode Stable 不恢复。
2. **Setapp：** 安装官方客户端、人工登录，恢复 inventory 中的 14 个应用。
3. **Swift 工具链：** 按项目需要安装 Xcode Beta、Command Line Tools、SDK/Simulator，
   再验证外部 XcodeGen；仓库不替你接受许可证。
4. **厂商/手工应用：** 只从 inventory 中的官方入口恢复，并核对 bundle ID/Team ID。
5. **外部 formula：** 只按当前需求恢复 XcodeGen 等明确 owner；不要恢复已由 Issue #60
   退役的全局 PostgreSQL 16。项目 Python 由 uv 按项目声明重建，不恢复 Homebrew Python
   兼容层。
6. **数据：** 最后按各应用自己的恢复流程恢复数据库、容器、vault、profile、账号和历史。

## 3. 所有权验收

恢复完成后至少确认：

- Nix 应用只来自 Home Manager Apps，不存在旧 VS Code、Zed Preview 或 #61 所列七个
  `/Applications` rollback bundle；
- Homebrew Bundle 恰好声明 1 个 tap、28 个 cask、9 个 MAS app、0 个 formula；不再声明
  `claude-code`，正常环境也不存在旧 `/opt/homebrew` Claude；
- 干净 Fish 中 `codex`、`claude`、`agy`、`omp` 的首个 PATH 来源均为 Home Manager
  profile，版本分别为 0.146.0、2.1.220、1.1.9、17.2.4；
- 通信应用声明为中国区 `feishu`，不再声明全球版 `lark`；
- 不存在旧 `Lark.app`、`LarkSuite.app`、`lark` receipt 或 #57/#61 的 Trash rollback
  目录；live 应用数据仍按外部数据验收；
- `homebrew.onActivation.cleanup = "none"`；
- `ChatGPT.app` 是 `com.openai.codex`，`ChatGPT Classic.app` 是 `com.openai.chat`；
- OrbStack 是唯一容器运行时，`docker ps` 在启动 OrbStack 后正常；
- Atuin 配置和 `.hushlogin` 来自 Nix Store，但 key/history 保持本机可写状态；
- macOS 中文输入消费锁定 Darwin nixpkgs 的 `pkgs.rime-ice` 2026.06.30，经薄 data view 合入
  本地 overlay 并递归投影静态 leaves；Fcitx5.app、plugin、输入源、可写配置与全部 GUI/runtime
  偏好仍由各自 owner 管理，且已分别记录人工 activation、deploy 与真实输入 smoke；
- `~/.local/share/chezmoi` 不再 apply，旧 dotfiles 不再参与配置生成；
- OrbStack、编辑器、浏览器、Setapp 数据以及 AI CLI 的状态/凭据没有被 activation
  覆盖；数据库由各消费方自己的恢复流程处理。

## 4. 回滚顺序

### 4.1 Nix 与 defaults

优先使用上一代 system generation：

```fish
sudo darwin-rebuild --rollback switch
```

该命令恢复 Nix 声明，不撤销 Homebrew 已完成的 adoption/MAS 安装，也不回滚数据或 AI
CLI 的状态。macOS defaults 的逐键试用前值和定向回滚命令见
[`phase-4-macos-defaults.md`](../inventory/phase-4-macos-defaults.md)。

### 4.2 macOS 中文输入

中文输入异常时，Nix-owned 静态文件、Fcitx 外部状态与用户数据是三个不同边界，按以下顺序
停止并回滚：

1. 先检查候选旧 generation 的配置来源和行为语义。若它早于 #140，可能重新包含
   activation-time Fcitx behavior provider，并在 activation 时通过官方 API POST 旧 Desired；
   必须在当前窗口单独记录和批准这项副作用，不能把 generation rollback 当成静态-only 动作；
2. 通过上述人工关卡后，选择 activation 前记录的 nix-darwin generation；
3. 上一代恢复其自身 Nix-owned 的 Rime 静态声明与 overlay；#140 之后的 generation 使用薄
   data view，#140 之前的 generation 可能恢复旧 65-leaf closure；
4. generation rollback 不会自动恢复 Fcitx GUI/runtime 偏好的“正确值”。当前 #140 终态不再
   提供行为 rollback helper；若旧 provider 未被允许运行或偏好仍异常，通过 Fcitx GUI 对照本节
   推荐值人工修正。2026-08-11 的 owner-only live 应急副本只可回退对应事故缓解，不可作为
   通用回滚来源；
5. 保留 `luna_pinyin.userdb`、`rime_ice.userdb`、`sync`、`installation.yaml`、
   `user.yaml` 与 Fcitx 可变状态；只有出现数据损坏证据时才按对应备份策略恢复，禁止为
   回滚清空 Rime 用户目录或无条件覆盖当前 userdb；
6. 仅当该回滚实际改变静态 overlay 或 compiled Rime 配置时，由维护者人工重新部署 Rime；
   只有另有证据和当前批准时才重启 Fcitx5；随后重新完成
   飞书、Terminal、原生应用与浏览器的输入、左右 Shift、候选、userdb 可写性和既有状态验收，
   并在 Issue/PR 记录结果。

若上一代移除 Home Manager 静态链接且目标已有 unmanaged regular files，必须使用独立 Issue
审阅并批准的窄流程恢复；不得恢复或覆盖 userdb、sync，也不自动重新部署 Rime。

切回 generation 只能恢复 Nix declaration 和 Nix-owned 静态 leaf，不能恢复用户学习数据、
sync、installation/user state、Fcitx 配置/plugin/偏好或 Squirrel 遗留状态。任何回滚、重启或
重新部署仍需当前 Issue/PR 中针对 exact commit 与执行窗口的人工批准。

### 4.3 Homebrew 与 MAS

1. 先从声明中撤回问题项并构建验证；
2. 只有获得新的精确批准后，才定向卸载单个 cask/formula；
3. 默认设置 `HOMEBREW_NO_AUTOREMOVE=1`，防止 Homebrew 隐式回收范围外依赖；
4. 不使用 cleanup/zap；MAS 应用由 App Store receipt 与人工安装恢复。

### 4.4 Setapp、厂商应用与数据

Setapp/厂商应用通过其官方渠道重新安装。若 package 回滚后仍异常，分别恢复应用数据，
不要删除整个 `Application Support`、容器或数据库目录来“验证干净安装”。OrbStack 与
各消费方数据库需要各自的数据 runbook；没有恢复验证时不得执行破坏性迁移。

## 5. 后续变更流程

任何新增、删除或换源都先更新软件所有权 inventory，再建立窄 Issue/PR。Agent 可以完成
只读盘点、私有备份、构建和回滚清单；真实 activation 只由维护者执行。只有真实机器
验证与合并证据完成后，才更新本文的终态。
