# nixbox 的 Linux 桌面与微工具研究

## 1. 结论先行

nixbox 当前以 GNOME + GDM 为桌面基线，并已有 Ghostty、Zed、Yazi、btop、LocalSend、Tailscale、Codex、ax 与 RTK。最有价值的下一步不是立刻换桌面或堆一份“Linux 必装清单”，而是先把当前锁定 GNOME Shell 50.2 里已经存在、但容易被 macOS 使用习惯遮住的能力用熟：GNOME Overview 与动态工作区、内置搜索、左右分屏、通知中心、截图/录屏、Files 与 portal、以及 PipeWire 的逐应用音频图。

这份研究把微观候选分成五层：

1. **现在就能体验**：不安装、不改声明，先验证现有 GNOME 会话已有能力；
2. **低风险加一项**：单一用户工具，能够说清 package owner 与可变状态；
3. **可回滚的桌面 configuration 实验**：候选 configuration 只保留 niri、Hyprland、Sway 或 Plasma 这一套桌面 owner；首次 `test` 期间，已验收的 GNOME/GDM 仍是当前默认 system generation；
4. **需要系统级 Issue**：会增加 daemon、libvirt、Flatpak runtime、设备访问、input hook、特权 tracing、网络或硬件控制；
5. **不建议现在做**：在同一 configuration 永久并装完整桌面、候选稳定前删除唯一已验收 system generation 或其 GC root、堆叠扩展、双重 package owner 或为兼容性全局放宽安全边界。

真正值得优先感受的 Linux 差异是“系统各层可以被看见并重新连接”：桌面会话是可替换组件，音频是可观察的 graph，应用可经 portal 获得窄权限，VM 可直接使用 KVM，程序与 kernel 的交互可用 `strace`、`perf`、Sysprof、rr 与 eBPF 拆开观察，Nix closure 又能被搜索、比较和浏览。

本文是后续设计输入，**不构成安装、NixOS/Home Manager activation、网络、防火墙、boot、disk、driver、设备权限或特权 tracing 授权**。任何进入 nix-config 的变化仍须有范围准确的 Issue、完整能力合同、离线验证与真人关卡。

## 2. 先分清桌面的三个层次

### 2.1 DE、compositor 与 extension 不是一回事

