# Phase 11：SOPS / age 机密能力事实

> 范围：Issue #10 / PR #102 的历史验收事实，以及后续 reconcile 状态。本文只记录公开 recipient、声明式运行时合同和人工关卡；不得记录 identity、私钥内容、真实 secret、解密输出或凭据。Phase 11 已完成并合并。

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

## 3. 验收时的最小权限矩阵（历史）

| 加密文件 | 管理员 | macbook | nixbox | server |
| --- | --- | --- | --- | --- |
| `secrets/macbook/phase11-demo.yaml` | 可恢复/编辑 | 可解密 | 否 | 否 |
| `secrets/nixbox/phase11-demo.yaml` | 可恢复/编辑 | 否 | 可解密 | 否 |
| `secrets/server/phase11-demo.yaml` | 可恢复/编辑 | 否 | 否 | 可解密 |

同一 host rule 中的两个 recipient 是独立解密入口，不使用 Shamir threshold。任何新增 recipient 都必须说明它为何需要读取该 host 的全部文件。

## 4. 验收时的运行时合同（历史）

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
- `nix flake check path:.`：PASS；当时的 macOS system 与 Phase 11 两项策略检查均通过；
- `nix build --no-link path:.#checks.aarch64-darwin.phase11-admin-key-policy`：PASS；helper 的拒绝覆盖、owner/mode 与临时 identity 生命周期测试通过；
- `nix build --no-link path:.#checks.aarch64-darwin.phase11-sops-policy`：PASS；三个文件均被 SOPS 识别为密文，每个文件恰有管理员加对应 host 两个 recipient，仓库 private-key marker 扫描通过；
- `nix build --no-link --print-out-paths path:.#darwinConfigurations.macbook.system`：PASS，输出为 `/nix/store/8sxjrv29ga5sbi86b6hci2x4f1flbvhw-darwin-system-26.05.c3e90c8`；
- 将同一不可变 flake archive 复制到 nixbox 的 Nix Store 后，分别构建 `nixosConfigurations.nixbox.config.system.build.toplevel` 与 `nixosConfigurations.server.config.system.build.toplevel`：PASS，输出分别为 `/nix/store/g6j29b97n4wi1grrf6ml0cbj4bz6why2-nixos-system-nixos-26.05.20260719.fd14620` 和 `/nix/store/ji49z8k49czg5sw28c92l6fv0nygfwc8-nixos-system-server-26.05.20260719.fd14620`。

nixbox 首次构建曾因其到 `proxy.golang.org` 超时而无法取得 sops-nix 的固定 Go 依赖；把 macbook 已构建的同一 Nix Store 固定输出复制到 nixbox 后重试通过。这是 builder 网络可达性问题，不是配置求值或构建失败。所有验证只产生 Nix Store 路径；没有读取管理员 identity、解密值或 host private key。

## 6. 首次 activation 验证

macbook 于 2026-08-04 在维护者明确批准后，从提交 `6d24b68` 执行首次 activation：

- `darwin-rebuild switch --flake path:/Users/sayori/Desktop/nix-config#macbook`：PASS；
- sops-nix 导入 `/etc/ssh/ssh_host_ed25519_key` 后报告的 public age fingerprint 与已记录 macbook recipient 完全一致；
- `/run/secrets/phase11-demo`：普通文件，owner `sayori`、group `staff`、mode `0400`，PASS；
- 非生产 demo 内容由维护者仅在 macbook 本机查看并记录 PASS，内容未进入命令日志、Issue、PR、聊天或本文。

该批准不覆盖 nixbox、server、PR 合并或 production secret。

nixbox 于 2026-08-04 在维护者另行明确批准后，从提交 `e61672b` 执行首次 activation：

