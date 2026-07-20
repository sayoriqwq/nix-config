# macOS Home Manager 迁移手册

本手册用于 Phase 3 Issue #5。目标是先构建 `darwinConfigurations.macbook.system`，再由维护者在完成私有备份、chezmoi 所有权交接和当次批准后手动激活。Agent 不执行 activation，也不自动覆盖用户文件。

## 1. 范围与前置条件

本阶段只接管：

- Git 的 XDG config、global ignore 与 credential helper；
- Fish、FZF、Zoxide、Atuin hook、Starship 和少量已有 shell 行为；
- Helix、tmux、direnv/nix-direnv；
- 一组已在使用的跨平台 CLI。

Phase 2 已完成 nix-darwin 首次激活并保留可回滚 generation。开始人工激活前还必须满足：

1. Phase 3 commit 已推送到 Draft PR；
2. `nix flake check` 与 Darwin system build 均成功；
3. 当前工作树干净，审批记录写明准确 commit；
4. 维护者保持一个已打开且可 sudo 的终端；
5. 本手册第 3–5 节的备份、identity 分离和冲突清单完成；
6. 维护者在 Issue/PR 对这一次 activation 给出明确批准。

## 2. 只构建，不激活

在仓库根目录执行：

```fish
nix fmt -- --check .
nix flake check
nix build '/Users/sayori/Desktop/nix-config#darwinConfigurations.macbook.system' --no-link
```

记录每条命令的输出和 `$status`。`--no-link` 避免在工作树创建 `result` symlink。构建成功不授权 activation。

## 3. 创建私有备份

以下命令由维护者在 Mac 本地手动执行。备份含 Git identity、GitHub 本机状态和 Atuin key，不能提交到 Git、Issue 或 PR。

```fish
set phase3_backup (/usr/bin/mktemp -d /Users/sayori/home-manager-phase3.XXXXXX)
/bin/chmod 700 $phase3_backup

/usr/bin/tar -C /Users/sayori -cpf $phase3_backup/home-files.tar \
  .gitconfig \
  .config/git \
  .config/fish \
  .config/helix \
  .config/starship.toml \
  .config/gh \
  .config/atuin \
  .local/share/atuin
/bin/chmod 600 $phase3_backup/home-files.tar

/opt/homebrew/bin/chezmoi managed >$phase3_backup/chezmoi-managed.txt
/usr/bin/tar -tf $phase3_backup/home-files.tar >/dev/null
echo $status
echo $phase3_backup
```

预期：`tar -tf` 的状态为 `0`，备份目录权限为 `700`，archive 权限为 `600`。把备份目录路径记入 PR，但不要粘贴 archive 内容或账户标识。

## 4. 分离 Git identity

仓库不保存 Git 邮箱。维护者在移动旧 `~/.gitconfig` 前，从当前有效配置创建私有 include：

```fish
set phase3_git_name (/usr/bin/git config --global --get user.name)
set phase3_git_email (/usr/bin/git config --global --get user.email)

/bin/mkdir -p /Users/sayori/.config/git
/usr/bin/git config --file /Users/sayori/.config/git/identity.inc user.name "$phase3_git_name"
/usr/bin/git config --file /Users/sayori/.config/git/identity.inc user.email "$phase3_git_email"
/bin/chmod 600 /Users/sayori/.config/git/identity.inc

/usr/bin/git config --file /Users/sayori/.config/git/identity.inc --get user.name >/dev/null
/usr/bin/git config --file /Users/sayori/.config/git/identity.inc --get user.email >/dev/null
echo $status
```

预期最终状态为 `0`。不要把变量值写进 PR；只记录 identity include 已建立且权限正确。

## 5. 显式处理冲突与 chezmoi 所有权

Home Manager 不配置 `backupFileExtension`，因此不会自动改名或覆盖 regular file。维护者应在保持当前终端开启的前提下，把下列路径逐个移动到第 3 节的私有备份目录：

