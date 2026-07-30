# Phase 7 Server 迁移前置盘点

本文记录 Issue #9 的脱敏证据、维护者决策、未知事实与 Phase 8 阻塞项。Phase 8–10 的低风险设计结论另见 [`docs/plans/phase-7-server-migration-practice-research.md`](../plans/phase-7-server-migration-practice-research.md)。当前阶段只盘点 Ubuntu source state，不建立 `nixosConfigurations.server`、standalone Home Manager、`disko` 或生产服务声明，也不修改 server。

## 1. 证据与批准边界

- 2026-07-30 已完成仓库、Issue #9、架构文档、ADR、迁移路线图与 Contabo 官方恢复文档审查。
- 2026-07-30 已经维护者批准，从 macbook 通过既有 SSH alias 对 server 执行无 `sudo` 的只读盘点；没有读取 `.env`、私钥、secret value、数据库内容或完整业务配置。
- 原始命令输出只短暂保留在执行端，仓库仅记录脱敏结论。公网地址、私有地址、MAC、账号 ID、序列号、私有主机名、完整 SSH key、登录来源、业务路径与 secret 不进入本文。
- 维护者明确接受当前 server 的全部系统、服务与数据在迁移中丢失，不要求备份、异机副本或恢复测试，也不要求恢复现有业务。
- 维护者不限制停机时间。正式替换后的首要且唯一强制验收条件是：维护者仍能从 macbook 通过 SSH 取得 server 控制权。
- 上述数据丢失与停机决策不构成当前清盘授权。格式化、重装、boot/network/firewall/SSH 变更和 reboot 仍留在后续 Issue 的精确目标与当次批准关卡。

## 2. 当前实机基线

| 类别 | 2026-07-30 脱敏事实 | 迁移判定 |
| --- | --- | --- |
| 角色 / provider | 逻辑 output 为 `server`；Contabo KVM 虚拟服务器；当前 Ubuntu，目标 Headless NixOS | provider 与当前实例的 Reinstall、Rescue、VPS Control、VNC 入口均已在面板实时确认 |
| OS / 架构 | Ubuntu 24.04.3 LTS、`x86_64`、Linux 6.8.0-90-generic；未安装 Nix | 已实时确认 |
| RAM / kexec | 约 8 GiB RAM 且无 swap；当前 kernel 启用 `KEXEC` / `KEXEC_FILE`，运行态未禁用 kexec | 满足 `nixos-anywhere` 当前官方 target requirements；正式窗口仍须重复 preflight |
| 当前用户 | SSH alias 使用 `root`；UID 0、home `/root`、shell `/bin/bash` | 只记录 source state；未来 NixOS 管理用户不从 root 模型推断 |
| boot | 运行态未暴露 EFI firmware，记录为 BIOS；`grub-pc` 已安装；磁盘仍有已挂载的 vfat `/boot/efi`，并存在 EFI 相关 package | 当前启动证据指向 BIOS；EFI 分区可能是镜像残留，Phase 8 不得据其猜 UEFI |
| disk / filesystem | 唯一可写虚拟磁盘 `/dev/sda`，约 75 GiB；稳定 QEMU SCSI `by-id` 指向该磁盘；ext4 `/`、独立 ext4 `/boot`、vfat `/boot/efi`；另有只读虚拟光驱 | Phase 8 的 disko/GRUB 目标应使用 stable `by-id`；正式执行仍需核对 alias、容量、唯一性与底层 device 并取得当次批准 |
| storage driver | Virtio SCSI controller；当前 kernel 内建 Virtio PCI/SCSI 与 SCSI disk 支持 | Phase 8 initrd 与 Phase 9 BIOS VM 必须覆盖同一启动链路，不能从空 `lsmod` 猜 driver 不需要 |
| 容量 | `/` 约 72 GiB，盘点时使用约 38%；`/boot` 与 `/boot/efi` 均有充足剩余空间 | 只作 source-state 摘要，不形成未来分区设计 |
| network | 单一 `virtio_net` NIC；当前名为 `eth0`，但 udev 给出其他 predictable-name 候选；同时承载静态 IPv4/IPv6 默认路由；systemd-networkd、cloud-init Netplan 与 systemd-resolved 参与配置 | address、prefix、gateway、route 与 DNS 已保存为仓库外私有输入；Phase 8 不能硬编码 `eth0`，推荐按 driver 匹配并断言单 NIC |
| SSH | `ssh.socket` 与 `ssh.service` active；public-key 登录实时成功；root authorized-keys mode/owner 正确；`nixos-anywhere` bootstrap 所需的 `tar` 与 `setsid` 可用；当前还允许 root 与密码认证，keyboard-interactive 已关闭 | 当前 macbook 管理链路与 bootstrap 前置工具已验证；未来最小 NixOS 不应无意复制宽松 source policy |
| firewall | UFW unit 虽 enabled，但 `ufw status` 为 inactive，运行态规则数为 0 | 撤回 Phase 1 的“UFW 已启用”摘要；Phase 8 必须显式设计最小 firewall，不能假定已有保护 |
| 健康 | `cloud-init.service`、`nginx.service` 与 `systemd-networkd-wait-online.service` failed；cloud-init 总状态为 error | 3 个 failed units 已实时确认；现有业务不要求修复或迁移 |
| service / ports | Docker、containerd 与 1Panel active；PM2 root unit inactive；SSH、DNS、HTTP/HTTPS 与若干高位 TCP 端口监听 | 只用于确认将被清除的 source workload；高位端口不在公开 inventory 展开 |
| containers / data | 7 个运行容器，包括应用栈、MongoDB 7、Redis、反向代理/控制面；4 个 Docker volumes，并存在 bind mounts | 服务和数据全部按维护者决策舍弃；不读取或迁移 volume、bind path、database、`.env` 与 secret |
| lifecycle | 系统报告 55 个可用更新并要求重启 | Phase 7 不执行 apt upgrade、服务 restart 或 reboot |

