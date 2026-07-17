# ADR-0001：一个 Flake 管理多台主机

- **状态：** 已接受
- **日期：** 2026-07-17
- **决策范围：** 仓库级

## 背景

需要管理一台 macOS、一台 NixOS 工作站和一台服务器。三台机器共享部分用户配置，但系统、硬件和角色不同。如果使用多个互相复制的仓库或让机器之间直接同步配置，很容易出现版本漂移、重复修改和无法确认“哪一份是真的”。

## 决策

使用一个 Git 仓库和一个顶层 Flake：

- `flake.lock` 固定所有 inputs；
- 每台机器拥有独立、明确命名的 output；
- 主机通过模块组合共享配置，不复制完整配置；
- macOS 使用 `darwinConfigurations`；
- NixOS 工作站与最终服务器使用 `nixosConfigurations`；
- Ubuntu 过渡期使用 standalone `homeConfigurations`；
- `flake.nix` 只负责 inputs、outputs 和少量组合逻辑，具体配置进入模块。

初期使用普通 Flake 代码，不立即引入 flake-parts、Blueprint 或自动主机发现框架。

## 结果

### 正面

- 所有机器共享同一个依赖锁和审计历史；
- 可在一台机器上 build 另一台机器的配置（架构允许时）；
- 共享边界通过 import 关系显式表达；
- 更新 inputs 可以在一个 PR 中比较三台机器的影响；
- Codex 只需理解一个仓库和一套治理协议。

### 代价

- `flake.nix` 需要维护多种 output；
- Darwin 与 Linux 可能需要不同 nixpkgs 分支或平台处理；
- 需要严谨控制模块边界，避免所有逻辑集中到一个文件；
- 跨架构 build 可能需要 remote builder 或只做 evaluation。

## 被否决的替代方案

### 每台机器一个仓库

会重复用户配置和依赖更新，难以保持一致，不采用。

### 用 rsync 同步 `/etc/nixos` 或 dotfiles

无法可靠表达平台差异、依赖版本和变更原因，不采用。

### 一开始使用大型 Flake 框架

当前主机数量有限，框架会在理解真实需求前增加抽象。等 v1 稳定后再根据痛点通过新 ADR 评估。

## 复审条件

出现以下情况时重新评估：

- 主机/用户数量显著增长；
- `flake.nix` 的组合代码成为主要维护成本；
- 需要统一部署、mesh networking、备份编排或多所有者权限；
- 有数据证明现有结构阻碍测试或复用。
