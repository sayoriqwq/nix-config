# Phase 7：Contabo Ubuntu → NixOS 低风险迁移实践调研

> 范围：为 Issue #9 收敛 Phase 8–10 的实现与执行方案。本文依据 2026-07-30 的脱敏实机证据和一手资料，不授权对 production server 执行 kexec、disko、安装、网络/SSH 修改或重启。
>
> 维护者已接受现有系统、服务与数据全部丢失，不要求备份、恢复测试、业务恢复或有限停机窗口。唯一强制的生产验收目标是：替换后仍能从 macbook 取得 SSH 控制权。该 waiver 不替代 boot、network、SSH、provider rescue 与精确 destructive target 的人工关卡。

## 1. 结论

**推荐主路径：从当前 Ubuntu 的可信 root SSH 入口运行 `nixos-anywhere`，由 nixbox 在本地预构建并推送完整 closure；kexec 进入临时 NixOS installer 后，以 disko 创建 BIOS/GPT 最小磁盘布局，最终安装最小 NixOS。macbook 保留独立管理路径，Contabo VNC 与 Rescue 作为带外恢复。**

这条路径的变量最少：当前系统已经满足 `nixos-anywhere` 的架构、RAM、SSH 和 kexec 要求；官方 kexec installer 会把当前地址、路由、authorized keys 与 SSH host keys 带入临时 initrd。Contabo Custom Image/Reinstall 需要额外处理镜像格式、Cloud-Init 与 provider 安装语义，适合作为最后重建手段，不应成为首选安装路径。

建议的整体链路是：

```text
macbook ──独立 SSH／现场监督──▶ current Ubuntu ──kexec──▶ temporary NixOS installer
   │                                                        │
   └──SSH──▶ nixbox ──build + VM test + push closure────────┘

Contabo VNC ──观察 boot／network
Contabo Rescue ──挂载、修复或重新安装
Contabo Reinstall／Custom Image ──最后重建手段
```

为了把“重装后必须还能访问”置于最高优先级，推荐同时采用三个访问设计：

1. 最终 NixOS 的普通管理用户使用 `sayori`，同时授权 macbook 维护 key 与 nixbox 专用 deploy key；两把私钥分别只留在各自机器；
2. 首次替换阶段保留一个仅允许 public-key 的 root break-glass 入口，待 macbook、nixbox、`sudo -n` 与二次重启全部验证后，再通过后续批准关闭；
3. 若没有当前主机身份泄露迹象，首次替换使用 `--copy-host-keys` 保留现有 SSH host identity，避免安装完成时发生未经核验的 host-key 轮换。

## 2. 实机适配证据