## 3. 管理与部署链路

### 3.1 macbook → server

最初的失败信号为：TCP 22 可建立，但 SSH 在取得 server banner 前被关闭。到 server 的路由当时进入 Clash Verge TUN 的 GVisor 虚拟接口。

2026-07-30 完成同条件 A/B：

| 状态 | 本机路由 | SSH 结果 |
| --- | --- | --- |
| TUN 开启、未排除 server | Clash TUN 虚拟接口 | TCP 成功；banner 前关闭；SSH status 255 |
| TUN 关闭 | macbook 物理网络接口 | host key 与 OpenSSH banner 成功；public-key 认证成功；SSH status 0 |
| TUN 恢复、未排除 server | Clash TUN 虚拟接口 | 原失败稳定复现 |

经维护者针对当前动作明确批准，已在 Clash Verge TUN 的“排除自定义网段”中加入 server IPv4 的单一 `/32`。保存后 TUN 继续开启，但 server 路由改走 macbook 物理接口；普通 OpenSSH 和 Termius 均已实际登录成功。

该 `/32` 是 macbook 上 Clash Verge 的可变本地状态，不由 nix-config 声明。macbook 重装或 Clash 状态重置后，必须先恢复这一窄排除，或使用另一条经验证的直连路径，才能把 macbook 视为独立 server recovery path。仓库不记录实际地址。

### 3.2 nixbox → server

2026-07-30 的只读验证确认 macbook 可用既有 public-key 链路进入 nixbox，且 nixbox 到 server 的 TCP 22 可达。nixbox 当前没有该 server 的 known-host 记录，因此没有绕过 host-key 校验继续尝试 SSH authentication，也没有写入 `known_hosts`、复制 key 或修改 SSH 配置。

结论是网络路径已建立，但部署认证链路尚未建立。Phase 8/9 必须明确 host-key 验证与最小部署凭据的提供方式；server 不保存 GitHub 协作凭据，nixbox 也不能靠关闭 host-key 检查来部署。

## 4. Contabo 恢复能力

Contabo 当前官方文档给出以下 provider 能力：

