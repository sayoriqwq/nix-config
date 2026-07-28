# Phase 1 主机盘点

本文只记录建立最小 Flake 骨架所需的脱敏事实。原始命令输出保留在对应机器或维护者本地，不提交公网地址、Wi-Fi 名称、文件系统 UUID、序列号或其他敏感值。

## macOS 工作站

- 逻辑角色：macOS 工作站
- output：`macbook`
- OS / 版本：macOS 26.6
- 架构：Apple Silicon，目标平台 `aarch64-darwin`
- Nix：Phase 1 采集时尚未安装；2026-07-20 在 Phase 2 中由维护者手动安装 Lix 2.95.2 完成 bootstrap，第一次 nix-darwin 激活后由锁定 nixpkgs 的 `pkgs.lix` 管理为 Lix 2.94.2；system type 为 `aarch64-darwin`，`flakes` 与 `nix-command` 已启用，长期实现选择见 ADR-0005
- 主用户与 home：`sayori`，`/Users/sayori`
- 默认 shell：`/opt/homebrew/bin/fish`
- sudo：接入前的 `/etc/pam.d/sudo_local` 已启用 `pam_tid.so`；Phase 2 已通过 nix-darwin 生成包含同一 PAM 模块的 `sudo_local`。激活后在 Ghostty 普通 shell 与 macOS Terminal.app 中测试时，macOS 26.6 均只显示系统密码授权框，未提供指纹选项；密码认证正常。该兼容性现象不阻塞 Phase 2，后续单独处理
- Homebrew：已安装于 `/opt/homebrew`；formula 与 cask 原始清单仅保留在本地
- 现有 Nix 配置：无
- 现有 `system.stateVersion` / `home.stateVersion`：不适用；首次引入时必须按对应模块的兼容性规则设置并保留
- 主机名：未提交，Phase 1 的 Flake evaluation 不依赖该值
- Nix 安装方案：Lix Installer bootstrap，nix-darwin 后续固定 `nix.package = pkgs.lix`
- 当前激活状态：维护者于 2026-07-20 手动完成第一次 nix-darwin 激活；`/run/current-system` 指向 nix-darwin 26.05 generation，system profile 为 `system-2-link`
- 当前回滚边界：优先回滚 nix-darwin generation；完整卸载仅作为最后手段，详见 Phase 2 runbook
- 证据采集日期：2026-07-20
- 证据来源：维护者 Mac 本地只读命令

## NixOS 工作站（ThinkPad）

- 逻辑角色：NixOS 工作站
- output：`nixbox`
- 当前配置中的主机名：`nixos`
- OS / 版本：NixOS 26.05，采集时版本为 `26.05.1947.a0374025a863 (Yarara)`
- 架构：`x86_64-linux`
- 内核：Linux 6.18.35
- Nix：由 NixOS 系统管理，版本 `2.34.7`；接入前仅启用 `nix-command`，Phase 5 声明将同时启用 Flakes
- 主用户与 home：`sayori`，`/home/sayori`；默认 shell 为 Bash；UID 1000，属于 `wheel` 与 `networkmanager`
- 现有配置位置：`/etc/nixos/configuration.nix` 与 `/etc/nixos/hardware-configuration.nix`
- `system.stateVersion`：`26.05`，来源为现有 `configuration.nix`
- `home.stateVersion`：未发现 Home Manager 配置
- 启动配置：实时确认使用 UEFI；现有配置启用 systemd-boot 和 EFI variables，`/boot` 为 1 GiB vfat
- 存储摘要：约 512 GB NVMe；1 GiB vfat `/boot`，其余为 ext4 根文件系统；无 swap
- 图形硬件：Intel Iris Xe，采集时使用 `i915` 驱动
- 网络硬件：Intel Wi-Fi，采集时使用 `iwlwifi`；NetworkManager 已启用；网络名称和地址不提交
- 桌面与基础服务：GNOME 50.1 + GDM、PipeWire/PipeWire Pulse/WirePlumber、Bluetooth、CUPS、NetworkManager、Avahi、Firefox；实时检查无 failed units
- SSH：Phase 5 盘点时使用一次可重启撤销的 `nixos-rebuild test` 通道；维护者已批准在仓库中永久声明同一把公钥，并关闭密码、keyboard-interactive 与 root SSH 登录
- 原始硬件配置：Phase 5 已从目标机重新采集并逐项核对；维护者批准将根分区与 EFI 分区 UUID 作为必要硬件事实写入 `hosts/nixbox/hardware-configuration.nix`
- generation：永久 system profile 为 generation 4，盘点时启动的永久 generation 为 3；当前盘点运行态另叠加临时 SSH test generation，重启即可回到永久 generation
- 回滚边界：首次 Flake 接入先使用 `nixos-rebuild test`；失败时重启回永久 generation。持久化后可从 systemd-boot 选择已知好的 generation
- 用户 profile：目标机未安装 Home Manager，也没有用户 channel/package；一次只读盘点命令意外留下空的 `~/.nix-profile` 符号链接与空 profile 目录，未安装任何包，Phase 5 不擅自删除
- 延后项：Home Manager 与 LocalSend 留到 Phase 6；不在首次系统接入中修改 shell、用户文件或 LAN 应用端口
- 证据采集日期：2026-07-28
- 证据来源：维护者授权后由 Mac 经临时 key-only SSH 通道执行的脱敏只读盘点；原始配置私有备份保留在维护者 Mac

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
