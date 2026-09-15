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
  └── hosts/<host>                 精确选择
       ├── intents/<intent>.nix    一起选择的使用需求
       ├── software/<software>     软件 package/config/service owner
       └── shared/                 有实际复用的公共数据与声明
```

- Software 聚合同一软件的声明、材料、实现与外部状态边界；选择软件不代表拥有其全部状态。
- Intent 表达一起选择的使用需求，通过 Software 公开行为显式列出依赖，可以只涉及一个软件。
- Host 是最终 caller：显式选择 Intent、独立 Software 与机器事实；没有 registry、bundle、自动扫描或平台全选。
- 可变数据库、登录态、缓存、凭据和用户内容继续由应用或维护者拥有，不进入 Nix Store。

完整规则见 [项目上下文](CONTEXT.md)、[整体架构](docs/architecture/overview.md) 与 [模块边界](docs/architecture/module-boundaries.md)。

## 常用验证

纯文档修改检查链接、术语与规范一致性。Nix 修改先格式化并求值受影响的 Host，必要时通过 nh 或原生命令构建；按本次改动在激活后验收实际功能：

```fish
nix fmt -- --check .
nix eval --raw .#darwinConfigurations.macbook.system.drvPath
nh darwin build . -H macbook --diff always
nix build --no-link .#nixosConfigurations.nixbox.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.server.config.system.build.toplevel
```

🧪 按影响范围验证声明；构建不会激活；Linux 构建需对应架构的构建条件。

## 文档入口

- [维护约定](AGENTS.md)
- [领域词汇](CONTEXT.md)
- [日常 Nix 维护](docs/runbooks/daily-nix-maintenance.md)
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
- [快捷键参考](docs/runbooks/shortcuts.md)

## 日常维护

使用 nh 和按需增加的包装命令，见[日常 Nix 维护](docs/runbooks/daily-nix-maintenance.md)。Agent 的必要约定集中在 [AGENTS.md](AGENTS.md)。
