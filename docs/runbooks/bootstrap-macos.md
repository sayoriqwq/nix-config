# macOS 最小 nix-darwin 接入手册

本文对应 Issue #4 / Phase 2。目标是让 `darwinConfigurations.macbook` 可以构建并完成第一次受监督激活，不迁移 Home Manager、dotfiles、Homebrew、GUI 应用或 macOS defaults。

所有会修改 Mac 的命令都由维护者手动执行。Agent 只准备配置、检查结果和操作说明。

## 1. 已确认前提

- 用户：`sayori`
- home：`/Users/sayori`
- UID：`501`
- 平台：`aarch64-darwin`
- 当前 shell：`/opt/homebrew/bin/fish`，本阶段不接管或修改
- Phase 2 开始时没有 `/nix`、`/etc/nix`、Nix daemon 或 Nix/Lix 安装收据
- output：`darwinConfigurations.macbook`

## 2. Bootstrap 选择

使用 Lix Installer 完成第一次 Nix 实现安装，随后由 nix-darwin 管理 Nix daemon，并在配置中固定 `nix.package = pkgs.lix`。

这是维护者在了解上游 Nix 与 Lix 的替代关系后，于 2026-07-20 明确接受的项目决策。长期依据、代价与复审条件见 [ADR-0005](../adr/0005-macos-nix-implementation-lix.md)。

选择依据：

- nix-darwin 官方 README 推荐没有现有 Nix 安装时使用带自动卸载能力的 Lix Installer；
- Lix Installer 支持 Apple Silicon macOS、默认启用 Flakes、保留安装收据，并提供 `/nix/lix-installer uninstall`；
- 不使用 Determinate Nix，因为它的独立 daemon 管理会要求 `nix.enable = false`，与本阶段由 nix-darwin 管理 Nix 基础设置的目标不同。

参考：

