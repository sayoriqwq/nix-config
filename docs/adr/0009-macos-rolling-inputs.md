# ADR-0009：macOS 使用独立 rolling inputs

- **状态：** 已接受
- **日期：** 2026-08-05
- **决策范围：** `macbook` 的 nixpkgs、nix-darwin 与 Home Manager 兼容边界
- **关联 Issue：** [#106](https://github.com/sayoriqwq/nix-config/issues/106)
- **后续修订：** [#115](https://github.com/sayoriqwq/nix-config/issues/115)
- **批准记录：** 维护者在真实 activation 后明确决定保留 rolling inputs；2026-08-06
  明确要求先升级 Home Manager 并验证，而不是关闭 release check

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

2026-08-06 的后续 activation 再次证明该组合可工作，但明确报告 Home Manager
26.05/26.11 release mismatch。初始修复方案准备保留旧 Home Manager 并关闭检查；维护者
否决该顺序，要求先升级和验证。#115 因此为 macbook 新增独立的 Home Manager `master`
input，使 macOS 的 package、system module 与 user module 共同 rolling；Linux 主机继续
使用完整的 26.05 release 组合。同次诊断还确认 nix-darwin 的默认 channel 兼容层把不存
在的 root channels 路径加入 `NIX_PATH`；仓库没有 mutable channel 需求。

## 决策

### 1. Darwin 与 Linux 使用不同更新节奏

- `macbook` 使用 `nixpkgs-unstable` 和 nix-darwin `master`；
- `nixbox` 与 `server` 继续使用 `nixos-26.05`；
- `macbook` 使用独立的 `home-manager-darwin` `master` input，并让其 nixpkgs input
  follows `nixpkgs-darwin`；
- `nixbox` 与 `server` 继续使用 `home-manager` `release-26.05`，并让其 nixpkgs input
  follows 根 `nixpkgs`；
- `flake.lock` 固定每个 input 的精确 revision 与 hash，rolling 表示更新来源，
  不表示构建时绕过锁文件获取最新提交；
- Zed 按 ADR-0006 形成独立的真实平台 seam：macbook 由 owner-local
  `software/zed/package.nix` 固定官方 Preview 二进制并手动 sync，不随 Darwin input
  更新；nixbox 直接使用 Linux release package set 的 Stable。两边都不得把 source
  build 作为正常回退，server 不选择 Zed。

Darwin input 更新必须作为可审阅的 Git diff 进入独立维护范围，并至少通过 formatter、
Flake check、macbook system build 和与已知兼容 seam 对应的 policy check。

三台主机都保留 `home.enableNixpkgsReleaseCheck` 默认值。macbook 的 Home Manager
release 必须与 `system.nixpkgsRelease` 相同；policy check 固定该关系，不能用关闭检查
代替 input 对齐。

Darwin 同时设置 `nix.channel.enable = false`，不提供 `nix-channel` 或 mutable channel
state；system-wide Flake registry 继续固定 nixpkgs，`NIX_PATH` 只保留
`nixpkgs=flake:nixpkgs`，用于兼容仍使用 `<nixpkgs>` 的表达式。

### 2. 保持 stateVersion 与实现所有权不变

渠道变化不得修改 `system.stateVersion = 7` 或 `home.stateVersion = "26.05"`。
这些值描述初次采用时的数据兼容语义，不是当前 package channel。

macbook 继续通过 `nix.package = pkgs.lix` 使用 Lix。rolling nixpkgs 可以改变锁定的
Lix 版本，但不能把 Lix 所有权切换为上游 Nix 或安装器自升级。

### 3. 只保留已证明的兼容 seam

Obsidian capability 仅在 Darwin 对 `pkgs.obsidian` 做 override：清除错误的
`sourceRoot` 假设，并在解包结果中定位第一个 `Obsidian.app`。Linux 继续直接使用
原始 `pkgs.obsidian`。

Home Manager 26.05 曾直接读取 Fish package 中已经移除的
`create_manpage_completions.py`，因此 Darwin 暂时关闭过 man-page completion 生成。
锁定的 Home Manager `master` 已改为从 Fish 二进制的内置资源提取生成器；#115 删除该
本地 workaround，macbook 与 Linux 都恢复 Home Manager 默认 completion generation。

以上兼容层不是通用 patch 集合。上游 package 或 Home Manager 修复后，必须通过 build
证据删除失效 override，不能无限累积本地分叉。

## 结果

### 正面

- macbook 可以获取当前 Darwin packages 与 nix-darwin module 支持；
- Linux/NixOS release 基线不被桌面更新节奏带动；
- macbook 的 Home Manager 与 Darwin Nixpkgs 回到同一 release line，通用兼容检查保持
  开启；
- 已修复的 Fish seam 及时退场，剩余兼容问题仍有窄平台条件和回归检查；
- Lix、Linux Home Manager release 与 stateVersion 的既有边界保持不变。

### 代价与风险

- Darwin package、nix-darwin 与 Home Manager module 都采用 rolling refs，每次 input
  更新的审阅和 build 成本更高；
- Home Manager `master` 可能引入尚未进入 release branch 的 option 或 activation 变化，
  必须与 `nixpkgs-darwin` 一起验证；
- Darwin 不再提供 `nix-channel`；若未来出现经过批准的 mutable channel 需求，必须先以
  独立 Issue 修订当前 Flake-only 边界；
- Obsidian DMG 布局或 Fish/Home Manager behavior 修复后，本地兼容层可能过期；
- macbook 与 NixOS 主机不再共享同一个 nixpkgs cadence，排障时必须注明平台 input。
- Zed 也明确采用 macbook Preview / nixbox Stable 的不同节奏；版本差异是有意策略，
  排障与运行态 smoke 必须同时注明 host 和 Zed channel。

## 被否决的替代方案

### 三台主机全部切换到 unstable

会把 macOS 桌面更新需求扩散到 nixbox 与 production server，违反主机角色与风险边界。

### macOS 继续固定 26.05 release

更新频率更低，但不保留维护者已经 activation 并明确接受的 Darwin rolling 状态。

### 三台主机的 Home Manager 全部切换到 master

会把 macOS 的桌面更新节奏扩散到 nixbox 与 production server，并在 Linux 26.05
Nixpkgs 上重新制造反向 release mismatch；只为 macbook 拆分 input。

### 关闭 Home Manager release check

可以隐藏 warning，却不会修复版本线差异。维护者要求先升级验证，因此三台主机均保留
默认检查，并由 policy check 保证 macbook 的两个 rolling inputs 对齐。

### 创建空 root channels 目录

可以让路径存在，却会保留没有需求的 mutable channel interface，并把宿主状态伪装成声明
完整性；本仓库直接关闭 channel compatibility layer。

### 把兼容命令放入 activation script

会绕过 package/module 的声明边界并在真实机器上执行可变修补，不采用。

## 回滚

运行态优先切回 activation 前一代 nix-darwin generation。代码层回滚应在独立 Issue 中：

1. 把 `nixpkgs-darwin` 与 nix-darwin 恢复到审阅过的 release refs；
2. 把 `home-manager-darwin` 恢复到与目标 Nixpkgs 对应的 release ref；
3. 更新对应 lock nodes；
4. 删除只为 rolling inputs 存在且已经不再需要的兼容层；
5. 重新 build macbook output，并由维护者另行批准 activation。

不得通过提高或降低任何 stateVersion 进行回滚。

## 复审条件

- Home Manager `master` 与 rolling Darwin packages 出现重复 build 或 runtime 回归；
- macbook 的 Home Manager 与 Nixpkgs release line 再次分离；
- nix-darwin master 或 nixpkgs-unstable 引入不可接受的 activation 回归；
- Obsidian package 修复 DMG source root；
- 维护者希望重新统一 Darwin/Linux 的更新节奏。
