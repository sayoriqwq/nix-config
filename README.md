# nix-config

以 macOS 主工作站的日常使用为中心，在一个 Flake 中保存认可过的稳定配置，并按维护者选择复用到其他机器：

| Output | 平台 | 角色 |
| --- | --- | --- |
| `macbook` | `aarch64-darwin` | macOS 主工作站，nix-darwin + Home Manager |
| `nixbox` | `x86_64-linux` | NixOS 次级工作站、Linux 实验与 server 预生产验证节点 |
| `server` | `x86_64-linux` | 最小 NixOS production host，只按真实需求增加服务 |

Git 和 `flake.lock` 保存稳定声明；当前运行环境是实际状态的唯一事实来源。可以先在 Mac 调整，再保存希望复用的配置；每次应用前检查已声明字段，避免覆盖想保留的修改。未声明的额外设置不构成偏移。私有现场证据由独立 Macwarden 项目管理，不进入公开声明。管理约定见[主工作站管理](docs/architecture/workstation-management.md)。

Build 只证明配置可构建；真实 activation、远端访问、磁盘和生产数据操作仍需针对目标与动作的明确授权。

## 架构

```text
flake.nix
  ├── hosts/<host>                 精确选择
  │    ├── intents/<intent>        一起选择的使用需求
  │    ├── software/<software>     软件 package/config/service owner
  │    └── modules/                少量系统或跨 owner primitive
  ├── checks/                      窄 contract checks
  └── operations/                  人工触发、无隐式 target 的安全操作
```

- Software 聚合同一软件的声明、材料、实现与外部状态边界；选择软件不代表拥有其全部状态。
- Intent 表达一起选择的使用需求，通过 Software 公开行为显式列出依赖，可以只涉及一个软件。
- Host 是最终 caller：显式选择 Intent、独立 Software 与机器事实；没有 registry、bundle、自动扫描或平台全选。
- 可变数据库、登录态、缓存、凭据和用户内容继续由应用或维护者拥有，不进入 Nix Store。

完整规则见 [项目上下文](CONTEXT.md)、[整体架构](docs/architecture/overview.md) 与 [模块边界](docs/architecture/module-boundaries.md)。

## 常用验证

纯文档修改检查链接、术语与规范一致性。Nix 修改从下面选择相关检查和受影响的 output：

```fish
nix fmt -- --check .
nix flake check
nix build --no-link .#darwinConfigurations.macbook.system
nix build --no-link .#nixosConfigurations.nixbox.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.server.config.system.build.toplevel
```

🧪 按影响范围验证声明；构建不会激活，也不留下 result 链接。

只有修改 server 的磁盘、启动、网络或 SSH 声明时，才需要在 `x86_64-linux` 节点额外构建按需恢复配置：

```fish
nix build .#nixosConfigurations.server-recovery-install.config.system.build.toplevel
```

🛟 只构建隔离 installation configuration；完整 VM 演练需要在当前任务中明确范围与授权。

## 文档入口

- [Agent 规范](AGENTS.md) 与 [中文译文](docs/agents/protocol.zh-CN.md)
- [领域词汇](CONTEXT.md)
- [主工作站管理](docs/architecture/workstation-management.md)
- [整体架构](docs/architecture/overview.md)
- [模块与目录边界](docs/architecture/module-boundaries.md)
- [ADR](docs/adr/)
- [主机盘点](docs/runbooks/host-inventory.md)
- [macOS 恢复](docs/runbooks/restore-macos-environment.md)
- [nixbox 稳定访问](docs/runbooks/stable-workstation-access.md)
- [nixbox 桌面恢复](docs/runbooks/nixbox-desktop-recovery.md)
- [Server recovery](docs/runbooks/server-recovery.md)
- [Server 终端排障](docs/runbooks/server-terminal-troubleshooting.md)
- [Zed Preview / Stable 手动更新](docs/runbooks/update-zed-preview.md)
- [快捷键参考](docs/guide/SHORTCUTS.md)

## 变更流程

普通维护按当前明确请求，在现有 checkout 完成修改、必要验证和本地提交。保留与本次任务无关的未提交改动；不默认 push。

需要跨会话跟踪或协作时使用 Issue，需要审阅时使用 PR，需要并行隔离时使用 branch/worktree。它们都不是日常工作的前置条件。授权、验证与完成标准以 [Agent 规范](AGENTS.md) 为准，具体使用方式见[协作流程](docs/agents/issue-tracker.md)。

## 安全边界

- 不提交明文 secret、private key、token、credential、解密输出或私有 `.env`。
- 不猜测 host、disk、boot、network、SSH、firewall、stateVersion 或运行态事实。
- 不用 generation rollback 代替应用数据恢复，也不把 external state 清理隐含在配置变更中。
- Disk、boot、filesystem、encryption、mount、remote network、DNS、firewall、SSH access、reboot、Rescue 和 Reinstall 都需要绑定 exact target 与 rollback 的当次人工批准。
