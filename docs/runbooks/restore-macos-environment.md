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

### 2.2 当前机器的 Lark 恢复关卡

Issue #74 确认旧 `Lark.app` 与专属数据仍在
`~/.Trash/nix-config-phase4-retired-apps.sTa1Cr`。在当前机器恢复时：

1. 不清空 Trash，也不先启动或安装新的 Lark；
2. 先在仓库外建立隔离目录的私有副本，再把旧 `Lark.app`、`LarkShell`、字体
   workaround、preferences 与 HTTPStorage 恢复到原位置；cache 可选，不恢复过期 socket；
3. 由维护者先启动旧 `Lark.app`，验证账号、聊天和本地文件，完成必要同步或导出后退出；
4. 再执行绑定精确 commit 的 nix-darwin activation，安装当前 `LarkSuite.app`；
5. 新旧应用 bundle/Team/Keychain identity 不同；维护者首次启动新应用、完成可能需要的
   重新登录并验证迁移。两份应用不得同时运行，验收前不删除旧应用或私有回滚副本。

Nix build 只能证明声明可构建，不能证明 4.7 GB 的 Lark 可变数据逻辑完整。若任何目标
路径已存在，停止恢复并先建立私有备份/比较，不覆盖。

### 2.3 安装 Nix 系统层

1. 按 [`bootstrap-macos.md`](bootstrap-macos.md) 安装 Lix，并只构建目标
   `darwinConfigurations.macbook.system`。
2. Agent 完成私有 preflight 备份和 build；维护者单独批准并执行精确 commit 的
   `darwin-rebuild switch`。
3. 若首次启用 Zed Cachix，使用编辑器 runbook 中记录的精确 URL 与公钥完成 bootstrap，
   不全局开启 `accept-flake-config`。

首次 activation 将同时恢复 Nix/Home Manager 应用、CLI、静态配置、Homebrew cask、
MAS 声明和 defaults。它不会自动恢复外部数据。

### 2.4 验证声明式层

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

### 2.5 恢复外部软件

按所有权逐层恢复，避免同一路径出现两个写入者：

1. **Mac App Store：** 人工登录，确认 9 个 receipt；Xcode Stable 不恢复。
2. **Setapp：** 安装官方客户端、人工登录，恢复 inventory 中的 14 个应用。
3. **Swift 工具链：** 按项目需要安装 Xcode Beta、Command Line Tools、SDK/Simulator，
   再验证外部 XcodeGen；仓库不替你接受许可证。
4. **厂商/手工应用：** 只从 inventory 中的官方入口恢复，并核对 bundle ID/Team ID。
5. **外部 formula：** PostgreSQL 16 按 Issue #60 的数据迁移流程处理；现有 Python 兼容
   venv 和 XcodeGen 在消费者验证完成前不得删除。
6. **数据：** 最后按各应用自己的恢复流程恢复数据库、容器、vault、profile、账号和历史。

## 3. 所有权验收

恢复完成后至少确认：

- Nix 应用只来自 Home Manager Apps，不存在旧 VS Code、Zed Preview 或 #61 所列七个
  `/Applications` rollback bundle；
- Homebrew Bundle 恰好声明 1 个 tap、29 个 cask、9 个 MAS app、0 个 formula；
- `homebrew.onActivation.cleanup = "none"`；
- `ChatGPT.app` 是 `com.openai.codex`，`ChatGPT Classic.app` 是 `com.openai.chat`；
- OrbStack 是唯一容器运行时，`docker ps` 在启动 OrbStack 后正常；
- Atuin 配置和 `.hushlogin` 来自 Nix Store，但 key/history 保持本机可写状态；
- `~/.local/share/chezmoi` 不再 apply，旧 dotfiles 不再参与配置生成；
- PostgreSQL、OrbStack、编辑器、浏览器和 Setapp 数据没有被 activation 覆盖。

## 4. 回滚顺序

### 4.1 Nix 与 defaults

优先使用上一代 system generation：

```fish
sudo darwin-rebuild --rollback switch
```

该命令恢复 Nix 声明，不撤销 Homebrew 已完成的 adoption/MAS 安装，也不回滚数据。macOS
defaults 的逐键试用前值和定向回滚命令见
[`phase-4-macos-defaults.md`](../inventory/phase-4-macos-defaults.md)。

### 4.2 Homebrew 与 MAS

1. 先从声明中撤回问题项并构建验证；
2. 只有获得新的精确批准后，才定向卸载单个 cask/formula；
3. 默认设置 `HOMEBREW_NO_AUTOREMOVE=1`，防止 Homebrew 隐式回收范围外依赖；
4. 不使用 cleanup/zap；MAS 应用由 App Store receipt 与人工安装恢复。

### 4.3 Setapp、厂商应用与数据

Setapp/厂商应用通过其官方渠道重新安装。若 package 回滚后仍异常，分别恢复应用数据，
不要删除整个 `Application Support`、容器或数据库目录来“验证干净安装”。OrbStack 和
PostgreSQL 需要各自的数据 runbook；没有恢复验证时不得执行破坏性迁移。

## 5. 后续变更流程

任何新增、删除或换源都先更新软件所有权 inventory，再建立窄 Issue/PR。Agent 可以完成
只读盘点、私有备份、构建和回滚清单；真实 activation 只由维护者执行。只有真实机器
验证与合并证据完成后，才更新本文的终态。
