# Server 从 Ubuntu 替换为最小 NixOS：关卡与失联恢复

> 本 runbook 贯穿 Phase 8–10。Phase 8 只产出声明与 build 证据，Phase 9 只在隔离 VM 执行安装测试。只有 Phase 10 Issue 列出精确 host、disk、commit、短命令、窗口和恢复步骤并取得新的明确批准后，才可触碰 production server。

## 1. 不变目标与停止条件

唯一强制的 production 结果是：替换完成后，维护者仍能从 macbook 通过 SSH 取得 server 控制权。当前 Ubuntu 的系统、服务与数据允许全部丢失；不做 backup、dump、restore test，也不恢复旧业务。这个 waiver 不授权任何磁盘、boot、network、SSH、Contabo 或电源动作。

满足任一条件都立即停止，不进入或不中途继续 destructive step：

- 当前 disk alias、唯一性、容量或底层 device 与冻结证据不一致；
- firmware 不再是 BIOS，或 Virtio SCSI / `virtio_net` 拓扑变化；
- public address、prefix、gateway、DNS 或 IPv6 on-link 语义变化；
- macbook 或 nixbox 的 strict host pin/SSH 路径失败；
- VNC 尚未实际连接，Rescue/Reinstall 入口不可确认；
- VM 首启、二次重启、双栈网络、SSH、sudo 或 firewall 测试未通过；
- 待执行 commit、closure、短 entry command 或现场批准与 Issue 记录不一致。

## 2. 资料边界

Git 中允许存在：public routing facts、stable disk alias、public keys、声明、VM 输入、检查项和脱敏结果。

Git、Issue、PR、聊天与 Nix Store 中禁止存在：private key、passphrase、SSH host private key、未公开 fingerprint、Contabo/VNC/Rescue credential、account/endpoint 标识或 production secret。它们只在 mode `0600` 的本地私密记录、客户端受限文件和现场 UI 中处理。

不要要求维护者手抄 hash、store path、public key、fingerprint 或长参数。Phase 9 应生成并验证一个窄作用域 helper；Phase 10 只暴露 `preflight` 与 `install` 两个短入口。helper 固定目标和参数、默认拒绝漂移，现场结束后删除临时副本。

## 3. Phase 8：只构建，不执行

Phase 8 的完成条件：

1. `server` output 的 disk、boot、network、SSH、sudo、firewall 与 capability 全部可追溯到 Phase 7 证据；
2. nixbox 专用 deploy private key 只留在 nixbox，Git 只有 public half；
3. macbook 的既有可信 host pin 已通过受信链路复制到 nixbox 的专用 known-hosts file，记录摘要一致；
4. `nix fmt -- --check .` 与 `nix flake check` 通过；
5. nixbox 原生 evaluate/build server closure 通过；
6. production Ubuntu、Contabo 控制面和 server SSH 均未被本阶段操作。

Phase 8 build 只证明 closure 可构建，不证明真实 disk 可以清空、真实网络可达或允许安装。

## 4. Phase 9：隔离 VM 演练

