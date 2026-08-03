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
3. 在 macbook 的 clean checkout 对精确 commit 运行不接受参数的短入口 `nix run .#phase10-preflight`；它固定 `ssh sayori`、物理直连路由与 strict host pin，并逐项比较 host、architecture、BIOS、disk、NIC、network、RAM、kexec、SSH bootstrap 与近期 kernel health；
4. macbook 与 nixbox 各自以严格 host checking 验证当前可信 SSH 路径；
5. 实际连接 Contabo VNC，并确认 Rescue/Reinstall 入口；
6. 在 Issue #13 记录精确 host、stable disk alias、commit、短 install command、窗口、观察人、停止条件和全量数据丢失 waiver；
7. 维护者对该次动作明确批准。任何上一轮或设计批准都不能代替。

`phase10-preflight` 的 expected disk 与 routing facts 直接从同一 commit 的 `nixosConfigurations.server` 派生，远端 probe 只经 stdin 执行，不创建文件。它会输出 exact disk device/capacity 和脱敏事实；不输出 key、fingerprint、credential、private path 或原始 journal。helper 的实现与实时记录见 [`Phase 10 正式替换现场记录`](../inventory/phase-10-server-replacement.md)。

#### 当前 Ubuntu 到 nixbox 的 bootstrap authentication

Phase 8 的 nixbox deploy public key 只存在于未来 NixOS 声明；Phase 10 开始时，当前 Ubuntu 尚未授权它。因而 macbook preflight 之后还必须先关闭这项真实缺口，不能直接声称 nixbox 已能安装。当前实例已按单独批准临时关闭该缺口，精确 commit 与验证结果见现场记录。

选定方案是在单独行动卡和批准下，由可信 macbook root 会话把已声明的 nixbox deploy public key 原子、幂等地追加到当前 Ubuntu root `authorized_keys`。不得删除现有 macbook key、复制任何 private key、关闭 strict checking 或改用 password root。若正式安装前中止，使用另一次批准移除该单行；最终 NixOS 的声明式 root key 集合仍只保留 macbook break-glass。

这个临时授权是 production SSH access 修改，不由 VNC、preflight、Phase 8/9 或本文自动批准。完成后，nixbox 还必须使用专用 deploy identity 与专用 known-hosts file 做一次 strict、只读登录验证，才允许冻结 install helper。

该动作只暴露两个不接受参数的短入口：

```text
nix run .#phase10-bootstrap-nixbox
nix run .#phase10-rollback-nixbox-bootstrap
```

add 与 rollback 都先自动重跑 production preflight。底层 SSH 强制 system SSH、声明式 host、root/22、无 forwarding/proxy/jump/connection sharing 与 strict host checking；远端命令只发送 `bash -s`，action 与从同一 NixOS configuration 派生的两把 public key 经 shell escaping 固化在 stdin 脚本内部，避免 OpenSSH 重组远端参数时拆分 key。它在任何写入前验证 root SSH 目录/文件不是 symlink、权限 owner 正确、macbook key 精确保留且 deploy key 无重复或 metadata 漂移，再通过同目录临时文件、候选解析与原子 rename 更新。两种 action 均幂等；rollback 只移除精确 deploy key，但仍必须单独批准。

