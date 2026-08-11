# Phase 9：Server 隔离 VM 安装演练

> 范围：Issue #12。本文保留 2026-07-31 在 nixbox 上运行的一次性 QEMU/NixOS 演练证据；不连接 production server，不读取或修改 Contabo 控制面，不使用 `sudo`。Phase 10 完成后，同一安全边界已改名为长期 `server-recovery-test`，一次性迁移 helper 已删除。

## 1. 批准与安全边界

维护者在 Issue #12 对本阶段作出当次批准。批准只覆盖：

- nixbox 上的隔离 QEMU/NixOS VM；
- destructive action 只落在测试 VM 的单个 4 GiB sparse disk；
- RFC 5737 / RFC 3849 dummy network、一次性测试 key 与模拟 host-key copy；
- 最多 4 vCPU、4 GiB 同时运行的 VM RAM；
- 本仓库的 Phase 9 分支、文档、验证、Draft PR 与 Issue 记录。

下列动作仍然禁止：连接或指定 production server、运行 production kexec/install、修改 nixbox 的 host network/firewall/route/SSH、使用 `sudo`、接触真实 disk、操作 Contabo、记录 private key/credential，或把本阶段结果解释为 Phase 10 批准。

Phase 9 当时的短入口不接受 host、disk、SSH identity 或任何额外参数：

```text
nix run .#phase9-test
```

当前长期入口保持相同的参数拒绝与 production 隔离边界：

```text
nix run .#server-recovery-test
```

入口在执行 VM 前会拒绝非 `x86_64`、不可访问 `/dev/kvm`、dirty checkout、低于 100 GiB 可用空间或任意额外参数。因而不能把它改造成 production target runner。

## 2. 冻结版本与生产输出不变性

| 输入 | 冻结值 |
| --- | --- |
| nixos-anywhere | `5887f1c72fbf0e88000716237194de414d2299ee`（1.13.0） |
| disko | `ff8702b4de27f72b4c78573dfb89ec74e36abdf1` |
| Nixpkgs | 仓库 `flake.lock` 中的 `nixos-26.05` revision |
| production output | `nixosConfigurations.server` |
| 测试入口 | Phase 9 当时为 `apps.x86_64-linux.phase9-test`；当前为 `apps.x86_64-linux.server-recovery-test` |

Phase 9 只给 `server` output 增加 `disko.tests` 定义；普通 production 配置没有启用测试覆盖层。修改前后
`nixosConfigurations.server.config.system.build.toplevel.drvPath` 均为：

```text
/nix/store/wzag8v8iv686cz62qcy6zaxas97c5nhv-nixos-system-server-26.05.20260719.fd14620.drv
```

这项相等性只证明 Phase 9 没改变 Phase 8 的 production closure，不代表真实安装已经获批或成功。

## 3. 两层演练结构

测试入口顺序执行两层 VM，因此不会叠加超过批准的资源上限。

### A. nixos-anywhere / disko 安装层

固定版本的 `nixos-anywhere --vm-test` 构建 `server.config.system.build.installTest`。该 upstream test：

- 创建一块 4096 MiB sparse QCOW2 test disk；
- 以 BIOS QEMU 启动，不使用 EFI/OVMF；
- 只在 guest 的 `/dev/vda` 上执行 disko 的 destroy/format/mount；
- 安装 GRUB 与 NixOS，关闭安装 VM，再从同一测试 disk 启动最终系统；
- 在最终系统检查 GPT `EF02`、ext4 `/`、无 swap、dummy network、SSH policy、firewall 与 capability boundary；
- 再执行一次独立 reboot，复查 boot ID、SSH host identity、filesystem、route 与 sudo。

固定 disko 的 `installTest` 会用手工 QEMU command 重建 booted machine，未暴露该机器的 NIC model 配置，因此使用
QEMU implicit `e1000`。安装层只用它承载 dummy network 并验证 disk/boot 与配置能启动；不会把它写成
production NIC 已验证。production 等价的单张 `virtio_net`、driver match、失败关闭 preflight 与实际双栈 TCP/SSH
全部由下一层覆盖。这个拆分避免为测试修改或放宽 production server 的 `virtio_net` 声明。

upstream `--vm-test` 分支在构建 `installTest` 后直接结束，不接收 SSH destination，也不会运行 remote
`--copy-host-keys` 路径。因此 host-key copy 不能伪装成已由 nixos-anywhere 覆盖；本阶段在第二层单独做行为等价的
ephemeral simulation，并把这项差异保留到 Phase 10 人工关卡。

