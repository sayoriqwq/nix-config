# macOS 环境恢复与回滚

本手册恢复 `macbook` 的声明式系统和软件来源，不恢复应用数据库、账号或用户内容。

## 1. 前置与禁止项

恢复前确认：

- 目标仍是兼容的 Apple Silicon macOS；
- 管理员、FileVault/recovery 与重要数据备份可用；
- 仓库和 `flake.lock` 来自已审阅 commit；
- 浏览器、编辑器、OrbStack、云盘、AI CLI、Atuin、Rime userdb 与应用账号有各自恢复策略。

不要运行批量 Homebrew cleanup/zap，不覆盖未知 `/Applications` 或 `~/Library` 内容，不把 private key、token、Keychain、TCC、database、profile 或容器 volume 放进 Git/Nix Store。

## 2. 恢复顺序

### 2.1 盘点与数据保护

按 [host-inventory.md](host-inventory.md) 重新收集当前机器事实。记录现有 Nix generation、Homebrew/MAS receipts 和应用冲突；先备份用户数据，再恢复声明。

### 2.2 Lix 与非激活构建

macbook 使用 Lix 作为 Nix implementation；bootstrap 和完整卸载遵循 Lix 官方 installer/receipt，日常版本由 `nix.package = pkgs.lix` 与 lock file 管理。

```fish
nix flake check
nix build .#darwinConfigurations.macbook.system
```

🔍 先验证 Flake 并构建目标 generation，不 activation。

若 `/nix`、daemon、mount 或 installer receipt 与预期不一致，停止并单独诊断；不要把重装 Nix 当作 generation rollback。

### 2.3 Activation

审阅 exact commit、build output、现有 generation 和 rollback 后，维护者另行批准并执行 activation。Activation 可以落地 nix-darwin、Home Manager、Homebrew/MAS 声明与 macOS defaults，但不会恢复外部应用数据，也不会自动删除现场多余应用。

### 2.4 外部 owner

按单一 owner 恢复外部状态：

- Fcitx5.app/frontend 由官方 installer 和 macOS 输入源拥有；Nix 只投影 Rime Ice 静态 schema leaves。不得覆盖 `~/.config/fcitx5`、userdb、sync、identity 或整个 Rime 根目录；只有静态 overlay 实际改变且另获批准时才人工 deploy。
- RTK CLI 由 Nix 安装，`~/.codex/RTK.md` 由 RTK init 生命周期生成；Codex/Claude/Antigravity/Oh My Pi 的 auth、session、history、plugins 与 cache 保持外部。
- Raycast 的 Script Commands 由 Nix 投影；Settings、database、shortcuts、extensions 和 Script Directory 选择保持外部。
- Browser profile、Obsidian vault、VS Code/Zed live settings、Atuin history/key、OrbStack VM/container/volume、cloud data、licenses 和账号通过各自产品流程恢复。

RTK 需要恢复时由维护者运行：

```fish
rtk init -g --codex
rtk init -g --codex --show
```

🧭 重新生成并读回 RTK 自己拥有的全局 Codex policy 依赖，不复制 auth/session 数据。

## 3. 验收

在新登录 Fish 中至少确认：

```fish
command -s fish git uv mise zed code codex rtk
echo $EDITOR
echo $VISUAL
```

✅ 确认主要 CLI 来自 Home Manager profile，并核对默认编辑器环境。

随后人工验证 Ghostty/Fish、Zed、Raycast、Fcitx/Rime、Tailscale、Homebrew/MAS 应用和必要 macOS defaults。Build 不能替代这些 runtime checks。

## 4. 回滚

优先切回 activation 前一代 nix-darwin generation；这只恢复 Nix 声明，不会撤销 Homebrew 已执行安装、vendor login、TCC、数据库或用户数据变化。

Homebrew/MAS 问题先从声明撤回并重新 build；定向 uninstall、zap、receipt 修复或数据删除必须另获批准。Fcitx/Rime 回滚要区分静态 Nix leaves、外部 frontend/preferences 与 userdb；禁止通过清空用户目录验证“干净恢复”。

如果上一代本身包含已退役的 activation side effect，切换前必须先审阅该 generation，不能假设旧 generation 只恢复静态文件。
