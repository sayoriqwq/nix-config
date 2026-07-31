# Phase 10：Server 正式替换现场记录

> 范围：Issue #13。本文记录 production 替换前的实时证据、只读 preflight 合同、未闭合关卡与后续验收。任何记录或 helper 都不自动授权 Rescue、SSH access 修改、kexec、disko、安装、重启或 Reinstall。

## 1. 当前批准与实时证据

- 维护者继续接受当前 Ubuntu、服务、容器、数据库和数据全部丢失，不要求 source backup、dump 或 restore test；失败恢复目标仍是重新建立可从 macbook SSH 管理的最小 NixOS。
- 2026-07-31 已在维护者登录的 Contabo Customer Control Panel 中只读复核唯一目标 VPS：Ubuntu 24.04、Running，VNC 已启用，Rescue 与 Reinstall 入口均存在。
- 维护者单独批准一次实际 VNC 连接。Contabo 不显示现有 VNC 密码，只提供密码修改表单；维护者亲自设置临时密码，Agent 未读取、保存或记录凭据。
- macOS 内置“屏幕共享”已实际连接到目标控制台，窗口身份与当前实例一致；“记住密码”未启用。Agent 没有向 guest 发送鼠标、按键或命令，观察完成后主动断开。
- VNC 画面停留在旧的 Linux `soft lockup` / RCU stall 警告。维护者随后单独批准严格 host-key 的 SSH 只读健康诊断：当前负载很低，最近 6 小时没有同类 kernel warning；VNC 中的 kernel monotonic timestamp 比当前 uptime 早约 73 天，因此判定为旧控制台日志，不是当前持续 lockup。
- `systemctl is-system-running` 仍为 `degraded`；失败项仍是 Phase 7 已知的 cloud-init、nginx 与 networkd-wait-online，没有发现新增失败单元。本阶段不修复这些将被清除的 Ubuntu 服务。
- 上述控制面与健康诊断在当时没有执行 restart、stop、Rescue、Reinstall、guest package/service/network/SSH 修改或 reboot；后续经两张独立行动卡完成的 Rescue 与回盘演练见第 5 节。
- 2026-07-31 Rescue 演练已完成：实际登录临时 Rescue、确认稳定目标盘后，经单独批准回到原 Ubuntu；VNC、macbook strict SSH、nixbox strict SSH 与完整 production preflight 均再次通过。敏感 endpoint、实例标识、credential、fingerprint 与 private-key path 只留在仓库外私有记录。

## 2. Macbook 只读 preflight 短入口

维护者入口固定为：

```text
nix run .#phase10-preflight
```

该入口不接受 target 或其他参数，也不能执行安装。它只在 macbook 上运行，并在连接 production 前依次拒绝：

1. checkout 不 clean；
2. `ssh sayori` 不再解析为冻结的 public host、`root`、TCP 22；
3. SSH 使用 ProxyCommand 或 ProxyJump；
4. 到目标的路由不再经过 macbook 物理接口 `en0`；
5. 不能使用 `BatchMode=yes`、`IdentitiesOnly=yes` 与 `StrictHostKeyChecking=yes` 通过现有可信 pin。

入口明确调用 macOS `/usr/bin/ssh`，以兼容现有 SSH 配置中的 Apple `UseKeychain` 扩展并复用 Keychain identity；不向 `PATH` 注入 portable OpenSSH，也不读取或复制 private key。

远端 probe 通过 stdin 交给 Ubuntu 的 `bash -s`，不创建远端文件。期望的 stable disk alias、IPv4/IPv6 address、gateway 与 DNS 直接从同一 commit 的 `nixosConfigurations.server` 求值结果生成，不维护第二份手写 production 参数。

远端只读检查覆盖：

- `x86_64`、Contabo KVM、BIOS、至少 1.5 GiB RAM、无 swap；
- 当前 kernel 的 kexec 配置与运行态开关；
- stable disk alias 必须解析为唯一可写 disk，并输出 exact device 与 byte capacity；
- 恰好一张 `virtio_net` NIC；
- 静态 IPv4/IPv6 address、双默认 gateway、IPv6 `onlink` 与 link DNS；
- `tar`、`setsid`、root `authorized_keys` mode/owner 与可复制的现有 SSH host key；
- system state 只能为 running/degraded，不得出现 Phase 7 已知集合之外的新 failed unit；
- 最近 6 小时不得出现新的 soft lockup、RCU stall、starvation 或 NMI backtrace。

probe 只输出 public routing facts、stable disk alias/device/capacity 与脱敏 PASS/FAIL；不输出 authorized key、host fingerprint、private-key path、credential、环境变量、业务路径或原始 journal。任一事实不一致都会在 kexec/disko 前失败。

