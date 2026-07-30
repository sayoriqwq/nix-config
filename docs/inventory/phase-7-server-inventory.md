# Phase 7 Server 迁移前置盘点

本文记录 Issue #9 的脱敏证据、未知事实与 Phase 8 阻塞项。当前阶段只盘点 Ubuntu source state，不建立 `nixosConfigurations.server`、standalone Home Manager、`disko` 或生产服务声明，也不修改 server。

## 1. 证据边界

- 2026-07-30 已完成仓库、Issue #9、架构文档、ADR 与迁移路线图审查。
- 目前主机事实只来自 2026-07-20 的 Phase 1 脱敏盘点；除非另有采集日期，本文不把这些旧证据表述为当前实时状态。
- 原始命令输出不进入仓库。公网地址、私有地址、MAC、账号 ID、序列号、私有主机名、完整 SSH key、业务路径、域名与 secret 必须在本地检查和脱敏。
- `UNKNOWN` 表示当前没有足够证据，不能根据云主机惯例、现有挂载、服务名称或配置一致性推断。
- 本阶段不授权 `sudo`、敏感文件读取、provider console 操作、备份生成、恢复测试、服务变更、安装、重启或其他生产变更。

## 2. 仓库已有证据

| 类别 | 已有脱敏事实 | 证据日期与来源 | 当前判定 |
| --- | --- | --- | --- |
| 角色 | 逻辑 output 为 `server`；当前是 Ubuntu Server，目标是 Headless NixOS | 2026-07-20，[Phase 1 主机盘点](phase-1-hosts.md#ubuntu-server) | 已确认目标角色；实时状态待复核 |
| OS / 架构 | Ubuntu 24.04.3 LTS、`x86_64-linux`、Linux 6.8.0-90-generic；未安装 Nix | 2026-07-20，[Phase 1 主机盘点](phase-1-hosts.md#ubuntu-server) | 旧证据，待只读复核 |
| 当前用户 | 当前管理用户为 `root`，home 为 `/root`，shell 为 `/bin/bash` | 2026-07-20，[Phase 1 主机盘点](phase-1-hosts.md#ubuntu-server) | 旧证据；未来 NixOS 管理用户不得据此推断 |
| 启动 | 运行中的内核未暴露 `/sys/firmware/efi`，但存在已挂载的 vfat `/boot/efi` | 2026-07-20，[Phase 1 主机盘点](phase-1-hosts.md#ubuntu-server) | 证据存在冲突；provider 启动模型必须重新核对 |
| 存储摘要 | 一块约 75 GB QEMU 虚拟磁盘；ext4 `/`、独立 ext4 `/boot`、vfat `/boot/efi` | 2026-07-20，[Phase 1 主机盘点](phase-1-hosts.md#ubuntu-server) | 仅摘要；不是 target disk 或可清空证明 |
| 服务摘要 | Docker 与 containerd 已启用；Docker 29.1.5、Compose v5.0.1；UFW 已启用 | 2026-07-20，[Phase 1 主机盘点](phase-1-hosts.md#ubuntu-server) | 旧证据；服务、容器和规则明细未知 |
| SSH 摘要 | `ssh.socket` 已启用且 active，`ssh.service` 由 socket 激活；macbook 当时可通过既有 SSH alias 登录 | 2026-07-20，[Phase 1 主机盘点](phase-1-hosts.md#ubuntu-server) | 只证明当时 macbook 链路；不证明恢复路径或 nixbox 链路 |
| 健康摘要 | 当时存在 3 个 failed systemd units | 2026-07-20，[Phase 1 主机盘点](phase-1-hosts.md#ubuntu-server) | 单元身份、影响与当前状态未知 |
| 控制面设计 | nixbox 负责主要 `x86_64-linux` closure 构建/验证/推送；macbook 保留独立 SSH 管理与救援路径；server 不保存 GitHub 协作凭据 | [ADR-0008](../adr/0008-direct-nixos-server-replacement.md)、[迁移路线图](../plans/migration-roadmap.md#5-控制链路与部署方向) | 已接受的目标设计，不等同于链路已验证 |

## 3. 仓库实现审计

2026-07-30 对 `flake.nix`、`hosts/`、`modules/` 与相关文档的只读搜索确认：

- `flake.nix` 当前只暴露 `darwinConfigurations.macbook` 与 `nixosConfigurations.nixbox`；
- `hosts/server/` 不存在；
- `modules/nixos/server.nix` 与 server `disko` 声明不存在；
- Ubuntu 没有 standalone Home Manager output；
- 现有 capability matrix 只记录 server 的目标能力边界，没有把 GUI、工作站可变开发运行时、GitHub 协作凭据或跨设备 Atuin 同步组合到 server。

因此当前仓库没有提前实施 Phase 8，也没有发现需要在 Phase 7 回滚的越界 server 配置。

## 4. 待采证据矩阵

| 类别 | 当前状态 | 需要的最小脱敏证据 | 采集边界 |
| --- | --- | --- | --- |
| provider / 虚拟化 | `UNKNOWN`；只有 QEMU 磁盘摘要 | provider 类型；虚拟化模型；console/rescue/VNC、snapshot、重装入口是否可用 | provider console 与账号界面需新的明确批准；不记录账号 ID |
| boot | BIOS 与 `/boot/efi` 证据冲突 | 实际 firmware boot mode、provider 启动要求、bootloader 与分区用途 | 先用无修改的运行态证据；任何 boot 变更禁止 |
| disk / filesystem | 只有容量和挂载摘要 | 精确 block topology、分区、filesystem、mount、容量；哪块磁盘是候选 target | `sudo lsblk` 需要新批准；没有明确 target 前不得写 `disko` |
| network / DNS / firewall | `UNKNOWN`；只知道 UFW 已启用 | 地址获取模型、接口、route、DNS 来源、外部入口、UFW/上游 firewall 所有权 | 输出先本地脱敏；不得修改网络、DNS 或规则 |
| SSH / sudo / recovery | macbook 旧链路存在 | daemon 生效配置来源、认证方式、authorized key 所有权、sudo 模型、长期管理用户、独立恢复路径 | 不读取私钥或完整 key；敏感配置与 `sudo` 需新批准 |
| systemd / ports | 旧证据有 3 个 failed units | enabled services、timers、failed units、监听端口、每项业务影响 | 端口、域名、地址和业务路径脱敏；不重启服务 |
| containers / databases | 只有 Docker/Compose 版本摘要 | 容器与 Compose project、image tag、health、database 类型/版本、依赖 | 不读取 `.env`、secret value、dump 内容或完整敏感配置 |
| data / configuration | `UNKNOWN` | data directory、volume/bind mount、稳定配置来源、secret 来源类型、owner、恢复顺序 | 只记录存在、类别和所有权；不复制生产数据或 secret |
| backup / restore | `UNKNOWN` | 独立备份位置类别、最近成功时间、校验方法、异机副本、至少一次隔离恢复测试及结果 | 备份生成和恢复测试均需新批准；“有备份”不等于“可恢复” |
| snapshot / rollback | `UNKNOWN` | provider snapshot 能力、保留边界、失败时回滚与 rescue 顺序 | snapshot 操作需新批准；不能把 snapshot 当作唯一备份 |
| macbook → server | 仅有 2026-07-20 成功摘要 | 当前 key-only 只读连通性、链路 owner、nixbox 不可用时的恢复职责 | 不读取 SSH 私钥或把 alias/address 写入仓库 |
| nixbox → server | `UNKNOWN` | 当前只读连通性或明确缺口；未来 closure copy 所需的认证边界 | 本阶段不配置 key、SSH daemon 或部署工具 |
| 维护窗口 / 验收 | `UNKNOWN` | 可接受停机、期望窗口、RPO/RTO、系统与业务验收责任人 | 只记录非敏感决策；正式动作留在后续 Issue |
| server CLI 能力 | 目标矩阵已定义 | 维护者确认最小编辑/救援工具是否需要补充 | 明确无 GUI、无 GitHub 协作凭据、无跨设备 Atuin 同步 |

## 5. Phase 8 blockers

以下任一项没有可追溯证据时，Issue #11 必须保持 blocked：

1. provider console/rescue 与失败后重新取得控制权的路径；
2. target disk、精确分区/文件系统、boot mode 与 provider 启动要求；
3. network model、DNS 来源、外部入口、firewall 所有权与 SSH recovery；
4. 独立备份、异机副本、校验结果和至少一次隔离恢复测试；
5. production service、container、database、data path、secret source 与恢复顺序；
6. macbook 独立管理链路和 nixbox 构建/部署链路的职责与可达性；
7. 维护窗口、停机容忍度、RPO/RTO 与系统/业务验收责任。

即使所有 blocker 都解除，Phase 7 也不授权编写或运行安装、磁盘、boot、network、firewall、SSH、reboot 或 production restore 动作。

## 6. 后续只读采集原则

- 优先使用不需要 `sudo` 且不会读取敏感文件的命令；需要权限提升的项目单独列出并等待维护者当次批准。
- 先在执行端保存原始输出并人工检查，再只把脱敏结论写入本文；不要求维护者手打 hash、store path、密钥或长参数。
- 若一批命令无法保持短入口，应使用经过审阅的临时 helper，由维护者以短命令执行并在采集后删除；helper 不修改系统。
- 实际采集时记录日期、执行端、命令类别、脱敏结果与仍未知事实；不把旧证据伪装为实时验证。
- 备份位置、数据目录或 secret 来源只记录抽象类别与责任边界，不记录可用于访问生产系统的值。