- **Desktop Environment（DE）** 是一整套工作环境。GNOME 包括 GNOME Shell、设置、会话、通知、文件选择和一组集成应用；KDE Plasma 则围绕 Plasma Shell、KWin、System Settings、KRunner、Klipper 与 KDE 应用形成另一套完整体验。
- **Wayland compositor** 同时负责合成显示、输入、窗口排列与协议实现。niri、Hyprland、Sway 都是 compositor，不等于一套开箱即用的完整 DE；特别是 Hyprland 官方安装文档明确提醒它不是完整 DE，launcher、bar、portal、polkit agent、锁屏等组件需要自行组合。[Hyprland：Installation](https://wiki.hypr.land/Getting-Started/Installation/)
- **GNOME Shell extension** 是加载进 GNOME Shell 的扩展代码，不是独立桌面。它可以补 clipboard、tiling 或 dock 行为，但会跟随 Shell API 变化；GNOME 官方也明确提示第三方扩展可能造成 Shell 崩溃或异常。[GNOME Extensions：About](https://extensions.gnome.org/about/)

所以“想试自动平铺”不要求在同一 configuration 并装两个桌面。更稳妥的顺序是：先用 GNOME 原生分屏与工作区；再只加一个可撤销的小工具；确实要换 compositor 时，为目标桌面建立单一 owner 的候选 configuration。首次 `nixos-rebuild test` 不更新 system profile，恢复点仍是当前默认的 GNOME generation；候选通过 smoke 并被提升后，GNOME 才成为上一代 generation。

### 2.2 GNOME：先榨干当前基线

GNOME 的强项不是把所有按钮常驻，而是把 app 搜索、窗口总览和动态工作区汇在 Overview：按 `Super` 后直接输入即可启动应用或搜索，工作区用于按任务分组窗口，原生支持两窗左右平铺。[GNOME：Windows and workspaces](https://help.gnome.org/gnome-help/shell-windows.html)，[GNOME：Switch between workspaces](https://help.gnome.org/users/gnome-help/stable/shell-workspaces-switch.html)

当前 GNOME 还原生整合通知与日历、快速设置，以及区域/窗口/全屏截图和录屏；截图同时进入文件与 clipboard，录屏保存为普通视频文件。[GNOME：Visual overview](https://help.gnome.org/gnome-help/shell-introduction.html)，[GNOME：Screenshots and screencasts](https://help.gnome.org/gnome-help/screen-shot-record.html)

GNOME 50 的官方发布说明还覆盖改进的 fractional scaling、VRR、远程桌面硬件加速与 HiDPI、摄像头重定向、HDR screen sharing 和 Files 改进。这些是当前桌面值得先验证的能力，不应误写成要另装的新工具。[GNOME 50 Release Notes](https://release.gnome.org/50/)

与 macOS 相比，GNOME 的 Overview 更鼓励“任务工作区”而不是在 Dock、Mission Control 和 Spotlight 之间切换；代价是高阶 tiling、clipboard history 与 Raycast 式插件生态通常要靠 extension 或额外 app。对 nixbox 的建议是先形成 `Super → 搜索/切窗 → 工作区` 的肌肉记忆，暂不堆扩展。

若原生两窗分屏确实不够，第一个温和的桌面实验应是 **Tiling Shell**：官方扩展页当前标记 GNOME 50 为 active，提供自定义布局、多屏、键盘操作、类似 Fancy Zones 的 snap assistant 与可选自动平铺。[Tiling Shell 官方扩展页](https://extensions.gnome.org/extension/7065/tiling-shell/)。一次只能有一个 tiling owner；不要同时启用 Tiling Shell、Tiling Assistant、PaperWM 或另一套会修改 workspace/gesture 的扩展。

Clipboard Indicator 官方扩展页当前同样列出 GNOME 50 支持，可提供搜索与历史；但 clipboard history 可能持久化密码、token、private key 或截图，采用前必须有敏感内容排除、保留时间/自动清理与一键禁用合同。[Clipboard Indicator 官方扩展页](https://extensions.gnome.org/extension/779/clipboard-indicator/)

PaperWM 是更强的 scrollable-tiling 范式，会管理部分 GNOME 设置，并可能与改变 workspace、gesture、top bar 的扩展冲突。它适合在第二阶段与 niri 做 A/B，而不是和 Tiling Shell 同时启用。[PaperWM 官方仓库](https://github.com/paperwm/PaperWM)

### 2.3 KDE Plasma：完整而显式的另一种桌面

Plasma 更像一套可以逐项显式配置的桌面：KRunner 能启动应用、搜索桌面数据、计算和执行插件动作；Klipper 是原生 clipboard history；KWin 提供窗口规则和效果；Activities 可让不同任务拥有不同 widgets、主题和桌面上下文。[KDE：KRunner](https://docs.kde.org/stable_kf6/en/plasma-desktop/plasma-desktop/krunner.html)，[KDE：Activities](https://docs.kde.org/stable_kf6/en/plasma-desktop/kcontrol/kcmactivities/index.html)，[KDE：Klipper](https://docs.kde.org/stable5/en/plasma-workspace/klipper/)

它和 macOS 的差异在于：窗口规则、global shortcut、launcher、clipboard、panel 与 widgets 都更公开、更可组合。代价是配置面更大；若与 GNOME 同时存在，还会出现两套 portal、keyring、默认应用和视觉设置。Plasma 应作为**完整 replacement configuration 实验**，不应为了一个 clipboard history 或 launcher 就引入整套 DE。

### 2.4 niri、Hyprland 与 Sway：三种 Wayland 平铺方向

- **niri** 把窗口排成无限横向列；新增窗口不会挤压既有窗口，每个显示器有独立的动态工作区，并带 Overview、截图、portal 录屏、敏感窗口遮挡和手势。它与 GNOME 的动态工作区心智较接近，又能体验 scrollable tiling，最适合作为第一个独立 compositor 会话。[niri 官方仓库](https://github.com/niri-wm/niri)
- **Hyprland** 强调动态平铺、动画、窗口组、special workspace、IPC 与插件，视觉可塑性最高；但官方也明确它不是完整 DE，外围组件的选择、拼装与升级兼容都由用户承担。[Hyprland 官网](https://hypr.land/)，[Hyprland：Must-have utilities](https://wiki.hypr.land/Useful-Utilities/Must-have/)
- **Sway** 是与 i3 配置和操作模型兼容的 Wayland compositor，默认网格式平铺、键盘驱动、配置面稳定清晰；它最适合想学习“窗口树 + 明确快捷键”的用户，但完整桌面体验同样需要 bar、launcher、notification daemon、portal 和锁屏等配套。[Sway 官网](https://swaywm.org/)，[Sway 官方仓库](https://github.com/swaywm/sway)

三者都可以在候选 configuration 中直接取代 GNOME desktop。正确实验形态是：独立配置目录，明确 portal/polkit/notification/lock contract，运行中的 configuration 只有一套 desktop session owner；首次可暂时沿用已知可用的 GDM，把 display manager 更换留作后续独立决策。锁定 NixOS 的 GDM 模块自身仍以 GNOME Shell/Session 运行 greeter，因此“移除 GNOME desktop session”不等于 closure 中没有任何 GNOME package。`test` 阶段的恢复路径是 reboot 进入仍为默认的 GNOME/GDM generation，而不是依赖同一 configuration 内注销换会话。

## 3. Top 12 微观体验

| 排名 | 体验 | 为什么值得 | 分层 |
| --- | --- | --- | --- |
| 1 | GNOME Overview + 动态工作区 | 零安装，最能改变 macOS 用户的窗口组织习惯 | 现在就能体验 |
| 2 | Tiling Shell 单扩展 | 在不换 GNOME 的情况下体验自定义 zone、多屏与可选自动平铺 | 低风险加一项；唯一 tiling owner |
| 3 | GNOME 原生截图/录屏 + Gradia | 从捕获到标注、打码、代码图形成短闭环 | 现在体验捕获；Gradia 低风险加一项 |
| 4 | PipeWire 的 `wpctl` / `qpwgraph` 音频图 | 看见并重连 app、麦克风、耳机和虚拟节点，是 macOS 默认 UI 很少暴露的能力 | 现在只读；GUI patchbay 低风险加一项 |
| 5 | Resources | 用原生 GNOME GUI 看 CPU、内存、GPU、网络、存储和电池，补足已有 btop | 低风险加一项 |
| 6 | `nix-index` + `comma` | 从“哪个包提供这个文件”到“一次性运行而不安装” | 低风险加一项 |
| 7 | 现有 `nh`/`nom` + `nix-tree` + `nix store diff-closures` | 看 build 进度、closure 依赖和 generation 差异；`nh` 已以 `nom` 为 runtime dependency | 现有能力 + 低风险加一项 |
| 8 | GNOME Boxes | 用几次点击体验 KVM VM、snapshot、USB、clipboard 和文件共享 | 需要系统级 Issue |
| 9 | rootless Podman + Distrobox | 在 NixOS 上临时进入传统发行版 userland，理解兼容层与 owner 边界 | 需要系统级 Issue |
| 10 | `strace`，再到 Sysprof 与 rr | 从 syscall 到 GUI flame chart，再到确定性重放一个故障 | `strace` 低风险；Sysprof service 与 rr 权限另审 |
| 11 | niri replacement configuration | 用 system configuration 边界体验 scrollable tiling，首次失败时 reboot 回到当前默认 GNOME generation | 可回滚的桌面 configuration 实验 |
| 12 | Proton + Gamescope + MangoHud | 体验 Linux 游戏兼容、嵌套 compositor、缩放和帧时间观测 | 需要系统级 Issue；非开发主线 |

去重说明：Ghostty、Zed、Yazi、btop、LocalSend、Tailscale、Codex、ax、RTK、Fish、tmux、direnv、mise/uv、Obsidian、Chrome、Clash 与 Termius 已属于 nixbox 基线，不重复列为“新发现”。上表中的 Resources 补充 btop 的桌面与 GPU 视角；Nix 微工具补充已有 `nh`，不是替换它。

## 4. 日常桌面微能力目录

表中“声明适配”只描述未来适合由谁拥有，不授权实现。“风险”一栏同时覆盖 service、network 与 privilege；“状态”是应用或 runtime 的可变内容，不应因 package 被 Nix 管理就进入 Store。

| 项目 | 能做什么 / 与 macOS 差异 | 当前 GNOME 适配 | Nix 声明适配 | mutable state | service / network / privilege 风险 | 推荐层级 |
| --- | --- | --- | --- | --- | --- | --- |
| Overview、搜索、动态 workspace | 一个入口启动、查找、切窗、分任务；比 Spotlight + Mission Control 更统一 | 原生、已有 | 已属 GNOME 系统基线；不需新 package | workspace/session 运行态 | 无新增 service/network/privilege | 现在就能体验 |
| 原生左右 tiling | 拖到边缘或快捷键形成 50/50 布局；比 macOS 原生窗口排列更直接，但不等于自动平铺 | 原生、已有 | 无需声明；稳定快捷键以后可评估 dconf owner | dconf 与 session | 无 | 现在就能体验 |
| Tiling Shell | 自定义 zone、多屏、键盘与可选自动平铺，是保留 GNOME 的温和增强 | GNOME 50 active；一次只启用一个 tiling extension | extension package/version 与 dconf 应同属一个用户 capability | extension preference、布局 | Shell upgrade compatibility 与崩溃域；必须有禁用恢复 | 低风险加一项，第一桌面实验 |
| Clipboard Indicator | 搜索和复用 clipboard history；macOS 通常依赖第三方工具 | GNOME 50 active；只能有一个 clipboard owner | extension 与 privacy policy 一起声明 | clipboard history/database | 可能保存密码、token、key、截图；需自动清理/排除 | 低风险但先写隐私合同 |
| Launcher | GNOME search 已能启动与搜索；Plasma KRunner 的 calculator/actions/plugins 更像可组合 Raycast | GNOME search 原生；KRunner 属 Plasma | 不先引入第三方 launcher；若以后选一个，必须是单一 owner | 搜索历史、插件、index | 搜索插件可能联网；index 可能记录文件名 | 现在用 GNOME；Plasma 独立实验 |
| Clipboard history | GNOME 默认只提供当前 clipboard；Plasma 的 Klipper 原生保存历史，GNOME 常靠 extension/app | GNOME 需额外组件；不能假装原生 | 只选一个 owner；敏感内容默认排除或短保留 | clipboard database/history | 可能保存密码、token、截图；Shell extension 有兼容风险 | 低风险加一项，但先写隐私合同 |
| 通知中心 | GNOME 在时钟菜单集中通知、日历和日程；行为比 macOS 更简洁 | 原生、已有 | 可声明有限 dconf；应用授权仍是运行态 | notification history/permission | 通知可能泄漏内容；勿全局禁用 portal | 现在就能体验 |
| 截图与录屏 | 区域、窗口、全屏截图和 screencast 一体，结果进文件/clipboard | 原生、已有 | 无需 package；保存目录不由 Nix 管内容 | `~/Pictures/Screenshots`、`~/Videos/Screencasts` | 录屏可能捕获秘密；Wayland 下应用捕获经 portal | 现在就能体验 |
| Portal | sandbox app 通过用户选择获得文件、URI、打印、通知、截图等窄访问，而不是默认看到整台主机 | GNOME portal 是当前桌面关键基础设施 | portal backend 必须随桌面/会话一起审查，不单装“一个包” | permission store、document portal state | screen/file/device grants 是安全边界；多 backend 可能选错 | 现在观察；变更需系统级 Issue |
| Files / file manager | Nautilus 与 recent、network location、portal file chooser 深度整合；macOS Finder 更偏 Apple 服务整合 | 原生、已有 | 已属 GNOME 基线；不重复装第二 file manager 竞争默认角色 | recent、thumbnail、bookmark、mount state | network mount 会引入凭据和连接；先本地使用 | 现在就能体验 |
| Junction | 每次点击链接或文件时选择用哪个 app 打开，适合多浏览器/多 profile | GNOME 原生风格，集成良好 | 纯用户 GUI 候选；default-app owner 需唯一 | chooser preference | 无 daemon；打开外部 URI 有常规 phishing 风险 | 低风险加一项 |
| PipeWire routing | 把 browser tab、player、mic、filter、headset 视为 node/port/link，可逐流路由；比 macOS 默认 Sound UI 更像 patchbay | GNOME 音量控制已有；`wpctl` 可只读查看，`qpwgraph` 可视化 | package 可声明；WirePlumber policy 属跨层能力，不能藏在用户 dotfile | runtime graph、WirePlumber state/config | 改 link 会中断音频；mic graph 暴露隐私，低延迟/设备 policy 属系统层 | 现在只读；patchbay 低风险加一项 |
| Phone integration | [KDE Connect](https://kdeconnect.kde.org/) 协议可传文件、共享 clipboard、媒体控制、遥控输入和通知；比 AirDrop/Continuity 更开放、跨 Android/Linux | 当前 GNOME 应优先选 [GSConnect](https://github.com/GSConnect/gnome-shell-extension-gsconnect)，不与 KDE Connect desktop app 同时部署 | package、extension、firewall 与 state 要形成跨层合同；LocalSend 已覆盖基本传文件 | paired devices、keys、plugins、clipboard | NixOS 模块会开放 TCP/UDP 1714–1764；另有配对 identity、clipboard/notification 泄漏 | 需要系统级 Issue；没有真实需求先不加 |
| [`scrcpy`](https://github.com/Genymobile/scrcpy) | 通过 USB 或 TCP/IP 镜像并用键鼠控制 Android，无需 root 或在手机永久安装 app；Linux、macOS、Windows 均可用 | 普通 Wayland 窗口，可与 GNOME 共存 | package 可为用户能力；ADB/udev 与无线模式需独立说明 | ADB trust key、录屏与设备偏好 | USB debugging 等于信任主机；无线 ADB 会增加网络暴露，clipboard/input control 也属敏感能力 | 有真实 Android 开发/控制需求后评估 |
| Input remap | keyd/input-remapper 可做层、组合键、设备特定映射，比 macOS 通用设置更底层 | GNOME 可用但不属于 GNOME | daemon、udev/input group 与用户 GUI 必须同一能力公开 | mapping config、device IDs | 读取 `/dev/input` 可观察所有按键，常需 root/system daemon | 需要系统级 Issue |
| Hardware control | [Solaar](https://github.com/pwr-Solaar/Solaar) 面向部分 Logitech 设备，[Piper/libratbag](https://github.com/libratbag/piper) 面向受支持鼠标；[fwupd](https://github.com/fwupd/fwupd) 可查询/部署受支持 firmware，[OpenRGB](https://github.com/CalcProgrammer1/OpenRGB) 面向部分 RGB hardware | GUI 可融入 GNOME，但支持完全取决于具体硬件 | 必须先采真实 USB/PCI 与上游支持证据，再声明 package/udev/service owner | pairing、device profile、firmware/runtime state | raw USB/HID、udev、ratbagd、kernel module 与 firmware mutation；fwupd 更新可能要求重启，OpenRGB 权限面尤其大 | 需要系统级 Issue；OpenRGB 不建议现在做 |

PipeWire 官方把媒体建模为 device、node、port 与 link，WirePlumber 等 session manager 决定连接 policy；`wpctl status` 与 qpwgraph 分别给出文字和图形视图。[PipeWire：Overview](https://docs.pipewire.org/devel/page_overview.html)，[PipeWire：Session Manager](https://docs.pipewire.org/page_session_manager.html)

这里也不需要把所有 PipeWire 前端都装一遍：`wpctl` / `pw-top` 适合终端观察，qpwgraph 与 Helvum 都是 patchbay、应二选一；EasyEffects 则不是路由器，而是给输出和麦克风插入 EQ、compressor、limiter、noise reduction 等效果链。EasyEffects 会保存 preset、可常驻处理音频并增加 DSP load，采用时应把 preset、autostart、plugin 依赖与“故障时绕过效果链”的恢复方式一起定义；上游也特别警告不要把它创建的虚拟设备设成系统默认设备。[Helvum 官方仓库](https://gitlab.freedesktop.org/pipewire/helvum)，[EasyEffects 官方仓库](https://github.com/wwmm/easyeffects)

Flatpak 官方则明确说明：sandbox 默认只可访问 app/runtime、自身 `~/.var/app/$FLATPAK_ID` 与少数 runtime path，文件、通知、截图等能力主要由 portal 按需授权。[Flatpak：Sandbox Permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html)

## 5. Linux 原生与 Linux 上更完整的工具

### 5.1 桌面应用分发与兼容环境

| 项目 | 能做什么 / 与 macOS 差异 | 当前 GNOME 适配 | Nix 声明适配 | mutable state | service / network / privilege 风险 | 推荐层级 |
| --- | --- | --- | --- | --- | --- | --- |
| Flatpak + Flatseal | 给 GUI app 独立 runtime 与 sandbox；Flatseal 图形化查看/覆盖权限 | 与 GNOME portal 集成很好 | Flatpak system support、remote 与 app owner 必须明确；同一 app 不与 Nix package 双装 | `~/.var/app`、user/system repo、runtime、permission overrides | remote 下载、portal/device/network grant；Flatseal 放宽权限会削弱 sandbox | 需要系统级 Issue |
| rootless Podman | Linux 原生、daemonless OCI container，普通用户可运行多数 workload | CLI/TUI 与 GNOME 无冲突 | engine 与稳定 rootless policy 可声明；项目 image/volume 不进全局 profile | image、volume、auth、container DB | user namespace、subuid/subgid、网络 namespace；禁止默认 privileged/host network | 需要系统级 Issue |
| Distrobox | 在 Podman/Docker 上进入 Ubuntu/Fedora 等 userland，运行传统 FHS 软件甚至 GUI | 能共享 Wayland/X11/audio；桌面集成方便 | wrapper 可声明；box 内容是可变环境，不能冒充 Nix 声明 | container rootfs、package DB、exported desktop files、HOME 内容 | 官方明确它紧密共享 HOME、显示、音频、设备、journal、SSH agent，**不以隔离为目标** | 需要系统级 Issue；仅解明确兼容缺口 |
| GNOME Boxes | 低门槛创建 KVM VM、分配资源、snapshot、USB、3D、clipboard 与文件共享 | GNOME 原生最佳适配 | QEMU/KVM/libvirt/权限是跨层能力；disk 不进 Store | 默认 image 位于 `~/.local/share/gnome-boxes/images/`，另有 libvirt state | `/dev/kvm`、libvirt service、USB passthrough、guest network | 需要系统级 Issue |
| virt-manager | 更细控制 libvirt network、storage pool、CPU、disk 与虚拟硬件 | GTK GUI 可用，但比 Boxes 更偏管理工具 | 只在 Boxes 不够且有高级需求时单独能力化 | libvirt XML、disk image、snapshot、NVRAM | system libvirt、bridge/NAT、device passthrough、特权管理面 | 需要系统级 Issue；晚于 Boxes |

Boxes 官方说明其基于 QEMU/KVM、libvirt-glib 与 SPICE；KVM 可让同架构 guest 接近原生执行。Boxes 50 还提供资源限制、snapshot、USB、3D、clipboard 和文件共享。[GNOME Boxes：技术栈](https://help.gnome.org/gnome-boxes/supported-protocols.html)，[GNOME Boxes](https://apps.gnome.org/Boxes/)，[Boxes：disk images](https://help.gnome.org/gnome-boxes/disk-images.html)

Distrobox 官方目标是让任意发行版 userland 深度集成宿主，并明确警告 rootful 模式；其隔离边界弱于普通 sandbox。对 NixOS，它是“遇到 vendor 只支持 Ubuntu/FHS 时的有意识兼容层”，不是默认开发环境；项目 devShell 仍优先。[Distrobox 官方仓库](https://github.com/89luca89/distrobox)

### 5.2 Windows 应用与游戏栈

| 项目 | 能做什么 / 与 macOS 差异 | 当前 GNOME 适配 | Nix 声明适配 | mutable state | service / network / privilege 风险 | 推荐层级 |
| --- | --- | --- | --- | --- | --- | --- |
| Wine | 直接实现 Windows API 兼容层，不是 VM；Linux 图形/游戏生态围绕它形成完整工具链 | GNOME 可运行窗口，但输入、缩放、Wayland/XWayland 与 GPU 要实测 | 只能由明确应用能力选择版本；不做全局“万能 Wine” | prefix、registry、installed app、cache | 运行不可信 Windows 程序仍可访问用户文件/网络 | 不建议单独作为第一步 |
| Bottles | 每个 Bottle 管 runner、DXVK/VKD3D 与环境模板，适合非 Steam Windows app | GUI 友好 | package 可声明；首次启动下载组件，Bottle 内容完全可变 | Bottles data、prefix、runner、DXVK/VKD3D、installer cache | 网络下载可执行组件；filesystem grant 与 app 权限需审 | 需要系统级 Issue/独立应用需求 |
| Lutris | 统一管理 Wine、emulator、native game 与 installer recipe | GNOME 可用 | package owner 与 Steam/Bottles 职责先划分 | game library、runner、installer recipe、credential、save | 下载第三方 runner/script；游戏与 account 网络访问 | 有非 Steam 库时再评估 |
| Steam + Proton | Proton 基于 Wine，让 Windows-only Steam 游戏运行于 Linux；Valve 建议普通用户用 Steam 自带 Proton | GNOME 下可用，GPU/driver/Wayland 需实机验证 | 完整 gaming capability，而非零散包；游戏与账号不由 Nix 管 | Steam library、Proton prefix、shader cache、save、account | unfree、32-bit graphics、GPU、anti-cheat、网络与大体积状态 | 需要系统级 Issue；好玩但非开发主线 |
| Gamescope + MangoHud | Gamescope 是可嵌套 micro-compositor，可提供虚拟分辨率、帧限、FSR/NIS/整数缩放；MangoHud 显示 FPS、frametime、温度与 CPU/GPU load | 可从 GNOME 会话内嵌套运行 | 应归 gaming capability，同一 Vulkan layer owner | per-game config、benchmark log | Vulkan layer、GPU driver、benchmark log 可能含路径；上传日志是外部网络动作 | gaming 获批后再加 |

官方依据：[Bottles environments](https://docs.usebottles.com/getting-started/environments)，[Bottles runners](https://docs.usebottles.com/components/runners)，[Valve Proton](https://github.com/ValveSoftware/Proton)，[Valve Gamescope](https://github.com/ValveSoftware/gamescope)，[MangoHud](https://github.com/flightlessmango/MangoHud)。

### 5.3 Linux 的“拆开看”工具

| 项目 | 能做什么 / 与 macOS 差异 | 当前 GNOME 适配 | Nix 声明适配 | mutable state | service / network / privilege 风险 | 推荐层级 |
| --- | --- | --- | --- | --- | --- | --- |
| `strace` | 逐 syscall/signal 观察文件、网络、进程为何失败；Linux 接口直接、资料丰富 | 在 Ghostty 使用即可 | 跨项目诊断工具可为用户 package；server 已有不代表 nixbox 已有 | trace/log 文件 | attach 受 ptrace policy 限制；输出可能含路径、参数、token | 低风险加一项；先 trace 自己启动的 demo |
| Sysprof | GUI 采样 app 或系统，展示 call graph、flame chart、frame timing、allocation 等 | GNOME 原生开发工具，但启用 GNOME 不等于 Sysprof 已安装/启用 | NixOS 的受支持集成会加入 package、D-Bus 与 profiling daemon，应作为系统能力评审 | capture 文件、symbol/debuginfo cache | capture 可能含进程、路径与性能敏感信息；daemon/system capture 是特权边界 | 需要系统级 Issue；先用 `strace` 解决窄问题 |
| rr | record 一次 Linux 程序执行，再在 GDB 中确定性 replay/reverse execution，适合偶发 bug | CLI 与编辑器调试可组合 | 项目 devShell 优先；证明跨项目后再全局 | trace 目录可能很大并含程序输入/内存 | CPU/VM 条件、`perf_event` 权限；不完整 syscall 支持 | 受控项目实验 |
| `perf` | 通过 kernel `perf_events` 做 counter、sampling、report、top 与 tracepoint 分析 | CLI；Sysprof 可提供更友好的 GUI 入口 | 工具与 kernel 匹配，最好由系统能力提供 | `perf.data`、symbol/build-id cache | `perf_event_paranoid`、系统级/跨进程采样可能泄露执行与内存相关信息 | 需要系统级 Issue 才放宽权限 |
| bpftrace | 以高级语言动态挂 kprobe、uprobe、tracepoint，做低开销 Linux tracing | CLI | package 可声明，但 kernel feature、BPF policy 与 helper 是系统合同 | script、map/output、capture | 常需 root/capability；错误 probe 有性能/稳定性风险，输出可能含敏感数据 | 后置系统观察实验 |

`strace` 官方定义就是追踪 process 与 Linux kernel 之间的 system call、signal 和状态变化；Sysprof 是 GNOME 官方的应用/系统 profiler；rr 的核心价值是对已记录的失败做确定性重放；`perf` 基于 Linux `perf_events`，支持 `stat`、`record`、`report`、`top`、tracepoint 等。[strace 官方站](https://strace.io/)，[Sysprof](https://apps.gnome.org/Sysprof/)，[rr](https://rr-project.org/)，[Linux perf tutorial](https://perfwiki.github.io/main/tutorial/)，[bpftrace documentation](https://bpftrace.org/docs/)

### 5.4 Nix 专属微工具

| 项目 | 能做什么 / 与 macOS 差异 | 当前 GNOME 适配 | Nix 声明适配 | mutable state | service / network / privilege 风险 | 推荐层级 |
| --- | --- | --- | --- | --- | --- | --- |
| `nix-index` / `nix-locate` | 搜索哪个 nixpkgs package 提供某个文件，修正“传统发行版里装哪个 apt 包”的思维 | 终端工具 | 用户 package + database 来源要有单一 owner | index database/cache | 生成/更新 index 会访问 cache/network；database 可重建 | 低风险加一项 |
| `comma` | 根据 `nix-index` 找 package，再用 `nix shell` 临时运行命令而不写入长期 profile | 终端工具 | 与 `nix-index` 一起设计，避免另一套索引 owner | Nix download/store paths、index | 可能联网下载 closure；“未安装”不等于无执行风险 | 低风险加一项 |
| `nix-tree` | TUI 浏览 runtime/build dependency、closure size 与 `why-depends` | Ghostty 很适合 | 纯用户工具 | 通常无持久状态 | 查询 remote store 时联网；不需 privilege | 低风险加一项 |
| `nix-output-monitor` (`nom`) | 给 Nix build 展示实时 build/download tree 与耗时 | 当前 `nh` wrapper 已把 `nom` 作为 runtime dependency，先观察现有输出 | 默认不重复增加 package；只有需要直接调用 `nom` 时才另定 owner | build timing/cache（实现相关） | Nix 构建原有网络/daemon 权限不变；输出可能含路径 | 现在发现已有能力；非默认新增项 |
| `nix store diff-closures` / [`nvd`](https://git.sr.ht/~khumba/nvd) | 比较两个 system/profile closure 的 package 与版本差异 | 终端工具 | 内建 `diff-closures` 优先；`nvd` 成熟且 nixpkgs 仍打包，但上游长期低变更，不把它描述为活跃开发 | 无关键持久状态 | 只读比较；store path 仍可能透露软件清单 | 现在可用内建命令；nvd 低风险候选 |

一手项目说明：[nix-index](https://github.com/nix-community/nix-index)，[`comma`](https://github.com/nix-community/comma)，[`nix-tree`](https://github.com/utdemir/nix-tree)，[`nix-output-monitor`](https://github.com/maralorn/nix-output-monitor)，[Nix `diff-closures`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store-diff-closures.html)。

### 5.5 Linux / Nix 随身显微镜：无需换桌面

这组工具比“再装一个 app”更能解释 Linux 强在哪里。先使用当前系统已经提供的只读入口；只有出现明确问题，才为缺少的工具建立 package owner。不要为了体验而 attach 别人的进程、读取 raw input、放宽 kernel policy 或进入其他 namespace。

| 显微镜 | 能看见什么 / 与 macOS 的差异 | GNOME 与 Nix 适配 | mutable state | 权限与风险 | 推荐层级 |
| --- | --- | --- | --- | --- | --- |
| `systemctl` / `journalctl` | unit dependency、失败状态、结构化日志、当前 boot；Linux 日常诊断围绕统一 service model | 系统已有，不需桌面；稳定 service 才进入 NixOS module | journal 与 runtime unit state | 自己的 user unit 最安全；system journal 可能含主机与服务敏感信息 | 现在就能体验 user unit / 只读系统状态 |
| `systemd-cgls` | 直接看到 process 属于哪个 slice、scope、service 和 cgroup | 系统已有；可与 GNOME app、terminal、build 对照 | 只有运行态层级/counter | 通常可只读；不要据此随手改 system resource policy | 现在就能体验 |
| `wpctl` / `pw-top` | source、sink、stream、默认路由与实时 DSP load | 当前 PipeWire/WirePlumber 环境直接适配；先不改 policy | runtime media graph | 麦克风与 app 名称有隐私；`set-*`/link 是写操作 | 现在只读；修改路由为低风险实验 |
| `udevadm monitor` | 插拔 USB、蓝牙接收器、disk、input 后 kernel/udev 发了哪些 event | 无需换桌面；稳定 rule 属 NixOS system layer | 临时 event stream | event 会暴露 device metadata；不要从观察直接跳到自写 udev rule | 现在只读观察自有外设 |
| `wev` | Wayland compositor 实际发送给当前测试窗口的键盘、鼠标、touch event | 非全局 keylogger，适合 GNOME/独立 compositor 比较 | 无关键状态 | 只看聚焦测试窗口；输出仍可能包含输入 | 低风险加一项 |
| `evtest` | 读取 kernel evdev 的 raw device event，位于桌面/compositor 之下 | 与 GNOME 无关；仅用于真实输入故障 | 无关键状态 | 通常需要 `/dev/input` 权限；可看到全部按键，敏感且不应常驻授权 | 需要系统级 Issue/临时特权关卡 |
| `lsns` | 查看 process 所在 mount、PID、network、user 等 namespace | 系统工具；可对照 Podman/Flatpak/服务 | 无 | 普通用户信息有限；跨用户/进入 namespace 权限更高 | 现在只读查看自己的进程 |
| `unshare` / `nsenter` | 前者建立临时 namespace，后者进入现有 namespace；直接体验 container 的 Linux 基础原语 | 不依赖 GNOME；比先装容器栈更底层 | namespace 生命周期与其内临时文件 | user namespace 支持依系统 policy；`nsenter` 其他进程/系统 namespace 常需 root，进入后影响真实对象 | 独立 demo；特权使用需系统级 Issue |
| `strace` / rr | syscall 对话与确定性 record/replay | 终端/调试器即可，项目 devShell 优先 | trace 可能包含输入、路径、memory | ptrace/perf 权限与隐私边界 | 自己程序低风险；跨进程/放宽 policy 后置 |
| `perf` / bpftrace | CPU counter、sampling、tracepoint、kprobe/uprobe 与 kernel 行为 | Sysprof 可做 GUI 前端；工具与 kernel 要匹配 | profile、map、trace buffer | system-wide counter/BPF 可泄漏敏感行为并影响性能，常需 capability/root | 需要系统级 Issue |

官方入口：[systemd system and service manager](https://systemd.io/)，[`journalctl`](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)，[`systemd-cgls`](https://www.freedesktop.org/software/systemd/man/latest/systemd-cgls.html)，[`udevadm`](https://www.freedesktop.org/software/systemd/man/latest/udevadm.html)，[Linux namespaces](https://man7.org/linux/man-pages/man7/namespaces.7.html)，[PipeWire tools](https://docs.pipewire.org/page_man_pipewire_1.html)。

## 6. 精选的 GNOME 小应用：少而有角色

GNOME 官方应用目录收录的是遵循 GNOME 设计、与当前桌面一致的应用。对 nixbox 来说，下列一小组比复制普通日历、音乐、终端 app 更有增量价值。[Apps for GNOME](https://apps.gnome.org/)

| 应用 | 明确角色 | 和现有能力的关系 | 状态 / 风险 | 推荐层级 |
| --- | --- | --- | --- | --- |
| Resources | GUI 查看 CPU、内存、GPU、网络、storage、battery 和进程 | 补充已有 btop 的 GPU、桌面 app 与图形视角，不替换 btop | 本地只读为主；结束进程仍是写操作 | 低风险加一项 |
| Gradia | 快速标注、裁切、打码截图，并可把代码呈现成分享图 | 接在 GNOME 原生截图之后，不重复截图入口 | 输出文件可含敏感信息，分享前复核 | 低风险加一项 |
| Junction | 链接/文件打开时临时选择 app | 适合 Chrome 多 profile 或以后并存浏览器；不等于新增 launcher | 保存 chooser preference | 低风险加一项 |
| Text Pieces | 编码/解码、hash、文本转换的开发者 scratchpad | GUI 化零碎转换，不替代 ax/RTK 或项目脚本 | clipboard/input 可能含秘密，敏感数据勿粘贴 | 低风险加一项 |
| D-Spy / Bustle | 浏览 D-Bus object/interface 或录制/检查 D-Bus 消息 | Linux 桌面调试专用，帮助理解 portal、service 与 app 集成 | bus capture 可能含文件名、通知和 app 数据 | 后续受控实验 |
| Workbench | 即时试 GTK/libadwaita UI 与 GNOME API | 如果未来做 Linux GUI 才有价值；当前锁定 nixpkgs 浅层顶级 attr 未确认 | scratch code/project state | 有明确 GTK 学习目标后再核对来源 |

有趣但暂不需要“能力化”的体验还包括：用 `sl`、`cowsay`、`lolcat` 或 `asciiquarium` 理解 `comma` 的一次性运行；用 `nix-tree` 追一个意外的大 closure；用 qpwgraph 把一个播放器临时连到另一输出。这些实验的价值在于理解机制，不在于把玩具永久加入全局 profile。

## 7. 四周微观体验菜单

每周只做 2–3 个体验；先记录“好在哪里、哪里别扭、是否重复现有能力”，不要求安装或实现。

### 第 1 周：只用已有 GNOME

1. 用 Overview 把“开发、资料、通信”分到三个动态工作区，整周只用 `Super` 搜索和切换；
2. 分别做一次区域截图、窗口截图与短录屏，确认 clipboard、保存位置和分享前隐私检查；
3. 在 Files 中观察默认打开方式、recent、bookmark 与一次 portal 文件选择，辨认“应用看到整个 home”和“用户只授予一个文件”的区别。

### 第 2 周：看见系统内部

1. 只读查看 PipeWire/WirePlumber 的 sink、source、stream，再用图形 patchbay 草拟一次临时路由实验；
2. 用 Resources 与已有 btop 同时观察一次 build，比较 GUI、GPU 与终端信息各自优势；
3. 对自己控制的短命 demo 先用 `strace` 回答一个窄问题，例如“它打开了哪些文件”；只有出现需要 call graph/flame chart 的真实问题，再为 Sysprof 的 package、D-Bus 与 profiling daemon 建 Issue。

### 第 3 周：理解 Nix 的微型超能力

1. 用 `nix-index` 找一个命令/共享库来自哪个 package，再用 `comma` 运行一个无害小工具；
2. 用 `nix-tree` 查看一个已知 closure 的最大依赖或 `why-depends`；
3. 对两个已存在的 closure 做只读 `nix store diff-closures`，练习区分“build 结果差异”和“机器已 activation”。

### 第 4 周：只选一条分支

- **桌面分支：** 在独立 Issue 里设计 niri replacement configuration，只体验 scrollable tiling，并从当前默认 GNOME generation 验证首次恢复；或
- **虚拟化分支：** 为 Boxes 设计 KVM/libvirt、disk state、guest network、snapshot 与卸载合同；或
- **兼容分支：** 针对一个真实非 FHS/vendor 工具设计 rootless Podman + Distrobox spike；或
- **游戏分支：** 针对一款明确游戏核对 Steam/Proton、GPU、32-bit graphics、Gamescope/MangoHud 与 game state。

第 4 周只选一条，不同时引入第二桌面、Flatpak、Podman、libvirt 与 gaming stack。

## 8. 必须正视的 Linux / NixOS 微观摩擦

### 8.1 Wayland 的自动化限制是安全模型的一部分

Wayland client 默认不能像 X11 应用那样任意读取全局按键、窗口内容、坐标或向别的 app 注入输入；截图、录屏、remote desktop 和文件访问通常经 compositor 与 portal 授权。这会让某些 macOS/X11 风格全局自动化、取色、窗口控制或 macro 工具受限，但也减少任意应用静默监视整个桌面的能力。[XDG Desktop Portal：ScreenCast](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html)，[RemoteDesktop](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.RemoteDesktop.html)

因此不要为了某个自动化工具默认切回 X11、给 Flatpak `--socket=x11`、开放 `/dev/input` 或使用全局 input injection。先确认 compositor/portal 是否有窄接口，再把确需的权限写入独立能力合同。

### 8.2 GNOME extension 有版本与故障域成本

extension 运行在 Shell 故障域内，GNOME major upgrade 可能改变兼容性。clipboard、tiling、GSConnect、dock 等每加一个 extension，都应记录上游、Shell version、mutable preference、禁用恢复路径与登录 smoke；不要一次装一套“必装 extensions”。

### 8.3 NixOS 不是传统 FHS 发行版

网页、npm package、vendor installer 或 AppImage 附带的动态 Linux binary 常假设 `/lib`、`/usr/lib` 与固定 interpreter，在 NixOS 上可能直接报找不到 loader/library。优先次序应是：锁定 nixpkgs package → 项目 devShell/正式 packaging → 针对真实缺口的 Distrobox/Flatpak/Bottles；只有明确需求才评估 `nix-ld` 或 FHS 环境，不全局打开兼容层。[nix.dev FAQ：non-Nix executables](https://nix.dev/guides/faq.html#how-to-run-non-nix-executables)

### 8.4 多个 package owner 会制造“看似能用”的漂移

同一 app 不应同时由 Home Manager、NixOS、Flatpak、Distrobox export、Bottles、Steam 或手工 installer 管。典型冲突包括：Nix 版与 Flatpak 版应用各有 profile；GNOME 与 Plasma portal backend 同时竞争；Bottles/Lutris/Steam 各自下载 Wine/Proton；两个 clipboard manager 同时监听；GNOME extension 与 compositor 规则重复改窗口。

采用前必须回答：谁安装 package，谁管理稳定配置，谁拥有 desktop entry/default app，状态在哪里，卸载哪一层不会删用户数据。

### 8.5 Driver、外设与休眠不能从“Linux 支持”推断到本机

GPU/Vulkan、VRR/HDR、fractional scaling、多显示器、摄像头、麦克风、蓝牙 codec、打印、鼠标 feature、USB passthrough、睡眠/唤醒都依赖具体 hardware、firmware、kernel、driver、compositor 与应用组合。当前 GNOME 可登录只证明基线，不证明 Plasma/niri、Steam、KVM passthrough 或 suspend 都可靠。

即使已有硬件 inventory，也不能从设备型号直接推断某项能力已经可靠；Plasma/niri 下的显示效果、virtualization firmware 开关、HDR/VRR、休眠与具体外设仍须逐项采集真实 nixbox 证据。也不为了体验顺手改 kernel parameter、udev、initrd、boot 或 driver。

## 9. 分层后的候选决策

### 现在就能体验

- GNOME Overview、搜索、动态工作区与原生左右平铺；
- 通知中心、截图/录屏、Files 与现有 portal 文件选择；
- 当前 PipeWire/WirePlumber 的只读状态；
- 已有 `nh` 与 Nix 内建 `nix store diff-closures` 的只读视角；
- Ghostty/Zed/Yazi/btop/LocalSend/Tailscale/Codex/ax/RTK 的既有能力，不重复安装。

### 低风险加一项

- Resources、Gradia、Junction 或 Text Pieces 中一次只选一个；
- qpwgraph 只作为当前 PipeWire graph 的用户 patchbay，不改全局 WirePlumber policy；
- `nix-index` + `comma` 作为一个组合，或单独增加 `nix-tree`；`nh` 已携带 `nom` runtime，不重复加 `nix-output-monitor`；
- `strace` 先用于自己启动的 demo，不 attach 别人的进程，也不放宽 system-wide tracing 权限。

### 可回滚的桌面 configuration 实验

- 第一候选是 niri；第二候选按偏好选择 Plasma（完整 DE）、Sway（i3 模型）或 Hyprland（视觉与插件）；
- 候选 configuration 移除 GNOME desktop，只组合目标 session/config；bar、launcher、notification、clipboard、polkit agent、locker、idle manager 与 portal backend 各自只能有一个 owner；
- 首次 `test` 期间，当前默认的 GNOME/GDM system generation 及其 GC root 必须保留；若后续用 `boot` 或 `switch` 提升候选，还要验证 systemd-boot 中仍有已验收 GNOME generation 的启动项；display manager 是否更换与 desktop 是否更换分开决策；
- 一次只试一个桌面，不同时比较四套桌面。

### 需要系统级 Issue

- Flatpak/Flathub/Flatseal 与 portal/permission ownership；
- Podman/Distrobox 的 rootless、subuid/subgid、image/volume/auth 与 host integration；
- Boxes/virt-manager 的 KVM、libvirt、disk、snapshot、guest network 与 USB；
- KDE Connect/GSConnect 的 listener、firewall、pairing、clipboard 与 notification；
- keyd/input-remapper、Piper/libratbag、OpenRGB 等 device/input/udev/service 权限；
- Steam/Proton、32-bit GPU stack、Gamescope/MangoHud；
- Sysprof 的 package、D-Bus 与 profiling daemon 集成；
- system-wide perf、bpftrace 或放宽 `perf_event_paranoid`/ptrace policy。

### 不建议现在做

- 在同一候选 configuration 永久并装 GNOME 与另一套完整桌面；
- 在同一步同时更换 desktop、display manager 与底层输入策略，或在候选稳定前删除已验收 GNOME system generation、其 GC root 或启动项；
- 一次加入大量 GNOME extensions 或复制网络上的“必装扩展清单”；
- 同时运行 GNOME + Plasma 两套默认应用/portal/keyring 而不定义 owner；
- 同一 app 同时用 Nix package 与 Flatpak，或同时部署 Bottles、Lutris、系统 Wine 与多套 Proton；
- 为 vendor binary 全局开启宽泛 FHS/nix-ld、为 macro 开 `/dev/input`、为 VM 直接建 bridge/passthrough；
- 现在引入 OpenRGB、GPU passthrough、custom kernel 或改真实 disk/boot/休眠策略。

## 10. 锁定 nixpkgs 的只读可用性证据

2026-08-12 只读评估 `nixosConfigurations.nixbox.pkgs`，未 build、安装或 activation。已确认候选包括：

- desktop/compositor：GNOME Shell 50.2、Plasma 6.6.6、`niri` 26.04、`hyprland` 0.55.4、`sway` 1.12、COSMIC session 1.2.0、Xfce session 4.20.4、Waybar 0.15.0；
- media / desktop：`pipewire` 1.6.6、`wireplumber` 0.5.14、`qpwgraph` 1.0.3、`gnome-boxes` 50.0、`virt-manager` 5.1.0；
- compatibility / gaming：`podman` 5.8.2、`distrobox` 1.8.2.5、`bottles` 63.2、Wine 11.0、`lutris` 0.5.22、`proton-ge-bin`、`gamescope` 3.16.23、`mangohud` 0.8.3；
- tracing：`rr` 5.9.0、`strace` 7.1、kernel-matched `perf`、`bpftrace` 0.25.1、`sysprof` 50.0；
- Nix 工具：`nix-index`、`comma`、`nvd`、`nix-tree`、`nix-output-monitor`；
- hardware/input 候选：`input-remapper`、`keyd`、`kanata`、`piper`、`openrgb`；其中 keyd 是基于 evdev/uinput 的 system-wide daemon，官方明确警告错误映射可导致机器无法操作，因此必须有 emergency/recovery smoke，且不能与 input-remapper/Kanata 叠加 owner。[keyd 官方仓库](https://github.com/rvaiya/keyd)，[input-remapper 官方仓库](https://github.com/sezanzeb/input-remapper)，[Kanata 官方仓库](https://github.com/jtroo/kanata)

补充的只读精确 attr 核对确认：Tiling Shell 76、Clipboard Indicator 71、AppIndicator 64、GSConnect 72、`helvum`、`kdePackages.kdeconnect-kde`、`gnomeExtensions.paperwm`、`gnomeExtensions.tiling-assistant`、`easyeffects`、`pwvucontrol`、`wiremix`、`warehouse`、`scrcpy`、`solaar`、`fwupd`、`kanata` 以及本文精选的 Resources、Gradia、Junction、Bustle、D-Spy 均有锁定候选。`flatseal` 顶级 attr 不存在；若未来采用，应作为 Flathub 管理 Flatpak 权限的 app 核对，不得声称它来自当前 nixpkgs。可用不等于推荐，尤其 extension、音频 mixer、input remapper 与 hardware tool 都不能叠加多个 owner。

## 11. 微工具采用前的统一合同

任何微工具若要从“体验”进入 nix-config，Issue 至少回答：

1. 它解决哪个重复出现的真实任务，而不是只因“Linux 用户都装”；
2. 它是项目 devShell、纯用户 capability、跨层 capability、NixOS system module，还是 host/hardware fact；
3. package、desktop entry、default app、稳定配置与更新的唯一 owner 是谁；
4. mutable state、downloaded runtime、index、prefix、VM disk、game library、trace 与 credential 在哪里，谁备份，卸载时保留什么；
5. 是否新增 daemon、socket、listener、firewall、portal backend、network remote、udev rule、input/device access、group、capability 或 sudo；
6. 离线 build/evaluation 能证明什么，真实 GNOME/Wayland、GPU、audio、device、sleep 与 reboot 又需要哪些真人 smoke；
7. 如何在不删可变数据的情况下恢复：`test` 阶段 reboot 回当前默认 generation；候选提升后再从上一代启动或 rollback。

本文没有授权执行 `nixos-rebuild test` / `boot` / `switch`、Home Manager activation、Flatpak remote/app 安装、container pull、libvirt/VM 创建、desktop session 切换、Steam/Wine runner 下载、input/udev/driver 修改、网络/firewall 变更、特权 trace、reboot、删除 system generation/GC root、boot 或 disk 操作。首次 `test` 的默认恢复点是当前默认 GNOME/GDM generation；候选被提升后，恢复点才是保留下来的上一代 GNOME/GDM generation。尚未完成的真人验证关卡仍以对应 Issue 的记录为准。

## 12. 如果要换桌面：候选、利弊与社区建议

这里的“社区建议”只表示少量真实用户报告呈现的**经验信号**，不是统计结论或普遍共识。硬件、驱动、显示器和配置差异足以让相反经验同时成立；功能与整合判断仍以项目文档、锁定 nixpkgs 模块和 nixbox 实机 smoke 为准。

### 12.1 建议顺序

1. **GNOME 不换：** 先用一周原生工作区；若决定换桌面，首次 `test` 时它仍是当前默认 generation，候选提升后才成为上一代已验收 generation。
2. **niri：** 第一套 replacement configuration，最小成本验证自己是否真喜欢键盘驱动与 scrollable tiling。
3. **Plasma：** 如果想比较的是完整桌面，而不是窗口排列算法，第二个试它。
4. **COSMIC：** 想要“完整 DE + 内建自动平铺”时做预览性实验；当前不取代基线。
5. **Sway / Hyprland 二选一：** 前者学习稳定、显式的 i3 树模型；后者追求动画、special workspace 和深度定制。不要同时组装两套外围组件。
6. **Xfce：** 仅在“传统桌面、X11 或低资源占用”成为明确需求时进入候选，不是当前 Wayland-first nixbox 的默认升级方向。

所有切换实验都应把恢复能力留在 system profile 与 boot entry，而不是在当前桌面里。NixOS 26.05 手册说明：`nixos-rebuild test` 只切换运行态，不更新 system profile 或默认启动配置；因此首次候选锁死时应 reboot 回到仍为默认的 GNOME generation，不能把 `nixos-rebuild switch --rollback` 当成撤销 `test`，因为 profile 从未指向候选。只有候选经 `boot` 或 `switch` 被提升为 system generation 后，保留下来的上一代 GNOME generation 才能作为 boot/rollback 目标。[NixOS Manual：Changing the Configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config)，[Rolling Back Configuration Changes](https://nixos.org/manual/nixos/stable/#sec-rollback)

nixbox 使用 systemd-boot；其可见历史还受 `boot.loader.systemd-boot.configurationLimit` 和实际生成的 boot entry 约束。当前配置没有收紧该 limit，但候选 Issue 仍应在提升前记录已验收 generation，在提升后核对对应 entry，而不是仅凭 Store 中仍有 closure 就假定 boot menu 一定可恢复。[NixOS Options：systemd-boot configurationLimit](https://search.nixos.org/options?show=boot.loader.systemd-boot.configurationLimit&query=boot.loader.systemd-boot.configurationLimit)

这不是 mutable-data rollback：目标桌面写入的 dconf、`~/.config`、portal permission、clipboard history、Flatpak 数据、浏览器 profile 与其他应用状态不会随 system generation 自动倒退。候选 Issue 必须先记录这些状态的 owner 和保留/清理边界；失败时优先保留证据并回到旧 generation，不删除用户数据。

### 12.2 GNOME：已验收基线，而不是候选 configuration 的永久共存项

- **范式与强项：** 完整、克制的 DE；Overview、动态工作区、搜索、通知、设置、keyring 与 portal 已形成一致体验，当前 GNOME 50 还把 fractional scaling、VRR、远程桌面等能力放在同一系统中。[GNOME 50 Release Notes](https://release.gnome.org/50/)
- **明显缺点：** 原生平铺较浅；深入定制常依赖 extension/dconf，Shell 大版本升级会扩大兼容与恢复成本。
- **NixOS 整合：** 成本最低，当前 GDM、GNOME portal、Files 和 keyring 都已有 owner；不新增另一套默认应用或 portal。
- **适合谁 / 建议：** 想把机器尽快变成可靠开发机、重视一致性多于配置自由的人。先保留至少一个完整体验周期，再判断痛点是不是桌面本身。
- **经验信号：** 一组 NixOS 用户讨论报告 GNOME “低配置即可工作”，同时也有人认为 GNOME/Plasma 的状态型配置不如文本配置 compositor 直观；这是配置偏好样本，不是流行度结论。[NixOS Discourse：No love for GNOME?](https://discourse.nixos.org/t/no-love-for-gnome/73226)

### 12.3 KDE Plasma：最值得比较的完整替代 DE

- **范式与强项：** 传统桌面骨架加高度可配置的 KWin、panel、KRunner、Klipper、窗口规则与 Activities；对从 macOS 来、但希望系统把设置显式展示出来的人最友好。[KDE Plasma](https://kde.org/plasma-desktop/)
- **明显缺点：** 选项与状态面很大，Qt/KDE 与 GTK/GNOME 应用的主题、默认应用、wallet/keyring 和设置可能形成两套心智模型。
- **NixOS 整合：** 锁定 `services.desktopManager.plasma6.enable` 会加入 KDE/GTK portal、KWallet、polkit agent 和系统包，注册 Plasma 会话并把默认会话设为 `plasma`；它会预配置 SDDM 的 package/theme/Wayland defaults，但不会因此自动启用 SDDM。候选 configuration 应移除 GNOME desktop、显式保持单一 display manager，再检查 file chooser、screen sharing、secret portal 与默认应用。
- **适合谁 / 建议：** 喜欢传统 panel/taskbar、GUI 设置和窗口规则，希望开箱完整而不是自己拼 bar/launcher 的人。排在 niri 后，是因为它引入的是整套 DE，而非一个小会话。
- **经验信号：** NixOS 讨论里既有“GNOME/Plasma 完整省心”，也有“二者声明式管理不如文本配置 WM 顺手”的报告；把它理解为配置模型取舍，不应推导为 Plasma 不可靠。[NixOS Discourse：No love for GNOME?](https://discourse.nixos.org/t/no-love-for-gnome/73226)

### 12.4 niri：nixbox 的第一平铺候选

- **范式与强项：** 横向无限列的 scrollable tiling；窗口不会因新窗口加入而被不断压缩，各显示器有独立动态工作区，心智模型比树状平铺更接近 GNOME 工作区。[niri 官方仓库](https://github.com/YaLTeR/niri)
- **明显缺点：** 不是完整 DE；bar、launcher、通知、idle/lock、polkit agent 仍要选 owner，旧 X11 应用还要核对 `xwayland-satellite`。
- **NixOS 整合：** 锁定 `programs.niri.enable` 已注册 display-manager session，并为 GNOME/GTK portal、GNOME Keyring、Nautilus file chooser 和 screencast 提供系统侧默认，显著减少手拼成本；外围应用仍须单独声明。
- **适合谁 / 建议：** 想真正改变窗口组织方式，又不想先承担 Hyprland 全套美化工程的人；作为第一套 replacement configuration 试一周。
- **经验信号：** 有用户从复杂手配转为只启用 NixOS niri 模块后获得可用 screen sharing，也有用户因额外堆 portal 导致困惑；信号是“先信模块默认、少加组件”，不是零故障保证。[NixOS Discourse：GNOME portal 与 niri](https://discourse.nixos.org/t/gnome-portal-niri/69280)，[How to install Niri?](https://discourse.nixos.org/t/how-to-install-niri/63975)

### 12.5 Sway：最清楚的键盘与窗口树课程

- **范式与强项：** i3-compatible 的显式容器树、稳定快捷键与朴素文本配置；行为可预测、文档成熟，适合把桌面当作可编程工具。[Sway 官网](https://swaywm.org/)
- **明显缺点：** 默认体验简陋；自动适应式布局、视觉动画和完整设置中心都不是重点，外设与显示配置更多落到命令/配置层。
- **NixOS 整合：** 锁定 `programs.sway.enable` 注册会话，并明确把 ScreenCast/Screenshot 交给 wlr portal、其余接口交给 GTK portal；仍需选择 bar、launcher、notification、locker 和 polkit owner。
- **适合谁 / 建议：** 已确定喜欢 i3 式树模型、愿意从配置文件构建工作流的人。若只是好奇平铺，先试 niri；若想学习经典 WM 模型，再试 Sway。
- **经验信号：** 引用讨论中有用户报告曾在 Sway/Hyprland 上为 screen sharing 花费很久，而 niri 模块默认后来可直接工作；这是一个“少手配 portal”的案例，不足以比较三者总体可靠性。[NixOS Discourse：GNOME portal 与 niri（含 Sway/Hyprland 对照经验）](https://discourse.nixos.org/t/gnome-portal-niri/69280)

### 12.6 Hyprland：最高可塑性，也有最高组装税

- **范式与强项：** 动态平铺、动画、窗口组、special workspace、IPC、插件与丰富规则，最容易做出鲜明的个人桌面。[Hyprland 官网](https://hypr.land/)
- **明显缺点：** 官方明确它不是完整 DE；配置面和升级变化较快，美化配置容易掩盖 portal、idle、lock、polkit、notification 等基础设施缺口。[Hyprland：Must-have utilities](https://wiki.hypr.land/Useful-Utilities/Must-have/)
- **NixOS 整合：** 锁定 `programs.hyprland.enable` 会注册会话、加入专用 portal，并为实时调度创建带 `cap_sys_nice` 的 wrapper；这已超出“加一个用户包”，多会话时尤其要验证 portal 选择。
- **适合谁 / 建议：** 把桌面本身当长期 hobby project、愿意维护配置与外围组件的人。只在 niri/Sway 证明自己喜欢 compositor 工作流后采用。
- **经验信号：** 有用户非常依赖 special workspace，也有 2026 年多桌面并存时 Hyprland portal 干扰 COSMIC/Plasma 发现的报告；前者是体验偏好，后者是应纳入 smoke 的真实集成风险，均不能外推成整体结论。[NixOS Discourse：多桌面体验](https://discourse.nixos.org/t/spent-all-weekend-trying-and-managed-to-get-nixos-working-right/78003?page=2)，[portal discovery 冲突](https://discourse.nixos.org/t/hyprland-home-manager-module-breaks-portal-discovery-for-other-desktop-environments/78042)

### 12.7 COSMIC：完整 DE 与自动平铺之间的新中间态

- **范式与强项：** Rust/Wayland-native 的完整 DE，把 launcher、panel/dock、动态或固定工作区、逐工作区自动平铺、floating 与 window stacking 做成同一套产品体验；比 GNOME 更显式，比手拼 compositor 更完整。[System76：COSMIC](https://system76.com/cosmic)，[COSMIC 桌面基础](https://support.system76.com/support/articles/pop-basics)
- **明显缺点：** 生态、设置覆盖和跨发行版经验都比 GNOME/Plasma 年轻；当前 NixOS 没有高层声明式 COSMIC settings options，用户设置写入 `~/.config/cosmic/` 的 RON 状态。[NixOS Wiki：COSMIC](https://wiki.nixos.org/wiki/COSMIC)
- **NixOS 整合：** 锁定 `services.desktopManager.cosmic.enable` 是整套系统模块，不是轻量 session：它加入 COSMIC/GTK portal、polkit、rtkit、accounts-daemon、UPower、GeoClue，并默认启用 NetworkManager/Bluetooth；候选 configuration 必须移除 GNOME desktop，并逐项审查它对现有非桌面系统 owner 的影响。
- **适合谁 / 建议：** 想要自动平铺但不想自己选 bar/launcher/setting daemon 的人。当前排在 Plasma 之后作为预览；首次 `test` 的恢复入口仍是当前默认 GNOME generation，候选提升后才是上一代 GNOME generation。
- **经验信号：** 近期 NixOS 用户既有日用报告，也有初始设置、键盘布局和多 portal 并存问题；样本说明它已经可试，但更适合“单桌面 candidate configuration + 完整 smoke”。[NixOS Discourse：COSMIC 初始设置案例](https://discourse.nixos.org/t/cosmic-wont-let-me-get-past-the-initial-setup/77095)，[portal discovery 冲突](https://discourse.nixos.org/t/hyprland-home-manager-module-breaks-portal-discovery-for-other-desktop-environments/78042)

### 12.8 Xfce：有条件保留，不作为 Wayland-first 首选

- **范式与强项：** 传统 panel/menu/window desktop；项目定位是轻量、易用，适合远程机、旧硬件或明确偏爱经典桌面的人。[Xfce：About](https://xfce.org/about/)
- **明显缺点：** Xfce 4.20 官方仍把 Wayland 标为 experimental，且自身 `xfwm4` 尚无 Wayland compositor；官方建议实验时配 Labwc/Wayfire，部分 workspace、systray、keyboard/mouse settings 功能仍不完整。[Xfce 4.20 Tour](https://xfce.org/about/tour)
- **NixOS 整合：** 锁定 `services.xserver.desktopManager.xfce.enable` 默认仍是 X11/Xfwm 路径；`enableWaylandSession` 也明确标为实验，并另带 GTK/XApp/wlr portal 组合。它会把本项目从 Wayland-first 比较拉回另一条兼容路线。
- **适合谁 / 建议：** 只有在资源、X11 兼容或传统 UI 成为可验证需求时试；否则 Plasma 提供更完整的传统 DE 对照，Sway/niri 提供更清晰的 Wayland 对照。
- **经验信号：** 轻量桌面讨论常推荐 Xfce 作为“完整但较轻”的选择，但这主要是用户印象与特定机器测量，不是跨硬件性能基准。[NixOS Discourse：Lightweight WM/DE](https://discourse.nixos.org/t/lightweight-wm-de/59546)

### 12.9 每个候选都用同一张验收表

只在一个候选通过以下 smoke 后才把它提升为默认启动 generation：登录/注销；锁屏/解锁；睡眠/唤醒；多显示器插拔与缩放；键盘布局和输入法；文件选择；浏览器 screen sharing；通知；secret/keyring；音频输入输出；截图录屏；XWayland 应用；default app/URI；polkit 提权提示。`test` 阶段失败时 reboot 回当前默认 GNOME generation；候选提升后失败时，才从仍有启动项的上一代 GNOME generation 启动或 rollback。两种情况都应保留失败证据；不要靠全局增加 portal、关闭安全边界或同时安装另一套组件来“碰运气修好”。