- [nix-darwin 官方安装说明](https://github.com/nix-darwin/nix-darwin/tree/nix-darwin-26.05#prerequisites)
- [Lix 官方安装说明](https://lix.systems/install/)

## 3. `system.stateVersion` 选择

首次采用值为 `7`。

仓库锁定的 nix-darwin 26.05 revision 为 `c3e90c89649b07d1a96e4b9dd6cd0d6e44b91a74`。该 revision 的 `system.maxStateVersion` 是 `7`，并明确提示新安装使用当前最大值。首次成功激活后不得为了追随新版本而修改它。

参考：[固定 revision 的 `system.stateVersion` 定义](https://github.com/nix-darwin/nix-darwin/blob/c3e90c89649b07d1a96e4b9dd6cd0d6e44b91a74/modules/system/version.nix#L34-L54)

## 4. 人工安装 Lix（已完成）

先确认仍是干净状态：

```bash
command -v nix || echo "Nix/Lix 尚未安装"
test ! -e /nix && echo "/nix 不存在"
```

由维护者阅读安装计划并手动确认：

```bash
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.lix.systems/lix \
  | sh -s -- install
```

维护者于 2026-07-20 手动执行并确认安装成功。安装器报告完成了以下操作：

- 创建加密 APFS `Nix Store` 并挂载到 `/nix`；
- provision Nix；
- 创建 UID 351–382 的构建用户和 GID 350 的构建组；
- 配置 Time Machine exclusions；
- 配置 Nix、zsh 非交互 shell 支持和 launchd PATH；
- 配置 Nix daemon 的 launchd 服务；
- 清理临时安装目录。

此记录只证明 Lix Installer 完成，不代表 nix-darwin 已构建或激活。

维护者随后在新终端完成版本验证，结果为：

- `nix (Lix, like Nix) 2.95.2`；
- system type 为 `aarch64-darwin`；
- additional system type 包含 `x86_64-darwin`；
- system configuration 为 `/etc/nix/nix.conf`；
- store 与 state directory 分别为 `/nix/store`、`/nix/var/nix`；
- experimental features 为 `flakes nix-command`。

以上结果确认当前终端已正确加载 Lix，且 Flakes 与 `nix-command` 已启用；不代表 nix-darwin 已构建。

安装结束后关闭当前终端，打开一个新终端，然后验证：

```bash
nix --version
nix config show experimental-features
```

版本与 experimental features 验证均已通过。

如果安装失败，不继续执行 nix-darwin。优先使用安装器自己的回退：

```bash
sudo /nix/lix-installer uninstall
```

## 5. 只构建，不激活

维护者已于 2026-07-20 在 `macbook` 手动执行：

```bash
nix flake check --all-systems /Users/sayori/Desktop/nix-config
```

命令没有输出，fish 的 `$status` 为 `0`，确认 Mac 本机 Flake check 通过。

维护者随后手动执行只构建命令：

```fish
nix build '/Users/sayori/Desktop/nix-config#darwinConfigurations.macbook.system' --no-link
```

构建产生正常的 `darwin-rebuild`、`darwin-option`、`system-path` 等 phase 日志，最终 fish 的 `$status` 为 `0`。这确认 `darwinConfigurations.macbook.system` 已在真实 `aarch64-darwin` 主机上构建成功；`--no-link` 没有创建 `result` 链接，且没有执行 activation。

```bash
cd /Users/sayori/Desktop/nix-config

nix fmt -- --check flake.nix hosts/macbook/default.nix modules/darwin/base.nix
nix flake check --all-systems
nix build .#darwinConfigurations.macbook.system --no-link
```

以上验证已经通过。命令不得使用 `sudo`，也不会激活 nix-darwin。未来重复构建失败时应停止，并把完整错误交给对应维护任务处理。

## 6. 第一次激活前备份

只有 build 成功并在 PR 中获得针对第一次激活的明确人工批准后，才执行本节。

创建本地备份目录：

```bash
backup_dir="$HOME/nix-darwin-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"

sudo cp -a /etc/nix "$backup_dir/"
sudo cp -a /etc/synthetic.conf "$backup_dir/" 2>/dev/null || true
sudo cp -a /etc/fstab "$backup_dir/" 2>/dev/null || true
sudo cp -a /Library/LaunchDaemons/org.nixos.nix-daemon.plist \
  "$backup_dir/" 2>/dev/null || true

printf '备份目录：%s\n' "$backup_dir"
```

同时确保：

- 当前仓库无未提交修改；
- 至少保留一个不关闭的管理员终端；
- 已记录 Lix 安装器路径 `/nix/lix-installer`；
- 已复制 PR commit SHA 和本手册路径。

## 7. 第一次激活：人工关卡

以下命令现在**不要执行**。它必须等 Phase 2 PR 中出现当次明确批准后，由维护者手动执行：

```bash
cd /Users/sayori/Desktop/nix-config

sudo nix run \
  github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild \
  -- switch --flake .#macbook
```

激活完成后验证：

```bash
darwin-rebuild --list-generations
nix --version
nix config show experimental-features
dscl . -read /Users/sayori NFSHomeDirectory UserShell
```

预期：

- 存在第一代 nix-darwin generation；
- Nix 实现仍为 Lix；
- Flakes 仍启用；
- home 仍为 `/Users/sayori`；
- shell 仍为 `/opt/homebrew/bin/fish`。

## 8. 回滚

如果已经产生上一代 generation，先尝试：

```bash
sudo darwin-rebuild --rollback
```

如果第一次激活失败且没有可回滚 generation：

1. 保留错误输出和当前终端；
2. revert Phase 2 PR 或切回合并前 commit；
3. 根据第 6 节的备份比较 `/etc/nix` 与 daemon plist；
4. 只有决定完整移除 Nix/Lix 时，才手动运行：

```bash
sudo /nix/lix-installer uninstall
```

完整卸载是最后手段，不能和 nix-darwin rollback 同时盲目执行。
