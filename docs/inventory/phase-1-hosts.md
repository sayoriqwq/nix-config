# Phase 1 主机盘点

本文只记录建立最小 Flake 骨架所需的脱敏事实。原始命令输出保留在对应机器或维护者本地，不提交公网地址、Wi-Fi 名称、文件系统 UUID、序列号或其他敏感值。

## macOS 工作站

- 逻辑角色：macOS 工作站
- output：`macbook`
- OS / 版本：macOS 26.6
- 架构：Apple Silicon，目标平台 `aarch64-darwin`
- Nix：尚未安装
- 主用户与 home：`sayori`，`/Users/sayori`
- 默认 shell：`/opt/homebrew/bin/fish`
- Homebrew：已安装于 `/opt/homebrew`；formula 与 cask 原始清单仅保留在本地
- 现有 Nix 配置：无
- 现有 `system.stateVersion` / `home.stateVersion`：不适用；首次引入时必须按对应模块的兼容性规则设置并保留
- 主机名：未提交，Phase 1 的 Flake evaluation 不依赖该值
- 未确认事实：Nix 安装方案、首次 nix-darwin 激活前的回滚方式
- 证据采集日期：2026-07-20
- 证据来源：维护者 Mac 本地只读命令

## NixOS 工作站（ThinkPad）

- 逻辑角色：NixOS 工作站
- output：`nixbox`
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
- 未确认事实：home 路径、默认 shell、实时 UEFI/BIOS 状态、enabled services、当前 generation 与回滚路径；这些事实不影响 Phase 1 的 evaluation，正式接入前在 Phase 5 重新采集
- 证据采集日期：2026-06-21 与 2026-07-20
- 证据来源：维护者提供的本地快照 `thinkpad-initial`，包括 NixOS 配置、`nixos-version`、`uname`、`lsblk`、`lspci` 和 NetworkManager 设备摘要

## Ubuntu Server

- 逻辑角色：Ubuntu Server（未来迁移为 NixOS Server）
- output：`server`
- OS / 版本：Ubuntu 24.04.3 LTS（Noble）
- 架构：`x86_64-linux`
- 内核：Linux 6.8.0-90-generic
- Nix：尚未安装
- 当前管理用户与 home：`root`，`/root`；默认 shell 为 `/bin/bash`
- 长期管理用户：尚未决定；不得从当前 root 登录方式推断未来 NixOS 用户模型
- 启动模式：运行中的内核未暴露 `/sys/firmware/efi`，按实时证据记录为 BIOS；磁盘上仍存在已挂载的 vfat `/boot/efi` 分区，后续迁移阶段必须再次核对 provider 启动方式
- 存储摘要：75 GB QEMU 虚拟磁盘；ext4 根文件系统、独立 ext4 `/boot`、vfat `/boot/efi`
- 关键服务：Docker 与 containerd 已启用；Docker 29.1.5、Compose v5.0.1；UFW 已启用
- SSH：`ssh.socket` 已启用且处于 active，`ssh.service` 由 socket 激活；Mac 现有 SSH 别名可以登录，地址不提交
- 健康摘要：采集时存在 3 个 failed systemd units；Phase 1 不读取业务详情，服务迁移前必须单独诊断
- 未确认事实：业务服务与容器清单、监听端口、备份与恢复验证、provider Rescue/VNC、目标迁移磁盘复核、网络模型和长期 SSH 恢复路径；这些属于后续服务器阶段的强制前置证据
- 证据采集日期：2026-07-20
- 证据来源：从 Mac 经现有 SSH 别名执行的只读命令；未修改服务器

## Phase 1 当前结论

- 已确认平台：macOS 为 `aarch64-darwin`，NixOS 工作站为 `x86_64-linux`。
- 已确认逻辑 output：`macbook`、`nixbox`、`server`。
- 已固定兼容的 26.05 inputs，并建立不包含可激活主机配置的最小 Flake evaluation 入口。
- Phase 1 的最低 inventory 已完成；各主机的延后事实均已明确归入对应接入阶段，不会以猜测代替。
- 本阶段不得激活任何配置；NixOS 原始配置的正式导入属于 Phase 5。