| 迁移条件 | 2026-07-30 脱敏证据 | 设计含义 |
| --- | --- | --- |
| 计算平台 | Contabo KVM、`x86_64-linux`，约 8 GiB RAM 且无 swap | 满足 `nixos-anywhere` 目标端至少 1.5 GiB RAM 的要求；nixbox 可原生构建同架构 closure |
| kexec | 当前内核启用 `KEXEC` / `KEXEC_FILE`，运行态 `kexec_load_disabled = 0` | 可优先从现有 Ubuntu 进入官方 kexec installer；正式窗口前仍需重复 preflight |
| boot | 运行态未暴露 EFI firmware，现有 GRUB package 为 BIOS 方向 | 首版按 BIOS + GRUB 设计，不因残留 vfat `/boot/efi` 猜测 UEFI |
| disk | 唯一可写磁盘约 75 GiB；稳定别名 `/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0` 指向 `/dev/sda`；控制器为 Virtio SCSI | disko 与 GRUB 使用稳定 `by-id`，Phase 10 再确认别名、容量、唯一性和底层设备一致 |
| storage driver | PCI 为 Virtio SCSI；当前内核内建 `virtio_pci`、`virtio_scsi` 与 SCSI disk 支持 | 最小 NixOS initrd 必须显式覆盖相同启动链路，并由 BIOS VM 二次启动验证 |
| network | 单一 provider NIC，driver 为 `virtio_net`；当前 Ubuntu 名为 `eth0`，udev 同时给出 `ens18` / `enp0s18` 候选名 | 最终配置不得依赖 `eth0` 字面值；应以 `virtio_net` driver 匹配，并在 preflight 断言只存在一张目标 NIC |
| addressing | provider 静态 IPv4 + IPv6；IPv6 默认网关为 link-local 且当前 route 具有 `onlink` 语义 | 最终 networkd 声明必须显式复现 address、prefix、双栈 route、DNS 与 `GatewayOnLink`，不能假设 DHCP |
| current SSH | macbook public-key root SSH 已在 Clash TUN `/32` 排除后反复验证；root authorized-keys mode/owner 正确；`tar` 与 `setsid` 可用 | 满足官方安装入口与 bootstrap 工具要求；最终不能照搬现有 password/root 宽松策略 |
| second path | macbook → nixbox SSH 成功；nixbox → server TCP 22 可达，但尚无 host pin 或出站 deploy key | Phase 8/9 需建立专用 key 与严格 host verification，不能用 `StrictHostKeyChecking=no` |
| provider recovery | 当前实例面板真实提供且已启用 VNC，并提供 Linux Rescue、Reinstall 与 Custom Image | 正式执行前必须实际连接 VNC；普通 SSH 丢失时按 VNC → Rescue → Reinstall 升级 |

