# nixbox 桌面验收与恢复

## 1. 用途与边界

本文用于维护者在 `nixbox` 上验收或恢复当前声明的 Hyprland、Fcitx 5 与 Rime Ice 桌面能力。仓库检查或构建通过不代表真实 activation、注销、重启或 rollback 已获批准；每次操作都必须在对应 Issue 或 PR 中绑定准确提交、目标机器、命令、执行窗口和恢复路径。

不得为排障运行 GC、删除 system generation、GC root 或 boot entry，也不得删除或迁移 keyring、Fcitx、Rime、dconf、portal permission、浏览器配置和其他应用状态。Generation rollback 只回退声明式系统，不恢复可变用户数据。

## 2. 操作前证据

执行任何 `test`、`switch`、注销或重启前，维护者必须确认：

1. 当前 Issue 或 PR 已批准准确提交与准确动作；
2. 工作树无未审阅改动；
3. 当前运行 closure、system profile、可恢复 generation 与 boot entry 已记录并核实；
4. 本地 TTY 或显示器可用，既有 SSH/Tailscale 恢复通道已从另一台获授权机器实测；
5. 旧 generation、profile、GC root 与 boot entry 在验收结束前不会被清理；
6. 重要可变数据已有独立备份，或维护者已接受 generation rollback 不覆盖它们。

在 `nixbox` 仓库根目录记录声明与恢复身份：

```fish
git rev-parse HEAD
git status --short
set -l running_system (readlink -f /run/current-system)
set -l profiled_system (readlink -f /nix/var/nix/profiles/system)
printf 'running:  %s\nprofiled: %s\n' $running_system $profiled_system
nixos-rebuild list-generations
bootctl list --no-pager
```

🔎 记录准确提交、运行 closure、profile、generation 与 boot entry，不把编号写成长期固定事实。

从另一台已授权机器验证恢复通道；不要在公开记录中粘贴地址、密钥或完整网络身份：

```fish
ssh nixbox 'systemctl is-active sshd tailscaled NetworkManager'
```

🔐 确认既有 SSH、Tailscale 与 NetworkManager 恢复入口在线。

## 3. 非激活构建

先构建当前 `nixbox` output；失败即停止，不通过临时新增桌面组件掩盖问题：

```fish
nix build .#nixosConfigurations.nixbox.config.system.build.toplevel --no-link
```

🏗️ 只构建 closure，不切换运行系统、profile 或 boot default。

## 4. Activation 后 smoke

Activation、注销或重新登录只由维护者在当前批准范围内执行。进入 `Hyprland (uwsm-managed)` 后，按顺序记录 PASS/FAIL：

- `sshd`、Tailscale、NetworkManager、display manager 与 rtkit 正常；
- Waybar、Hypridle、hyprpolkitagent、portal、PipeWire 与 WirePlumber 各有预期的唯一 owner；
- Ghostty、Fuzzel、窗口与 workspace 绑定、手动锁屏和正常结束 UWSM session 可用；
- Chrome 屏幕共享选择器、文件选择器、音频与网络正常；
- Fcitx 只运行一个实例，默认 engine 为 Rime，没有 IBus daemon 争夺 owner；
- Ghostty、Chrome、Qt 与 XWayland 应用都能输入，左右 Shift 只切换 Rime 内部中英文状态；
- GDM、Hyprlock 与密码字段不泄露预编辑文本，GNOME Keyring 不被删除、重建或另行解锁；
- Rime 学习结果在注销并重新登录后仍存在；重启验证必须另行批准。

检查关键 system 与 user services：

```fish
systemctl --no-pager --full status sshd tailscaled NetworkManager rtkit-daemon display-manager
systemctl --user --no-pager --full status waybar.service hypridle.service hyprpolkitagent.service
systemctl --user --no-pager --full status xdg-desktop-portal.service xdg-desktop-portal-hyprland.service pipewire.service wireplumber.service
pgrep -a fcitx5
fcitx5-remote -n
wpctl status
```

🩺 核对访问、桌面外围、输入法、portal 与音频的实际运行状态。

只读确认 Secret Service 可达，不创建测试 secret，也不输出已有内容：

```fish
secret-tool search nixbox-desktop-probe absent >/dev/null
busctl --user list | string match '*org.freedesktop.secrets*'
```

🗝️ 验证当前登录 session 可以访问 Secret Service。

## 5. 失败证据

核心访问、锁屏、密码安全或输入法 owner 失败时立即停止晋升；不要现场修改声明或清理状态。只收集必要日志，并在公开记录前删除账号、地址、密钥与应用内容：

```fish
journalctl -b -u display-manager -u NetworkManager -u tailscaled -u sshd --no-pager
journalctl --user -b -u waybar -u hypridle -u hyprpolkitagent -u xdg-desktop-portal -u xdg-desktop-portal-hyprland -u pipewire -u wireplumber --no-pager
journalctl --user -b | rg -i 'fcitx|rime|uwsm|hyprland'
```

🧾 收集当前 boot 的最小失败证据，不读取或上传可变数据内容。

## 6. 恢复模型

### `nixos-rebuild test` 失败

`test` 只临时切换当前运行系统，不移动 system profile，也不改变 boot default。继续使用已实测的 SSH 或本地 TTY；若重启已经单独获批，重启应返回操作前核实的 boot default。若默认项不可用，只选择操作前已核实身份且仍存在的旧 boot entry，不凭 generation 编号猜测。

### `nixos-rebuild switch` 后失败

`switch` 会更新 system profile 与 boot default。只有当前 Issue 或 PR 已批准准确 rollback、已重新核实上一代身份且恢复入口仍可用时，维护者才能执行：

```fish
sudo nixos-rebuild switch --rollback
```

↩️ 把 system profile 切回已核实的上一代；命令本身不授权重启，也不恢复可变用户数据。

若命令式 rollback 不安全或无法完成，使用本地 boot menu 选择操作前核实的旧 entry；重启同样需要当前批准。恢复访问后记录实际运行 closure、profile 与失败证据，再为声明修复建立独立 Issue。

## 7. 可变状态边界

以下路径可能在登录、输入或 Rime deploy 时变化，不由 generation rollback 撤销：

- `~/.config/fcitx5/`
- `~/.local/share/fcitx5/rime/` 下的 `*.userdb`、`build/`、`sync/`、`installation.yaml` 与 `user.yaml`
- `~/.local/share/keyrings/`
- dconf、portal permissions、浏览器 profile 与其他应用状态

除非另有一个包含备份、精确目标和恢复验证的批准 Issue，不得删除、覆盖或迁移这些路径。排障只记录必要的路径、类型、权限和时间戳，不公开内容。

## 8. 记录模板

```text
exact commit:
approved action: build / test / switch / rollback
running closure and profile recorded: PASS / FAIL
verified recovery generation and boot entry: PASS / FAIL
SSH + TTY recovery path: PASS / FAIL
core system services: PASS / FAIL
UWSM desktop services: PASS / FAIL
Fcitx/Rime input matrix: PASS / FAIL
password and keyring safety: PASS / FAIL
mutable state left untouched: PASS / FAIL
reboot: NOT RUN / PASS / FAIL
rollback: NOT RUN / PASS / FAIL
```

📝 记录真人运行结果与批准边界，不把构建结果误报为运行态验收。

NixOS 的 `test`、`switch` 与 rollback 语义以官方手册的 [Changing the Configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config) 和 [Rolling Back Configuration Changes](https://nixos.org/manual/nixos/stable/#sec-rollback) 为准。
