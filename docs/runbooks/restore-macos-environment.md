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

### 2.5 验证声明式层

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

### 2.6 恢复外部软件

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

### 4.2 Homebrew 与 MAS

1. 先从声明中撤回问题项并构建验证；
2. 只有获得新的精确批准后，才定向卸载单个 cask/formula；
3. 默认设置 `HOMEBREW_NO_AUTOREMOVE=1`，防止 Homebrew 隐式回收范围外依赖；
4. 不使用 cleanup/zap；MAS 应用由 App Store receipt 与人工安装恢复。

### 4.3 Setapp、厂商应用与数据

Setapp/厂商应用通过其官方渠道重新安装。若 package 回滚后仍异常，分别恢复应用数据，
不要删除整个 `Application Support`、容器或数据库目录来“验证干净安装”。OrbStack 与
各消费方数据库需要各自的数据 runbook；没有恢复验证时不得执行破坏性迁移。

## 5. 后续变更流程

任何新增、删除或换源都先更新软件所有权 inventory，再建立窄 Issue/PR。Agent 可以完成
只读盘点、私有备份、构建和回滚清单；真实 activation 只由维护者执行。只有真实机器
验证与合并证据完成后，才更新本文的终态。