## 3. 当前本地验证

Phase 10 helper 在 macbook 本地执行：

```text
bash -n tools/phase-10/remote-preflight.sh
nix fmt -- --check .
nix build --no-link path:<worktree>#checks.aarch64-darwin.phase10-preflight
nix build --no-link path:<worktree>#checks.aarch64-darwin.phase10-remote-preflight-shellcheck
nix flake check --no-build --all-systems path:<worktree>
git diff --check
```

本地构建和 ShellCheck 通过。dirty checkout 与额外 target 参数的失败关闭检查也已通过，且都在 SSH 连接前退出。

维护者批准后，首次对 clean commit `8c5ae430e238806ac40ad4c44632844a0be9a7a4` 启动 production preflight，但它在 remote probe 前以 SSH status 255 失败关闭。根因是 helper 当时向 `PATH` 注入的 portable OpenSSH 不识别 macOS 配置中的 Apple `UseKeychain` 扩展；macOS `/usr/bin/ssh` 对相同配置解析和 strict no-op SSH 均通过。修复后 helper 明确使用系统 SSH，重新通过本地构建、全系统 evaluation 与 dirty-checkout failure 测试。失败尝试没有读取 production inventory，也没有产生远端写入。修复后的 production preflight 必须绑定新的精确 commit 并重新取得维护者批准。

维护者随后单独批准 clean commit `6ea0717d3a527a40ece1a9886cc181cf0e4d1dc8`，production preflight 完整通过：

- local target 仍为 `sayori`、root、TCP 22，路由经 `en0`，strict host checking 生效；
- production 为 `x86_64`、KVM、BIOS，RAM 8,131,800 KiB，无 swap，kexec 可用；
- stable alias 唯一解析到 `/dev/sda`，它是唯一可写磁盘，容量 80,530,636,800 bytes；
- 唯一 provider NIC 为 `eth0` / `virtio_net`，声明式 IPv4、IPv6、双 gateway、IPv6 on-link 与三项 DNS 全部匹配；
- system state 为已知的 `degraded`，没有新增 failed unit；bootstrap tools、root `authorized_keys` 权限与 3 份可复制 SSH host private key 均通过；
- 最近 6 小时相关 kernel warning 为 0；probe 通过 stdin 执行且没有创建远端文件。

这关闭 macbook production read-only preflight 关卡，但不授权或完成 nixbox bootstrap authentication、Rescue rehearsal、closure build、install 或 reboot。

macbook 不能构建 `x86_64-linux` 的完整 server closure：本地执行相应 `nix build` 时，Nix 正确拒绝在 `aarch64-darwin` 上构建一个禁用 substitute 的 `x86_64-linux` derivation。这不是 evaluation 或配置失败；server drvPath 仍与 Phase 9 已验证值一致。正式替换前必须在 nixbox 对冻结 commit 重新完成完整 build，macbook 的本地结果不能代替该关卡。

## 4. Nixbox bootstrap authentication 关卡

本关卡开始时，当前 Ubuntu 的唯一可信入口是 macbook 的既有 key-only root SSH。nixbox 专用 deploy key 已在 Phase 8 创建，但其 public half 当时只声明在未来 NixOS 的 `sayori` 用户中，当前 Ubuntu 尚未授权该 key。因此：

- macbook preflight 通过不等于 nixbox 已能运行 `nixos-anywhere`；
- 不得复制 macbook private key 到 nixbox；
- 不得使用 password root、`StrictHostKeyChecking=no`、未核验 `ssh-keyscan` 或 SSH agent forwarding 作为捷径；
- Issue 中“两端以 `sayori` 登录”的最终验收不能被误写成当前 Ubuntu 已具备的事实。

经单独行动卡批准采用的最小 bootstrap 是：在 macbook preflight 全部通过后，由可信 macbook root 会话把仓库中已声明的 nixbox deploy **public key** 原子、幂等地追加到当前 Ubuntu root `authorized_keys`。该动作：

- 不传输任何 private key；
- 不删除或替换现有 macbook key；
- 只让 nixbox 在当前 Ubuntu/kexec installer 阶段以严格 host pin 建立安装链路；
- 若安装前中止，可用单独批准的反向动作移除该单行；
- 正式 NixOS closure 的 root keys 只保留 macbook break-glass，因此临时 nixbox root authorization 不会进入最终系统。

这是 production SSH access 修改，每次执行都必须另给中文行动卡、完整底层命令、验证与撤销步骤，并取得绑定精确 commit 的当前明确批准。实际执行结果记录在本节末尾。

仓库提供两个不接受参数的 macbook 短入口：

