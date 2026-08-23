# nix-config

这是一个用于管理个人设备与服务器的声明式 Nix 配置仓库。目标是在一个 Git 仓库中，以可复现、可审计、可逐步回滚的方式管理：

- 一台 macOS 工作站；
- 一台 NixOS 工作站；
- 一台已运行最小 NixOS、后续按需增加生产能力的服务器；
- 三台机器按真实需求显式选择的能力模块。

## 当前状态

Phase 0–11 已完成：三台机器均由同一 Flake 管理，server 已从 Ubuntu 替换为最小 NixOS；Phase 11 的 SOPS/age 非生产路径曾完成三机实机验收，但无 consumer 的 readiness 已由 Issue #205 退役。Phase 12 按维护者决定明确延后；当前只处理独立维护 Issue 与按需能力。Issue #99 正在把 server 的长期交互管理恢复为 `sayori + sudo`：macbook 与 nixbox 使用不同现有密钥登录同一个远端 `sayori` 用户，root SSH 关闭；仓库变更不等于 production 已 activation。

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

server 当前运行已经验收的最小 NixOS。旧 Ubuntu、业务与数据不恢复；新的服务、数据与 production secret 只在出现真实需求后，通过独立 Issue 建立各自的部署、备份、恢复和回滚合同。

当前控制关系为：

```text
维护者 ──macbook maintenance identity──▶ server:sayori ──sudo / sudo -i──▶ root
   │                                         ▲
   └──实际 Unix 用户 `sayori`──▶ nixbox ─────┘
                                  独立 deploy identity
```

macbook 上的 `sayori` 是指向 server 的本地 SSH Host 别名，远端用户也固定为实际 Unix 用户 `sayori`。维护者使用 maintenance identity，日常单条提权用 `sudo`，确需连续 root 操作时用 `sudo -i`；不使用 `su`，也不设置 root password。nixbox 是维护者的次级 NixOS 工作站和 `x86_64-linux` 预生产节点；它以独立 deploy identity 登录同一个远端用户，并只在获批部署中使用 `sudo -n`。两把 key 的区别是凭据来源、撤销和轮换边界，不是两套 Unix 权限；root SSH、password 与 keyboard-interactive 登录均关闭，Contabo VNC 是已实连验证的带外恢复路径。

Git 只同步声明式配置。数据库、浏览器资料、服务数据、备份和其他可变状态不通过此仓库同步。

## 核心原则

1. **一个 Flake，多台主机输出。** 每台机器只构建自己的 output。
2. **用户层与系统层分离。** Home Manager 管用户环境；nix-darwin 和 NixOS Modules 管操作系统。
3. **能力组合不等于继承。** Host 显式 import 需求能力；基础配置留在能力内部，不使用 `common`、`desktop` 或泛化 Linux bundle 全选。
4. **每个阶段一个 Issue、一个 Draft PR。** 当前阶段完成并经过人工验收后才进入下一阶段。
5. **危险操作必须人工批准。** 磁盘、启动、网络、防火墙、远程重装、重启和数据迁移不能由 Agent 自主执行。
6. **优先使用成熟模块。** 先查 Home Manager、NixOS 和 nix-darwin 现有选项，再考虑脚本或自定义模块。
7. **不把秘密放进 Nix Store 或 Git。** 当前没有 secret consumer 或预置框架；未来需求必须独立立项并明确运行时权限、轮换与恢复合同。

## 文档导航

- [项目上下文与术语](CONTEXT.md)
- [整体架构](docs/architecture/overview.md)
- [模块与目录边界](docs/architecture/module-boundaries.md)
- [主机角色与能力矩阵](docs/architecture/capability-matrix.md)
- [迁移路线图](docs/plans/migration-roadmap.md)
- [主机盘点手册](docs/runbooks/host-inventory.md)
- [Server 终端运维与故障排查手册](docs/runbooks/server-terminal-troubleshooting.md)
- [macOS 最小 nix-darwin 接入手册](docs/runbooks/bootstrap-macos.md)
- [Phase 3 macOS 用户层盘点](docs/inventory/phase-3-macos-home.md)
- [macOS Home Manager 迁移手册](docs/runbooks/migrate-macos-home-manager.md)
- [Phase 4 macOS 软件所有权终态](docs/inventory/phase-4-macos-software-ownership.md)
- [macOS 登录项与 launchd 盘点](docs/inventory/macos-startup-items.md)
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
docs/
```

逻辑 output 名称已在 Phase 1 确认为 `macbook`、`nixbox`、`server`。它们不要求与真实主机名相同；脱敏后的平台事实见 [`docs/inventory/phase-1-hosts.md`](docs/inventory/phase-1-hosts.md)。

## 安全提示

不要从这个仓库中复制并执行磁盘或远程安装命令，除非对应 Issue 已明确记录：完整备份与恢复验证，或维护者对可丢弃 source data 的明确 waiver；以及目标磁盘、启动模式、网络方案、SSH 恢复路径和维护者的当次批准。数据 waiver 不构成格式化或安装授权。
