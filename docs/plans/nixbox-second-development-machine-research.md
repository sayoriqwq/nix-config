# nixbox 第二开发机能力调研

> 范围：回答“Linux / NixOS 到底强在哪里”，并把值得体验的能力收敛为 nixbox 的角色与 30/60/90 天路线图。
> 本文依据仓库已确认事实、Issue #148 / #152 截至 2026-08-12 的运行态记录与一手资料；它是后续 Issue / ADR 的设计输入，**不构成任何实现、activation、远程操作、网络 / firewall、disk / filesystem 或 boot 变更授权**。

## 1. 结论

Linux 并非全方位优于 macOS。它对这台 nixbox 最有价值的地方，是把四类原本隔着虚拟机或远端服务器的能力搬到本机原生环境：

1. **与 production server 同为 `x86_64-linux` 的开发与验证面**：在发布前构建、运行和测试 Linux artifact、NixOS closure 与多机服务拓扑；
2. **可观察、可组合的系统实验面**：直接学习 systemd、cgroups、namespaces、日志、设备与内核接口；
3. **低摩擦的容器与虚拟化宿主**：优先 rootless 容器，待需求明确后再使用 KVM/QEMU 做整机与 NixOS 集成测试；
4. **由 Nix 固定工具链和系统声明的第二工作站**：项目依赖放进项目 `devShell`，主机只显式 import 真正需要的能力，构建与真实 activation 继续分开。

因此推荐把 nixbox 定位为：

> **Linux-native 第二开发工作站 + server 同平台预生产 build/test 节点 + 有边界的系统实验站。**

真实 production deploy 不属于普通开发机能力：nixbox 只有在独立 deploy identity、精确 closure、当次人工批准与 server 回滚条件同时满足的窗口，才承担既有 closure push 路径。

