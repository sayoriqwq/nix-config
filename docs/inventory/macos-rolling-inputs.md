# macOS rolling inputs 收口记录

> 范围：Issue [#106](https://github.com/sayoriqwq/nix-config/issues/106)。本文记录维护者已经执行的真实 activation 与随后批准保留的声明；不授权新的 activation、重启、GC 或 generation 删除。

## 1. 已确认运行态

维护者于 2026-08-05 从 dirty worktree 完成 macbook nix-darwin activation，并随后明确
决定保留这组改动。只读复核确认：

- managed PATH 中 `nil` 为 `/etc/profiles/per-user/sayori/bin/nil`，版本
  `2026-07-23`；
- Fish 版本为 `4.8.1`；
- Nix 实现仍为 Lix `2.95.2`，没有切换到上游 Nix；
- macbook Home Manager 求值结果为 `programs.fish.generateCompletions = false`；
- nixbox 同一选项仍为 `true`；
- macbook 的 Obsidian package 求值为 `1.13.4`，Darwin override 的
  `sourceRoot = null` 与 `Obsidian.app` 定位逻辑均存在。

这些事实证明当前运行态和声明方向，不把未捕获的终端输出补写为虚构日志，也不把本次
仓库收口解释为第二次 activation。

## 2. 锁定 input 边界

本次收口时，根 Flake 的相关 lock nodes 为：

| input | update ref | locked revision | host scope |
| --- | --- | --- | --- |
| `nixpkgs-darwin` | `nixpkgs-unstable` | `104240a772428cc2e20d8fd86c9ddbb886bbaff2` | macbook |
| `nix-darwin` | `master` | `15abb8c98f336cd8bd840d71059adebabe60bf04` | macbook |
| root `nixpkgs` | `nixos-26.05` | unchanged by #106 | nixbox/server |
| `home-manager` | `release-26.05` | unchanged by #106 | all composed Home Manager users |
| `zed` | upstream default ref | unchanged by #106 | macbook/nixbox Zed package |

`nix-darwin.inputs.nixpkgs` 继续 follows `nixpkgs-darwin`。Rolling ref 不绕过
`flake.lock`，每次更新仍必须形成新的 Git diff。

## 3. 兼容层

### Obsidian

Darwin 的 unstable Obsidian DMG 当前把 `Obsidian.app` 嵌套在版本目录中。Capability
只在 Darwin 清除 package 的固定 source root，并从解包树定位 app；找不到 app 时 build
明确失败。Linux package 不进入该 override。

### Fish

Home Manager 26.05 的 man-page completion 生成会调用 Fish 4.8 已移除的 helper。
Darwin + Fish >= 4.8 因此关闭该生成步骤，保留 package 自带 completions。nixbox/server
不受该条件影响。

## 4. 不在范围内

- 不更新或处理 Zed Nightly PR #95；
- 不改变 nixbox/server package channel、配置或运行态；
- 不改变 Home Manager release、Lix 所有权或 stateVersion；
- 不处理其他应用升级、数据、secret、GC 或 generation。

## 5. 回滚

真实机器出现回归时优先选择 activation 前一代 nix-darwin generation。代码层回滚按
ADR-0009 恢复 Darwin release refs、更新 lock nodes、重新 build，并在新的人工关卡后
activation；不得用 stateVersion 变化代替回滚。

## 6. 仓库验证

2026-08-05 从 Issue #106 分支执行：

- `nix fmt -- --check .`：PASS；
- `nix build --no-link path:.#checks.aarch64-darwin.macos-rolling-inputs`：PASS；
- `nix flake check --no-build --all-systems path:.`：PASS；
- `nix build --no-link path:.#checks.aarch64-darwin.macbook-ai-clients`：PASS，
  锁定版本为 Codex `0.146.0`、Claude `2.1.220`、Antigravity `1.1.9` 与
  Oh My Pi `17.2.4`；
- `nix flake check path:.`：PASS；
- `nix build --no-link path:.#darwinConfigurations.macbook.system`：PASS，输出为
  `/nix/store/fzfw3dd8hggrwz8w6khzay5dgq4474zg-darwin-system-26.11.15abb8c`。

Home Manager 在 build 中明确报告其 26.05 release 与 Darwin Nixpkgs 26.11 不匹配。
当时保留该 warning 作为已接受组合的持续复审信号；上述 build 没有执行第二次 activation。

## 7. #115 warning 收口

2026-08-06 的后续 activation 再次出现相同 release mismatch warning，并同时报告不存在的
`/nix/var/nix/profiles/per-user/root/channels`。只读诊断确认：

- release mismatch 是 ADR-0009 已接受组合的静态事实，不是新故障；
- root channels 路径来自 nix-darwin 默认 `nix.channel.enable = true`，仓库没有使用或恢复
  mutable channels 的需求；
- 系统 Flake registry 已固定 nixpkgs，关闭 channel 后仍保留
  `nixpkgs=flake:nixpkgs` compatibility mapping。

#115 因此仅对 macbook 关闭 Home Manager release check，并在 Darwin 基础层关闭 channel
compatibility。对应 policy check 固定这两个选择，并确认 nixbox 的 release check 不受影响。
这不更新 input、不改变 stateVersion，也不创建空 channel state 目录；真实 activation 仍需
维护者在 PR build 通过后另行批准。

分支验证结果：

- `nix fmt -- --check .`：PASS；
- `nix build --no-link path:.#checks.aarch64-darwin.macos-rolling-inputs`：PASS；
- 在仅保留 `NIX_PATH=nixpkgs=flake:nixpkgs` 的环境中执行
  `darwin-rebuild build --flake path:/Users/sayori/Desktop/nix-config#macbook`：PASS，输出为
  `/nix/store/rwlf4jl8ih5ya35272pmh3vwgydg4fay-darwin-system-26.11.15abb8c`，构建输出不再
  包含两条目标 warning；
- `nix flake check path:.`：PASS；
- `nix flake check --no-build --all-systems path:.`：PASS；
- `nix build --no-link path:.#darwinConfigurations.macbook.system`：PASS。