### B. 网络、访问与失败注入层

NixOS integration test 先单独启动 512 MiB 的 ambiguous VM，验证：

- 两张 `virtio_net` NIC 会被“一张 NIC” preflight 拒绝；
- 错误 firmware 预期会被拒绝；
- 缺失 test disk 会被拒绝；
- 拒绝后 QEMU serial/test console 仍可观察并执行恢复动作。

ambiguous VM 关闭后，再同时启动 1536 MiB server 与 512 MiB gateway。两者只连接 NixOS test VLAN，使用：

- IPv4：`192.0.2.0/24` 文档网段；
- IPv6：`2001:db8:9::/64` 文档前缀；
- IPv6 link-local dummy gateway：`fe80::1`；
- gateway 内的隔离 dnsmasq；
- 每台 VM 1 vCPU。

该层对三台 VM 都显式清空测试框架默认的 QEMU networking options，不创建隐式 SLiRP NIC，也不提供默认外网出口。
ambiguous VM 只连接两张测试 VLAN NIC；server 与 gateway 各只连接双方共享的一张测试 VLAN NIC。

该层验证真实 TCP/SSH 交互：双栈 TCP 22、DNS、`sayori` 两类 key、`sudo -n`、password 与 keyboard-interactive 拒绝，以及 firewall 对未声明 TCP 8080 listener 的阻断。原始 Phase 9 还验证仅 maintenance key 的 root break-glass；2026-08-10 的 #99 将长期 `server-recovery-test` 更新为两类 key 的 root login 都必须失败，历史演练结果不改写。

## 4. Key 与秘密边界

仓库只保存两个测试 public-key slot；它们没有可恢复的 private half，也不是 production key。

实际 SSH client key 与模拟 source host key 只在一次性 VM 运行时生成。测试使用 strict host-key checking，
把模拟 source host public key 写入 gateway 的临时 `known_hosts`，验证第一次访问和第二次 reboot 后身份一致。
结束前会停止测试 sshd，删除：

- gateway 的两组 runtime client key 与 `known_hosts`；
- server 的 runtime `authorized_keys`；
- 模拟 source host key；
- 安装到 `/etc/ssh` 的模拟 host key。

随后关闭 VM。private key、host private key、fingerprint、disk image 与测试日志均不提交 Git、Issue 或 PR。
Nix build closure 仍按 nixbox 的正常 store/GC policy 管理；测试不会为了“清理”而运行 host 级 `nix store gc`。

## 5. 声明边界检查

当前 `checks.x86_64-linux.server-recovery-policy`（Phase 9 当时名为 `phase9-policy`）从 production server 配置派生 test variant，并在纯求值时断言：

- dummy address、gateway、DNS 与 networkd network 唯一；
- firewall 只开放 TCP 22；
- SSH 为 key-only，root 为 `prohibit-password`；
- 普通用户和 root 的 test public-key slot 精确匹配；
- `system.stateVersion` 与 `home.stateVersion` 均保持 `26.05`；
- Atuin 没有 sync，且没有 GitHub collaboration、GUI、Docker 或 workstation bundle。

它输出的 JSON 只包含 dummy network、public test key 与非敏感策略证据。

## 6. 验证命令与结果

macOS 侧先执行非破坏性检查：

```text
nix fmt -- --check .
nix flake check --no-build --all-systems
nix eval --raw .#nixosConfigurations.server.config.system.build.toplevel.drvPath
nix build --no-link .#nixosConfigurations.server.config.system.build.toplevel
git diff --check
```

nixbox 对 clean checkout 的精确 commit 执行：

```text
nix run .#phase9-test
```

### 6.1 首次完整通过记录

| 项目 | 结果 |
| --- | --- |
| 执行节点 | nixbox，`x86_64-linux`，KVM 可用；未使用 `sudo` |
| 精确 commit | `41f17684cfbf8079374bbfaf9050362d8d80d280` |
| 执行时间 | 2026-07-31 11:57–11:59 CST（UTC+08:00） |
| checkout | clean，且与上述 commit 精确一致 |
| 资源 | 单次最多 2 vCPU / 2 GiB VM RAM；安装层仅一块 4096 MiB sparse test disk |
| 结果 | `phase9-test: PASS; no production target was accepted or contacted` |
| 清理检查 | 测试退出后 `qemu-system-x86_64` 与 `qemu-kvm` 均无残留进程 |