```text
nix run .#phase10-bootstrap-nixbox
nix run .#phase10-rollback-nixbox-bootstrap
```

两个入口都先重跑同一 commit 的完整只读 `phase10-preflight`，随后固定 macOS system SSH、`sayori` alias、声明式 production host、root、TCP 22、无 forwarding、无 proxy/jump、无 connection sharing 与 strict host checking。deploy public key 和当前 macbook root public key 都直接从同一 server configuration 派生，维护者不手抄 key 或长参数。SSH 远端命令本身只包含 `bash -s`；action 与两把 public key 经 Nix shell escaping 固化在 stdin 脚本开头的 `set --` 中，不经过 OpenSSH 的远端命令参数重组。

远端 state-changing helper 的失败关闭合同：

1. 只接受内部固定的 `add` 或 `remove` action，以及两把已声明的 canonical ED25519 public key；
2. `/root/.ssh` 必须是 mode `0700` 的 root-owned 实体目录，`authorized_keys` 必须是 mode `0600` 的 root-owned 实体文件；任一 symlink、权限或 owner 漂移都拒绝；
3. 当前 macbook root key 必须精确出现一次；nixbox key 的 payload、comment 或重复数量异常都拒绝；
4. 使用同目录 mode `0600` 临时文件，保留原文件属性，只构造预期候选内容；候选文件必须再次保留 macbook key、满足精确 deploy-key count 并通过 `ssh-keygen` 解析；
5. 候选内容先同步，再以同目录 rename 原子替换；成功输出只包含 action、是否实际改变、macbook key 已保留和 deploy-key count，不输出 key 或 fingerprint；
6. `add` 已存在和 `remove` 已不存在均为无写入的幂等 PASS；回滚只移除精确 deploy public-key 行，不删除 macbook key。

回滚入口的存在不是自动执行授权。bootstrap 后若 nixbox strict verification 失败，保持 macbook SSH 会话与 VNC 可用并停止后续步骤；是否立即回滚必须在该次行动卡中单独批准。本轮已取得 verification 失败时的条件式回滚批准，但两端验证均通过，未触发回滚。

macbook 已通过 add/rollback wrapper build、remote ShellCheck 与全系统 evaluation。`checks.x86_64-linux.phase10-nixbox-bootstrap` 隔离 NixOS VM test 覆盖 add、重复 add、rollback、重复 rollback，以及 duplicate payload、changed metadata、unsafe mode 和 symlink 失败注入。

2026-07-31 在 nixbox 对精确 commit `7d7778fb0fe59047593595e2397cb01e56bd7ead` 实际运行该 VM test，结果完整 PASS。nixbox 直接获取 GitHub commit 曾因连接超时在五次重试后失败，随后由 macbook 通过现有严格 SSH 的 Nix store 通道传输同一 clean flake archive，再从不可变 source path 构建；没有修改 nixbox checkout，也没有连接 production server。

维护者随后批准在 clean commit `bab95ad9e5509aeab97dd095c7308e35ffa4d5c4` 执行 add、macbook/nixbox strict verification，并仅在 verification 失败时回滚。bootstrap 入口先完整重跑 production preflight 且再次 PASS，但 state-changing 远端脚本随即以 `internal argument contract mismatch` 失败关闭。失败发生在脚本读取 `/root/.ssh` 或构造临时文件之前，因此没有修改 `authorized_keys`，也无需执行回滚。根因是 OpenSSH 会把本地多个远端命令参数重新拼成 shell command string，包含空格的 public key 因而被拆成多个远端参数。

修复后 action 与 public key 改为固化在 stdin 脚本内部，SSH argv 不再携带 key；隔离 VM test 也改为执行实际生成的 add/remove stdin 脚本，而不是只直接调用底层脚本。本地已通过生成脚本参数合同、add/remove 额外参数失败关闭、wrapper build、ShellCheck、格式检查与全系统 evaluation。2026-07-31 又在 nixbox 对精确 clean commit `7e304e5fd7fd032e2e6f8c59b7ac32e03a0b6fb3` 的不可变 source 完整构建新 VM derivation，add、重复 add、remove、重复 remove 与全部失败注入均 PASS；传输和构建没有连接 production。代码变化使上一轮 production 批准失效，任何再次 add 都必须绑定包含本记录的新 commit 重新取得明确批准。

