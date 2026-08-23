# Server recovery 隔离 Operation

> Phase 9 / Issue #12 首次建立了不连接 production 的 VM 恢复演练。Issue #195 在 V3 中从已批准需求重新实现长期 Operation；旧 `tests/server-recovery` implementation 已删除，不是当前实现或设计输入。

## 1. 当前调用图

```text
production
  flake -> hosts/server + production modules

validation
  flake -> operations/server-recovery
        -> production modules + test-only install module -> disko installTest
        -> production modules + test-only network node   -> runNixOSTest

exposure
  checks.x86_64-linux.server-recovery-policy
  checks.x86_64-linux.server-recovery-network
  packages/apps.x86_64-linux.server-recovery-test
```

`nixosConfigurations.server` 不 import Operation、check 或 test-only module。`nixosConfigurations.server-recovery-install` 只给锁定的 nixos-anywhere `--vm-test` 暴露隔离安装 engine；它使用 `/dev/vda`、文档网段和无 private half 的测试 public-key slots，不是 production 配置或部署入口。

## 2. 安全边界

维护者短入口仍为：

```fish
nix run .#server-recovery-test
```

🧪 在具备 KVM 的 x86_64-linux clean checkout 中串行运行隔离恢复验证，不接受目标参数。

Runner 在任何构建或 VM 启动前拒绝：

- 任意额外参数、host、address、SSH identity 或 target；
- 非 `x86_64-linux`；
- 当前用户不可读写的 `/dev/kvm`；
- dirty checkout；
- 少于 100 GiB 的可用空间。

Runner 不使用 `sudo`，不接受 production destination，也不在真实机器上运行 install、activation、reboot、disko 或网络变更。所有 destructive disk action 只发生在 nixos-anywhere 创建的一次性 VM disk 中；网络测试只连接 RFC 5737 / RFC 3849 文档网段的测试 VLAN。

## 3. 验证层

### Production policy

`server-recovery-policy` 从公开的最终 Nix 配置观察：

- production `disko.tests` 保持上游默认空值，证明 recovery overlay 不在 production graph；
- production firewall 只开放 TCP 22，SSH 拒绝 password、keyboard-interactive 与 root login，wheel sudo 不要求密码；
- production 保留两类已批准 public-key slot；
- 隔离安装配置改用 `/dev/vda`、独立 hostname、单一 dummy network 与两枚无 private half 的测试 key；
- `server-recovery-test` 对任意 target-like 参数立即失败。

### Disk/install

Runner 调用仓库已锁定的 nixos-anywhere `--vm-test`，构建 `server-recovery-install.config.system.build.installTest`。该 test-only 配置复用 production declarations，并只在 Operation 内覆盖：

- BIOS 测试 VM 的 `/dev/vda`；
- GPT `EF02` + ext4 root + no-swap 验证；
- 隔离 hostname、文档网段与无 private half 的 public-key slots；
- 启动后的 SSH、sudo 与 firewall policy readback。

### Network/SSH/firewall

`server-recovery-network` 使用 `pkgs.testers.runNixOSTest` 启动 server 与 gateway 两个隔离节点。Server 复用 production modules，但 test-only node 关闭 disko filesystem realization、移除 production public keys，并把 authorized-key source 改为 `/run` 中的 runtime file。

测试在 VM 内生成两枚临时 private key，分别验证 maintenance 与 deploy 登录、`sudo -n`、root login 拒绝、password-only 拒绝、IPv4/IPv6 TCP 22，以及 firewall 对未声明 TCP 8080 listener 的阻断。测试结束前删除 runtime key、known-hosts 与 authorized-key file；这些材料不进入 Git 或 Nix Store。

## 4. 执行顺序与结果记录

短入口串行执行：

1. production policy 与 runner 参数边界；
2. production server closure build，不 activation；
3. nixos-anywhere/disko 隔离安装 VM；
4. runNixOSTest 双栈、SSH 与 firewall 黑盒测试。

macOS 可以执行纯求值和本机可用检查，但不能把跨架构 evaluation 冒充 VM PASS：

```fish
nix flake check --no-build --all-systems
nix eval --raw .#nixosConfigurations.server.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.server-recovery-install.config.system.build.installTest.drvPath
nix eval --raw .#checks.x86_64-linux.server-recovery-network.drvPath
```

🔎 在 macOS 上确认 production 与 Operation 的公开输出可求值；不启动 x86_64 VM。

最终 x86_64-linux PASS 必须记录 clean checkout 的 exact commit、执行时间、KVM 可用性、命令结果及无残留 VM；nixbox 当前不可达时，该运行证据延后到最终 release Gate，不阻塞仓库内 V3 重构。

## 5. 历史证据

Phase 9 首次完整演练在 2026-07-31 于 nixbox 完成，exact commit 为 `41f17684cfbf8079374bbfaf9050362d8d80d280`，结果为 `phase9-test: PASS; no production target was accepted or contacted`。该记录只证明当时的隔离 VM 行为；旧 runner、overlay、policy 和 test source 已在 V3 退役，不能复制或继续约束新实现。

## 6. VM 不能证明的事项

即使 Operation 全部通过，仍不能证明：

- provider 当前 firmware、disk alias、NIC、route、DNS 或 recovery UI 没有漂移；
- VNC/Rescue/Reinstall 与真实 destination 当前可达；
- production private-key path、host-key pin 或 provider network 已通过；
- 允许任何真实 disk、install、activation、network、SSH、firewall 或 reboot 动作。

真实机器动作必须在新的 Issue/PR action card 中冻结 exact commit、target、窗口、readback、rollback 与 rescue path，并取得当次人工批准。
