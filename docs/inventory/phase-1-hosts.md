# Phase 1 主机盘点

本文只记录建立最小 Flake 骨架所需的脱敏事实。原始命令输出保留在对应机器或维护者本地，不提交公网地址、Wi-Fi 名称、文件系统 UUID、序列号或其他敏感值。

## macOS 工作站

- 逻辑角色：macOS 工作站
- 拟定 output：`macbook`（待维护者最终确认）
- OS / 版本：macOS 26.6
- 架构：Apple Silicon，目标平台 `aarch64-darwin`
- Nix：尚未安装
- 主用户与 home：`sayori`，`/Users/sayori`
- 默认 shell：`/opt/homebrew/bin/fish`
- Homebrew：已安装于 `/opt/homebrew`；formula 与 cask 原始清单仅保留在本地
- 现有 Nix 配置：无
- 现有 `system.stateVersion` / `home.stateVersion`：不适用；首次引入时必须按对应模块的兼容性规则设置并保留
- 主机名：未提交，Phase 1 的 Flake evaluation 不依赖该值
- 未确认事实：Nix 安装方案、逻辑 output 最终名称、首次 nix-darwin 激活前的回滚方式
- 证据采集日期：2026-07-20
- 证据来源：维护者 Mac 本地只读命令

## NixOS 工作站（ThinkPad）

- 逻辑角色：NixOS 工作站
- 拟定 output：`nixbox`（待维护者最终确认）
- 当前配置中的主机名：`nixos`
- OS / 版本：NixOS 26.05，采集时版本为 `26.05.1947.a0374025a863 (Yarara)`
- 架构：`x86_64-linux`
- 内核：Linux 6.18.35
- Nix：由 NixOS 系统管理，版本 `2.34.7`；`nix-command`/Flakes 当前未启用；channel/profile 尚未采集
- 主用户：`sayori`；home 路径和默认 shell 尚未由只读命令确认
- 现有配置位置：`/etc/nixos/configuration.nix` 与 `/etc/nixos/hardware-configuration.nix`
- `system.stateVersion`：`26.05`，来源为现有 `configuration.nix`
- `home.stateVersion`：未发现 Home Manager 配置
- 启动配置：现有配置启用 systemd-boot 和 EFI variables，`/boot` 为 1 GiB vfat；实时启动模式仍需用 `/sys/firmware/efi` 确认
- 存储摘要：约 512 GB NVMe；1 GiB vfat `/boot`，其余为 ext4 根文件系统；无 swap
- 图形硬件：Intel Iris Xe，采集时使用 `i915` 驱动
- 网络硬件：Intel Wi-Fi，采集时使用 `iwlwifi`；NetworkManager 已启用；网络名称和地址不提交
- 桌面与基础服务：GNOME + GDM、PipeWire、CUPS、Firefox
- 原始硬件配置：已在维护者本地保存，包含文件系统 UUID，因此 Phase 1 不复制进本仓库；Phase 5 接入时必须保持原样并重新审查
- 已知快照缺陷：传输到 Mac 的 `configuration.nix` 仍含一条无效的自定义 `trusted-public-keys` 值（以 `RwA=` 结尾）。该副本早于真实机器上的修复，不得直接用于构建或部署；Phase 5 前必须重新同步修复后的 `/etc/nixos/configuration.nix`
- 未确认事实：逻辑 output 最终名称、home 路径、默认 shell、实时 UEFI/BIOS 状态、enabled services、当前 generation 与回滚路径
- 证据采集日期：2026-06-21 与 2026-07-20
- 证据来源：维护者提供的本地快照 `thinkpad-initial`，包括 NixOS 配置、`nixos-version`、`uname`、`lsblk`、`lspci` 和 NetworkManager 设备摘要

## Ubuntu Server

- 逻辑角色：Ubuntu Server（未来迁移为 NixOS Server）
- 拟定 output：`server`（待维护者最终确认）
- 当前事实：尚未开始采集
- 未确认事实：Issue #3 与 `docs/runbooks/host-inventory.md` 要求的全部服务器事实

## Phase 1 当前结论

- 已确认平台：macOS 为 `aarch64-darwin`，NixOS 工作站为 `x86_64-linux`。
- 当前仍不能完成主机 output：三个逻辑 output 名称尚未由维护者最终确认，Ubuntu Server inventory 为空。
- 当前可以继续的工作：确认 inputs 兼容关系并设计不包含虚构主机值的最小 Flake evaluation 入口。
- 本阶段不得激活任何配置；NixOS 原始配置的正式导入属于 Phase 5。