维护者随后对最终 clean commit `0c9267f860e187decc32f33349b2c0b1bf758a6a` 明确批准 add、macbook/nixbox strict 只读验证，以及仅在 verification 失败时执行精确 rollback。入口再次完成 production preflight 后，add 返回 `changed=yes`、macbook key preserved、deploy-key count 1。macbook 以原有 identity 和 strict host pin 登录 production root PASS；nixbox 再以专用 deploy identity、专用 known-hosts、public-key-only 与 strict checking 登录 production root PASS。nixbox verifier 的首次本地派发因 macOS Fish 不支持一个纯解析选项而在连接 nixbox 前退出；移除该选项后实际验证 PASS。该本地派发错误没有连接任何远端，不构成 verification 失败。条件式 rollback 未触发。

当前 Ubuntu 因此临时授权了精确一条 nixbox deploy public key，macbook 原管理入口仍保持可用。这只关闭 bootstrap authentication 关卡；不授权 Rescue、closure build、install、reboot 或其他 production 修改。

## 5. Rescue 登录与回盘演练

维护者先批准绑定 PR HEAD `452959447028054c72b85d538d1a302069aa00df` 的 Rescue 启动行动卡。启动前，macbook 再次运行完整 `phase10-preflight` 并 PASS；控制面目标、稳定磁盘别名与 byte capacity 均未漂移。

现场严格使用 Contabo 页面内导航，从首页左侧 `VPS control` 进入目标的 `Rescue system`，并等目标实例行完成加载后才处理表单。维护者亲自在 `Standard` Rescue 表单设置一次性 credential 并点击 `Start Rescue System`；Agent 没有读取、输入、保存或记录该 credential。

旧控制面在提交后显示通用处理错误，但请求实际上已经生效。现场没有重试提交，而是先观察原 Ubuntu SSH 消失、strict host checking 拒绝临时 Rescue identity，再通过既有 VNC 确认进入 Debian 12 Rescue。没有覆盖 production known-hosts、接受未核验 host key、关闭 strict checking 或改用 Reinstall。

维护者经 VNC 登录 Rescue 后，只运行短只读命令核对：

- architecture 为 `x86_64`；
- `/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0` 精确解析为 `/dev/sda`；
- `/dev/sda` 为 `disk`、`RO=0`，容量为 80,530,636,800 bytes；
- target disk 与现有各分区的 mountpoint 均为空。

VNC 自动键盘输入受远端 Caps Lock 状态影响，最初长探针只产生 Bash syntax error / command-not-found，没有形成有效检查或状态修改。现场随即停止自动输入，改由维护者运行三条短只读命令；没有执行 mount、fsck、block write、分区、网络/SSH 修改或安装。

磁盘检查通过后，维护者又单独批准当前 Rescue 控制台的一次 `reboot`。由于同一 VNC 键盘映射会把自动输入改为大写，Agent 在回车前取消自动输入，由维护者手动运行小写 `reboot`。VNC 随后观察到 Ubuntu 24.04 从磁盘启动并到达 login prompt；原 production host identity 恢复，macbook strict SSH no-op PASS。

回盘后的完整 `phase10-preflight` 再次 PASS：system state 为 `running`，architecture、BIOS、stable disk、唯一 `virtio_net` NIC、双栈 routing、DNS、SSH bootstrap 与近期 kernel health 均符合冻结证据。nixbox 随后以专用 deploy identity、专用 known-hosts、public-key-only 与 strict checking 登录当前 Ubuntu root 并执行只读 no-op，结果 PASS。nixbox verifier 的两次 macOS Fish 私密路径解析改写都在连接 nixbox 前失败关闭；改用只验证字段数量和安全字符、且不输出路径的解析后，实际双跳验证 PASS。

本演练只证明 provider Rescue、VNC、目标盘可见性与回到原 Ubuntu 后的双管理路径可用。它不授权 closure build、kexec、disko、nixos-anywhere、安装、再次 reboot、网络/SSH 修改或 Reinstall。

## 6. 后续顺序

1. 合并前保持 Draft PR，先审阅 helper 的 target、拒绝条件与输出边界；
2. **已完成：** 对精确 clean commit 单独批准并运行 macbook `phase10-preflight`；
3. **已完成：** 首次 production add 在任何写入前暴露的 SSH 参数边界缺陷已修复，修复版隔离 VM test 已在 nixbox 通过；
4. **已完成：** 对最终精确 commit 批准并执行 bootstrap，随后从 macbook 与 nixbox 以各自 identity 和 strict host pin 只读验证当前 Ubuntu；两端均 PASS，未触发 rollback；
5. **已完成：** 用独立行动卡启动 Rescue，实际登录并确认目标磁盘；再经第二次批准回到 Ubuntu，VNC、macbook、nixbox 与完整 preflight 均 PASS；
6. 在 nixbox 重跑 Phase 9、预构建 closure，冻结 install helper、commit、disk、完整命令、窗口与停止条件；
7. 维护者对该次 destructive install 重新明确批准后，才进入 kexec/disko/安装。
