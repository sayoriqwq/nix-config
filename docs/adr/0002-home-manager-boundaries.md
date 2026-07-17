# ADR-0002：Home Manager 只管理用户层，并显式拆分平台边界

- **状态：** 已接受
- **日期：** 2026-07-17
- **决策范围：** 用户环境与系统环境

## 背景

macOS 上已有主要个人配置，NixOS 工作站目前较空，Ubuntu Server 未来还要重装。需要最大化复用 shell、Git、编辑器等用户配置，同时避免把 macOS GUI、NixOS 系统服务或服务器角色混入所谓“共享配置”。

Home Manager 可以作为 NixOS/nix-darwin 的集成模块，也可以 standalone 运行。如果三台机器都用完全独立的 Home Manager，系统与用户配置可能使用不同 nixpkgs 或分别激活；如果把所有内容都塞进一个 `common.nix`，共享层会充满平台判断。

## 决策

- macOS：Home Manager 作为 nix-darwin module 集成，由同一次系统构建组合。
- NixOS 工作站和最终 NixOS Server：Home Manager 作为 NixOS module 集成。
- Ubuntu Server 过渡期：使用 standalone Home Manager，只管理用户环境，不接管操作系统服务。
- 用户模块显式拆分为 `common`、`desktop`、`darwin`、`linux` 和 `server` 等角色。
- `common.nix` 必须平台中立并可用于 headless server。
- 优先使用 `programs.*` 等结构化模块；没有成熟模块时才链接静态 dotfiles；activation script 是最后选择。
- NixOS/nix-darwin 集成模式优先共享系统提供的 `pkgs`，避免用户层和系统层无意使用不同包集合。

## 结果

### 正面

- 两台工作站可以共享真实可移植的用户体验；
- 系统与用户配置在 NixOS/Darwin 上一起 evaluate 和 build；
- Ubuntu 过渡阶段不会干扰 apt、systemd、boot 或网络；
- 平台差异通过模块组合而不是大量条件表达；
- 服务器不会被迫安装桌面软件。

### 代价

- 同一用户可能有多个模块组合；
- standalone Ubuntu output 与集成 output 的激活命令不同；
- 需要持续审查 `common.nix` 是否发生平台泄漏；
- 某些软件在 Darwin/Linux 包名或能力不同，需要平台模块处理。

## 被否决的替代方案

### 所有机器只用 standalone Home Manager

会把系统与用户层的 nixpkgs、构建和激活拆开，降低整体可验证性，不作为 NixOS/Darwin 的长期方案。

### 一个巨大 `home.nix`

会隐藏桌面、服务器和平台边界，导致条件分支与无关包不断增长，不采用。

### 用裸 symlink 管理所有 dotfiles

无法利用结构化选项和依赖管理，也容易把可写状态链接进只读 Store，不采用。

## 复审条件

- 一个用户需要多个完全不同的 profile；
- Home Manager 集成造成无法接受的构建耦合；
- 未来采用能够显式建模多用户/多节点的 fleet 工具；
- 某类配置无法合理归入当前模块边界。
