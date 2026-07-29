# nix-config

这是一个用于管理个人设备与服务器的声明式 Nix 配置仓库。目标是在一个 Git 仓库中，以可复现、可审计、可逐步回滚的方式管理：

- 一台 macOS 工作站；
- 一台 NixOS 工作站；
- 一台当前运行 Ubuntu、最终迁移到 NixOS 的服务器；
- 三台机器按真实需求显式选择的能力模块。

## 当前状态

仓库目前处于 **Phase 5.5：建立能力模块与主机组合新基线**。

Phase 0–5 已完成治理、主机盘点、macbook 的 nix-darwin/Home Manager/应用接入，以及 nixbox 的原有 NixOS 系统基线。Phase 6 实施中发现 `common` / `desktop` / 平台 bundle 会让 nixbox 隐式继承 macbook 全量配置，因此先用 #66 把 macbook 重组为显式 capability imports，并保持 nixbox Phase 5 不变。

## 目标模型

```text
                  Git repository + flake.lock
                             │
                    capability modules
                 ┌───────────┼───────────┐
                 │           │           │
             macbook       nixbox      server
             全量组合       按需子集     headless 子集
            nix-darwin      NixOS       NixOS 终态
          + Home Manager + Home Manager + Home Manager
```

当前 server 仍运行 Ubuntu，但不建立 standalone Home Manager 过渡层：按只读盘点、最小 NixOS、隔离 VM 测试、人工批准直接替换、Secret、业务恢复的顺序推进。

Git 只同步声明式配置。数据库、浏览器资料、服务数据、备份和其他可变状态不通过此仓库同步。

## 核心原则

1. **一个 Flake，多台主机输出。** 每台机器只构建自己的 output。
2. **用户层与系统层分离。** Home Manager 管用户环境；nix-darwin 和 NixOS Modules 管操作系统。
3. **能力组合不等于继承。** Host 显式 import 需求能力；基础配置留在能力内部，不使用 `common`、`desktop` 或泛化 Linux bundle 全选。
4. **每个阶段一个 Issue、一个 Draft PR。** 当前阶段完成并经过人工验收后才进入下一阶段。
5. **危险操作必须人工批准。** 磁盘、启动、网络、防火墙、远程重装、重启和数据迁移不能由 Agent 自主执行。
6. **优先使用成熟模块。** 先查 Home Manager、NixOS 和 nix-darwin 现有选项，再考虑脚本或自定义模块。
7. **不把秘密放进 Nix Store 或 Git。** 后续统一使用 sops-nix 与 age 管理需要部署的机密。

## 文档导航

- [项目上下文与术语](CONTEXT.md)
- [整体架构](docs/architecture/overview.md)
- [模块与目录边界](docs/architecture/module-boundaries.md)
- [主机角色与能力矩阵](docs/architecture/capability-matrix.md)
- [迁移路线图](docs/plans/migration-roadmap.md)
- [主机盘点手册](docs/runbooks/host-inventory.md)
- [macOS 最小 nix-darwin 接入手册](docs/runbooks/bootstrap-macos.md)
- [Phase 3 macOS 用户层盘点](docs/inventory/phase-3-macos-home.md)
- [macOS Home Manager 迁移手册](docs/runbooks/migrate-macos-home-manager.md)
- [Phase 4 macOS 软件所有权终态](docs/inventory/phase-4-macos-software-ownership.md)
- [Phase 4 完成矩阵](docs/inventory/phase-4-completion-matrix.md)
- [macOS 环境恢复与回滚手册](docs/runbooks/restore-macos-environment.md)
- [架构决策记录](docs/adr/)
- [中文 Agent 协议](docs/agents/protocol.zh-CN.md)
- [英文规范性 Agent 协议](AGENTS.md)

## 协作方式

```text
GitHub Milestone
       │
       ├── Phase Issue（中文目标、边界、验证与人工关卡）
       │          │
       │          └── agent/phase-N-* 分支
       │                     │
       │                     └── Draft PR
       │                             │
       │                       自动/本地构建检查
       │                             │
       └────────────────────── 人工机器验证与合并
```

Codex 或其他 Agent 在开始工作前必须阅读 `AGENTS.md`、当前 Issue、`CONTEXT.md`、相关 ADR 与架构文档。面向维护者的说明使用中文；为了减少模型误解，规范性强约束保留英文，并提供同步的中文译文。

## 目录模型

目录会在对应阶段按需建立，不预先制造空实现：

```text
flake.nix
flake.lock
hosts/
  macbook/
  nixbox/
  server/
modules/
  capabilities/
  home/
    capabilities/
    common/       # internal primitives
    desktop/      # internal primitives
    darwin/       # internal primitives
  darwin/
  nixos/
dotfiles/
secrets/
docs/
```

逻辑 output 名称已在 Phase 1 确认为 `macbook`、`nixbox`、`server`。它们不要求与真实主机名相同；脱敏后的平台事实见 [`docs/inventory/phase-1-hosts.md`](docs/inventory/phase-1-hosts.md)。

## 安全提示

不要从这个仓库中复制并执行磁盘或远程安装命令，除非对应 Issue 已明确记录：完整备份、恢复验证、目标磁盘、启动模式、网络方案、SSH 恢复路径以及维护者的当次批准。
