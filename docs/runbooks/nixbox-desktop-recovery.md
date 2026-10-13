# nixbox 桌面检查与恢复

配置来源为 [nixbox](../../hosts/nixbox/default.nix)、[桌面组合](../../intents/hyprland-workstation.nix)和[中文输入](../../intents/chinese-input.nix)。NixOS 提供 Hyprland／UWSM 会话，Home Manager 管理用户配置；Fcitx5 通过 XDG 自启动，不另建第二个会话或输入法服务。

应用、注销或重启前按 [AGENTS.md](../../AGENTS.md) 明确目标与恢复办法，保留本地 TTY／显示器和已验证的 SSH 通道。当前运行系统、默认启动项及可用旧代际必须从目标机核实，不能由仓库推断；恢复完成前不清理代际、GC root 或启动项。

## 检查目标与候选

在 nixbox 上查看运行系统和启动恢复点：

```fish
hostname
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
nixos-rebuild list-generations
bootctl list --no-pager
```

🔎 区分当前运行系统、正式 profile 和默认启动项，确认拟恢复的代际仍存在。

在具备 `x86_64-linux` 构建条件的仓库 checkout 中准备候选：

```fish
nix build .#nixosConfigurations.nixbox.config.system.build.toplevel --no-link
```

🏗️ 只构建候选，不切换运行系统或启动项；失败时先修复声明。

## 桌面与输入故障

在 nixbox 的目标用户会话中检查：

```fish
systemctl --no-pager --full status sshd tailscaled NetworkManager rtkit-daemon display-manager
systemctl --user --no-pager --full status waybar hypridle hyprpolkitagent
systemctl --user --no-pager --full status xdg-desktop-portal xdg-desktop-portal-hyprland pipewire wireplumber
pgrep -a fcitx5
fcitx5-remote -n
wpctl status
busctl --user list | string match '*org.freedesktop.secrets*'
```

🩺 检查系统和用户服务、Fcitx 实例及引擎、音频设备与 Secret Service 注册；这些状态不能代替实际桌面操作。

按本次改动或故障验证相关功能：

- 使用 `Hyprland (uwsm-managed)` 登录，确认 Ghostty、Fuzzel、工作区、锁屏、退出会话和休眠唤醒正常；UWSM 是唯一会话管理者。
- 检查浏览器共享屏幕、文件选择器和音频，避免只看到 portal 或 PipeWire 服务在线就判定可用。
- Fcitx5 只运行一个实例，默认使用 Rime；在 Ghostty、Chrome、Qt 与 XWayland 应用中验证输入和左右 Shift 行为。
- GDM、Hyprlock 和密码字段不泄露预编辑文本；钥匙环正常使用，Rime 学习结果在重新登录后保留。

收集故障日志时限定到本次启动和相关服务：

```fish
journalctl -b -u display-manager -u NetworkManager -u tailscaled -u sshd -n 100 --no-pager
journalctl --user -b -u waybar -u hypridle -u hyprpolkitagent -u xdg-desktop-portal -u xdg-desktop-portal-hyprland -u pipewire -u wireplumber -n 100 --no-pager
journalctl --user -b -n 300 --no-pager | rg -i 'fcitx|rime|uwsm|hyprland'
```

🧾 保存必要错误摘要，不公开完整会话日志或应用内容。SSH 故障另见[稳定访问手册](stable-workstation-access.md)。

## 恢复系统配置

`nixos-rebuild test` 只切换当前运行系统，不移动正式 profile 或默认启动项。失败时从保留的 SSH 或 TTY 处理；需要重启恢复时，先确认默认启动项确实是已知可用版本。

`nixos-rebuild switch` 会修改正式 profile 和默认启动项。只有上一代就是所需恢复点时，在可靠控制台或 SSH 通道执行：

```fish
sudo nixos-rebuild switch --rollback
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
```

↩️ 切回上一代并核对运行系统和 profile；动作按本次授权执行，不同时清理其他代际。

上一代不可用时，从本地启动菜单选择已核实的旧项，或使用[指定 NixOS 代际恢复](server-recovery.md#恢复已知可用代际)。恢复访问、锁屏和输入后再修复仓库声明，不把旧代际的启动成功当成问题已经解决。

## 不随代际恢复的数据

`~/.config/fcitx5/`、Rime 的 `*.userdb`／`build`／`sync`／身份文件、`~/.local/share/keyrings/`、dconf、portal 权限和浏览器资料都是外部可变状态。Nix 只投影[静态 Rime 方案文件](../../software/rime-ice/home-manager.nix)，不保存学习数据。

不要通过删除这些目录测试“干净恢复”。需要修复或迁移数据时，先确定精确目标并准备对应备份；系统回滚不撤销 Rime deploy、学习、登录或应用产生的变化。