`nixos-anywhere` 的官方 requirements 要求目标可达、Linux x86-64/aarch64、kexec 支持且 RAM 不含 swap 至少 1.5 GiB；当前实机证据满足这些条件。[官方 Requirements](https://github.com/nix-community/nixos-anywhere/blob/5887f1c72fbf0e88000716237194de414d2299ee/docs/requirements.md)

## 3. 推荐的最小 NixOS 设计

### 3.1 Disk 与 boot

首版采用一块磁盘、GPT、1 MiB `EF02` BIOS boot partition 与单一 ext4 `/`：

- disko target 和 `boot.loader.grub.device` 都使用已验证的稳定 `by-id`，不把 `/dev/sda` 当长期身份；
- 不创建 swap、LVM、RAID、LUKS、ZFS、impermanence 或独立业务分区；这些都没有当前需求，只会扩大无法启动或无法修复的状态空间；
- 不为“也许是 UEFI”建立混合 boot。运行态证据是 BIOS，Phase 9 应用 BIOS VM 真实完成首次启动和第二次重启；
- initrd 显式包含 Virtio PCI/SCSI 所需模块；不要从 Ubuntu 的 `lsmod` 为空推断模块不需要，因为当前 Ubuntu 内核把相关 driver 编为 built-in；
- 新安装的 `system.stateVersion` 使用仓库锁定的首次 NixOS release `26.05`，之后不因升级 release 随意修改。

该布局与 disko 官方的 [GPT BIOS compatibility example](https://github.com/nix-community/disko/blob/ff8702b4de27f72b4c78573dfb89ec74e36abdf1/example/gpt-bios-compat.nix) 及其 [`efi = false` test](https://github.com/nix-community/disko/blob/ff8702b4de27f72b4c78573dfb89ec74e36abdf1/tests/gpt-bios-compat.nix) 一致。NixOS 手册要求 BIOS GRUB 明确设置安装磁盘；稳定别名优于可能变化的内核枚举名。[NixOS Manual：Bootloader](https://nixos.org/manual/nixos/stable/#sec-installation-boot-loader)

### 3.2 Network

最终系统使用 `systemd-networkd` 声明静态双栈网络，网络 unit 按 `Driver=virtio_net` 匹配，而不是按当前 `eth0` 名称匹配。正式执行前的 preflight 必须断言：目标只有一张 provider `virtio_net` NIC；若数量或 driver 改变，停止窗口并更新配置。

声明必须包括：

- 静态 IPv4 address/prefix 与默认 route；
- 静态 IPv6 address/prefix；
- IPv6 link-local gateway 与 `GatewayOnLink=yes`；
- 已验证的 provider DNS；
- 禁止把 DHCP/RA 当成静态配置的隐式替代；
- SSH 服务启动前即可建立的 early-boot 网络，不依赖 Cloud-Init、容器或业务 secret。

systemd 对 `GatewayOnLink=` 的定义是：即使 kernel 尚未把 gateway 判断为直接可达，也允许安装该 route；这正是当前 link-local IPv6 gateway 需要显式保留的语义。[systemd.network(5)](https://www.man7.org/linux/man-pages/man5/systemd.network.5.html)

#### 公网路由事实的版本化边界

**最不容易踩坑的方案是：经维护者明确批准后，把 public address、prefix、gateway 与 nameserver 作为非凭据 host facts 写入 `hosts/server/`。** 它们决定 early boot 是否可达，必须和接受验证的 closure 一起冻结，才能保证 nixbox build、VM variant、production install 与后续 recovery 使用同一输入。

当前 Issue #13 仍禁止把 IP 写入 Git，而维护者已说明 public IP 本身不构成顾虑；这两个口径必须在 Phase 8 前显式对齐。若仍要求 exact values 不进公开 Git，次选方案应是一个独立版本化、带内容 hash、同时存在于 macbook 与 nixbox 的 private flake input，并另写 ADR。不要采用以下伪私有方案：

- untracked `network.nix`：Git flake 默认看不到未跟踪文件；
- `--impure` 环境变量或现场字符串替换：精确 commit 不再能重建相同 closure；
- 把网络值当 sops-nix secret：Phase 11 才引入 secret 能力，而且网络建立前无法依赖在线取 key；
- 只复制 mutable `/etc/systemd/network` 文件：后续 rebuild、recovery 与 VM 测试容易发生声明漂移。

Nix 的 Git flake 只包含 Git 已跟踪文件；local path 又会成为 Nix 输入并复制到 store，所以“放在旁边但仍被 Nix import”既不等于 secret 管理，也不自动可复现。[Nix Flake reference](https://nix.dev/manual/nix/2.26/command-ref/new-cli/nix3-flake.html)，[nix.dev：Working with local files](https://nix.dev/tutorials/working-with-local-files.html)

### 3.3 SSH、用户与 sudo

首次 NixOS 的访问模型建议如下：

| 身份 | key 来源 | 首次替换用途 | 长期方向 |
| --- | --- | --- | --- |
| `sayori` 管理用户 | 现有 macbook server maintenance public key | 独立日常管理与救援 | 保留 |
| `sayori` 管理用户 | 新建 nixbox 专用 deploy public key | 从 nixbox 推送 closure；不复制 macbook private key | 保留，可独立轮换 |
| `root` | 仅 macbook maintenance public key | 首次启动期间 break-glass | 两条普通用户路径和重启均通过后，再经批准关闭 |

最小策略为：

- `PasswordAuthentication = false`；
- `KbdInteractiveAuthentication = false`；
- 首次替换暂用 `PermitRootLogin = prohibit-password`，只允许 key-only root；
- `sayori` 属于 `wheel`，首次最小系统使用可脚本验证的 passwordless sudo；
- firewall 明确启用，只开放 SSH 所需 TCP port；不恢复现有 HTTP、高位端口、Docker 或控制面；
- 不设置额外 `AllowUsers`、改端口、fail2ban 或自定义算法清单，以免在首次接入时增加隐藏拒绝条件。

OpenSSH 明确说明 `PermitRootLogin=prohibit-password` 会禁止 root 的 password 与 keyboard-interactive 登录，但保留 public-key；`PasswordAuthentication` 与 `KbdInteractiveAuthentication` 是两条独立认证路径。[OpenBSD sshd_config(5)](https://man.openbsd.org/sshd_config)

### 3.4 Host identity

当前没有 host key 泄露或机器被攻陷的证据，维护者又把“重装后仍可访问”列为最高优先级，因此首次安装建议：

1. macbook 继续用当前已验证的 host key；
2. 安装前通过 macbook 的可信会话把同一 host public key 传给 nixbox 的专用 `known_hosts`，不要求维护者手抄 fingerprint；
3. `nixos-anywhere` 使用 `--copy-host-keys` 把现有 `/etc/ssh/ssh_host_*` 保留到最终 NixOS；
4. macbook 与 nixbox 始终使用 `StrictHostKeyChecking=yes` 和专用 known-hosts file；绝不使用 `StrictHostKeyChecking=no`；
5. 若出现 compromise 证据，再改为 rotation：从 VNC/Rescue 控制台核验新 ED25519 fingerprint 后才更新客户端 pin。

`nixos-anywhere` 官方说明 `--copy-host-keys` 会把既有 host keys 复制到最终安装；官方 kexec image 的源码还表明，进入临时 installer 前会把当前 authorized keys 与 host keys 加入 initrd，所以 kexec 前后可以维持受信 SSH identity。[nixos-anywhere reference](https://nix-community.github.io/nixos-anywhere/reference.html)，[Secrets / existing host keys](https://nix-community.github.io/nixos-anywhere/howtos/secrets.html)，[kexec-run source](https://github.com/nix-community/nixos-images/blob/6ece16b0c97986fe085122e796044add4cc3ff64/nix/kexec-installer/kexec-run.sh)

`ssh-keyscan` 本身不验证对端身份；OpenSSH 手册明确警告，未经核验就建立 key database 会暴露于中间人攻击。因此它只能作为采集工具，不能成为信任来源。[ssh-keyscan(1)](https://man.openbsd.org/ssh-keyscan)

### 3.5 最小能力边界

Phase 8 的 server output 应分成两个互不倒置的层次：

1. access-critical system plane：boot、disk/mount、静态网络、DNS、OpenSSH、管理用户、sudo、基础 firewall、Nix/Flake 基础设置及必要 recovery 工具；SSH 登录与 sudo 不得依赖 Home Manager activation 成功；
2. Issue #11 已批准的 headless user plane：Nix 运维、Fish、Atuin 本地历史、Git 基础、Shell 辅助、主机概览与诊断能力。Home Manager 只能作为 NixOS module 组合到最终系统；Atuin sync 与 GitHub collaboration 必须保持关闭。

不要导入 workstation 的 `base` / `desktop` bundle，也不要加入 GUI、Clash、Termius、LocalSend、GitHub 协作凭据、Docker、数据库或原业务服务。若复用已有能力，host 必须通过明确的 requirement-driven capability import 选择，不能把工作站 bundle 当 server 角色接口。Ubuntu 上的 standalone Home Manager 仍然禁止；这与 NixOS output 内经 Issue #11 批准的 Home Manager module 不是同一边界。

## 4. 分阶段实施顺序

### Phase 7 / Issue #9：只读收口

在合并当前 Draft PR 前：

1. 记录本调研及新增的 kexec、driver、stable disk identity 证据；
2. 由维护者确认本节第 7 章列出的三项设计选择；
3. 对齐 roadmap 与 Issue #13 的 backup waiver、public routing facts 与 host-key wording；
4. 不在 server、nixbox 或 Contabo 创建 key、接受 host key、启动 VNC/Rescue 或运行安装。

### Phase 8 / Issue #11：只构建，不接触 production

1. 固定 disko input；新增 `nixosConfigurations.server` 与 host-specific BIOS/disk/network/SSH 模块；
2. 仅在维护者明确批准该 nixbox 本地状态变更后，创建专用 deploy key；经审阅后只把 public half 纳入 server authorized keys，private half 不离开 nixbox；
3. macbook maintenance public key 进入 server 声明；不复制 private key；
4. 在 nixbox 完成 format check、flake check 与 server toplevel build；
5. 按 Issue #11 显式组合已批准的 headless CLI capabilities，并验证 Atuin 不同步、Git 不带 GitHub collaboration；
6. 检查最终 closure 不包含 private key、密码、VNC/Rescue credential 或 GitHub credential；
7. 保持 production Ubuntu 完全不变。

### Phase 9 / Issue #12：隔离 VM 安装验证

1. 固定 `nixos-anywhere` input；使用一次性 VM 磁盘和非生产 key；
2. 以 BIOS 模式运行 `--vm-test`，验证 GPT/EF02、ext4 root、GRUB、首次启动与第二次重启；
3. VM variant 使用测试地址或 DHCP，不携带 production network values；另外以等价的 dummy 双栈 topology 测试 link-local IPv6 gateway + `GatewayOnLink` 语义；
4. 验证 `sayori`、两类 authorized-key slot、`sudo -n`、root break-glass、key-only SSH 与只开放预期 port；
5. 验证 headless CLI capabilities 可用，Atuin 没有跨设备同步，closure 没有 GUI、业务、GitHub credential 或 mutable checkout；
6. 生成一条维护者可审阅的短 entry command；不得要求手抄 hash、store path、key 或长参数。

### Phase 10 / Issue #13：维护者现场监督的 production replacement

正式窗口应严格分成四段，每段可独立 abort：

#### A. 冻结与 preflight

- 冻结已经在 nixbox 通过 VM test 的 commit 与 `flake.lock`；提前构建 kexec、disko 与 system closure；
- 从可信 SSH 再次核对 BIOS、唯一 disk stable alias/容量、单一 `virtio_net` NIC、静态双栈 route/DNS、RAM 与 kexec runtime；任何差异都停止；
- macbook 直连 SSH、Clash `/32` 排除、nixbox 网络与两把 key 认证均需在窗口开始前成功；
- 实际连接 Contabo VNC，而不只是看到“enabled”；现场确认 Rescue 入口可用，临时凭据不记录；
- 屏幕上明确展示 target host、stable disk alias、commit 与将运行的 command，维护者再给当次批准。

#### B. 安装

由 nixbox 使用 Phase 9 已审阅的短 entry command。底层 `nixos-anywhere` 选项应显式包含以下语义，但不要求维护者手打：

- local build on nixbox；
- destination 不自行 substitute；
- 保留现有 SSH host keys；
- strict host-key verification 与专用 known-hosts file；
- 精确、冻结的 flake output。

`--no-substitute-on-destination` 很重要：官方 kexec image 源码会恢复 address 与 route，但没有写入 DNS 的逻辑。**据源码推论**，临时 installer 的 DNS 不应视为可靠；由 nixbox 预构建完整 closure 并关闭 destination substitution，可以避免安装阶段依赖目标机解析 cache 域名。[route restoration source](https://github.com/nix-community/nixos-images/blob/6ece16b0c97986fe085122e796044add4cc3ff64/nix/kexec-installer/restore_routes.py)，[nixos-anywhere CLI reference](https://nix-community.github.io/nixos-anywhere/reference.html)

#### C. 首次验收

安装完成后，按以下顺序验收，不恢复业务：

1. VNC 观察 GRUB、kernel 与 login target；
2. macbook 以 `sayori` 登录并执行 `sudo -n true`；
3. nixbox 以自己的 deploy key 登录同一普通用户并执行只读 closure/generation 检查；
4. 验证 IPv4、IPv6、default routes、DNS、sshd effective policy 与 firewall；
5. 确认只存在最小预期监听端口，HTTP、Docker 与旧控制面均未恢复。

#### D. 二次启动

维护者另行批准一次 reboot；VNC、macbook SSH、nixbox SSH、sudo、network、mount 与 firewall 全部再次验证。完成前保留 key-only root break-glass；关闭 root SSH 是后续单独变更，不与首次清盘混做。

## 5. 失联处理顺序

| 失败点 | 首选动作 | 升级动作 | 明确不做 |
| --- | --- | --- | --- |
| kexec 前 preflight 不一致 | 停止，不运行安装 | 更新证据、配置与 VM test | 不“试一下”真实 disko |
| kexec 后 SSH 未恢复 | VNC 观察 temporary installer；检查等待时间与网络 | 经批准启动 Rescue | 不关闭 host-key check 重连 |
| 安装完成但 GRUB/kernel 不启动 | VNC 记录错误 | Rescue 挂载目标，修复 closure/GRUB 或重跑已验证安装 | 不恢复旧业务或随机改 boot mode |
| NixOS 启动但无网络 | VNC 确认系统启动；Rescue 复核 NIC 与 route | 从冻结配置修正网络并重新部署/安装 | 不假定 DHCP，不在面板盲改 IP |
| 网络通但 SSH 失败 | VNC/Rescue 检查 sshd、authorized keys 与 firewall | 从冻结配置恢复 key-only break-glass | 不临时开放 password root |
| NixOS 无法修复 | Rescue 重新安装同一已验证最小 NixOS | Contabo Reinstall/Custom Image 最后重建 | 不承诺恢复 Ubuntu 数据 |

维护者已放弃 source data rollback，因此这里的“回滚”含义是恢复一个可 SSH 的最小 NixOS，不是恢复 Ubuntu、容器或数据库。若 provider IP、磁盘或虚拟硬件在恢复流程中改变，必须回到 preflight 与 VM/provider 差异关卡，不能继续使用旧假设。

## 6. 不推荐的替代方案

| 方案 | 不采用的原因 |
| --- | --- |
| Contabo Custom Image 作为主安装路径 | 增加镜像格式、upload、Cloud-Init、provider add-on 与 boot 变量；当前 Ubuntu 已是满足要求的可信入口 |
| 直接在 Ubuntu 手工分区或运行 disko | 绕过 nixos-anywhere 的 kexec/closure 流程，且更容易在运行中的 root filesystem 上误操作 |
| 在目标 Ubuntu/installer remote build | 引入目标 DNS、substituter、RAM、磁盘空间和 mutable source 依赖；与 ADR-0008 的 nixbox build/push 方向相反 |
| 只配 DHCP | 当前实证是静态双栈，provider panel 也没有给出 DHCP 保证；最可能造成首启失联 |
| 硬编码 `eth0` | NixOS predictable name 可能为 `ens18` / `enp0s18`；接口改名即可切断所有远程恢复 |
| 首次安装立即禁止 root SSH | 普通用户、sudo 或 key 声明任一错误都会失去最后的 guest-level SSH recovery |
| 首次安装强制轮换 host key | 增加两个客户端的身份更新与 MITM 核验变量；当前无 compromise 证据 |
| `StrictHostKeyChecking=no` 或盲信 `ssh-keyscan` | 把访问便利建立在取消 server identity 验证上；不满足独立恢复链路要求 |
| 混合 BIOS/UEFI、LUKS、ZFS、LVM、swap 或 impermanence | 没有需求且没有 provider 实证；扩大 boot/storage 状态空间和 Rescue 难度 |
| 在同一阶段恢复 Docker/数据库/业务 | 无法区分系统、网络、SSH 与业务失败；违反“先最小系统稳定”的 Phase 顺序 |

Contabo 官方说明 VNC 可在网络或 OS 启动异常时连接 guest console，Rescue 是内存中的临时系统；Reinstall 会删除现有数据。它们支持上述逐级恢复，但不能替代真实连接与现场凭据验证。[VNC](https://help.contabo.com/en/support/solutions/articles/103000407800-how-to-connect-to-your-server-using-vnc)，[Rescue](https://help.contabo.com/en/support/solutions/articles/103000295053-how-do-i-boot-a-rescue-system-for-my-server-)，[Reinstall](https://help.contabo.com/en/support/solutions/articles/103000271913-how-do-i-install-my-contabo-server-)

## 7. 进入 Phase 8 前需要维护者确认的设计选择

1. **Public routing facts（推荐批准）：** 允许把 server 的 public address、prefix、gateway 与 nameserver 作为非凭据 host facts 写入 Git；继续禁止账号 ID、VNC endpoint/credential、MAC、private key 与 host-key private material。若不批准，先做 private flake input ADR，不能退化为 untracked/impure 注入。
2. **SSH identity（推荐批准）：** 普通管理用户为 `sayori`；声明 macbook maintenance public key，并在 nixbox 新建专用 deploy key后声明其 public half；首次保留仅 key-only 的 root break-glass。
3. **Host identity 与 waiver（推荐批准）：** 首次安装保留现有 SSH host keys；把 Issue #13 的“新 host key”改成“已批准的预期 host key”；同时把 roadmap/#13 的强制 backup/restore 条件改为维护者已记录的全量数据丢失 waiver，失败恢复目标改为重新建立最小 NixOS。

这三项都不是当前 production 执行授权。Phase 10 仍必须针对精确 host、stable disk alias、commit、command 与当次窗口取得新的明确批准。

## 8. 一手来源清单

1. [nixos-anywhere Requirements（固定 commit）](https://github.com/nix-community/nixos-anywhere/blob/5887f1c72fbf0e88000716237194de414d2299ee/docs/requirements.md)
2. [nixos-anywhere CLI Reference](https://nix-community.github.io/nixos-anywhere/reference.html)
3. [nixos-anywhere：existing SSH host keys](https://nix-community.github.io/nixos-anywhere/howtos/secrets.html)
4. [nixos-images kexec-run（固定 commit）](https://github.com/nix-community/nixos-images/blob/6ece16b0c97986fe085122e796044add4cc3ff64/nix/kexec-installer/kexec-run.sh)
5. [nixos-images route restoration（固定 commit）](https://github.com/nix-community/nixos-images/blob/6ece16b0c97986fe085122e796044add4cc3ff64/nix/kexec-installer/restore_routes.py)
6. [disko GPT BIOS example 与 test（固定 commit）](https://github.com/nix-community/disko/tree/ff8702b4de27f72b4c78573dfb89ec74e36abdf1)
7. [NixOS Manual：Bootloader](https://nixos.org/manual/nixos/stable/#sec-installation-boot-loader)
8. [NixOS Manual：Networking](https://nixos.org/manual/nixos/stable/#sec-networking)
9. [systemd.network(5)](https://www.man7.org/linux/man-pages/man5/systemd.network.5.html)
10. [OpenBSD sshd_config(5)](https://man.openbsd.org/sshd_config)
11. [OpenBSD ssh_config(5)](https://man.openbsd.org/ssh_config)
12. [OpenBSD ssh-keyscan(1)](https://man.openbsd.org/ssh-keyscan)
13. [Nix Flake reference](https://nix.dev/manual/nix/2.26/command-ref/new-cli/nix3-flake.html)
14. [nix.dev：Working with local files](https://nix.dev/tutorials/working-with-local-files.html)
15. [Contabo VNC](https://help.contabo.com/en/support/solutions/articles/103000407800-how-to-connect-to-your-server-using-vnc)、[Rescue](https://help.contabo.com/en/support/solutions/articles/103000295053-how-do-i-boot-a-rescue-system-for-my-server-)、[Reinstall](https://help.contabo.com/en/support/solutions/articles/103000271913-how-do-i-install-my-contabo-server-) 与 [Custom Images](https://help.contabo.com/en/support/solutions/articles/103000274171-can-i-use-custom-images-on-my-server-)

本文的一手资料调研固定在 2026-07-30。production 执行前仍需按冻结 flake inputs、当前 Contabo 面板和实时硬件/network preflight 重新核验。
