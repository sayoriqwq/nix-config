# nix-config

一个 Flake 管理三台机器的声明式系统与用户配置：

| Output | 平台 | 角色 |
| --- | --- | --- |
| `macbook` | `aarch64-darwin` | macOS 主工作站，nix-darwin + Home Manager |
| `nixbox` | `x86_64-linux` | NixOS 次级工作站、Linux 实验与 server 预生产验证节点 |
| `server` | `x86_64-linux` | 最小 NixOS production host，只按真实需求增加服务 |

Git 和 `flake.lock` 是声明的来源，不是远程控制面、应用数据库或备份系统。Build 只证明配置可构建；真实 activation、网络变更、重启、磁盘操作和数据处理仍需当前人工批准。

## 架构

```text
flake.nix
  ├── hosts/<host>                 精确选择
  │    ├── intents/<intent>        跨 Software 的可执行组合
  │    ├── software/<software>     软件 package/config/service owner
  │    └── modules/                少量系统或跨 owner primitive
  ├── checks/                      窄 contract checks
  └── operations/                  人工触发、无隐式 target 的安全操作
```

- Software 是纵轴 owner：拥有一个软件的 package、稳定配置、服务与平台实现。
- Intent 是横轴组合：只通过 Software 的公开 Primary Capability 或 Extension 形成需求结果。
- Host 是最终 caller：显式选择 Intent、独立 Software 与机器事实；没有 registry、bundle、自动扫描或平台全选。
- 可变数据库、登录态、缓存、凭据和用户内容继续由应用或维护者拥有，不进入 Nix Store。

完整规则见 [项目上下文](CONTEXT.md)、[整体架构](docs/architecture/overview.md) 与 [模块边界](docs/architecture/module-boundaries.md)。

## 常用验证

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system
nix build .#nixosConfigurations.nixbox.config.system.build.toplevel
nix build .#nixosConfigurations.server.config.system.build.toplevel
```

🧪 检查格式、Flake contracts，并构建受影响主机；这些命令都不会 activation。

只有修改 server 的磁盘、启动、网络或 SSH 声明时，才需要在 `x86_64-linux` 节点额外构建按需恢复配置：

```fish
nix build .#nixosConfigurations.server-recovery-install.config.system.build.toplevel
```

🛟 只构建隔离 installation configuration，不连接或修改 production target；完整 VM 演练由对应 Issue 的行动卡单独批准。

## 文档入口

- [Agent 规范](AGENTS.md) 与 [中文译文](docs/agents/protocol.zh-CN.md)
- [领域词汇](CONTEXT.md)
- [整体架构](docs/architecture/overview.md)
- [模块与目录边界](docs/architecture/module-boundaries.md)
- [ADR](docs/adr/)
- [主机盘点](docs/runbooks/host-inventory.md)
- [macOS 恢复](docs/runbooks/restore-macos-environment.md)
- [nixbox 稳定访问](docs/runbooks/stable-workstation-access.md)
- [Server recovery](docs/runbooks/server-recovery.md)
- [Server 终端排障](docs/runbooks/server-terminal-troubleshooting.md)
- [Zed Preview / Stable 手动更新](docs/runbooks/update-zed-preview.md)
- [快捷键参考](docs/guide/SHORTCUTS.md)

## 变更流程

1. 以 GitHub Issue 固定目标、owned paths、禁止项、验证、风险和人工关卡。
2. 使用独立分支和 worktree；一个 PR 只处理一个 Issue。
3. 默认创建中文 Draft PR，记录精确命令、结果、风险与 rollback。
4. 没有维护者当前批准，不标 Ready、不 merge、不 activation。
5. 新服务必须独立说明 secret、数据、备份、恢复、网络与运行责任；不得恢复已退役的 Ubuntu 业务层。

## 安全边界

- 不提交明文 secret、private key、token、credential、解密输出或私有 `.env`。
- 不猜测 host、disk、boot、network、SSH、firewall、stateVersion 或运行态事实。
- 不用 generation rollback 代替应用数据恢复，也不把 external state 清理隐含在配置变更中。
- Disk、boot、filesystem、encryption、mount、remote network、DNS、firewall、SSH access、reboot、Rescue 和 Reinstall 都需要绑定 exact target 与 rollback 的当次人工批准。