```text
/Users/sayori/.gitconfig
/Users/sayori/.config/git/ignore
/Users/sayori/.config/fish/config.fish
/Users/sayori/.config/fish/conf.d/atuin.env.fish
/Users/sayori/.config/fish/conf.d/zz-theme-tokens.fish
/Users/sayori/.config/fish/functions/__sayori_cd.fish
/Users/sayori/.config/fish/functions/fish_greeting.fish
/Users/sayori/.config/helix/config.toml
/Users/sayori/.config/starship.toml
```

移动前逐项确认路径与备份副本存在；不要删除整个 `~/.config/fish`、`~/.config/git` 或其他目录。Fish universal variables、Atuin config/data、GitHub hosts、Rustup、OpenCLI completion 和未列出的文件必须原地保留。

这一步只处理 target 冲突，不会修改 chezmoi source repository。验证成功前不要对上述路径运行 `chezmoi apply`；验证成功后再从 chezmoi source 中移除重复条目并独立提交。若出现任何未列出的 Home Manager file conflict，停止 activation，记录完整路径并重新决定所有权，不使用强制覆盖。

## 6. 人工 activation 关卡

只有在 Issue/PR 记录当前 commit、备份路径、上一代 generation 和维护者当次批准后，才由维护者手动执行：

```fish
sudo -H /run/current-system/sw/bin/darwin-rebuild switch \
  --flake '/Users/sayori/Desktop/nix-config#macbook'
```

Agent 不执行此命令。若命令报告冲突或用户 activation 失败，不要删除额外文件或重复重试；保留终端和完整输出，进入第 8 节回滚。

## 7. 激活后人工验证

在新开的普通 Fish shell 中验证并把脱敏结果写入 PR：

```fish
echo $SHELL
type -a fish git hx tmux direnv atuin starship fzf zoxide eza bat btop gh jq rg fd lazygit nh tree
/usr/bin/git config --get user.name >/dev/null
/usr/bin/git config --get user.email >/dev/null
/usr/bin/git config --get-all credential.https://github.com.helper
atuin --version
atuin status
direnv version
tmux -V
hx --health
sudo /run/current-system/sw/bin/darwin-rebuild --list-generations
```

同时人工确认：

- `$SHELL` 仍为 `/opt/homebrew/bin/fish`；
- Nix-managed CLI 在 PATH 中先于同名 Homebrew CLI，未迁移工具仍可作为后备访问；
- Git identity 查询成功但值不进入 PR，GitHub HTTPS credential helper 可用；
- Fish 启动无错误，Up/Down 保持默认行为，Ctrl+Up 打开 Atuin；
- `cd` 对真实目录、单一 Zoxide 命中和多命中选择的行为与迁移前一致；
- Starship prompt、Helix `ayu_dark` 主题、tmux、direnv/nix-direnv 和常用 CLI 正常；
- `~/.config/direnv/lib/hm-nix-direnv.sh` 存在，且新项目仍需要显式 `direnv allow`；
- Atuin 既有 history 可读，daemon 与数据库未被重置；
- OrbStack/OpenClaw integration 仅在对应文件存在时加载；
- `~/.config/fish/fish_variables`、GitHub hosts 和其他可变状态仍为 regular writable data，不是 Store symlink。

## 8. 回滚

若 activation 已产生有问题的新 generation，优先在仍打开的终端中执行：

```fish
sudo -H /run/current-system/sw/bin/darwin-rebuild --rollback
```

然后把第 5 节移开的文件从私有备份目录恢复到原路径，并检查 chezmoi source 未被改变。若新 generation 没有完成，保留错误输出，恢复文件后继续使用上一代 generation；不要卸载 Lix，也不要删除 Atuin/GitHub/Fish 数据目录。

回滚后验证：默认 shell、Git identity、Fish 启动、Atuin history 和上一代 nix-darwin generation 均恢复。问题原因、冲突路径和恢复结果写入 Draft PR，再决定是否修改声明后重新 build；每次 activation 重试都需要新的明确批准。
