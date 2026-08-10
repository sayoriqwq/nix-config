# Phase 8：Server 最小 NixOS 声明

> 范围：Issue #11 的声明、非破坏性 evaluation/build 与后续关卡输入。本文不授权连接或修改 production Ubuntu server，也不授权运行 disko、nixos-anywhere、kexec、format、reboot、Rescue、Reinstall 或任何 Contabo 电源动作。
>
> **后续决策：** Phase 8 将 root SSH 标为首次替换 break-glass；维护者于 2026-08-05 曾在任何关闭配置 activation 前采用单管理员 root public-key-only 模型，又于 2026-08-10 重新打开 #99 并恢复 `sayori + sudo` 目标。当前仓库声明关闭 root SSH；production 只有在独立行动卡获批并 activation 后才改变。本文表格中的首次安装事实保持历史原貌。

## 1. 证据到声明的映射

| 关注点 | Phase 7 证据或维护者决策 | Phase 8 声明 |
| --- | --- | --- |
| 平台 | Contabo KVM，`x86_64-linux` | `nixosConfigurations.server` 固定 `nixpkgs.hostPlatform = "x86_64-linux"` |
| boot | 运行态证据指向 BIOS；现有磁盘上的 EFI 残留不作为 UEFI 证据 | GRUB BIOS、GPT、1 MiB `EF02` boot partition；不启用 EFI |
| disk | 唯一约 75 GiB Virtio SCSI 可写盘；稳定 alias 指向当前 `/dev/sda` | disko 只引用 `/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0`；单一 ext4 `/`；无 swap |
| initrd | Virtio PCI/SCSI 与 SCSI disk driver 为当前启动链路 | 显式加入 `virtio_pci`、`virtio_scsi`、`sd_mod` |
| NIC | 当前只有一张 provider NIC，driver 为 `virtio_net`；接口名可能变化 | networkd 按 `Driver=virtio_net` 匹配，不硬编码 `eth0`；单 NIC 作为 Phase 9/10 preflight 硬关卡 |
| IPv4 | `38.242.129.34/21`，gateway `38.242.128.1` | 静态 address 与 default route |
| IPv6 | `2a02:c207:2301:9930::1/64`，link-local gateway `fe80::1` | 静态 address；route 显式 `GatewayOnLink=true`；保留 IPv6 link-local |
| DNS | `213.136.95.10`、`213.136.95.11`、`2a02:c207::1:53` | networkd link DNS；禁用 DHCP 与 RA |
| 管理用户 | 维护者批准 `sayori`、双普通用户 key、passwordless sudo | `sayori` 属于 `wheel`，声明 macbook maintenance 与 nixbox deploy public key，`sudo -n` 可用 |
| break-glass | 首次替换保留只由 macbook key 使用的 root SSH | `PermitRootLogin=prohibit-password`；root 只声明 macbook public key |
| SSH / firewall | 首要验收目标是替换后仍能 SSH；首版不恢复业务端口 | 禁用 password 与 keyboard-interactive；firewall 只开放 TCP 22，不开放 UDP |
| 用户能力 | 只组合已批准的 headless CLI 能力 | Fish、Nix 运维、本地 Atuin 历史、Git 基础、Shell 辅助和主机诊断；无 GUI、GitHub collaboration、工作站 runtime 或 Atuin sync |
| 版本 | 新 NixOS host 首次锁定 26.05 | `system.stateVersion` 与 `home.stateVersion` 均为 `26.05` |

固定版本的 disko 在发现 `EF02` 分区时会从 disk device 自动生成 `boot.loader.grub.devices`。Phase 8 曾同时声明单值 `boot.loader.grub.device`，非破坏性 evaluation 发现 duplicated devices 断言后已删除重复声明；最终生成值仍是上表的稳定 disk alias。

2026-08-10 的 #99 在不改变 disk、boot、network、firewall 或服务边界的前提下，新增 Helix、Yazi 与系统级 `lsof`、`dig`、`mtr`、`tcpdump`、`strace`。这些 package 不启用 daemon 或 listener；其中抓包、跨进程检查和跨进程追踪按需经 sudo。

## 2. 组合边界

- `hosts/server/default.nix` 只组合 server host facts、disko、network 与已批准 capability；
- `modules/nixos/server.nix` 只承载 server 的 firewall、sudo 与 SSH root policy；
- `modules/nixos/server-diagnostics.nix` 只提供已批准的系统级诊断 CLI，不启用 service、listener 或 firewall rule；
- `modules/nixos/base.nix` 改为接收 host composition 传入的 `username`，不再夹带 nixbox 的 authorized key 或 root policy；
- `hosts/nixbox/default.nix` 显式保留原 authorized key 与 `PermitRootLogin = "no"`，从而保持既有 nixbox 行为；
- server 不声明 production service、旧容器、数据、secret、GitHub credential 或自行 checkout/build 的机制。

未来 production secret 只记录为 Phase 11 的运行时缺口。Phase 8 不放占位 secret、不把敏感值送入 Nix Store，也不为了未来服务提前引入 sops-nix。

## 3. Deploy key 与 host identity 边界

2026-07-30 已在 nixbox 创建 server 专用 ED25519 deploy key：

- private half 只留在 nixbox，未复制到 macbook、Git、Issue、PR 或聊天；
- public half 已纳入 `sayori` 的 server authorized keys；
- macbook 维护 public key 同时用于 `sayori` 与首次 root break-glass；
- private key 路径、fingerprint、server host-key pin、Contabo endpoint 与面板凭据只保存在 mode `0600` 的本地私密记录中。

