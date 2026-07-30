# Phase 7 Server 迁移前置盘点

本文记录 Issue #9 的脱敏证据、维护者决策、未知事实与 Phase 8 阻塞项。当前阶段只盘点 Ubuntu source state，不建立 `nixosConfigurations.server`、standalone Home Manager、`disko` 或生产服务声明，也不修改 server。

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
| 角色 / provider | 逻辑 output 为 `server`；Contabo KVM 虚拟服务器；当前 Ubuntu，目标 Headless NixOS | provider 已确认；实际控制面入口仍需维护者在面板验证 |
| OS / 架构 | Ubuntu 24.04.3 LTS、`x86_64`、Linux 6.8.0-90-generic；未安装 Nix | 已实时确认 |
| 当前用户 | SSH alias 使用 `root`；UID 0、home `/root`、shell `/bin/bash` | 只记录 source state；未来 NixOS 管理用户不从 root 模型推断 |
| boot | 运行态未暴露 EFI firmware，记录为 BIOS；`grub-pc` 已安装；磁盘仍有已挂载的 vfat `/boot/efi`，并存在 EFI 相关 package | 当前启动证据指向 BIOS；EFI 分区可能是镜像残留，Phase 8 不得据其猜 UEFI |
| disk / filesystem | 唯一可写虚拟磁盘 `/dev/sda`，约 75 GiB；ext4 `/`、独立 ext4 `/boot`、vfat `/boot/efi`；另有只读虚拟光驱 | `/dev/sda` 是唯一 target 候选；维护者接受其内容全部丢失，但正式 target 批准留到安装 Issue |
| 容量 | `/` 约 72 GiB，盘点时使用约 38%；`/boot` 与 `/boot/efi` 均有充足剩余空间 | 只作 source-state 摘要，不形成未来分区设计 |
| network | `eth0` 同时承载 IPv4/IPv6 默认路由，均为静态模型；systemd-networkd、cloud-init Netplan 与 systemd-resolved 参与配置 | 地址、prefix、gateway、route 和 DNS 的精确值须作为私有 Phase 8 输入重新采集，不能提交公开仓库 |
| SSH | `ssh.socket` 与 `ssh.service` active；public-key 登录实时成功；当前还允许 root 与密码认证，keyboard-interactive 已关闭 | 当前 macbook 管理链路已验证；未来最小 NixOS 不应无意复制宽松 source policy |
| firewall | UFW unit 虽 enabled，但 `ufw status` 为 inactive，运行态规则数为 0 | 撤回 Phase 1 的“UFW 已启用”摘要；Phase 8 必须显式设计最小 firewall，不能假定已有保护 |
| 健康 | `cloud-init.service`、`nginx.service` 与 `systemd-networkd-wait-online.service` failed；cloud-init 总状态为 error | 3 个 failed units 已实时确认；现有业务不要求修复或迁移 |
| service / ports | Docker、containerd 与 1Panel active；PM2 root unit inactive；SSH、DNS、HTTP/HTTPS 与若干高位 TCP 端口监听 | 只用于确认将被清除的 source workload；高位端口不在公开 inventory 展开 |
| containers / data | 7 个运行容器，包括应用栈、MongoDB 7、Redis、反向代理/控制面；4 个 Docker volumes，并存在 bind mounts | 服务和数据全部按维护者决策舍弃；不读取或迁移 volume、bind path、database、`.env` 与 secret |
| lifecycle | 系统报告 55 个可用更新并要求重启 | Phase 7 不执行 apt upgrade、服务 restart 或 reboot |

## 3. macbook → server 管理链路

最初的失败信号为：TCP 22 可建立，但 SSH 在取得 server banner 前被关闭。到 server 的路由当时进入 Clash Verge TUN 的 GVisor 虚拟接口。

2026-07-30 完成同条件 A/B：

| 状态 | 本机路由 | SSH 结果 |
| --- | --- | --- |
| TUN 开启、未排除 server | Clash TUN 虚拟接口 | TCP 成功；banner 前关闭；SSH status 255 |
| TUN 关闭 | macbook 物理网络接口 | host key 与 OpenSSH banner 成功；public-key 认证成功；SSH status 0 |
| TUN 恢复、未排除 server | Clash TUN 虚拟接口 | 原失败稳定复现 |

经维护者针对当前动作明确批准，已在 Clash Verge TUN 的“排除自定义网段”中加入 server IPv4 的单一 `/32`。保存后 TUN 继续开启，但 server 路由改走 macbook 物理接口；普通 OpenSSH 和 Termius 均已实际登录成功。

该 `/32` 是 macbook 上 Clash Verge 的可变本地状态，不由 nix-config 声明。macbook 重装或 Clash 状态重置后，必须先恢复这一窄排除，或使用另一条经验证的直连路径，才能把 macbook 视为独立 server recovery path。仓库不记录实际地址。