完整入口依次通过：

1. 声明边界检查；
2. production server closure 的无 activation build；
3. BIOS/GPT/EF02/ext4 的 destructive disko 安装、冷启动及真实 reboot；
4. 无默认 SLiRP 出口的隔离双栈、DNS、SSH、sudo、host identity persistence 与 firewall 测试；
5. 错误 NIC 数、错误 firmware 预期和缺失 disk 的失败关闭检查；
6. runtime key、host key、known-hosts、VM 与 test disk 的测试内清理。

nixbox 当时无法通过 HTTPS 访问 GitHub，因此没有修改其网络。macOS 从精确 commit 创建临时 Git bundle，传输后在
nixbox 校验并导入；每个 bundle 导入后即删除。最终 guest 不依赖 GitHub checkout，production server 也没有被解析为
destination、探测或连接。

### 6.2 演练中发现并固定的陷阱

首次完整通过前的失败都发生在同一批准边界内的一次性 QEMU VM；每次失败后都确认无 QEMU 残留，未连接 production。

| 现象 | 原因 | 固定后的处理 |
| --- | --- | --- |
| disko 启动机的 NIC 与 production `virtio_net` 断言不符 | upstream disko test 用手工 QEMU command 重建机器，隐式采用 `e1000` | 安装层只验证 disk/boot；production 等价 `virtio_net` 在独立网络层验证 |
| 子层修改 NIC driver 没有生效 | 父层的 module 值已使用 `mkForce` | 不覆盖 production 声明，改为明确拆分两层职责 |
| 安装层静态网络等不到 carrier | 重建的 `e1000` 只承载 dummy network | 仅测试覆盖层启用 `ConfigureWithoutCarrier`；production 配置不变 |
| `authorized_keys` 数量误判为 0 | 单行文件没有结尾换行，`wc -l` 不适合作为条目计数 | 用 `grep -c` 按实际 key slot 计数 |
| `sshd -T` 没反映生成配置 | 裸命令没有读取 NixOS 生成的 sshd config | 显式传入 `/etc/ssh/sshd_config` |
| effective config 检查因 host key 缺失失败 | 真实 systemd service 会传 host key，独立探针没有 | 探针显式提供测试 host key |
| OpenSSH 10.4 输出大小写变化导致文本比较失败 | effective directive 保留了值的大小写 | 使用精确、大小写不敏感匹配，不放宽配置语义 |
| 测试驱动的 reboot 后 VM 不再启动 | disko 重建命令默认带 `-no-reboot` | 先冷关机并以 `allow_reboot` 重启，再执行一次真实 reboot |
| 网络层出现未声明的额外 NIC/外网路径 | NixOS test driver 默认注入 SLiRP NIC | 对全部节点强制清空默认 networking options，只保留显式测试 VLAN |

### 6.3 验证边界与最终 HEAD 复跑

固定 disko test 与 NixOS integration test 都通过 9p 暴露 `/nix/store`。该挂载的 ownership 语义会使
Home Manager activation service 的运行态所有权检查失真；因此本阶段不把该 service 的运行态作为 PASS 证据。
Home Manager capability 只由 production closure build 与纯求值 policy check 覆盖，真实文件所有权和 activation
仍须在 Phase 10 首启验收。

本节记录的是产生文档变更前的首次完整 PASS。包含本记录的最终 branch HEAD 还必须在 clean nixbox checkout 上重跑同一
短入口；精确 HEAD、时间、结果与最终临时目录清理写入 Issue #12 和 Draft PR，避免为了把 commit 自身写进文件而形成
自引用提交。

## 7. 不能由 VM 证明的事项

即使本套件全部通过，仍不能证明：

- Contabo 当前 firmware、disk alias、NIC、route、DNS 或 recovery UI 没有漂移；
- VNC/Rescue/Reinstall 现场可用；
- production strict host pin、两条真实 private-key path 或 host-key copy 已通过；
- destination 在真实 provider network 中可达；
- production disk 可清空，或允许 kexec、install、reboot。

这些事实必须在 Phase 10 由新的只读 preflight、实际 VNC 连接、精确 commit/closure/target/window 与当次批准重新冻结。
Phase 9 PASS 不是继续执行 production 的默认许可。
