# ADR-0009：macOS 使用独立 rolling inputs

- **状态：** 已接受
- **日期：** 2026-08-05
- **决策范围：** `macbook` 的 nixpkgs、nix-darwin 与 Home Manager 兼容边界
- **关联 Issue：** [#106](https://github.com/sayoriqwq/nix-config/issues/106)
- **批准记录：** 维护者在真实 activation 后明确决定保留当前改动并正式收口

## 背景

本仓库最初让 macOS 与 NixOS 都跟随 26.05 release 系列。两类主机的角色和更新需求
已经分化：NixOS 工作站与 server 需要稳定的 release 基线，而 macbook 是主要桌面
工作站，需要更及时的 Darwin package 与 nix-darwin module 支持。

维护者于 2026-08-05 在 macbook 上从 dirty worktree 完成一次真实 activation，实际采用：

- `nixpkgs-darwin` 跟随 `nixpkgs-unstable`；
- `nix-darwin` 跟随 `master`，并继续让其 nixpkgs input 指向
  `nixpkgs-darwin`；
- Home Manager 保持 `release-26.05`，并通过 `useGlobalPkgs = true` 使用
  macbook 的 Darwin package set；
- Linux/NixOS 的根 nixpkgs 继续跟随 `nixos-26.05`。

该组合暴露出两个已经由真实 build/activation 证明的平台兼容 seam：unstable 的
Obsidian Darwin DMG 把 `Obsidian.app` 放在版本目录内；Fish 4.8 又与 Home Manager
26.05 的 man-page completion 生成 helper 不兼容。维护者明确选择保留 rolling inputs
及这两个窄修复，而不是回退到 Darwin release channel。

## 决策

### 1. Darwin 与 Linux 使用不同更新节奏

- `macbook` 使用 `nixpkgs-unstable` 和 nix-darwin `master`；
- `nixbox` 与 `server` 继续使用 `nixos-26.05`；
- Home Manager 继续使用 `release-26.05`；
- `flake.lock` 固定每个 input 的精确 revision 与 hash，rolling 表示更新来源，
  不表示构建时绕过锁文件获取最新提交；
- Zed 仍由自己的上游 Flake 与独立更新 PR 管理，不随 Darwin input 更新。

Darwin input 更新必须作为可审阅的 Git diff 进入独立维护范围，并至少通过 formatter、
Flake check、macbook system build 和与已知兼容 seam 对应的 policy check。

### 2. 保持 stateVersion 与实现所有权不变

渠道变化不得修改 `system.stateVersion = 7` 或 `home.stateVersion = "26.05"`。
这些值描述初次采用时的数据兼容语义，不是当前 package channel。

macbook 继续通过 `nix.package = pkgs.lix` 使用 Lix。rolling nixpkgs 可以改变锁定的
Lix 版本，但不能把 Lix 所有权切换为上游 Nix 或安装器自升级。

### 3. 只保留已证明的兼容 seam

Obsidian capability 仅在 Darwin 对 `pkgs.obsidian` 做 override：清除错误的
`sourceRoot` 假设，并在解包结果中定位第一个 `Obsidian.app`。Linux 继续直接使用
原始 `pkgs.obsidian`。

Fish primitive 仅在 Darwin 且 package 版本不低于 4.8 时强制关闭 Home Manager 的
man-page completion 生成。Fish 自带的 completions 继续进入 profile；Linux 和较旧
Fish 版本保留 Home Manager 默认行为。

以上兼容层不是通用 patch 集合。上游 package 或 Home Manager 修复后，必须通过 build
证据删除失效 override，不能无限累积本地分叉。

## 结果

### 正面

- macbook 可以获取当前 Darwin packages 与 nix-darwin module 支持；
- Linux/NixOS release 基线不被桌面更新节奏带动；
- 两个真实兼容问题具有窄平台条件、回归检查和明确所有权；
- Lix、Home Manager 与 stateVersion 的既有边界保持不变。

### 代价与风险

- Darwin package 与 module 变化频率提高，每次 input 更新的 build 成本和回归风险更高；
- Home Manager release 与更新 package set 的组合可能出现新的版本 seam；
- Home Manager 会明确报告 26.05/26.11 release mismatch warning；当前保留该警告，
  不用 `home.enableNixpkgsReleaseCheck = false` 隐藏风险；
- Obsidian DMG 布局或 Fish/Home Manager behavior 修复后，本地兼容层可能过期；
- macbook 与 NixOS 主机不再共享同一个 nixpkgs cadence，排障时必须注明平台 input。

## 被否决的替代方案

### 三台主机全部切换到 unstable

会把 macOS 桌面更新需求扩散到 nixbox 与 production server，违反主机角色与风险边界。

### macOS 继续固定 26.05 release

更新频率更低，但不保留维护者已经 activation 并明确接受的 Darwin rolling 状态。

### Home Manager 同步切换到 master

会同时扩大 package、system module 与 user module 三个变化面；当前两个兼容 seam 已能在
保持 Home Manager release 的情况下窄修，不需要进一步扩大范围。

### 把兼容命令放入 activation script

会绕过 package/module 的声明边界并在真实机器上执行可变修补，不采用。

## 回滚

运行态优先切回 activation 前一代 nix-darwin generation。代码层回滚应在独立 Issue 中：

1. 把 `nixpkgs-darwin` 与 nix-darwin 恢复到审阅过的 release refs；
2. 更新对应 lock nodes；
3. 删除只为 rolling inputs 存在且已经不再需要的 Obsidian/Fish 兼容层；
4. 重新 build macbook output，并由维护者另行批准 activation。

不得通过提高或降低任何 stateVersion 进行回滚。

## 复审条件

- Home Manager 26.05 与 rolling Darwin packages 持续出现新的兼容问题；
- release mismatch warning 不再只是可控提示，而开始对应重复 build 或 runtime 回归；
- nix-darwin master 或 nixpkgs-unstable 引入不可接受的 activation 回归；
- Obsidian package 修复 DMG source root；
- Home Manager 修复 Fish 4.8 completion 生成；
- 维护者希望重新统一 Darwin/Linux 的更新节奏。
