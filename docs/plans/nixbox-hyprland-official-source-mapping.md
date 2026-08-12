# nixbox Hyprland 0.55 官方来源映射

## 1. 范围与结论

本文是 Issue [#167](https://github.com/sayoriqwq/nix-config/issues/167) 的实现前置证据，只覆盖
`nixbox` 从 GNOME desktop session 迁移到 Hyprland 0.55.4 候选所需的桌面能力。它不授权
activation、注销、重启、GC，也不启动 Phase 12。

结论是：锁定来源可以无冲突地组成首轮候选。采用 Hyprland 0.55.4、GDM、UWSM、
Hyprland + GTK portals、Mako、Fuzzel、Waybar、hyprpolkitagent、Hyprlock/Hypridle，继续复用
Ghostty、PipeWire/WirePlumber、IBus、GNOME Keyring 与现有字体。GNOME desktop session 必须关闭；
GDM 为运行 greeter 仍带入 `gnome-shell`/`gnome-session` 闭包，这是 display-manager 实现副作用，
不代表 GNOME session 仍可选择。

本次没有发现“Hyprland v0.55 官方文档与锁定模块源码无法映射”的 STOP 冲突。任何未来出现的
版本或语义分歧都必须停止实现并补到第 10 节，不能用社区配置补猜。

## 2. 版本与权威来源

| 层 | 固定事实 | 用途 |
| --- | --- | --- |
| Hyprland | `pkgs.hyprland` 0.55.4；上游 tag `v0.55.4` | compositor 行为和 Lua 配置语义 |
| Hyprland 文档 | 官方版本化 [v0.55 Wiki](https://wiki.hypr.land/0.55.0/) | 启动方式、must-have 与生态组件 |
| nixpkgs | 根 input 经 `flake.lock` 的 `root.inputs.nixpkgs = nixpkgs_3` 指向 `fd1462031fdee08f65fd0b4c6b64e22239a77870` | NixOS option、package 与隐式副作用 |
| Home Manager | `4ce190229c73d44536caa7072f6308fb2d8feeb3` | 用户配置和 user unit 语义 |
| 仓库 | `AGENTS.md`、架构文档、ADR-0001/0007、Phase 11 后 roadmap | scope、owner、状态与人工关卡 |

版本证据：锁定的 [Hyprland package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/hy/hyprland/package.nix)
明确构建 tag `v0.55.4`；v0.55 起官方配置格式改为 Lua，配置位于
`$XDG_CONFIG_HOME/hypr/hyprland.lua`，见 [Configuring/Start](https://wiki.hypr.land/0.55.0/Configuring/Start/)。
因此 Home Manager 必须使用锁定模块在 `home.stateVersion = "26.05"` 下的 `configType = "lua"`，
不能沿用 0.54 的 hyprlang 示例。[锁定 HM Hyprland module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/services/window-managers/hyprland.nix)

## 3. 核心行为与 Nix 映射

| 目标行为/组件 | 官方来源 | 锁定选项、包与隐式副作用 | 采用 | 理由 |
| --- | --- | --- | --- | --- |
| Hyprland session | [Hyprland on NixOS](https://wiki.hypr.land/0.55.0/Nix/Hyprland-on-NixOS/) | `programs.hyprland.enable = true` 安装 `pkgs.hyprland`，添加 DM session、CAP_SYS_NICE wrapper、dconf、polkit、XWayland、portal 与图形桌面基础；见 [NixOS module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/programs/wayland/hyprland.nix) | 是 | 官方称 NixOS module 为 required，HM module 不能替代系统副作用 |
| 用户配置 | [v0.55 Start](https://wiki.hypr.land/0.55.0/Configuring/Start/)、[Monitors](https://wiki.hypr.land/0.55.0/Configuring/Basics/Monitors/)、[Binds](https://wiki.hypr.land/0.55.0/Configuring/Basics/Binds/) | `wayland.windowManager.hyprland.enable = true`、`package = null`、`configType = "lua"`；HM 只生成配置，包由 NixOS 单一拥有 | 是 | 避免两层重复安装，同时获得声明式 Lua 配置 |
| 显示器 | [v0.55 monitor 通配示例](https://wiki.hypr.land/0.55.0/Configuring/Basics/Monitors/) | Lua `hl.monitor` / HM `settings.monitor` 使用空 output、`preferred`、`auto`、`auto` | 是，首轮仅通配 | 未收集精确输出名、分辨率、刷新率和缩放，不猜硬件事实 |
| 终端 | [v0.55 官方 example](https://github.com/hyprwm/Hyprland/blob/v0.55.4/example/hyprland.lua) 把 terminal 作为可替换变量 | HM Lua local 变量指向已有 `programs.ghostty`；不安装默认示例的 Kitty | 是 | Issue 要求复用现有 Ghostty；默认示例不是新增 Kitty 的需求 |
| 最小窗口操作 | [v0.55 Binds](https://wiki.hypr.land/0.55.0/Configuring/Basics/Binds/) 与 [v0.55.4 example](https://github.com/hyprwm/Hyprland/blob/v0.55.4/example/hyprland.lua) | HM Lua settings 声明启动终端/launcher、关闭窗口、退出、浮动、焦点、工作区与鼠标 move/resize | 是 | 没有这些绑定无法完成首轮桌面 smoke test；不加入输入重映射 |
| XWayland | [Hyprland on NixOS](https://wiki.hypr.land/0.55.0/Nix/Hyprland-on-NixOS/) | `programs.hyprland.xwayland.enable = true`，继而默认 `programs.xwayland.enable = true`；package 以 `enableXWayland` 构建 | 是 | 维持现有 GUI 兼容面；不是回退到 X11 session |
| GPU | [Installation](https://wiki.hypr.land/0.55.0/Getting-Started/Installation/) 仅在已知 NVIDIA 时指向专页 | 锁定模块已移除 `enableNvidiaPatches`；不设 `AQ_DRM_DEVICES` 或厂商变量 | 否 | 当前硬件证据不足；Issue 明禁猜 GPU 与厂商 workaround |
| 插件 | HM `plugins` option 仅提供机制；官方基础安装不要求 | `wayland.windowManager.hyprland.plugins = [ ]` | 否 | Issue 明确排除 Hyprland plugins |

## 4. UWSM、GDM 与 Home Manager systemd

官方 [Systemd startup](https://wiki.hypr.land/0.55.0/Useful-Utilities/Systemd-start/) 对 NixOS 明确给出
`programs.hyprland.withUWSM = true`，并警告同时使用 HM 时必须令
`wayland.windowManager.hyprland.systemd.enable = false`。采用这两个精确值。

锁定源码链如下，彼此一致而非冲突：

1. `programs.hyprland.withUWSM = true` 令 `programs.uwsm.enable = true`；UWSM 提供
   `graphical-session-pre.target`、`graphical-session.target`、XDG autostart 与清理语义，并把
   D-Bus implementation 设为 broker。见 [Hyprland NixOS module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/programs/wayland/hyprland.nix)
   和 [UWSM NixOS module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/programs/wayland/uwsm.nix)。
2. 锁定 `pkgs.hyprland` 的 `providedSessions` 同时包含 `hyprland` 与 `hyprland-uwsm`；
   `services.displayManager.sessionPackages = [ cfg.package ]` 因而让 GDM 发现包自带的 UWSM session。
   不需要再填 `programs.uwsm.waylandCompositors`。上游 desktop entry 见
   [`systemd/hyprland-uwsm.desktop`](https://github.com/hyprwm/Hyprland/blob/v0.55.4/systemd/hyprland-uwsm.desktop)。
3. HM Hyprland systemd integration 默认会自行导入环境并启停 `hyprland-session.target`；锁定实现见
   [HM module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/services/window-managers/hyprland.nix)。
   在 UWSM 下关闭它，外围 user units 改依赖通用 `graphical-session.target`，避免两个 session owner。

首轮保留 `services.displayManager.gdm.enable = true`，关闭
`services.desktopManager.gnome.enable`。锁定 [GDM module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/display-managers/gdm.nix)
为 greeter 明确加入 `gnome-session`、`gnome-shell`、AccountsService 与 PAM；这些是 GDM owner 的
闭包/服务副作用。只有 [GNOME desktop module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/desktop-managers/gnome.nix)
才把 GNOME desktop session 加入 `sessionPackages`，故关闭它满足“无 GNOME desktop session”。

## 5. 官方 must-have 与首轮外围

[v0.55 Must have](https://wiki.hypr.land/0.55.0/Useful-Utilities/Must-have/) 明确列出通知 daemon、
PipeWire/WirePlumber、portal、authentication agent、Qt Wayland 和字体。Hyprland 不是完整 DE，
这些不能假设由 compositor 自动提供。

| 类别 | 精确 owner/设置 | 是否采用 | 说明 |
| --- | --- | --- | --- |
| 通知 | HM `services.mako.enable = true`，`pkgs.mako` 1.11.0 | 是，必需 | Mako 是官方列出的示例之一；锁定 [HM Mako module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/services/mako.nix) 注册 package 与 D-Bus activation。只保留一个 notification owner |
| PipeWire | NixOS `services.pipewire.enable/alsa/pulse = true`，`pulseaudio = false` | 是，必需 | 保留现有 graphical-workstation owner；锁定 [PipeWire module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/desktops/pipewire/pipewire.nix) 生成用户 socket/service |
| WirePlumber | `services.pipewire.wireplumber.enable` 随 PipeWire 默认为 true | 是，必需 | 官方要求 WirePlumber 而非已移除的 pipewire-media-session；锁定 [WirePlumber module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/desktops/pipewire/wireplumber.nix) |
| Portal | NixOS Hyprland module + 精确 backend 集合，见第 6 节 | 是，必需 | 文件选择与屏幕共享所需 |
| polkit service | `security.polkit.enable = true`，由 NixOS Hyprland module 提供 | 是，必需 | 系统授权框架与图形 agent 是两个 owner |
| polkit agent | HM `services.hyprpolkitagent.enable = true`，`pkgs.hyprpolkitagent` 0.1.3 | 是，必需 | 官方称 GUI 提权所需；[v0.55 hyprpolkitagent](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/hyprpolkitagent/)，锁定 [HM unit](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/services/hyprpolkitagent.nix)。不再运行 polkit-gnome |
| Qt Wayland | `pkgs.qt5.qtwayland` 与 `pkgs.qt6.qtwayland` | 是，必需 | 官方要求两个 generation；包由 desktop capability 单一加入，不声明全局 toolkit 强制变量 |
| 字体 | NixOS `services.graphical-desktop` 默认字体 + 已有 Ghostty `maple-mono.NF-CN` | 是，必需 | 锁定 [graphical-desktop module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/misc/graphical-desktop.nix) 默认启用基本字体；Maple Nerd Font 继续提供 icon glyph，不额外复制 font owner |

### Bar、launcher 与 notifier

- notifier 是 must-have，首轮只选 Mako。
- launcher 不属于 must-have，但没有应用菜单时基础试用不完整；首轮只选 Fuzzel。它列于官方
  [App launchers](https://wiki.hypr.land/0.55.0/Useful-Utilities/App-Launchers/)，锁定
  [HM Fuzzel module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/programs/fuzzel.nix)
  只拥有 package 与静态配置。
- bar 不属于 must-have，但首轮需要可见的 workspace、时钟和基础状态；只选 Waybar。官方
  [Status bars](https://wiki.hypr.land/0.55.0/Useful-Utilities/Status-Bars/) 说明其原生支持 Hyprland，
  UWSM 下可用 systemd service；锁定 [HM Waybar module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/programs/waybar.nix)
  生成唯一 user unit，并绑定 `graphical-session.target`。

不同时引入 `dunst`/`swaync`/`fnott`、Rofi/Wofi/Hyprlauncher 或其他 bar；壁纸也不是首轮必须项。

## 6. Portal 精确选择

精确采用 `xdg-desktop-portal-hyprland` 1.3.12 与 `xdg-desktop-portal-gtk`，不采用
`xdg-desktop-portal-wlr` 或 `xdg-desktop-portal-gnome`：

- 官方 [XDPH page](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/xdg-desktop-portal-hyprland/)
  明确说 XDPH 提供 screen sharing/global shortcuts，但不实现 file picker，推荐并装 GTK backend。
- 锁定 NixOS Hyprland module 已设置 `enableWlrPortal = false`、加入 XDPH；共用的
  [wayland-session module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/programs/wayland/wayland-session.nix)
  加入 GTK portal。
- Hyprland 0.55.4 自带 [`hyprland-portals.conf`](https://github.com/hyprwm/Hyprland/blob/v0.55.4/assets/hyprland-portals.conf)，
  `default=hyprland;gtk`，而锁定 NixOS module 把该 package 放入 `xdg.portal.configPackages`。
  因此无需手写另一份 portal 路由。
- XDPH 1.3.12 的 [portal descriptor](https://github.com/hyprwm/xdg-desktop-portal-hyprland/blob/v1.3.12/hyprland.portal)
  只声明 Screenshot、ScreenCast、GlobalShortcuts，进一步证明 GTK fallback 不是可省略项。

GNOME Keyring 作为 Secret Service 仍被显式启用，其 NixOS module 会把 keyring package 追加到
`xdg.portal.extraPortals`。它不是“desktop portal backend”，策略测试对精确 desktop portal 集合
应只统计 `xdg-desktop-portal-*` 包，不能误删 secret-service owner。锁定 portal 的安装、D-Bus、
systemd 与配置副作用见 [xdg.portal module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/config/xdg/portal.nix)。

## 7. Hyprlock、PAM 与 always-on 边界

采用 HM `programs.hyprlock.enable = true` 管理配置，NixOS 显式声明
`security.pam.services.hyprlock = { }`。官方 [hyprlock page](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/hyprlock/)
警告没有配置时程序会退出且 session 不会锁；锁定 [HM Hyprlock module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/programs/hyprlock.nix)
也明确说明只有 HM package 没有 PAM 就不能认证。

`always-on-workstation` 的 Home Manager 实现采用 Hypridle 作为锁屏编排 owner，并保持
`listener = [ ]`；`hyprland-desktop` 不重复拥有这项空闲策略：

- `general.lock_cmd` 启动 Hyprlock；`before_sleep_cmd` 在外部请求 sleep 时锁定；
  `after_sleep_cmd` 恢复 DPMS。配置语义来自官方 [Hypridle](https://wiki.hypr.land/0.55.0/Hypr-Ecosystem/hypridle/)，
  unit 语义来自锁定 [HM Hypridle module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/services/hypridle.nix)。
- `always-on-workstation` 的需求是“不因空闲自动 suspend”，不是“禁止用户手动锁屏”或
  “屏蔽所有外部 sleep”。空 listener 明确不自动 lock、DPMS-off 或 suspend；保留锁屏命令和
  sleep 前保护。
- GDM greeter 的独立空闲 suspend 继续由 `services.displayManager.gdm.autoSuspend = false` 关闭；
  锁定 GDM option 明确说它不影响已登录 session 或 lock screen。
- 删除 GNOME session 专属 dconf idle/power 设置；Hyprland session 不由 GNOME Settings Daemon
  执行它们。不得以 Hypridle listener 重新引入 suspend。

## 8. GNOME 隐式能力的 owner 交接

锁定 GNOME module 在 `core-os-services` 中隐式启用了 IBus、keyring、polkit、rtkit、
AccountsService、UDisks2、UPower、power-profiles-daemon 等。关闭 GNOME 后必须逐项决定，不能把
`services.desktopManager.gnome.enable = false` 当作“外围自然保留”。源码证据见
[GNOME desktop module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/desktop-managers/gnome.nix)。

| 隐式能力 | 显式 owner 决策 | 理由/副作用 |
| --- | --- | --- |
| Bluetooth | 保留：`hardware.bluetooth.enable = true` | Phase 5 实机盘点已把 Bluetooth 记录为当前启用且须保留的能力；锁定 GNOME module 目前仅以 `mkDefault true` 隐式提供它，关闭 GNOME 后若不显式接管就会回退为 false。锁定 [Bluetooth module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/hardware/bluetooth.nix) 会安装 BlueZ、生成系统配置并注册 udev、D-Bus、systemd 服务；本次只保持既有 enable 行为，不修改 firewall/network policy，不声明、配对或操作任何设备 |
| Avahi/mDNS | 保留：`services.avahi.enable = true` | 锁定 GNOME module 目前以 `mkDefault true` 隐式提供 Avahi；关闭 GNOME 后若不显式接管，既有 mDNS 与 UDP 5353 会消失，并违反现有 stable-workstation-access 策略要求的 UDP `[5353, 41641, 53317]` 合同。锁定 [Avahi module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/networking/avahi-daemon.nix) 的 `openFirewall` 默认为 true，精确加入 UDP 5353；本次只保持既有 daemon/mDNS/firewall 行为，不增加 publish 设置、service files、reflector、wide-area、NSS integration 或其他端口 |
| IBus | 保留：`i18n.inputMethod.enable = true; type = "ibus"` | Issue 要求不切 Fcitx；锁定 [IBus module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/i18n/input-method/ibus.nix) 同时要求 dconf、D-Bus、XDG autostart、输入法环境与 portal integration |
| dconf | 保留：`programs.dconf.enable = true` | IBus 明确依赖；只删除 GNOME session 专属键，不删除 dconf service |
| secret service/keyring | 保留：`services.gnome.gnome-keyring.enable = true` | 锁定 [keyring module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/desktops/gnome/gnome-keyring.nix) 安装 package/D-Bus/portal，设置 CAP_IPC_LOCK wrapper，并令 login PAM `enableGnomeKeyring = true`；不能只装 package |
| polkit | 保留：NixOS Hyprland module owner；agent 由 HM hyprpolkitagent owner | 避免把 system daemon 与 prompt agent 混为一项，也避免两个 agent |
| AccountsService | 保留为 GDM 隐式 owner，不重复声明 | 锁定 GDM module 为选取用户启用它；只要 GDM 保留就不是 orphan |
| UDisks2 | 首轮不新增 owner；显式记录为不保留 | Issue 未要求 GNOME Files/自动挂载，现有能力矩阵也无 file-manager owner；若后续需要 GUI removable-storage 操作，另开窄 Issue。`services.udisks2.enable` 还会启用 polkit、D-Bus、udev 与 `/var/lib/udisks2`，见 [module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/hardware/udisks2.nix) |
| UPower | 首轮不新增 owner；显式记录为不保留 | 未确认电池/外设电量需求，且不猜 nixbox 形态；后续状态栏真实需求可独立采用。见 [module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/hardware/upower.nix) |
| power-profiles-daemon | 首轮不新增 owner；显式记录为不保留 | always-on 只约束自动 suspend，不等同于需要可切换 power profile；该 daemon 与 TLP/auto-cpufreq 有 assertion 冲突，不能顺手继承。见 [module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/services/hardware/power-profiles-daemon.nix) |
| rtkit | 保留在中立 graphical-workstation primitive | PipeWire 既有基线，不再由 GNOME 隐式拥有 |
| NetworkManager、PipeWire、打印、Firefox | 保留在中立 graphical-workstation primitive | 这些是迁移前 `modules/nixos/desktop.nix` 的既有工作站责任，不能随 GNOME session 删除 |

## 9. 可变状态与人工边界

| 路径/状态 | owner 与处理 |
| --- | --- |
| `~/.config/hypr/hyprland.lua`、`hyprlock.conf`、Mako/Fuzzel/Waybar 配置 | Home Manager 管理的稳定配置，不能让应用覆盖 Store link |
| `~/.config/uwsm/env`、`~/.config/uwsm/env-hyprland` | 官方 UWSM 环境入口；本 Issue 不加入 GPU/toolkit 猜测。若以后采用，须由声明单一拥有，不能保留手写漂移。见 [Environment variables](https://wiki.hypr.land/0.55.0/Configuring/Advanced-and-Cool/Environment-variables/) |
| `$XDG_RUNTIME_DIR/hypr`、Wayland socket、systemd user session 与 portal/PipeWire sockets | 登录 session 的易失运行态；不备份、不提交、不由 Git 恢复 |
| `~/.local/share/keyrings` 与登录解锁状态 | GNOME Keyring/用户拥有的敏感可变状态；绝不链接进 Store、复制进 Git 或由 generation rollback 覆盖 |
| dconf user database、IBus runtime/preferences | 用户/IBus 可变状态；保留 owner，不把 GNOME session 键继续声明。输入体验须在获批实机试用中验证 |
| GDM session choice/account state | GDM/AccountsService 可变状态；构建不会改变真实登录选择，generation rollback 也不保证恢复用户选择 |
| 应用状态 | Ghostty、Firefox、Chrome、Zed、Obsidian、LocalSend 等既有 profile/cache/session 继续各自拥有；本 Issue 不迁移、不删除、不备份 |

`nixos-rebuild test` 或 generation rollback 只能切换声明 closure，不能恢复上述用户状态。首次实机
试用必须使用独立、获批 runbook；失败时优先重启回当前默认 GNOME generation，且不得删除已验收
GNOME generation、GC root 或 boot entry。

## 10. 冲突、未知事实与 STOP 条件

### 已核对但不是冲突

- v0.55 Wiki 说 `withUWSM` 生成/提供 `hyprland-uwsm.desktop`；锁定模块没有自动填
  `programs.uwsm.waylandCompositors`。第 4 节证明 desktop entry 来自锁定 Hyprland package 自身的
  `providedSessions`，由 `sessionPackages` 暴露，最终行为一致。
- v0.55 NixOS page 把 fonts 列为 NixOS module 的 critical components；锁定 Hyprland module 经
  `services.graphical-desktop.enable` 默认启用字体包，行为一致。
- v0.55 hyprpolkitagent page 建议 UWSM 下 enable upstream user service；锁定 HM module生成等价的
  `graphical-session.target` unit。采用 HM unit 作为单一 owner，不同时 enable 第二份 upstream unit。
- GDM 引入 GNOME Shell/Session package 与“GNOME desktop session = false”不冲突；前者只服务 greeter，
  后者不再把 `gnome-session.sessions` 注册为用户 session。

### 仍需实机验证、不得猜测

- 显示输出名、分辨率、刷新率、缩放、VRR/HDR、GPU vendor 与任何 GPU workaround。
- IBus 在 UWSM/Hyprland 下的实际输入、keyring 是否随 GDM login 正确解锁、portal 文件选择与
  screen sharing、notification D-Bus activation、polkit prompt、Qt5/Qt6 Wayland app。
- Waybar 针对真实输出可用的模块；首轮不因猜测硬件而启用 battery/backlight/temperature。
- `nixbox` 是否未来需要 UDisks2、UPower 或 power profile UI；当前明确不继承 GNOME 默认。
- Hyprlock 解锁与手动 lock、外部 sleep 前 lock/唤醒后 DPMS；always-on 必须确认没有 idle suspend。

若任一构建结果出现额外 desktop portal、第二个 notification/launcher/polkit agent owner、HM
Hyprland systemd 被重新启用、GNOME session 仍注册、Hyprlock 无 PAM、或 Hyprland 不再是 0.55.4，
均为实现 STOP：先记录锁定源码差异，不能靠命令式 autostart、社区 dotfiles 或环境变量 workaround
绕过。

## 11. 明确排除项

- activation、注销、重启、GC、merge、auto-merge、把 Draft PR 标 ready；
- GNOME desktop session、Plasma、第二个 display manager；
- GPU 厂商设置、boot/filesystem/network/DNS/firewall/SSH/Tailscale/secret 变更；
- Hyprland plugins、主题/rice、壁纸、截图工作流、clipboard history、输入重映射、Fcitx；
- Kitty、Rofi、Wofi、SwayNC、Dunst、Hyprlauncher 或其他重复 owner；
- Flatpak、额外 portal、GNOME Files/UDisks UI、电源 profile UI；
- 把任何 keyring、dconf、IBus、浏览器、应用 profile 或 session 数据纳入 Git/Nix Store。