- 当前提交的不可变 Flake source 在 nixbox 原生构建 PASS，批准的 system closure 为 `/nix/store/j6kxka8p7w6fczid9yky76kzya88x2yr-nixos-system-nixos-26.05.20260719.fd14620`；
- 经过 SHA-256、owner 和 mode 验证的无参数入口调用标准 `nixos-rebuild switch`，最终报告 `activation=pass`，`/run/current-system` 精确指向批准 closure；
- sops-nix 导入 `/etc/ssh/ssh_host_ed25519_key` 后报告的 public age fingerprint 与已记录 nixbox recipient 完全一致；
- `/run/secrets/phase11-demo`：普通文件，owner `sayori`、group `users`、mode `0400`，PASS；
- system state 为 `running`、Home Manager result 为 `success`、failed unit 为 0；
- 非生产 demo 内容由维护者仅在本机查看并记录 PASS；该值不是凭据。验收记录不包含任何真实 secret；
- 前序派发尝试分别因预检 attribute 写错、`/tmp` 入口提前消失和 RTK 缓冲远端 sudo 提示而在 activation 前失败关闭；每次均确认原 system 未变、secret 不存在且 failed unit 为 0。最终成功后，稳定入口按已验证 SHA 删除，维护者既有 checkout 未被修改。

该批准不覆盖 server、PR 合并、reboot 或 production secret。

server 于 2026-08-04 在维护者另行明确批准后，从提交 `dd3ab76` 执行首次 activation：

- 当前提交的不可变 Flake source 先在 nixbox 构建出 `/nix/store/ji49z8k49czg5sw28c92l6fv0nygfwc8-nixos-system-server-26.05.20260719.fd14620`，server 随后从同一 source 本机构建出完全相同的 closure；
- 经过 SHA-256、owner、mode、Bash 语法、TTY 与参数拒绝验证的 root 稳定入口调用标准 `nixos-rebuild switch`，最终报告 `activation=pass`；`/run/current-system` 与 system profile 均精确指向批准 closure；
- sops-nix 导入 `/etc/ssh/ssh_host_ed25519_key` 后报告的 public age fingerprint 与已记录 server recipient 完全一致；
- `/run/secrets/phase11-demo`：普通文件，owner `sayori`、group `users`、mode `0400`，PASS；
- system state 为 `running`、Home Manager result 为 `success`、failed unit 为 0；既有 root break-glass SSH 在 activation 后继续 PASS，未执行 reboot；
- 非生产 demo 内容由维护者仅在本机查看并记录 PASS；该值不是凭据。验收记录不包含任何真实 secret；
- 普通 `server` 名称未命中已验收入口、root 默认 Bash 与预检 Fish 语法不匹配时均在修改前失败关闭。nixbox 到 server 的 Nix Store 复制因 destination `require-sigs` 拒绝未签名本地构建而停止；一次性的 source trust 不能绕过 destination 策略，因此没有关闭或持久修改签名要求，改由 server 本地构建；
- activation 后清理入口的首次 SSH 连接瞬时超时，复核确认 system 仍为 `running` 且 failed unit 为 0；重连后按已验证 SHA 删除稳定入口，临时目录已清理。

该批准不覆盖 reboot、PR 合并、旧业务恢复或 production secret。

## 7. Reconcile 后的当前状态

Issue #10 已关闭，PR #102 已合并。后续维护 Issue #103 将验收用 demo 的三份声明和 SOPS 密文、管理员 identity 初始化 helper 及其测试从仓库删除；`modules/capabilities/secret-deployment/` 只保留 sops-nix 与每机 SSH-host-derived age identity 的部署基础，当前没有实际 secret 声明。

删除声明不会自行修改真实机器。macbook、nixbox 与 server 上既有 `/run/secrets/phase11-demo` 只有在各自主机未来获得单独批准并激活 reconcile 后的配置时才会移除；本次仓库清理不执行 activation，也不把运行时残留误报为已删除。

任何真实 production secret 必须在独立 Issue 重新批准，并确认消费者、可恢复性、轮换代价、runtime metadata、服务 reload/restart 与失败回滚。Phase 12 已明确延后。