Phase 9 使用 [`Phase 8 inventory`](../inventory/phase-8-server-minimal.md#4-phase-9-隔离-vm-输入) 中的 dummy topology；设计、版本与结果记录在 [`Phase 9 隔离 VM 安装演练`](../inventory/phase-9-server-vm-test.md)。nixbox 只需在 clean checkout 运行不接受额外参数的短入口：

```text
nix run .#phase9-test
```

该入口先拒绝错误 architecture、不可用 KVM、dirty tree、空间不足与任何 target 参数，再依次覆盖：

1. preflight 对一张 `virtio_net` NIC 与测试 stable disk 成功，对第二张同 driver NIC 或 alias 漂移明确失败；
2. nixos-anywhere 在测试 disk 上完成 BIOS/GPT/EF02/ext4 安装；
3. QEMU serial/test console 可观察 boot 与 login target，并在 preflight 拒绝后保持恢复路径；
4. `sayori` key login、`sudo -n true`、key-only root break-glass 成功；password 与 keyboard-interactive 失败；
5. dummy IPv4/IPv6、link-local gateway、DNS、TCP 22 和 firewall 符合声明；
6. 首次启动和一次独立的第二次重启后重复全部关键验收；
7. installer 不依赖 destination DNS/substitute；最终 server 不依赖 GitHub checkout；
8. 记录 Phase 10 helper contract、参数清单和失败注入结果，但不生成可连接 production 的入口，也不连接 production target。

upstream `nixos-anywhere --vm-test` 只构建并运行 `system.build.installTest`，不进入 remote `--copy-host-keys` 路径。Phase 9 因此用独立的一次性 VM 模拟 copy 后的 strict host identity 与 reboot persistence；真实 copy 仍是 Phase 10 人工关卡，不得把模拟结果写成 production 已验证。

Phase 9 的 ephemeral key、host key、disk image、network namespace 与临时 helper 不提交 Git。清理只针对测试创建并在执行前解析确认的临时路径。`phase9-test` 不能复用于 production；Phase 10 的 `preflight` 与 `install` 必须另行冻结并重新批准。

## 5. Phase 10：现场顺序

下面是顺序约束，不是当前执行授权，也不包含可直接运行的 destructive command。

### A. 冻结与批准

1. 在 nixbox checkout 精确已审阅 commit，验证 clean tree 与 flake lock；
2. 原生重跑 evaluate、build 与 Phase 9 VM suite，记录 closure 与结果；
3. 运行只读 `preflight` 短入口，逐项比较 host、architecture、BIOS、disk、NIC、network、RAM、kexec、SSH host identity；
4. macbook 与 nixbox 各自以严格 host checking 验证当前可信 SSH 路径；
5. 实际连接 Contabo VNC，并确认 Rescue/Reinstall 入口；
6. 在 Issue #13 记录精确 host、stable disk alias、commit、短 install command、窗口、观察人、停止条件和全量数据丢失 waiver；
7. 维护者对该次动作明确批准。任何上一轮或设计批准都不能代替。

### B. 安装

1. macbook 保持 VNC 与独立 SSH 观察，不作为构建来源；
2. nixbox 运行已通过 VM 的短 `install` 入口；
3. helper 必须固定 local build/push、destination 不 substitute、strict host pin、专用 deploy identity、精确 flake output 与保留现有 SSH host keys；
4. 从 kexec 开始到最终 NixOS SSH 验收完成，不恢复业务、不开放额外端口、不现场顺带加固；
5. 任一 preflight 复核失败都在破坏动作前退出。

### C. 首次启动验收

按以下顺序记录结果：

1. VNC：GRUB、kernel、root mount 与 multi-user target；
2. macbook：`sayori` public-key login 与 `sudo -n true`；
3. nixbox：专用 deploy key 登录 `sayori`，并读取当前 system generation/closure；
4. macbook：key-only root break-glass；
5. guest：唯一 NIC、IPv4/IPv6 address、双默认 route、DNS、sshd effective policy 与 firewall；
6. 外部：只预期 TCP 22 可达，没有 HTTP、Docker 或旧业务 listener。

### D. 二次启动

首次验收不自动授权 reboot。维护者另行批准一次 reboot 后，通过 VNC 观察，并重复 macbook SSH、nixbox SSH、sudo、network、mount、DNS、sshd 与 firewall 验收。两轮全部通过前保留 root break-glass；关闭 root SSH 必须另建窄 Issue 并取得批准。

### E. closure copy 中断后的定向恢复

本节不是通用重试授权，只适用于 Issue #13 已记录的这一次现场：`kexec` 与 `disko` 已成功，正式 system closure 的复制中断，但 SSH host-key copy、`nixos-install` 和第一次 reboot 尚未开始。进入恢复前，新的只读 installer preflight 必须同时确认：

- VNC 仍停在预期的 temporary NixOS installer，SSH recovery path 可用；
- firmware、虚拟化、唯一 stable disk、容量、NIC 与冻结的 network facts 均未漂移；
- temporary installer 的 DNS 解析实际可用；installer 可使用 systemd-resolved global fallback，不要求其临时 link-scoped resolver 与最终 NixOS 的 static provider DNS 相同；
- 目标 ext4 已按审阅布局挂载到 `/mnt`，且没有意外的额外挂载或目标 SSH host-key partial state；
- 待安装 system 仍是原安装行动卡冻结的 `0ba710e…` 输出，而不是恢复 helper 所在分支的较新 server output；
- 现场证据仍能证明失败只发生在 closure copy，未进入 host-key copy、`nixos-install` 或 reboot。

任一事实无法证明或不一致时立即停止，不把本节当成猜测现场状态的依据。证据全部成立后，恢复顺序固定为：

1. 在 nixbox clean checkout 运行本地入口 `phase10-install-resume-plan`；该入口必须报告 `production-contact=no`，展示 helper commit、冻结输出、固定 phases 与脱敏后的连接策略，但不得连接 production；
2. 在 Issue #13 发布一张新的恢复行动卡，绑定本次 helper commit、原冻结输出、目标、观察窗口、停止条件与唯一短入口；首次安装的批准已经耗尽，不能继承；
3. 维护者审阅行动卡，并对这一次恢复给出新的明确批准；没有该批准，不运行 production 入口；
4. 批准后由维护者在 Ghostty 中保持一个前台、可见、不中断的真实 TTY，经 nixbox 运行 `phase10-install-resume`，并在再次核对 plan 后亲自输入 `RESUME`；
5. helper 先运行上述只读 installer preflight，随后只允许固定的 `install,reboot` phases：复用已完整复制的 store objects，继续复制同一冻结 closure，复制既有 SSH host keys，执行 `nixos-install`，再进行该行动卡包含的第一次 reboot；
6. reboot 后回到本 runbook 的“首次启动验收”；任何失败都停止并重新形成证据与行动卡。

恢复 helper 必须继续使用 local build/push、destination 不 substitute、strict host pin、专用 identity 与 fail-closed 参数检查。严禁重跑 `kexec` 或 `disko`，严禁手工清理 partial Nix store，严禁自动重试循环，也不得在 VS Code terminal、`tmux`、后台任务或无人值守会话中运行。若 Ghostty、VNC、SSH 或维护者现场监督中断，保持 installer 现场并停止；Rescue、Reinstall、额外 reboot、网络或 SSH 改写仍分别需要新的行动卡与批准。

恢复阶段放宽的是 temporary installer 的 DNS scope 判定，不是最终 server 配置：冻结的 NixOS 仍声明 provider static DNS，首启与二次启动都必须验证解析结果。由于恢复入口固定 local build/push 并禁止 destination substitute，installer DNS 不参与 closure 下载。

## 6. 失联恢复阶梯

| 失败阶段 | 首选恢复 | 下一层 | 禁止的捷径 |
| --- | --- | --- | --- |
| kexec 前发现漂移 | 停止窗口，保留 Ubuntu | 回到 Phase 8/9 更新证据与 VM test | 不先 format 再修配置 |
| kexec 后 temporary installer SSH 不通 | 从 VNC 观察 boot/network 与等待状态 | 经批准启动 Rescue | 不关闭 host-key check，不开放 password root |
| 安装后 GRUB/kernel/root mount 失败 | VNC 记录完整错误 | Rescue 挂载并按冻结 closure 修复，或重跑已验证安装 | 不猜 UEFI，不恢复旧分区布局 |
| NixOS 启动但无网络 | VNC 核对 unit、NIC 与 route | Rescue 复核 provider facts，修订后重新部署/安装 | 不切 DHCP，不盲改 IP/DNS |
| 网络通但 SSH 失败 | VNC/Rescue 核对 authorized keys、sshd 与 firewall | 从冻结声明恢复 key-only root break-glass | 不复制 private key，不临时开放额外端口 |
| 最小 NixOS 无法修复 | Rescue 重装同一已验证 closure | Contabo Reinstall/Custom Image 最后重建 | 不承诺恢复 Ubuntu、容器或数据库 |

这里的“恢复”只表示重新建立可从 macbook SSH 管理的最小 NixOS。若 provider 重建导致 IP、disk、firmware、NIC 或 host identity 改变，必须重新经过 evidence → declaration → VM test → exact approval，而不是套用旧 closure。

## 7. 最终记录

每次 Phase 9/10 演练或执行都记录：精确 commit、flake lock、closure、命令入口版本、开始/结束时间、每项验收、偏差、停止/升级决定和临时 artifact 清理结果。公开记录只保留脱敏结论；敏感 credential、fingerprint 与 endpoint 留在本地私密记录。
