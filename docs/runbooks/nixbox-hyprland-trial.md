# nixbox Hyprland 首次试用、验收与恢复

## 1. 用途与安全边界

本文只供维护者在 `nixbox` 上试用 Issue
[#167](https://github.com/sayoriqwq/nix-config/issues/167) 的 Hyprland 0.55.4 候选。仓库内
build 或 CI 通过不等于真实 activation 获批。执行 `nixos-rebuild test`、注销、重启或以后执行
`switch` 前，都必须在 Issue 或 PR 中记录针对**准确提交与准确动作**的当前人工批准。

当前 Issue 的实现阶段停在 build；本文中的 activation、注销和重启命令都不是当前授权的一部分，
本文编写期间也没有执行它们。不得在试用期间运行 GC、删除 system generation、移除 GC root、
删除 systemd-boot entry，或清理 keyring、dconf、portal permission、浏览器及其他应用状态。

恢复模型有两种，不能混用：

- `nixos-rebuild test` 会把候选切到当前运行系统，但不移动 system profile、不把候选设为 boot
  default，也不为候选建立可供下次启动选择的 generation entry。候选失败时，重启回试用前仍为
  boot default 的、已验收 GNOME generation。
- 只有未来另行获批执行 `nixos-rebuild switch`，候选才成为 system profile generation 与 boot
  default；此后才可用上一代 boot entry 或 `nixos-rebuild switch --rollback` 回退。

以上语义来自 NixOS 官方手册的
[Changing the Configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config) 与
[Rolling Back Configuration Changes](https://nixos.org/manual/nixos/stable/#sec-rollback)。

## 2. 首次 `test` 前置关卡

必须同时满足以下条件；任一条件不满足就停止，不靠现场猜测继续：

1. Issue/PR 已批准准确候选提交的 `test`、activation 可能立即结束当前图形会话，以及必要时的
   reboot；不能把 `test` 当作会保留当前 GNOME terminal 的无中断操作。
2. 在 `nixbox` 的仓库根目录，当前提交与获批提交一致，工作树没有未审阅改动。
3. 当前运行的、已验收 GNOME system closure 与 system profile 指向同一 closure；维护者已记录其
   generation 编号。
4. `bootctl list` 中仍能看到试用前的已验收 GNOME entry，且它仍是 boot default。没有确认该项时，
   不得依赖重启恢复。
5. 没有运行过会删除该 generation、profile symlink、GC root 或 boot entry 的操作；试用完成前不运行
   `nix-collect-garbage`、`nix store gc` 或 generation 清理命令。
6. 本地键盘与显示器可用；另一台机器已实测能通过既有 SSH/Tailscale 路径登录 `nixbox`。远程路径
   只是恢复辅助，不替代本地/boot-menu 恢复入口。
7. 重要可变数据已有独立备份或已接受不由 generation rollback 恢复的风险。

从仓库根目录核对提交和工作树：

```fish
git rev-parse HEAD
git status --short
```

🔎 核对获批提交并确认没有未审阅改动。

记录当前 closure、profile generations 与 boot entries：

```fish
set -l running_system (readlink -f /run/current-system)
set -l profiled_system (readlink -f /nix/var/nix/profiles/system)
printf 'running:  %s\nprofiled: %s\n' $running_system $profiled_system
test "$running_system" = "$profiled_system"; and echo 'PASS: current system is boot-profiled'; or echo 'STOP: current system differs from system profile'
nixos-rebuild list-generations
bootctl list --no-pager
```

🛟 记录试用前 GNOME generation，并确认其 profile、GC root 与 systemd-boot entry 仍可用。

从另一台已授权机器实测恢复通道；不要在文档或 Issue 中粘贴地址、密钥或其他敏感输出：

```fish
ssh nixbox 'systemctl is-active sshd tailscaled NetworkManager'
```

🔐 确认既有 SSH、Tailscale 与 NetworkManager 恢复通道在线。

## 3. 非激活构建

先从仓库根目录构建准确的 `nixbox` output。该命令不激活系统：

```fish
nix build .#nixosConfigurations.nixbox.config.system.build.toplevel --no-link
```

🏗️ 构建候选 closure，但不切换运行系统或 boot default。

构建失败即停止。不得为了通过构建临时加入社区 dotfiles、GPU vendor 环境变量、第二套 portal、
notification daemon、launcher、bar、polkit agent 或 input framework。

## 4. 首次 `test`（未来人工执行）

只有第 2 节的准确审批和恢复条件全部满足后，维护者才可从**已经实测的 SSH 控制面或本地 TTY**进入
`nixbox` 仓库根目录执行。不要从即将被替换的 GNOME terminal 运行：activation 可能重启/替换
display manager，并立即结束当前 GNOME session 与其中的 terminal。

```fish
sudo nixos-rebuild test --flake .#nixbox
```

🧪 临时切换当前运行系统到候选，不移动 system profile 或 boot default。

命令返回后继续使用同一 SSH 或本地 TTY 控制面，确认 `sshd`、Tailscale、NetworkManager、printing、
rtkit 与 GDM 没有异常；不要假设原 GNOME session 或 terminal 仍存活。PipeWire/WirePlumber 在登录
Hyprland 后按第 5.1 节检查。若关键访问能力回退，直接进入第 8 节，不继续桌面 smoke。

```fish
systemctl --no-pager --full status sshd tailscaled NetworkManager cups rtkit-daemon display-manager
```

🩺 检查候选切换后的关键系统服务；个别未安装或 socket-activated unit 应结合声明与日志判断。

完成检查后回到本地 GDM；若 activation 已结束 GNOME session，不要额外执行注销。如果旧图形会话
意外仍在，必须按已批准动作正常注销。在 GDM 的 session 菜单中必须精确选择
`Hyprland (uwsm-managed)`；不要选非 UWSM 的 `Hyprland` entry。官方 v0.55 的
[Systemd startup](https://wiki.hypr.land/0.55.0/Useful-Utilities/Systemd-start/) 明确要求 display
manager 用户选择该 entry，并要求 UWSM session 内用 `uwsm app --` 启动应用。

## 5. Hyprland 登录 smoke checklist

按顺序记录 PASS/FAIL 与必要日志，不记录密码、keyring 内容、账号、地址或浏览器隐私数据。任一核心
项目失败都不要提升候选为 `switch` generation。

### 5.1 会话、基础操作与唯一外围 owner

确认 GDM 登录成功，Waybar 只出现一份，且 workspace、活动窗口和时钟可见。确认以下首轮绑定：

| 操作 | 绑定 |
| --- | --- |
| 启动 Ghostty | `Super+Q`，经 `uwsm app -- ghostty` |
| 启动 Fuzzel | `Super+R`，经 `uwsm app -- fuzzel` |
| 关闭窗口 | `Super+C` |
| 切换浮动 | `Super+V` |
| 手动锁屏 | `Super+L`，执行 `loginctl lock-session` |
| 正常结束 UWSM session | `Super+Shift+M`，执行 `uwsm stop` |
| 聚焦窗口 | `Super+方向键` |
| 切换 workspace | `Super+0..9` |
| 移动窗口到 workspace | `Super+Shift+0..9` |
| 移动/缩放窗口 | `Super+鼠标左键` / `Super+鼠标右键` |

这些绑定的语义来自 Hyprland 0.55 官方
[example](https://github.com/hyprwm/Hyprland/blob/v0.55.4/example/hyprland.lua)、
[Binds](https://wiki.hypr.land/0.55.0/Configuring/Basics/Binds/) 和 UWSM 文档；Ghostty 与 Fuzzel
是本仓库 owner 映射。`Super+Shift+M` 只用于正常退出健康的 UWSM session，不能代替故障恢复。

查看 UWSM 管理的用户服务；Waybar、Hypridle 与 hyprpolkitagent 应各只有一个 owner：

```fish
systemctl --user --no-pager --full status waybar.service hypridle.service hyprpolkitagent.service
systemctl --user --no-pager --full status xdg-desktop-portal.service xdg-desktop-portal-hyprland.service pipewire.service wireplumber.service
```

🧩 核对 UWSM 会话、桌面外围、portal 与音频用户服务。

按 `Super+R` 打开 Fuzzel 并取消；随后通过标准 `org.freedesktop.Notifications.Notify` D-Bus method
触发一条 5 秒的短暂 Mako 测试通知。其 signature 是 `susssasa{sv}i`：五个标量字段之后分别传空的
actions array、空的 hints dictionary 和 expiry；这只测试 D-Bus notification owner，不新增
`libnotify` 或其他 package：

```fish
busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications Notify 'susssasa{sv}i' 'nixbox-hyprland-smoke' 0 '' 'nixbox Hyprland smoke' 'Mako D-Bus notification owner is reachable' 0 0 5000
```

🔔 验证 Fuzzel 与唯一的 Mako notification owner。

### 5.2 polkit、Hyprlock 与 always-on

从 Ghostty 发起一个不写入系统的 polkit 探针；出现图形授权窗口后取消即可，禁止借 smoke 修改系统：

```fish
uwsm app -- pkexec true
```

🔑 只验证 hyprpolkitagent 能显示授权窗口；取消后不产生特权变更。

按 `Super+L`，确认 Hyprlock 出现、密码可以解锁，且没有绕过或第二套 locker。然后确认生成的
Hypridle 配置没有 `listener` block：

```fish
if rg -n '^\s*listener\s*\{' ~/.config/hypr/hypridle.conf
    echo 'FAIL: unexpected idle listener'
else
    echo 'PASS: no automatic idle listener'
end
```

🕰️ 确认 Hypridle 不会因空闲自动 lock、DPMS-off 或 suspend。

在一段足以覆盖日常空闲观察的试用时间内，确认没有自动锁屏、关闭显示器或 suspend。空 listener
不影响 `Super+L` 手动锁屏；若系统收到外部 sleep 请求，官方
[Hypridle](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/hypridle/) 所述的 sleep 前锁屏与唤醒后
DPMS 恢复仍应生效。本 Issue 不授权为测试而主动 sleep/wake。

### 5.3 中文输入与 GNOME Keyring

Issue #169 已用独立能力取代本手册最初保留的 IBus owner。Fcitx daemon、Rime engine、左右 Shift、
Wayland/XWayland、GTK/Qt、密码安全与 userdb 持久性必须完整执行
[nixbox Fcitx 5 / Rime Ice 首次试用手册](nixbox-fcitx5-rime-trial.md)，不能用旧的 `ibus engine`
smoke，也不能把本节当作 activation、logout/relogin 或 deploy 授权。

用不存在的属性做只读 Secret Service 查询，并确认服务可达；不创建测试 secret，不读取或输出已有
secret。GDM 登录后不应再次要求单独解锁 keyring：

```fish
secret-tool search nixbox-hyprland-probe absent >/dev/null
busctl --user list | string match '*org.freedesktop.secrets*'
```

🗝️ 验证 GNOME Keyring/Secret Service 可由当前登录 session 访问且不暴露内容。

若查询触发额外 keyring 解锁、报 PAM/Secret Service 错误或服务不可达，记录 FAIL；不要删除、重建
或迁移 `~/.local/share/keyrings`。

### 5.4 Portal、屏幕共享、音频与网络

在 Firefox 中打开一个可信的现有 WebRTC/会议页面，发起“共享屏幕”，确认出现 Hyprland portal
选择器、可看到正确的 monitor/window，并在真正发送前取消。再触发一次文件选择器并取消。预期 desktop
portal 只有 `xdg-desktop-portal-hyprland` 与 GTK fallback，不应出现 wlr 或 GNOME backend。官方依据见
[XDPH](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/xdg-desktop-portal-hyprland/)；不得通过
命令式环境变量或新增 portal 来掩盖失败。

检查 PipeWire/WirePlumber 拓扑，在 Firefox 播放普通音频并确认输出正常：

```fish
wpctl status
```

🔊 核对 PipeWire/WirePlumber 的默认音频设备与播放链路。

只读检查 NetworkManager 与 Tailscale；不要在此 Issue 中改网络配置：

```fish
nmcli general status
tailscale status
```

🌐 验证既有网络与稳定访问能力没有因桌面替换回退。

### 5.5 多显示器与未知硬件事实

记录 Hyprland 实际识别的输出，不在 smoke 过程中加入显示器名、缩放、刷新率、VRR/HDR、GPU vendor
或驱动 workaround：

```fish
hyprctl monitors all
```

🖥️ 收集多显示器实际事实，并确认 fallback `preferred/auto/auto` 能正常显示。

确认所有已连接显示器有画面、焦点和 workspace 可切换、鼠标坐标连续。任何输出、缩放或 GPU 问题都
记录为后续硬件适配 Issue；先恢复，不现场猜配置。

## 6. 收集失败证据

从既有、已验证的 SSH 或本地 TTY 控制面收集本次 boot 的窄日志；健康的 Ghostty 可以作为补充，但
不是桌面替换后的可靠恢复控制面。先审阅日志，避免把敏感内容直接粘到公开 Issue：

```fish
journalctl --user -b --no-pager -u waybar.service -u hypridle.service -u hyprpolkitagent.service -u xdg-desktop-portal.service -u xdg-desktop-portal-hyprland.service
journalctl -b --no-pager -u display-manager.service -u NetworkManager.service -u tailscaled.service
```

📋 收集当前 boot 的会话、portal、display manager 与访问链路日志。

同时记录：准确 Git commit、失败步骤、GDM entry、显示器输出、是否仍可 SSH、是否发生额外 keyring
prompt。不要写入 public IP、账号标识、token、私钥或已有 secret 内容。

## 7. 正常结束 `test` 并回到 GNOME

在健康的 Hyprland session 中，`Super+Shift+M` 执行 `uwsm stop` 并返回 GDM；同时保持已验证的 SSH
或本地 TTY 作为可靠控制面。此时运行系统仍是候选 configuration，候选不提供 GNOME desktop
session，所以**仅注销不能回到 GNOME**。

完成证据收集后，只有在 reboot 已被当前审批覆盖、且第 2 节确认 boot default 仍是试用前 GNOME
generation 时，维护者才可重启：

```fish
sudo systemctl reboot
```

🔄 重启到未被 `test` 改动的 boot-default GNOME generation。

启动后确认 `/run/current-system` 回到第 2 节记录的 closure，并完成 GNOME、SSH/Tailscale、网络、
音频与开发工具的最小回归检查。若 boot menu 出现，选择第 2 节已确认的 GNOME generation；不要选择
未验收 entry。

## 8. `test` 失败恢复

恢复优先级如下：

1. 已验证的 SSH 可用：保持该控制面，收集第 6 节证据，再执行已批准的 reboot；不要依赖图形会话。
2. SSH 不可用但本地 TTY 可用：从 TTY 登录、收集日志，再执行已批准的 reboot。
3. Hyprland 仍响应：可额外用 `Super+Shift+M` 正常结束 UWSM，但它不替代 SSH/TTY 恢复路径或 reboot。
4. 候选卡死：直接硬件重启只应作为最后手段；启动时选第 2 节确认仍存在的已验收 GNOME entry。

远程恢复命令只在准确 reboot 动作已获批后执行：

```fish
ssh -t nixbox 'sudo systemctl reboot'
```

🧯 从已实测的既有访问路径重启回 boot-default GNOME generation。

`test` 候选没有自己的 profile generation 或 boot entry，所以这里不要运行
`nixos-rebuild switch --rollback`：它针对 system profile 的上一代，并不是“撤销当前 test”的准确
模型。

## 9. 未来 `switch` 晋升与 generation rollback

只有全部 smoke PASS、结果记录到 Issue/PR，且维护者对**准确提交**另行批准 `switch` 后，才进入本节。
晋升前再次确认已验收 GNOME generation 仍在 `nixos-rebuild list-generations` 与 `bootctl list` 中，
没有 GC，也没有删除其 profile symlink/GC root/systemd-boot entry。

未来获批的晋升命令是：

```fish
sudo nixos-rebuild switch --flake .#nixbox
```

🚦 将已验收候选提升为 system profile generation 与 boot default；当前阶段禁止执行。

晋升后若仍能使用终端/SSH，并且上一代正是第 2 节记录的已验收 GNOME generation，可在另行批准后
执行：

```fish
sudo nixos-rebuild switch --rollback
```

↩️ 将运行系统和 system profile 切回上一代 generation；执行前必须再次核对上一代身份。

如果新 generation 无法正常启动，则在 systemd-boot 中人工选择保留的已验收 GNOME generation。
这条路径成立的条件是：旧 generation 没有被 GC、其 Store closure/GC root 仍存在、boot entry 仍被
bootloader generation limit 保留。恢复成功后再决定是否将旧 generation 重新设为默认；不要先删
失败候选或旧 entry。

## 10. Generation 回滚不覆盖的状态

NixOS/Home Manager generation 能恢复声明式 system 与 Home Manager 配置版本，但不会把所有用户数据
做文件系统快照。以下状态必须独立处理，不能把“能回滚系统”理解成“桌面所有东西都会回滚”：

- `$XDG_RUNTIME_DIR/hypr`、Wayland socket、systemd user session、portal/PipeWire socket：易失运行态，
  注销/重启后重建，不备份。
- dconf user database 与遗留 IBus preferences/runtime：用户/旧 framework 可变状态；切换到 Fcitx
  不清理，generation rollback 也不还原试用期间的写入。
- `~/.config/fcitx5` 与 `~/.local/share/fcitx5/rime` 下的 build、userdb、sync、installation/user
  state：Fcitx/Rime 可变状态；generation rollback 不恢复，处理边界见专用 Fcitx 手册。
- XDG portal permission store 与 GDM 的 session choice/account state：由各自服务拥有；不会随 system
  generation 自动还原。
- `~/.local/share/keyrings` 与登录解锁状态：敏感可变状态；禁止放入 Git/Nix Store，恢复依赖独立备份。
- Ghostty、Firefox、Chrome、Zed、Obsidian、LocalSend 等应用的 profile、cache、session 与用户内容：
  继续由应用/用户拥有，不由本 Issue 迁移、删除或恢复。
- Home Manager 管理的 Hyprland、Hyprlock、Mako、Fuzzel 与 Waybar 稳定配置会随对应 generation 声明
  切换；应用运行时状态不会因此成为 Store 内容。

若试用改变了任何上述可变状态，只记录事实并建立独立、可审阅的数据处理任务；不要在桌面恢复现场
顺手清理。

## 11. 官方依据

- [Hyprland v0.55 Systemd startup / UWSM](https://wiki.hypr.land/0.55.0/Useful-Utilities/Systemd-start/)
- [Hyprland v0.55 Must-have](https://wiki.hypr.land/0.55.0/Useful-Utilities/Must-have/)
- [Hyprland v0.55 Binds](https://wiki.hypr.land/0.55.0/Configuring/Basics/Binds/)
- [Hyprland v0.55.4 官方 Lua example](https://github.com/hyprwm/Hyprland/blob/v0.55.4/example/hyprland.lua)
- [Hyprland v0.55 XDPH](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/xdg-desktop-portal-hyprland/)
- [Hyprland v0.55 hyprpolkitagent](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/hyprpolkitagent/)
- [Hyprland v0.55 Hyprlock](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/hyprlock/)
- [Hyprland v0.55 Hypridle](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/hypridle/)
- [NixOS 26.05 Changing the Configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config)
- [NixOS 26.05 Rolling Back Configuration Changes](https://nixos.org/manual/nixos/stable/#sec-rollback)