它不应成为 macbook 的镜像，也不应接管 Xcode / iOS / Apple 平台签名、Simulator、Apple 专属应用与设备连续互通工作。Apple 官方的 Xcode 支持矩阵把 Xcode 版本、macOS 版本与 Apple 平台 SDK / Simulator 绑定在一起；这些工作继续留在 macbook 才是正确分工。[Apple：Xcode SDKs and system requirements](https://developer.apple.com/support/xcode/)

### 本周先体验三件事

如果暂时不想理解后文所有名词，只做这三个小实验就能感受到 nixbox 的核心价值：

1. **项目环境：** 选一个真实项目，从 clean checkout 进入 `nix develop`，在不手工全局安装依赖的前提下完成一次 build / test；
2. **Linux 服务：** 用无网络、无特权的 systemd user service 跑一个短命程序，再从 unit status 和 journal 找到它的退出结果；
3. **同平台验证：** 在 nixbox 构建一个 Linux artifact 或现有 server closure，但停在 build / check，不把构建成功误当成 deploy / activation 授权。

这三件事分别对应 Nix、Linux/systemd 和本仓库多主机架构；都不要求先增加主机级 package、daemon、port 或 firewall 规则。

## 2. 先把几个经常混用的名字分开

| 名称 | 实际是什么 | 在 nixbox 上负责什么 |
| --- | --- | --- |
| Linux | 内核，不是完整桌面操作系统。内核官方也明确建议新用户选择一个完整发行版，而不是只下载 kernel；它提供进程、内存、网络、设备、文件系统和虚拟化等底层机制。[Linux kernel：What is Linux?](https://www.kernel.org/linux.html) | 硬件、进程隔离、cgroups、网络、KVM、文件系统与可观察接口 |
| GNU / userland | Shell、编译器、core utilities、libc 等用户空间工具；GNU 官方也将 GNU system 与 Linux kernel 区分，Linux 系统还可搭配非 GNU 组件。[GNU：Linux and the GNU System](https://www.gnu.org/gnu/linux-and-gnu.html) | 命令行与程序运行环境；具体组件由 Nixpkgs / NixOS 选择，不等同于 kernel |
| GNOME | 桌面环境：Shell、窗口 / workspace、设置与图形会话。Activities overview、应用启动和 workspace 是 GNOME 的体验，不是“Linux 内核功能”。[GNOME Help：Visual overview](https://help.gnome.org/users/gnome-help/stable/shell-introduction.html.en) | nixbox 已确认的 GUI 与交互桌面 |
| Nix | build system 与 package manager；Nix language 用来描述 package 和 configuration。[nix.dev glossary](https://nix.dev/reference/glossary) | 构建、Store、profile、开发环境与依赖固定 |
| Nixpkgs | 用 Nix 构建的软件发行集合。[nix.dev glossary](https://nix.dev/reference/glossary) | 软件包和 NixOS module 的主要来源 |
| NixOS | 基于 Nix 与 Nixpkgs 的 Linux 发行版。[nix.dev glossary](https://nix.dev/reference/glossary) | 声明整机的 service、user、desktop、network 等期望状态 |
| Home Manager | 用户环境的 Nix module；集成 NixOS 后随系统配置一起 build。[Home Manager：NixOS module](https://home-manager.dev/manual/unstable/nix-flakes/nixos.html) | Fish、终端工具、编辑器等用户能力与稳定配置 |

一句话判断归属：`KVM` 是 Linux 能力，`GNOME workspace` 是桌面能力，`nix develop` 是 Nix 能力，整机 generation 与 service 声明是 NixOS 能力，用户 dotfile 组合是 Home Manager 能力。

## 3. 相对 macOS，真正高价值的差异

### 3.1 原生 Linux 目标与 server 同构

macbook 可以写跨平台代码，但 Darwin kernel、framework、动态链接与文件系统语义并不等于 production Linux。nixbox 与本仓库 server 都是 `x86_64-linux`，所以它能原生构建和运行该平台的 Linux binary、systemd unit、容器 image、Nix closure 和 NixOS module；当两者消费同一 lock 和 closure 时，部分用户空间产物还能保持高度一致。NixOS VM tests 也能声明一台或多台测试机，以 QEMU 为后端执行可复现的集成测试。[nix.dev：Integration testing with NixOS virtual machines](https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html)

**价值：** 减少“Mac 能跑、server 不能跑”的架构和操作系统偏差；server 不需要 GitHub 写权限或 mutable checkout。

**代价 / 风险：** 同 CPU 架构和 OS family 不等于 production 等价；kernel、CPU feature、lock、module composition、disk、boot、network、SSH、secret 与 service data 都可能不同，仍须逐主机验证。

**Nix 声明：** devShell、package、check、NixOS test、server closure 很适合；部署凭据内容和真实发布批准不适合。

**可变状态：** source checkout、build cache、测试数据库、容器 volume、deploy key 和日志独立管理。

### 3.2 开发环境是项目产物，而非“这台机器碰巧装了什么”

`nix develop` 会进入与 derivation build environment 近似的交互环境，并优先读取 `devShells.<system>.default`；Flake input 与 lock file 用于固定依赖版本。[Nix manual：`nix develop`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-develop.html)，[nix.dev：Flakes](https://nix.dev/concepts/flakes.html)

**价值：** 项目切换不污染全局 profile；同一项目的 compiler、formatter、database client 和 codegen 工具可被 macbook / nixbox / CI 明确对照。

**代价 / 风险：** 初次构建可能慢，缓存和 Store 占空间；Darwin 与 Linux package 可用性仍可能不同。

**Nix 声明：** 高度适合；项目依赖必须进入各项目 devShell，而不是继续堆到 nixbox 全局能力。

**可变状态：** `.env`、credentials、`.venv`、`node_modules`、language cache 和项目数据库仍是项目 / 用户状态。

### 3.3 系统不是黑盒：service、日志和资源边界有统一接口

systemd 以 PID 1 管理 service，支持 socket / D-Bus activation、依赖事务，并用 cgroups 跟踪进程；unit 可表达 service、socket、mount、timer、slice 等对象。[systemd：System and Service Manager](https://systemd.io/)，[`systemd.unit`](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)。`journalctl` 可按 unit、boot 和结构化字段过滤日志。[`journalctl`](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)

**价值：** 学会从 unit → process → resource → log 的统一诊断链；这是运维 server 可直接复用的技能。

**代价 / 风险：** system service 可能拥有 root 权限、监听端口或开机常驻；错误 unit 会影响系统可用性。

**Nix 声明：** 稳定 unit、timer、resource limit 和 hardening 很适合，但必须成为公开 system / network 影响的能力合同。

**可变状态：** journal、runtime directory、数据库、socket、PID 与 service cache 不进入 Store。

### 3.4 NixOS generation：系统升级可以先构建、再切换、可回看

NixOS 把配置构建为 generation。官方手册区分 `dry-activate`、`test`、`boot` 与 `switch`：例如 `test` 可切换当前运行态而不改变默认启动 generation，`switch` 则同时更新启动配置并尝试切换运行态；启动菜单和 rollback 提供回到旧 generation 的路径。[NixOS manual：Changing the Configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config)，[NixOS manual：What happens during a system switch?](https://nixos.org/manual/nixos/stable/#sec-switching-systems)

**价值：** 配置 diff、构建产物与回滚路径都比“在机器上逐条改到能用”为清晰；尤其适合第二开发机大胆试验、主工作机保持稳定的分工。

**代价 / 风险：** generation、旧 closure 与构建缓存会占用 Store 空间，需要理解保留和 garbage collection 边界；失败构建、lock 更新与磁盘不足也是 NixOS 的日常成本。Generation 只能回滚声明式系统内容，不能自动回滚 database、browser profile、container volume 等可变数据；错误的 disk / boot / network 变更仍可能让机器失联或无法启动。[NixOS manual：Cleaning the Nix Store](https://nixos.org/manual/nixos/stable/#sec-nix-gc)

**Nix 声明：** system / user 稳定配置适合；真实 `test` / `switch` / reboot 仍受 exact commit 与当前窗口的人工关卡约束。

**可变状态：** profile / boot generation 是 Nix 管理对象，应用数据、日志、凭据与个人内容不是。

### 3.5 Linux 原生隔离和资源控制

Linux namespaces、cgroups 与 seccomp 是容器的底层积木；cgroup v2 将进程组织为层级结构进行资源控制，systemd 的 `CPUWeight=`、`MemoryMax=`、`TasksMax=` 等选项直接建立在 cgroups 上。[Linux kernel：cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)，[`systemd.resource-control`](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)，[Linux kernel：seccomp filter](https://docs.kernel.org/userspace-api/seccomp_filter.html)

**价值：** 能在本机理解容器为什么隔离、服务为什么会 OOM、如何限制失控 build / test。

**代价 / 风险：** 隔离不是完整安全边界；配置不当会误杀任务或给容器过宽设备 / host 权限。

**Nix 声明：** service 资源政策与宿主 capability 适合；临时实验命令和业务数据不应固化。

**可变状态：** cgroup 运行态、container writable layer、volume、image cache 与 secret 外置。

### 3.6 原生 KVM/QEMU：把“整台 Linux”也当测试对象

QEMU 能模拟完整机器；在 Linux x86 上可用 KVM accelerator，亦提供 TCG 跨架构模拟、VirtIO 设备、snapshot / migration block layer 和可机器调用的 QMP。[QEMU：System Emulation Introduction](https://www.qemu.org/docs/master/system/introduction.html)，[Linux kernel：KVM documentation](https://docs.kernel.org/virt/kvm/index.html)

**价值：** 快速启动一次性 NixOS、多机网络或恢复测试；比在真实 nixbox 上实验 boot / service 更容易隔离。

**代价 / 风险：** 需要 CPU virtualization、内存和磁盘；bridge、passthrough、nested virtualization 会显著扩大权限与网络风险。

**Nix 声明：** VM definition、test script、固定 image 很适合；大型 disk image、guest data 和 snapshot 属可变状态。

**可变状态：** 由 Nix 获取并固定 hash 的只读 base image 可以成为 Store 产物；writable qcow2 overlay、guest secrets / data、snapshot 与 libvirt runtime state 不入 Git / Store。

### 3.7 可观察性与“拆开看”的乐趣

Linux 通过 procfs / sysfs 暴露进程与 kernel object 信息；kernel tracing 文档覆盖 tracepoints、function tracer、kprobes、uprobes、event tracing 与 latency tracer，perf / eBPF 则提供更高层的计数、采样和可编程观察入口。[Linux kernel：procfs](https://docs.kernel.org/filesystems/proc.html)，[sysfs](https://docs.kernel.org/filesystems/sysfs.html)，[Tracing](https://docs.kernel.org/trace/index.html)，[BPF](https://docs.kernel.org/bpf/)，[Linux perf tutorial](https://perfwiki.github.io/main/tutorial/)

**价值：** 可以回答“哪个 syscall 慢、哪个进程打开了文件、service 为什么卡住、网络包去哪了”；这是 Linux 最独特的学习回报之一。

**代价 / 风险：** 部分能力需要 elevated privilege，探针会增加开销，错误结论比没有数据更危险。

**Nix 声明：** 工具 package 与已审阅的只读 helper 可声明；临时 trace、capture、dump 和内核调参通常不应持久化。

**可变状态：** trace buffer、profile、core dump、packet capture 可能含源码、路径、token 或业务内容，应短期、owner-only 保存。

## 4. 能力目录：有用、好玩，也值得学习

下表中的“优先级”不是安装清单。只有修改本仓库、形成主机 capability，或涉及 activation、service、network、privilege 的事项才必须进入范围准确的 Issue；项目级 devShell 与不落入本仓库的一次性隔离实验遵循所在项目流程。凡进入 nix-config 的候选仍须明确合同和离线验证。

| 能力 | 能获得什么 | 代价 / 风险 | 适合 Nix 声明 | 可变状态边界 | 优先级 |
| --- | --- | --- | --- | --- | --- |
| Linux 项目 devShell + direnv | 每项目固定 compiler / SDK / CLI；direnv 可在进入目录时加载项目环境。[direnv](https://direnv.net/) | 首建时间、Store 容量、跨平台分支 | 是：项目 `devShell` / lock | cache、`.env`、build output | 立即获得 |
| server closure 原生 build / check | 同架构构建与 pre-production 验证 | 不能替代 host-specific 与 production 验收 | 是：现有 Flake output / checks | result links、build logs | 立即获得 |
| systemd / journal 实验 | 学会 service、timer、socket、失败重启和结构化日志 | system unit 权限与常驻副作用 | 稳定实验可声明；先 user service | journal、runtime state | 立即获得 |
| SSH + tmux 远端工作台 | Mac GUI + nixbox Linux compute；真断线后恢复现场 | identity、host key、网络与真人恢复矩阵 | 客户端稳定配置可声明；登录态不行 | key、known_hosts、tmux session | 立即获得，待收尾 |
| rootless Podman | daemonless、普通用户可运行多数命令；可用 Quadlet 与 systemd 管理 container / pod。[Podman manual](https://docs.podman.io/en/latest/markdown/podman.1.html) | user namespace、subuid/subgid、网络差异；容器不是 VM | engine 与稳定 policy 适合；业务逐项 | image、volume、auth、container DB | 低风险下一步 |
| rootless Docker（兼容需求时） | Docker daemon 与 container 都在 user namespace 内以非 root 运行。[Docker：Rootless mode](https://docs.docker.com/engine/security/rootless/) | 仍有 daemon；与 Podman 双栈会造成 ownership 混乱 | 只有项目明确依赖 Docker 时 | image、volume、credential、daemon state | 条件式后续 |
| NixOS VM / 多机 integration test | 测 service、network、boot、client-server 场景 | CPU / RAM / disk 开销，测试仍是模型 | 非常适合：`testers.runNixOSTest` | test temp disk / log | 低风险下一步 |
| QEMU / KVM 一次性实验室 | 装别的发行版、测 recovery、跨架构 TCG | image 供应链、guest 网络、passthrough 风险 | VM 定义适合 | image、snapshot、guest data | 后续实验 |
| Flatpak sandbox 观察 | 体验 desktop app 的 sandbox / portal 权限；默认仅能访问 app/runtime 和限定路径。[Flatpak：Sandbox Permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html) | 与 Nix package 双 owner、portal 权限和 runtime 更新 | 系统支持可声明；app ownership 必须择一 | `~/.var/app`、runtime / repo state | 后续实验 |
| cgroups service 限额 | 给 build、agent、测试服务限定 CPU / memory / task | 限额不当导致随机失败 | 是，且应逐 service 有指标 | 运行态 counters | 后续实验 |
| perf / ftrace / eBPF | 看 syscall、scheduler、I/O、network 的真实行为 | 权限、kernel compatibility、性能和隐私 | package 可声明；探针按需 | profile / trace / capture | 后续实验 |
| Steam / Proton | 运行部分 Windows-only 游戏；Proton 官方说明以 Wine 实现，通常应使用 Steam 自带版本。[Valve Proton README](https://github.com/ValveSoftware/Proton#readme) | 游戏兼容、GPU driver、anti-cheat、磁盘占用 | Steam capability 可声明；游戏不行 | library、shader cache、save、account | 好玩，非开发主线 |
| Btrfs snapshot / send-receive lab | 体验 CoW subvolume、snapshot、增量 stream 和 checksum。[Btrfs：Subvolumes](https://btrfs.readthedocs.io/en/latest/Subvolumes.html)，[Send/receive](https://btrfs.readthedocs.io/en/latest/Send-receive.html)，[Checksumming](https://btrfs.readthedocs.io/en/latest/Checksumming.html) | 改真实根盘属高风险；官方明确 snapshot 不是 backup | 只适合独立 VM / loop image 的实验声明 | image、snapshot、receive target | 后续隔离实验 |
| 内核 / Nixpkgs 源码实验 | 编译 kernel、patch package、理解发行版构成 | 编译重、调试难、cache 大 | devShell / overlay / package 可声明 | source checkout、ccache、artifact | 90 天以后 |

## 5. 分层建议

### 5.1 立即获得：先用好已经有的 nixbox

- 把日常 Linux 项目放入各项目 devShell，在 nixbox 完成 build / unit test / lint；用成功率和环境准备时间建立基线。
- 用 `systemctl --user`、`journalctl --user-unit <unit>` 做一个无网络、无特权的短命 user service / timer 学习项目；先理解 unit 生命周期，不急着新增 system daemon。
- 把 server closure 的 build / check 留在 nixbox，继续遵守“build ≠ deploy ≠ activation”。
- 完成 Issue #148 的剩余真人矩阵：家庭网络、macbook Wi-Fi 切换与 relogin、独立 DHCP renew（或明确接受 reboot 后重新取得 DHCP 作为等价证据）、Clash off、真实 `work` 会话在 SSH-only 断线后的恢复、Zed 外部连接 smoke，以及 Gate 7 的 key-expiry 决策。已完成的是 Tailscale activation / enrollment、direct SSH / SCP / Nix Store / tmux 基础链路、公司网络到手机热点的异网 relay、真实 reboot 后自动重新加入并由 relay 升级 direct、Clash on、Termius 与临时 tmux 重连 smoke；这些仍不等于全部矩阵闭环。
- Issue #152 已闭环：nixbox 已 activation，Codex、ax、RTK 与 Python 已在 PATH，RTK init 与 `--show` 验收已通过。Codex 首次登录是独立、可选的用户认证动作，不是该 Issue 或本路线图的完成条件；credentials 与 RTK 生成状态继续留在仓库外。

### 5.2 低风险下一步：一次只引入一种隔离层

1. 选一个真实项目做 rootless Podman spike：无 host network、无 privileged、无宿主敏感目录 bind mount；记录 image / volume / auth ownership。
2. 把一个 client + server 示例写成 NixOS VM integration test，验证启动、端口、日志和失败场景；不连接 production。
3. 为项目 build 加可度量的 CPU / memory 观察，先记录数据，后决定是否需要 cgroup limit。

### 5.3 后续实验：收益明确后再能力化

- 使用 QEMU/KVM 建 disposable Linux lab，体验另一发行版、临时网络拓扑或 server recovery；默认 user-mode network，不先做 bridge / passthrough。
- 在独立 VM disk 或 loop image 中体验 Btrfs subvolume / snapshot / send-receive，绝不先迁移 nixbox 真实 root filesystem。
- 对一个自己能解释的程序做 perf / ftrace / eBPF 观察；保存最小、脱敏输出。
- 如果确有 Nix package 缺口，再学 override / overlay 与 upstream contribution；不要把 overlay 当普通配置的默认工具。
- Flatpak 只用于体验 sandbox / portal 或解决明确的 desktop distribution 问题；同一 app 不与 Home Manager / Nixpkgs 双重安装。

### 5.4 明确不建议现在做

- 重分区、把 ext4 根盘迁到 Btrfs / ZFS、LUKS、impermanence；这些涉及 disk / boot / recovery，且仓库已明确要求独立 Issue 与 ADR。
- 为“学习 Linux”开启公网 service、扩大 firewall、Tailscale Serve / Funnel、Tailscale SSH、subnet router 或 exit node。
- 同时部署 rootful Docker、rootless Docker、Podman、Kubernetes / k3s；先证明一个真实 workload 的需求。
- GPU passthrough、VFIO、custom kernel、nested virtualization、实时内核；它们都应由具体性能或兼容目标驱动。
- 把 database、browser profile、container volume、game library、VM disk、Atuin database 或 credentials 交给 Git / Nix Store。
- 把 macbook 的全部 GUI 软件和偏好复制到 GNOME，或把 Apple-only workflow 迁走。

## 6. 推荐目标角色与边界

```text
macbook（主工作站）
  ├─ Apple/Xcode/iOS/签名/Simulator/Apple 生态
  ├─ 主要交互控制面、GitHub/secret administration
  └─ GUI 编辑器 ──SSH──▶ nixbox

nixbox（第二开发机）
  ├─ GNOME + 本地 Linux 开发
  ├─ 项目 devShell / Linux artifact / rootless container
  ├─ NixOS VM / 多机 integration tests / 系统观察实验
  └─ server x86_64-linux closure build/test ──人工关卡──▶ server

server（最小 production）
  └─ 只按明确业务 Issue 接收 closure 与服务；不继承工作站状态
```

按仓库架构落地时，每个新增候选都要回答：

1. 它是项目依赖、纯用户能力、跨层 capability、NixOS system module，还是 host fact？
2. package 和稳定配置谁拥有？是否已有另一 owner？
3. 是否创建 service、监听端口、firewall、network、login shell 或特权边界？
4. 可变状态在哪里、谁备份、怎样恢复、怎样卸载而不删数据？
5. 离线 build / VM test 能证明什么，真实 activation 又需要哪个人工关卡？

Host 仍以显式 import 选择 requirement-driven capability；不要引入“Linux 全家桶”、递归扫描或全局 registry。项目语言和工具依赖进入项目 devShell，只有跨项目稳定使用的工具或完整用户行为才进入 nixbox 能力。

## 7. 30 / 60 / 90 天路线图

这不是按日期强推的安装清单，而是三道依次解锁的关卡：上一阶段的必修成果稳定后才进入下一阶段；每阶段只设一个必修成果，其余都是可选拓展。

### 前 30 天：形成可靠的日常 Linux 开发闭环

**目标**

- **必修：** 选择 1 个真实项目，在 nixbox 以 devShell 完成 edit / build / test 的完整闭环；
- **配套基础：** 用一个短命 systemd user unit 练习 status 与 journal，并只读查看 system generation、Store 占用和已知恢复入口；
- **并行收尾而非新增能力：** 完成 #148 真人矩阵；#152 已闭环，Codex 首次登录仅在实际需要使用时由用户独立完成。

**验收指标**

- 一个项目从 clean checkout 到测试通过有短文档入口，人工全局安装依赖数为 0；
- 连续 5 次进入 devShell 和核心测试成功率 100%；
- #148 剩余矩阵逐项记录 PASS 或具体 blocker，至少一次在 SSH-only 真实断线后恢复既有 `work` tmux session；
- 能从 unit 名定位一次失败的 exit status 与对应 journal，不使用全局“重装试试”；
- 能解释 generation rollback 与 Store garbage collection 各自会影响什么，并且没有为练习擅自执行 activation 或 GC。

### 31–60 天：建立容器与可复现 integration test

**目标**

- **必修二选一：** 用一个真实、非敏感项目试用 rootless Podman，或为一个 client / service 场景建立 NixOS VM integration test；
- **共同要求：** 记录所选实验的 image / disk、volume / state、secret、port 与 cleanup / restore 边界；
- **可选：** 量化 nixbox 构建 server closure 的时间、缓存命中与失败原因。

**验收指标**

- 若选择 Podman：rootless workload 不使用 privileged / host network，不 bind mount home 根目录；删除 container 后 volume 数据边界可解释；
- 若选择 NixOS test：integration test 可从 clean state 连续通过 3 次，并覆盖至少一个故障断言；
- production server 未因实验新增 port、credential 或 mutable checkout；
- 新能力若要进入仓库，已有独立 Issue，完整写出 package / config / state / service / network / approval contract。

### 61–90 天：把 nixbox 变成受控实验室，而不是玩具堆

**目标**

- **必修三选一：** 在 QEMU/KVM disposable VM 中完成一次安装、破坏、恢复循环；在 VM disk / loop image 内完成一次 Btrfs snapshot + send/receive；或在确有真实性能问题时用 perf / ftrace / eBPF 中的一种工具取得证据；
- 若没有真实性能问题，可用受控、可丢弃示例理解一种观察工具，但不把它设为阶段完成门槛；
- 复盘哪些实验值得能力化，哪些应删除。

**验收指标**

- 若选择 VM：实验可从声明重建，guest secret、disk 与 snapshot 不进 Git；
- 若选择 Btrfs：明确证明 snapshot 不是 backup，并有第二 target 的 receive 验证；
- 若选择性能诊断：修改前 / 后使用同一 workload，报告可复现指标而非“感觉更快”；
- 90 天末最多推进 1–2 个有真实重复收益的新 capability，其余保持项目级或一次性实验；
- 没有未经单独批准的 activation、network / firewall、disk / filesystem 或 boot 变更。

## 8. macOS 继续更强或不可替代的部分

- Xcode、iOS / iPadOS / watchOS / visionOS SDK、Simulator、code signing、notarization 与 Apple device 调试继续留在 macbook；官方 Xcode 支持表本身就是 macOS 与 Apple SDK 的绑定证据。[Apple：Xcode SDKs and system requirements](https://developer.apple.com/support/xcode/)
- AirDrop、iCloud Keychain、Continuity、Shortcuts、Apple 专属商业应用与精确色彩 / 音视频工作流，不应因为“Linux 可定制”就强行迁移。
- macbook 在续航、触控板、休眠唤醒、显示与硬件软件一体化方面可能更省心；nixbox 的价值是补足 Linux-native、可观察与服务器同构能力，而不是证明某个平台获胜。
- 若项目最终只发布 Apple 平台，nixbox 可承担通用 backend / docs / tests，但不能替代最终 Apple toolchain 验收。

### 迁移工作前必须验证的 Linux / NixOS 摩擦

- NixOS 不提供传统全局 library path，也不遵循普通发行版预期的完整 FHS；从网页、npm package 或 vendor installer 下载的动态链接 Linux binary 可能不能直接运行。优先使用 Nixpkgs、项目 devShell 或正式 packaging；只有明确兼容需求才评估 `nix-ld` / FHS 环境，而不是全局打开一个无限兼容层。[nix.dev FAQ：How to run non-nix executables?](https://nix.dev/guides/faq.html#how-to-run-non-nix-executables)
- GPU / Vulkan、外接显示、HiDPI / fractional scaling、Wayland screen sharing、输入法、摄像头、蓝牙、打印、休眠与唤醒都依赖真实硬件、driver、desktop 与应用组合；当前已知 GNOME 基线不能自动证明所有场景等同于 macOS。
- 一部分会议、设计、媒体 DRM、云盘和商业软件没有 Linux 版本，或只提供未经当前 NixOS 组合验证的 AppImage / Flatpak / vendor binary；不要在删除 macOS 工作流后才发现缺口。
- GNOME Shell extension 会进入桌面 Shell 进程，第三方扩展可能因版本不兼容造成崩溃或异常；桌面可定制不等于扩展可以无成本堆叠。[GNOME Shell Extensions：About](https://extensions.gnome.org/about/)
- 前 30 天只记录这些场景的实机 PASS / blocker，不猜测硬件表现，也不为了追求“Linux 完整体验”顺手更换 desktop、kernel、driver 或 package owner。

## 9. 决策门槛

未来任何候选能力只有同时满足以下条件才值得进入 nix-config：

1. 已有重复出现的真实工作，而不是“Linux 社区常见”；
2. 相比项目 devShell 或一次性 VM，主机级能力确有额外收益；
3. 软件与配置单一 owner 明确；
4. mutable state、secret、backup / restore 和卸载边界明确；
5. service / network / firewall / privilege 副作用公开；
6. 有窄 build / test 与真实机器人工验收标准；
7. 不破坏 nixbox 的核心角色：第二开发机和 server 同平台验证节点。

本文不授权创建这些能力，也不授权运行 `nixos-rebuild switch`、Home Manager activation、容器 daemon、VM bridge、远程部署、磁盘 / filesystem / boot 操作。实施必须从新的、范围准确的 Issue 开始；build 成功仍不等于 activation 或 production deployment 获批。

## 10. 一手来源清单

正文就近引用的资料来自 Linux kernel、systemd、Nix / NixOS / Nixpkgs、Home Manager、Podman、Docker、Flatpak、QEMU、Btrfs、Valve 与 Apple 的官方文档或官方源码。核心入口如下：

1. [Linux kernel documentation](https://docs.kernel.org/)
2. [systemd documentation](https://systemd.io/)
3. [Nix reference and tutorials](https://nix.dev/)
4. [NixOS 26.05 manual](https://nixos.org/manual/nixos/stable/)
5. [Home Manager manual](https://home-manager.dev/manual/unstable/)
6. [Podman documentation](https://docs.podman.io/)
7. [Docker rootless mode](https://docs.docker.com/engine/security/rootless/)
8. [Flatpak documentation](https://docs.flatpak.org/)
9. [QEMU system emulation documentation](https://www.qemu.org/docs/master/system/)
10. [Btrfs documentation](https://btrfs.readthedocs.io/)
11. [Valve Proton source documentation](https://github.com/ValveSoftware/Proton)
12. [Apple Xcode support](https://developer.apple.com/support/xcode/)