现有 server host identity 由 macbook 的既有可信记录提供。该记录已通过受信 macbook → nixbox SSH 链路复制到 nixbox 的专用 known-hosts file，并比较记录摘要一致；没有使用 `ssh-keyscan` 建立信任，也没有关闭 host-key 检查。Phase 8 没有尝试用新 deploy key 登录 production server，因为该 public key 只会随未来 NixOS 安装生效。

Phase 9/10 helper 必须固定以下 SSH 语义，维护者只运行短 entry command，不手抄 key、fingerprint、store path 或长参数：

- `IdentitiesOnly=yes`，只使用 nixbox 专用 deploy private key；
- `StrictHostKeyChecking=yes`，只使用专用 known-hosts file；
- 初次安装显式保留现有 SSH host keys；
- 不用 `ssh-keyscan`、`StrictHostKeyChecking=no`、password root 或把 macbook private key 复制到 nixbox 作为捷径。

## 4. Phase 9 隔离 VM 输入

Phase 9 必须从当前 server output 派生测试 variant，但用 `lib.mkForce` 或独立 test module 覆盖所有 production endpoint；不得让 VM 接触 production server 或把 production disk alias 当成宿主机设备打开。

| 维度 | 隔离测试输入 | 必验结果 |
| --- | --- | --- |
| firmware | QEMU x86_64，BIOS，关闭 EFI/OVMF | 首次启动与第二次重启均由 GRUB 进入 NixOS |
| disk | 单一临时 Virtio SCSI disk；测试专用稳定 serial/by-id | disko 只格式化临时 disk；GPT 含 `EF02` 与单一 ext4 `/`；无 swap |
| NIC | 单一 `virtio_net` NIC，隔离网络 namespace/bridge | driver match 只命中一张 NIC；增加第二张时 preflight 必须拒绝 |
| IPv4 | RFC 5737 dummy address/gateway | static address 与 default route 正确，不依赖 DHCP |
| IPv6 | RFC 3849 dummy address；link-local dummy gateway | `GatewayOnLink=true` 的 route 可用，不依赖 RA |
| DNS | 隔离测试 resolver | 生成的 link DNS 正确；测试不依赖 production DNS |
| SSH | 测试专用 ephemeral client/host keys | 两类 `sayori` key login 与 `sudo -n true` 通过；maintenance/deploy key 的 root login、password 和 keyboard-interactive 均失败 |
| firewall | 测试 network namespace | TCP 22 可达；未声明端口不可达；无旧业务 listener |

VM test 还必须断言：`stateVersion = 26.05`、Atuin 没有 sync 设置、没有 GitHub collaboration/GUI/工作站 bundle、最终 closure 不依赖 server checkout。测试产生的 ephemeral key 与 disk image 不进入 Git，测试结束后删除。

## 5. Phase 10 冻结输入

正式窗口前必须由 Phase 9 交付并由维护者逐项审阅：

1. 已通过 VM 首启与二次重启的精确 Git commit、flake lock 与 `nixosConfigurations.server` closure；
2. 只读 preflight helper 的结果，确认 architecture、BIOS、唯一可写 disk、stable alias → device、容量、唯一 `virtio_net` NIC、address/prefix、双栈 gateway、DNS、RAM、kexec 与当前 SSH host identity 全部未漂移；若已进入 temporary installer 后执行定向恢复，则 installer DNS 只要求实际解析成功，最终 NixOS 的 static link DNS 声明保持不变并留待首启验收；
3. macbook 与 nixbox 的 strict host pin、两条普通用户 key 路径、macbook root break-glass 与 `sudo -n` 验收步骤；
4. 已实际连接的 Contabo VNC，以及可在需要时启动的 Rescue/Reinstall 入口；credential 只在本地私密记录和现场 UI 中处理；
5. 由 helper 封装的短安装 entry command，其底层冻结 local build/push、destination 不 substitute、保留 host keys、精确 output 与严格 SSH options；
6. 精确 host、stable disk alias、commit、命令、窗口、现场观察人与数据全量丢失 waiver 的当次明确批准。

任何 disk、boot、NIC、route、host identity 或 provider recovery 差异，以及进入 kexec 前或最终 NixOS 验收时的 static DNS 差异，都会停止窗口并回到 Phase 8/9；temporary installer 定向恢复仅适用上一条的 functional DNS 例外。不得现场猜值或先运行 destructive command 再修。

## 6. Phase 8 验证记录

Phase 8 只允许以下非破坏性验证：

```text
nix fmt -- --check .
nix flake check
nix eval --json .#nixosConfigurations.server.config.boot.loader.grub.devices
nix eval --raw .#nixosConfigurations.server.config.disko.devices.disk.main.device
nix eval --raw .#nixosConfigurations.server.config.disko.devices.disk.main.content.partitions.boot.type
nix eval --raw .#nixosConfigurations.server.config.disko.devices.disk.main.content.partitions.root.content.format
nix eval --json .#nixosConfigurations.server.config.swapDevices
nix build .#nixosConfigurations.server.config.system.build.toplevel
```

不直接打印整个 `config.disko.devices`：该 module tree 含内部函数与兼容 option，整树 pretty-print 会产生无关的 upstream warning 并长时间展开；上面的纯值查询覆盖实际 destructive target、boot type、root filesystem、无 swap 与 GRUB device。最终结果以 Issue #11 与 Draft PR 的 validation section 为准；完整 closure 必须在 nixbox 原生 `x86_64-linux` 构建。build 成功不是 production activation 或安装授权。
