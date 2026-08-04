# Phase 11：SOPS / age 机密能力事实

> 范围：Issue #10。本文只记录公开 recipient、声明式运行时合同和人工关卡；不得记录 identity、私钥内容、真实 secret、解密输出或凭据。

## 1. 前置状态

- Phase 10 Issue #13 已关闭；server 已运行冻结的最小 NixOS，首次启动和独立第二次 reboot 验收均 PASS。
- server 未恢复旧 Ubuntu 服务、数据或 production secret，不存在本阶段需要迁移的旧明文。
- macbook、nixbox 与 server 均已有 Ed25519 SSH host identity；Phase 11 只读取 public half 并派生 age recipient，不读取或生成 host private key。

## 2. 公开 recipient

| 角色 | public age recipient | 私钥所有权 |
| --- | --- | --- |
| 管理员恢复 | `age1lece5fgs54jycjjhclgtwvugrxuzajacd0mdsxna8v3sunj9tdsqfwdyyn` | macbook SOPS 默认目录；恢复副本由维护者在仓库外自行管理 |
| macbook | `age1a49p4p9k0xwkwkh9e0t3zw88hwsuafs4t37nvfw3vtcq3kux0f0qavyd8r` | 既有 `/etc/ssh/ssh_host_ed25519_key`；仓库外 |
| nixbox | `age1xnjsz6n9uzsmj3w5umdwv9scltt035rc8wne0u2hsh2zuafcdu2qhu5knn` | 既有 `/etc/ssh/ssh_host_ed25519_key`；仓库外 |
| server | `age1zsv4uz44lkr0emz6u49jtwgg3svevm02e5xwgcp9fqwtw56vfv8qf60g8c` | Phase 10 保留的 `/etc/ssh/ssh_host_ed25519_key`；仓库外 |

公开 recipient 由维护者现有 strict host-key 路径取得 public key 后本地转换；输出中没有 private key、private path、host fingerprint、credential 或真实 secret。

管理员于 2026-08-04 运行仓库提供的无参数 helper。只读 metadata 验证 identity 为 `sayori:staff`、mode `0600`、普通文件；Agent 未读取内容。维护者同日确认恢复副本已存放在其认可的安全位置，并自行承担介质、位置、保护方式与可恢复性管理；具体位置和内容不进入仓库或验收记录，该事项不再阻断 Phase 11 activation。

锁定实现版本：sops-nix `f1406619a3884cd5c47992a70b8b35c9c0fcb4c9`，Nixpkgs 提供 age `1.3.1`、SOPS `3.13.2` 与 SSH-to-age `1.2.0`。

## 3. 最小权限矩阵

| 加密文件 | 管理员 | macbook | nixbox | server |
| --- | --- | --- | --- | --- |
| `secrets/macbook/phase11-demo.yaml` | 可恢复/编辑 | 可解密 | 否 | 否 |
| `secrets/nixbox/phase11-demo.yaml` | 可恢复/编辑 | 否 | 可解密 | 否 |
| `secrets/server/phase11-demo.yaml` | 可恢复/编辑 | 否 | 否 | 可解密 |

同一 host rule 中的两个 recipient 是独立解密入口，不使用 Shamir threshold。任何新增 recipient 都必须说明它为何需要读取该 host 的全部文件。

## 4. 运行时合同

三台机器的非生产示例都声明为：

- key：`phase11-demo`；
- path：`/run/secrets/phase11-demo`；
- owner：`sayori`；
- group：Darwin 为 `staff`，NixOS 取 `sayori` 用户的声明 group；
- mode：`0400`；
- service restart/reload：无；该示例不被任何 production service 消费；
- secret source：对应 host 的 SOPS YAML，加密文件可以进入 Nix Store，解密值不能作为 Nix 字符串插值。

## 5. 非激活验证

2026-08-04 在未执行任何 `switch`、activation 或远端 server 连接的前提下完成：

- `nix fmt -- --check .`：PASS；
- `nix flake check path:.`：PASS；当前 macOS system 与 Phase 11 两项策略检查均通过；
- `nix build --no-link path:.#checks.aarch64-darwin.phase11-admin-key-policy`：PASS；helper 的拒绝覆盖、owner/mode 与临时 identity 生命周期测试通过；
- `nix build --no-link path:.#checks.aarch64-darwin.phase11-sops-policy`：PASS；三个文件均被 SOPS 识别为密文，每个文件恰有管理员加对应 host 两个 recipient，仓库 private-key marker 扫描通过；
- `nix build --no-link --print-out-paths path:.#darwinConfigurations.macbook.system`：PASS，输出为 `/nix/store/8sxjrv29ga5sbi86b6hci2x4f1flbvhw-darwin-system-26.05.c3e90c8`；
- 将同一不可变 flake archive 复制到 nixbox 的 Nix Store 后，分别构建 `nixosConfigurations.nixbox.config.system.build.toplevel` 与 `nixosConfigurations.server.config.system.build.toplevel`：PASS，输出分别为 `/nix/store/g6j29b97n4wi1grrf6ml0cbj4bz6why2-nixos-system-nixos-26.05.20260719.fd14620` 和 `/nix/store/ji49z8k49czg5sw28c92l6fv0nygfwc8-nixos-system-server-26.05.20260719.fd14620`。

nixbox 首次构建曾因其到 `proxy.golang.org` 超时而无法取得 sops-nix 的固定 Go 依赖；把 macbook 已构建的同一 Nix Store 固定输出复制到 nixbox 后重试通过。这是 builder 网络可达性问题，不是配置求值或构建失败。所有验证只产生 Nix Store 路径；没有读取管理员 identity、解密值或 host private key。

## 6. 人工关卡

以下动作尚未因代码或 build 自动获批：

1. 维护者在 macbook 生成管理员 identity，只把 public recipient 交给实现；
2. 审阅 Draft PR 后分别批准 macbook、nixbox、server 的首次 activation；
3. activation 后只检查存在性、owner、group、mode 与非生产值是否匹配，不把内容复制到 Issue、PR、聊天或日志；
4. 任何真实 production secret 在 Phase 12 或独立 Issue 再批准，并重新确认该 secret 的可恢复性与轮换代价。