- [Customer Panel 重装](https://help.contabo.com/en/support/solutions/articles/103000271913-how-do-i-install-my-contabo-server-)会永久删除现有数据，并要求设置系统密码；Linux 产品/面板还可能支持保存 SSH public key；
- [Rescue System](https://help.contabo.com/en/support/solutions/articles/103000295053-how-do-i-boot-a-rescue-system-for-my-server-)适用于 VPS、VDS 与 Dedicated Server，可从 Customer Control Panel 启动并通过独立 root password 在 TCP 22 登录；
- [VNC](https://help.contabo.com/en/support/solutions/articles/103000407800-how-to-connect-to-your-server-using-vnc)可以在 guest 网络或系统启动异常时提供显示控制，但需先在面板启用、取得动态凭据并使用第三方 VNC client；启用本身需要 reboot；
- Contabo 的[产品变更说明](https://help.contabo.com/en/support/solutions/articles/103000269700-how-to-make-changes-to-your-vps-or-vds-plan)称普通重装保持 IP 不变，但正式迁移仍须以维护者面板中当前 server 的实际选项为准。

这些官方文档定义了预期能力；是否适用于当前实例仍以维护者账号中的实时控制面为准。

2026-07-30 已在维护者登录的 Customer Control Panel 中完成当前实例的只读实证：

- VPS Control 的 Restart、Start、Stop、Reinstall 与 Rescue System 均真实存在；面板明确说明这些控制独立于 guest OS；
- VNC 当前已启用，VNC Information 与现场取用 VNC Password 的入口可见；本次没有打开、保存或记录凭据，也没有切换 VNC 状态；
- Reinstall 页面明确提示会删除全部数据；可见标准镜像列表没有 NixOS，但 Advanced/Custom Image Installation 支持为 Admin 选择 SSH public key 与 Cloud-Init template；
- Linux-based Rescue System 入口真实存在，需要现场设置密码才能启动；本次没有填写密码、启动 Rescue 或触发 reboot；
- IP Management 只给出已分配地址和 provider 通用 DNS 信息，未给出完整 prefix/gateway。所缺值已通过无 `sudo` 的 guest runtime 查询复核，只保存在仓库外私有文档。

据此，失去普通 SSH 后的恢复顺序可定义为：先用已启用的 VNC 观察 boot/network 状态；若 guest 无法修复，再经当次批准启动 Rescue；只有在明确 destructive target 和 SSH/network 安装输入且取得正式批准后，才进入 Reinstall。面板核验本身未执行上述动作。

## 5. 仓库实现审计

2026-07-30 对 `flake.nix`、`hosts/`、`modules/` 与相关文档的只读搜索确认：

- `flake.nix` 当前只暴露 `darwinConfigurations.macbook` 与 `nixosConfigurations.nixbox`；
- `hosts/server/` 不存在；
- `modules/nixos/server.nix` 与 server `disko` 声明不存在；
- Ubuntu 没有 standalone Home Manager output；
- capability matrix 只记录 server 的目标能力边界，没有把 GUI、工作站可变开发运行时、GitHub 协作凭据或跨设备 Atuin 同步组合到 server。

因此当前仓库没有提前实施 Phase 8，也没有需要在 Phase 7 回滚的越界 server 配置。

2026-07-30 又基于一手资料与新增只读硬件证据完成 [`Phase 7 server migration practice research`](../plans/phase-7-server-migration-practice-research.md)。调研推荐从现有 Ubuntu 经 `nixos-anywhere` kexec 直接安装，以 nixbox local build/push、BIOS GPT/disko、static networkd、双管理 key、临时 key-only root break-glass、保留现有 SSH host identity 和 Contabo VNC → Rescue → Reinstall 逐级恢复作为 Phase 8–10 基线；这些仍是待维护者确认的设计，不是生产执行授权。

## 6. 已执行的只读采集

实际命令通过 macbook 的现有 SSH alias 执行；下面以 `<server-alias>` 隐去本地连接名称：

```text
ssh -o BatchMode=yes -o ConnectTimeout=8 <server-alias> true
command -v tar
command -v setsid
stat -c <authorized-keys-mode-and-owner> /root/.ssh/authorized_keys
systemd-detect-virt
test -d /sys/firmware/efi
free -b
grep <kexec-and-virtio-options> /boot/config-<running-kernel>
cat /proc/sys/kernel/kexec_load_disabled
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL -e 7
find -L /dev/disk/by-id /dev/disk/by-path -samefile /dev/sda
readlink -f /sys/class/block/sda/device/driver
lspci -nnk
findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS --target <system-mount>
readlink -f /sys/class/net/eth0/device/driver
udevadm info --query=property --path=/sys/class/net/eth0
ip -4 route show default
ip -6 route show default
ip -brief address show dev eth0
ip -4 route show
ip -6 route show
resolvectl dns eth0
resolvectl domain eth0
ssh -o BatchMode=yes -o ConnectTimeout=8 <nixbox-alias> true
ssh <nixbox-alias> "ssh-keygen -F <server-address> -f ~/.ssh/known_hosts"
ssh <nixbox-alias> "nc -z -w 5 <server-address> 22"
sshd -T
ufw status
systemctl list-units --failed --no-legend --no-pager
systemctl list-unit-files --state=enabled --no-legend --no-pager
ss -H -lntu
docker version
docker ps
docker compose ls
docker volume ls
docker network ls
docker inspect <running-container>
```

采集脚本只输出必要字段；network address、gateway、DNS value、SSH key、容器 path、环境变量与 secret 均未进入仓库。Docker inspect 只提取 Compose project 和 mount 类型，没有读取 mount source 或环境变量。

## 7. Phase 8 前的剩余关卡

Provider 控制面、静态网络私有输入与 macbook 的 Clash 直连恢复说明已完成。以下项目仍需在 Phase 8 实现或正式替换前关闭：

1. Phase 8 必须由维护者确认正式管理用户、macbook maintenance public key、nixbox 专用 deploy key、passwordless sudo 与首次 key-only root break-glass 设计；不能只依赖当前 Ubuntu root 登录行为；
2. 维护者已说明 public IP 本身不构成顾虑，但 Issue #13 仍禁止 IP 进入 Git。进入 Phase 8 前必须明确批准 public route facts 入库，或先通过 ADR 建立版本化 private flake input；不得使用 untracked/impure 现场注入；
3. nixbox → server 的 TCP 22 已可达，但仍需经 macbook 可信路径 pin host identity 并建立专用 SSH authentication/deployment key；本阶段不接受 host key、不创建 key 或修改 SSH；
4. 当前无 host identity 泄露证据。调研推荐首次安装保留现有 SSH host keys，以减少首启访问变量；该策略和 Issue #13 的“新 host key”措辞仍需维护者确认；
5. stable disk alias 已指向唯一 `/dev/sda`，但任何真实格式化/安装 Issue 仍须再次给出 alias、底层 device、容量与 exact command，并取得当次批准；当前“数据可全部丢失”不是格式化授权；
6. roadmap 与 Issue #13 仍把备份/恢复测试列为强制条件，必须在 Phase 10 前改成维护者已记录的数据丢失 waiver 与“重新建立最小 NixOS”的失败恢复目标；
7. 正式替换 runbook 必须把 VNC → Rescue → Reinstall 的升级顺序与每一步的实时人工批准写清楚，且不得保存临时 VNC/Rescue 密码。

备份、异机副本、恢复测试、现有业务恢复和停机窗口不再是未知 blocker：维护者已明确接受无备份、全量数据丢失、无限停机且不恢复现有业务。该 waiver 只缩小数据恢复范围，不放宽 disk、boot、network、SSH 与 provider rescue 关卡。

## 8. 当前结论

- Phase 7 已取得当前 OS、虚拟化、boot、disk、network model、SSH、firewall、service、port、container 与 data ownership 的实时只读证据；
- macbook → server 的 OpenSSH 与 Termius 链路已修复并验证；
- server 仍未发生配置、服务、package、disk、boot、network、firewall、SSH 或 reboot 变更；
- 当前实例的 provider 控制面与静态双栈网络私有输入已完成实证；
- 当前实机满足 `nixos-anywhere` 的架构、RAM 与 kexec 基本条件，并已有 stable disk identity、Virtio storage/network driver 证据；
- Phase 8 仍需由维护者确认 public route facts、SSH key/用户/root recovery、host identity 与 waiver 对齐，并建立 nixbox 的 host-key/authentication 部署链路；真实 target disk 操作继续保留当次批准关卡；
- 本文是 inventory，不声称 NixOS build、VM install 或 production replacement 已通过。