## 4. Contabo 恢复能力

Contabo 当前官方文档给出以下 provider 能力：

- [Customer Panel 重装](https://help.contabo.com/en/support/solutions/articles/103000271913-how-do-i-install-my-contabo-server-)会永久删除现有数据，并要求设置系统密码；Linux 产品/面板还可能支持保存 SSH public key；
- [Rescue System](https://help.contabo.com/en/support/solutions/articles/103000295053-how-do-i-boot-a-rescue-system-for-my-server-)适用于 VPS、VDS 与 Dedicated Server，可从 Customer Control Panel 启动并通过独立 root password 在 TCP 22 登录；
- [VNC](https://help.contabo.com/en/support/solutions/articles/103000407800-how-to-connect-to-your-server-using-vnc)可以在 guest 网络或系统启动异常时提供显示控制，但需先在面板启用、取得动态凭据并使用第三方 VNC client；启用本身需要 reboot；
- Contabo 的[产品变更说明](https://help.contabo.com/en/support/solutions/articles/103000269700-how-to-make-changes-to-your-vps-or-vds-plan)称普通重装保持 IP 不变，但正式迁移仍须以维护者面板中当前 server 的实际选项为准。

这些文档证明 provider 提供救援机制，不证明维护者当前账号已能看到并使用对应入口。Phase 8 前仍需维护者只读确认 Customer Panel 中该实例具备 Reinstall、Rescue System，以及适用时的 VNC/Control 入口；本阶段不点击、不启用、不 reboot。

## 5. 仓库实现审计

2026-07-30 对 `flake.nix`、`hosts/`、`modules/` 与相关文档的只读搜索确认：

- `flake.nix` 当前只暴露 `darwinConfigurations.macbook` 与 `nixosConfigurations.nixbox`；
- `hosts/server/` 不存在；
- `modules/nixos/server.nix` 与 server `disko` 声明不存在；
- Ubuntu 没有 standalone Home Manager output；
- capability matrix 只记录 server 的目标能力边界，没有把 GUI、工作站可变开发运行时、GitHub 协作凭据或跨设备 Atuin 同步组合到 server。

因此当前仓库没有提前实施 Phase 8，也没有需要在 Phase 7 回滚的越界 server 配置。

## 6. 已执行的只读采集

实际命令通过 macbook 的现有 SSH alias 执行；下面以 `<server-alias>` 隐去本地连接名称：

```text
ssh -o BatchMode=yes -o ConnectTimeout=8 <server-alias> true
systemd-detect-virt
test -d /sys/firmware/efi
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL -e 7
findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS --target <system-mount>
ip -4 route show default
ip -6 route show default
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

## 7. Phase 8 blockers

以下项目未完成前，Issue #11 必须保持 blocked：

1. 维护者在 Contabo Customer Panel 中确认当前实例的 Reinstall、Rescue System 与可用的 console/VNC 入口，并记录在失去 SSH 后重新取得控制权的最短顺序；
2. 以私有证据保存静态 IPv4/IPv6 的 address、prefix、gateway、route 与 DNS 模型，再为公开仓库提炼不泄露地址的 host 配置输入；
3. 明确正式替换使用的 SSH public key、首次登录用户与 root/sudo 恢复路径；不能只依赖当前 Ubuntu root 登录行为；
4. 明确 `/dev/sda` 为后续安装动作的精确 destructive target，并在对应 Issue 中再次批准；当前“数据可全部丢失”不是格式化授权；
5. 验证 nixbox → server 的只读 SSH 可达性或明确建立该链路所缺的认证步骤；本阶段不创建 key 或修改 SSH；
6. 为 macbook 重装/Clash 状态丢失准备 server `/32` 直连排除的恢复说明，避免唯一管理链路再次被 TUN 截断。

备份、异机副本、恢复测试、现有业务恢复和停机窗口不再是未知 blocker：维护者已明确接受无备份、全量数据丢失、无限停机且不恢复现有业务。该 waiver 只缩小数据恢复范围，不放宽 disk、boot、network、SSH 与 provider rescue 关卡。

## 8. 当前结论

- Phase 7 已取得当前 OS、虚拟化、boot、disk、network model、SSH、firewall、service、port、container 与 data ownership 的实时只读证据；
- macbook → server 的 OpenSSH 与 Termius 链路已修复并验证；
- server 仍未发生配置、服务、package、disk、boot、network、firewall、SSH 或 reboot 变更；
- Phase 8 继续被 provider 面板实证、静态网络私有参数、正式 SSH 恢复设计、target disk 当次批准与 nixbox 链路阻塞；
- 本文是 inventory，不声称 NixOS build、VM install 或 production replacement 已通过。
