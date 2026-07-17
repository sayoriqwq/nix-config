# 项目上下文（Context）

## 1. 项目领域

本仓库的领域是“个人基础设施配置管理”：用 Nix 声明机器应当具备的系统设置、软件、用户环境和服务定义，并通过 Git 与构建结果审计变化。

仓库不是远程控制平台，也不是备份系统。Agent 可以编写和审查声明，真实机器上的激活、重装和数据操作仍受人工关卡约束。

## 2. 当前机器拓扑

以下名称是逻辑角色，不代表已经确认的真实主机名：

| 逻辑角色 | 当前状态 | 目标状态 | 主要管理层 |
| --- | --- | --- | --- |
| `macbook` | macOS，主要个人配置目前在此 | nix-darwin + Home Manager | Darwin 系统层、共享用户层、Mac 专属用户层 |
| `nixbox` | 空的 NixOS，但已有自身硬件与系统配置 | NixOS + Home Manager | NixOS 系统层、共享用户层、Linux 桌面用户层 |
| `server` | Ubuntu Server | 先独立 Home Manager，后迁移到 NixOS | 过渡用户层、最终 NixOS 服务器层 |

Phase 1 会确认真实用户名、CPU 架构、主机名、Nix 安装方式、已有配置位置和其他必要事实。

## 3. 核心概念

### 声明（Declaration）

存入 Git、可由 Nix 评估和构建的配置。声明描述期望状态，不等同于已经在机器上激活。

### 主机输出（Host output）

Flake 为一台具体机器提供的构建入口，例如 `darwinConfigurations.<host>`、`nixosConfigurations.<host>` 或过渡期的 `homeConfigurations."<user>@<host>"`。

### 共享用户层（Portable user layer）

由 Home Manager 管理、可以跨 macOS 与 Linux 使用的用户工具和配置，例如 Git、shell、编辑器、tmux、direnv 和通用 CLI。共享层不得包含桌面、硬件、系统服务或平台专属假设。

### 平台用户层（Platform user layer）

仍由 Home Manager 管理，但只适用于 Darwin、Linux Desktop 或 Server 的用户配置。

### 系统层（System layer）

由 nix-darwin 或 NixOS Modules 管理的操作系统设置、系统软件、服务、用户、网络和启动配置。

### 主机层（Host layer）

只属于一台机器的硬件、磁盘、启动、主机名、GPU、网络接口和状态版本等事实。

### 可变状态（Mutable state）

数据库、容器卷、浏览器资料、缓存、上传文件、运行时密钥和服务数据。它们不由 Git 配置同步，需要独立的备份、恢复和迁移方案。

### 机密（Secret）

密码、token、私钥、恢复码、私有环境变量等敏感材料。加密后的机密文件可以按策略提交；明文机密不得进入 Git 或 Nix Store。

### 激活（Activation）

把已构建配置应用到真实机器，例如 `darwin-rebuild switch`、`nixos-rebuild switch` 或 Home Manager switch。构建成功不代表 Agent 获得激活权限。

### 破坏性操作（Destructive operation）

可能导致数据、网络连通性或启动能力丢失的动作，包括重新分区、格式化、修改远程网络/防火墙/SSH、远程重装、重启和生产数据迁移。

### 人工关卡（Human approval gate）

Issue 或 PR 中明确记录、针对当前具体动作的维护者批准。以前的泛化同意不能自动视为对新的破坏性动作授权。

### 迁移阶段（Migration phase）

路线图中的一个独立、可验证工作单元。一个阶段对应一个 Issue 和一个 Draft PR，不跨阶段实现。

## 4. 不变量

1. Git 仓库是配置事实来源，`flake.lock` 是依赖事实来源。
2. 现有 NixOS 的 `system.stateVersion` 与硬件配置在缺乏证据时保持不变。
3. `modules/home/common.nix` 必须跨平台并适用于无桌面的服务器。
4. 系统配置与用户配置分层，平台特有内容不得泄漏到共享层。
5. Agent 不猜测主机事实，不自主执行激活或破坏性动作。
6. 服务器先恢复到最小可 SSH 的 NixOS，再恢复业务；系统迁移与业务重构不同时进行。
7. 每项重大工具或架构变化必须通过 Issue 与 ADR 解释，而不是顺手引入。

## 5. 不属于本仓库的职责

- 完整数据备份仓库；
- 密码管理器；
- 数据库 dump 的长期存储；
- 浏览器同步；
- 自动批准和执行服务器清盘；
- 在没有真实机器证据时生成“看起来能用”的硬件或网络配置。

## 6. 术语使用规则

Issue、PR、代码和文档应优先使用本文件定义的概念。需要新增概念时，先判断它是否真的属于本项目；若属于，应在同一 PR 中更新本文件或对应 ADR，避免同一概念出现多套名称。
