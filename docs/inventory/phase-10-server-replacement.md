# Phase 10：Server 正式替换现场记录

> 范围：Issue #13。本文记录 production 替换前的实时证据、只读 preflight 合同、未闭合关卡与后续验收。任何记录或 helper 都不自动授权 Rescue、SSH access 修改、kexec、disko、安装、重启或 Reinstall。

## 1. 当前批准与实时证据

- 维护者继续接受当前 Ubuntu、服务、容器、数据库和数据全部丢失，不要求 source backup、dump 或 restore test；失败恢复目标仍是重新建立可从 macbook SSH 管理的最小 NixOS。
- 2026-07-31 已在维护者登录的 Contabo Customer Control Panel 中只读复核唯一目标 VPS：Ubuntu 24.04、Running，VNC 已启用，Rescue 与 Reinstall 入口均存在。
- 维护者单独批准一次实际 VNC 连接。Contabo 不显示现有 VNC 密码，只提供密码修改表单；维护者亲自设置临时密码，Agent 未读取、保存或记录凭据。
- macOS 内置“屏幕共享”已实际连接到目标控制台，窗口身份与当前实例一致；“记住密码”未启用。Agent 没有向 guest 发送鼠标、按键或命令，观察完成后主动断开。
- VNC 画面停留在旧的 Linux `soft lockup` / RCU stall 警告。维护者随后单独批准严格 host-key 的 SSH 只读健康诊断：当前负载很低，最近 6 小时没有同类 kernel warning；VNC 中的 kernel monotonic timestamp 比当前 uptime 早约 73 天，因此判定为旧控制台日志，不是当前持续 lockup。
- `systemctl is-system-running` 仍为 `degraded`；失败项仍是 Phase 7 已知的 cloud-init、nginx 与 networkd-wait-online，没有发现新增失败单元。本阶段不修复这些将被清除的 Ubuntu 服务。
- 控制面与健康诊断没有执行 restart、stop、Rescue、Reinstall、guest package/service/network/SSH 修改或 reboot。敏感 endpoint、实例标识、credential、fingerprint 与 private-key path 只留在仓库外私有记录。

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

macbook 不能构建 `x86_64-linux` 的完整 server closure：本地执行相应 `nix build` 时，Nix 正确拒绝在 `aarch64-darwin` 上构建一个禁用 substitute 的 `x86_64-linux` derivation。这不是 evaluation 或配置失败；server drvPath 仍与 Phase 9 已验证值一致。正式替换前必须在 nixbox 对冻结 commit 重新完成完整 build，macbook 的本地结果不能代替该关卡。

## 4. Nixbox bootstrap authentication 未闭合关卡

当前 Ubuntu 的可信入口是 macbook 的既有 key-only root SSH。nixbox 专用 deploy key 已在 Phase 8 创建，但其 public half 只声明在未来 NixOS 的 `sayori` 用户中，当前 Ubuntu 没有授权该 key。因此：

- macbook preflight 通过不等于 nixbox 已能运行 `nixos-anywhere`；
- 不得复制 macbook private key 到 nixbox；
- 不得使用 password root、`StrictHostKeyChecking=no`、未核验 `ssh-keyscan` 或 SSH agent forwarding 作为捷径；
- Issue 中“两端以 `sayori` 登录”的最终验收不能被误写成当前 Ubuntu 已具备的事实。

推荐但尚未批准的最小 bootstrap 是：在 macbook preflight 全部通过后，由可信 macbook root 会话把仓库中已声明的 nixbox deploy **public key** 原子、幂等地追加到当前 Ubuntu root `authorized_keys`。该动作：

- 不传输任何 private key；
- 不删除或替换现有 macbook key；
- 只让 nixbox 在当前 Ubuntu/kexec installer 阶段以严格 host pin 建立安装链路；
- 若安装前中止，可用单独批准的反向动作移除该单行；
- 正式 NixOS closure 的 root keys 只保留 macbook break-glass，因此临时 nixbox root authorization 不会进入最终系统。

这是 production SSH access 修改，必须另给中文行动卡、完整底层命令、验证与撤销步骤，并取得当前明确批准。本文只记录缺口与推荐方案，不执行该动作。

## 5. 后续顺序

1. 合并前保持 Draft PR，先审阅 helper 的 target、拒绝条件与输出边界；
2. 对精确 clean commit 单独批准并运行 macbook `phase10-preflight`；
3. 维护者理解并批准或否决临时 nixbox root deploy-key bootstrap；
4. bootstrap 后从 nixbox 以专用 key、专用 known-hosts 与 strict checking 只读验证当前 Ubuntu；
5. 用单独行动卡启动一次 Rescue，实际登录并确认目标磁盘，再回到 Ubuntu 复验两条管理路径；
6. 在 nixbox 重跑 Phase 9、预构建 closure，冻结 install helper、commit、disk、完整命令、窗口与停止条件；
7. 维护者对该次 destructive install 重新明确批准后，才进入 kexec/disko/安装。