production 前必须在 nixbox 运行隔离的 `checks.x86_64-linux.phase10-nixbox-bootstrap`，覆盖正常 add/rollback、幂等性以及 duplicate、metadata drift、unsafe mode、symlink 失败注入。测试通过只证明文件更新算法，不授权 production 修改；当前实例的精确 commit 与结果记录在 [`Phase 10 正式替换现场记录`](../inventory/phase-10-server-replacement.md#4-nixbox-bootstrap-authentication-关卡)。

#### Rescue 演练

Rescue 演练是 install 前的独立 provider 关卡，不得与 destructive install 共用批准。它拆成“进入 Rescue”和“从 Rescue 回盘”两次状态变更；每次都先给出中文行动卡并取得当前明确批准。

1. 启动前再次通过 macbook `phase10-preflight`、macbook/nixbox strict SSH 与既有 VNC，确认不是从已漂移或失联的 Ubuntu 出发；
2. 从 Contabo 首页左侧菜单进入 `VPS control`，再使用目标行的 `Rescue system` 页面内入口；不得复用深层 URL、浏览器返回或刷新；
3. 等 Rescue 页面的目标实例行从空占位完整加载为预期实例后才填写表单。若目标仍为空，不输入 credential、不提交；
4. 一次性 Rescue credential 只由维护者在现场 UI 输入并保管，不写入聊天、Git、命令、日志、浏览器自动化或私密记录，也不得与 VNC credential 混用；
5. 维护者点击 `Start Rescue System` 后，任何网页错误都先视为“结果未知”，不得立即重试。先检查 VNC、原 production SSH 可达性与 strict host identity：临时 Rescue identity 被既有 production pin 拒绝是预期保护，不得覆盖 pin 或关闭 strict checking；
6. 优先通过已验证 VNC 登录 Rescue，只运行 `uname -m`、`ls -l /dev/disk/by-id` 与 `lsblk -b <expected-device>` 等短只读命令；stable alias、底层 device、byte capacity、disk/RO 类型和空 mountpoint 任一不符都停止；
7. 不 mount、fsck、chroot、写分区、修改网络/SSH 或安装任何内容。若 VNC 键盘映射改变命令大小写或符号，取消输入并由维护者运行短命令，不猜测执行结果；
8. 磁盘事实通过后，另给回盘行动卡。维护者批准后只运行一次 `reboot`；不得用控制面 Restart、Stop 或 Reinstall 代替；
9. VNC 观察原系统从磁盘启动后，原 production host identity 必须在 macbook 与 nixbox 的既有 strict pin 下恢复，两条 SSH 路径和完整 `phase10-preflight` 都再次通过，才关闭演练关卡。

若 Rescue 启动或回盘 10 分钟后仍无 VNC/SSH，保持当前状态并重新请求批准；不连续点击 Rescue/Restart，不用 Reinstall 作为普通重试。只有既有磁盘系统确认不可启动且失联恢复阶梯要求升级时，才单独提交下一层行动卡。

### B. 安装

安装窗口前，先在 nixbox 的最终 clean checkout 运行非 production 计划入口：

~~~text
nix run .#phase10-install-plan
~~~

该入口不接受参数、不连接 production。它验证当前 HEAD 与 helper 内嵌 commit 一致，在 nixbox 本地实现精确 server closure、disko script 和 pinned kexec tarball，验证 dedicated identity/known-hosts 但不输出 private path，并打印行动卡所需的脱敏完整底层命令。若 plan 失败、输出 target/disk/closure/phase 漂移或没有明确报告 production-contact=no，则停止，不申请执行批准。

Issue #13 的本次行动卡必须绑定 plan 输出的精确 commit，并记录 target、stable disk、server derivation/output、kexec、phases、维护窗口、VNC/SSH 观察人、停止条件、数据全丢 waiver 和恢复阶梯。旧批准、实现批准、Rescue 批准或只读 preflight 批准都不能代替本次 destructive install 批准。

取得该行动卡的当前明确批准后，维护者只在 nixbox 的同一 clean checkout 运行：

~~~text
nix run .#phase10-install
~~~

现场顺序固定为：

1. macbook 保持已连接 VNC 和独立 SSH 观察，不作为构建来源；
2. install 入口重新执行与 plan 相同的本地冻结检查并再次打印 plan；
3. 维护者逐项核对 commit、target、disk、closure 与 phases 后，在真实交互式 TTY 手动输入短确认词 INSTALL；不得用参数、管道、后台或无人值守方式代替；
4. helper 先以 nixbox 专用 deploy identity、dedicated known-hosts、public-key only 和 strict host checking 对当前 Ubuntu 重跑完整只读 production preflight；
5. 任一 local 或 remote preflight 失败都在 kexec/disko 前退出；不要当场放宽 SSH、改 disk/network 或换用 Reinstall；
6. 只有 preflight PASS 后，helper 才调用本阶段专用的 pinned nixos-anywhere：local build、空 builders、destination 不 substitute、不使用 machine substituters、本地 kexec tarball、copy 现有 host keys，phases 精确为 kexec,disko,install,reboot；
7. 从 kexec 开始到首次 NixOS SSH 验收完成，不恢复业务、不开放额外端口、不现场顺带加固。

Phase 10 派生的 nixos-anywhere 只移除 upstream 1.13.0 内置的 UserKnownHostsFile=/dev/null 与 StrictHostKeyChecking=no；其余行为继续使用锁定版本。helper 再显式传入专用 host pin，并禁用 SSH agent、password、keyboard-interactive、proxy/jump、connection sharing、forwarding 与 host-key 自动更新。原始 Phase 9 package 不变，策略检查会在 upstream 参数形状漂移时构建失败。

install 的 phases 已包含安装后的第一次 reboot。不要在 nixos-anywhere 返回后立即再 reboot；首次启动必须先完成下一节验收，第二次 reboot 仍按 D 节提交独立行动卡并取得新的明确批准。

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
