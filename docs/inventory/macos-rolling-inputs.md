# macOS rolling inputs 收口记录

> 范围：Issue [#106](https://github.com/sayoriqwq/nix-config/issues/106) 与后续
> [#115](https://github.com/sayoriqwq/nix-config/issues/115)。本文记录维护者已经执行的真实
> activation、后续 warning 诊断和构建证据；不授权新的 activation、重启、GC 或 generation
> 删除。

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
| `home-manager-darwin` | `master` | `a7c70cc290290f373f50cd820403833d250459ac` | macbook |
| `home-manager` | `release-26.05` | unchanged by #106/#115 | nixbox/server |
| `zed` | upstream default ref | unchanged by #106 | macbook/nixbox Zed package |

`nix-darwin.inputs.nixpkgs` 与 `home-manager-darwin.inputs.nixpkgs` 都 follows
`nixpkgs-darwin`。Rolling ref 不绕过 `flake.lock`，每次更新仍必须形成新的 Git diff。

## 3. 兼容层

### Obsidian

Darwin 的 unstable Obsidian DMG 当前把 `Obsidian.app` 嵌套在版本目录中。Capability
只在 Darwin 清除 package 的固定 source root，并从解包树定位 app；找不到 app 时 build
明确失败。Linux package 不进入该 override。

### Fish

Home Manager 26.05 的 man-page completion 生成曾直接读取 Fish 4.8 package 中已移除的
helper，#106 因此仅在 Darwin 关闭该生成步骤。#115 锁定的 Home Manager `master` 已从
Fish 二进制内置资源提取生成器；旧 workaround 已删除，macbook 与 Linux 均恢复默认
completion generation。

## 4. #106 不在范围内

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

- macbook 的 Home Manager 26.05 确实落后于 Darwin Nixpkgs 26.11，不能用关闭 release
  check 代替升级验证；
- root channels 路径来自 nix-darwin 默认 `nix.channel.enable = true`，仓库没有使用或恢复
  mutable channels 的需求；
- 系统 Flake registry 已固定 nixpkgs，关闭 channel 后仍保留
  `nixpkgs=flake:nixpkgs` compatibility mapping。

维护者明确要求先升级验证，而不是消音。#115 因此新增仅供 macbook 使用的
`home-manager-darwin` `master` input；nixbox/server 继续使用 `release-26.05`。求值确认：

- macbook Home Manager release 为 `26.11`，`system.nixpkgsRelease` 也是 `26.11`；
- macbook 与 nixbox 的 `home.enableNixpkgsReleaseCheck` 都保持 `true`；
- nixbox Home Manager release 仍为 `26.05`；
- Home Manager `master` 已修复 Fish 4.8 completion generator 路径，旧 Darwin workaround
  退场；
- Darwin channel compatibility 关闭，`nix.nixPath` 只剩
  `nixpkgs=flake:nixpkgs`。

这不改变任何 stateVersion，也不创建空 channel state 目录；真实 activation 仍需维护者在
PR build 通过后另行批准。

分支验证结果：

- `nix fmt -- --check .`：PASS；
- `nix build --no-link path:.#checks.aarch64-darwin.macos-rolling-inputs`：PASS；
- `darwin-rebuild build --flake path:/Users/sayori/Desktop/nix-config#macbook`：PASS；
- 针对 release mismatch、root channels、FZF/Atuin `Ctrl-R` conflict 与 build error 的
  输出扫描：无匹配；
- `nix flake check path:.`：PASS；
- `nix flake check --no-build --all-systems path:.`：PASS；
- `nix build --no-link path:.#darwinConfigurations.macbook.system`：PASS。
