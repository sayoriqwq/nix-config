# Phase 0–11 Reconcile 记录

> 范围：Issue #103，基线为 `main@4178a8ee3ad4e0c858aae85e136f2bbc7fb0887f`。本文记录 2026-08-04 的全仓、GitHub、主机只读状态与维护者批准的清理结果；不授权 activation、Nix GC、generation 删除、PostgreSQL 变更或其他生产修改。

## 1. 当前阶段结论

- Phase 0–11 均已完成；server 已运行最小 NixOS，Phase 11 的三机 SOPS/age 首次 activation 已验收。
- Phase 12 / Issue #14 由维护者明确延后，不建立业务、生产 secret 或新框架占位。
- 当前保留的独立后续为 #60、#67，以及独立审阅的 Zed Nightly PR #95。#99 后续已在 2026-08-05 被维护者明确否决，见第 7 节。

## 2. 仓库收口

- 删除 Phase 10 正式迁移专用的 preflight、bootstrap、install/resume helpers 与对应 tests；历史执行证据保留在 Phase 10 inventory。
- 删除 Phase 11 管理员 identity 初始化 helper、验收 demo 声明和三份 SOPS 密文；Secret adapter 只保留 sops-nix 与 host SSH identity 基础。
- Phase 9 的无 target 隔离演练改名为长期 `server-recovery-test`，继续拒绝参数、production target、dirty checkout、无 KVM 与低空间环境。
- 删除已经失去可执行入口的 server 替换 runbook；Phase 8–10 的历史事实继续由 inventory 与 ADR 保存。
- README、Context、架构、路线图、ADR、Secret runbook 与英文/中文 Agent 协议同步为当前事实。

删除 secret 声明不会自行修改真实机器。三台主机上的历史 `/run/secrets/phase11-demo` 只有在各自主机未来取得单独批准并激活本变更后才会移除。

## 3. GitHub 收口

- 关闭并删除 PR #100 的生成分支：它错误识别仓库技术栈、引入第二份 Agent 规范并使用未锁定依赖，不符合仓库边界。
- 删除已被 Phase 10 成功路径取代的本地与远端 `agent/phase-10-server-replacement` 分支。
- 关闭已完成或被最终实现取代的 #74、#77、#81；保留 #14、#60、#67、#99 与 #103。
- 更新 v1 跟踪 Issue #1：Phase 11 已完成，Phase 12 明确延后。

## 4. 本地永久删除

维护者明确批准永久删除旧 Codex、OpenClaw 与迁移备份。清理前逐路径复核 type 与 owner；不使用 glob，也不扩大到其他 Trash 项。

已永久删除：

- 13 个 Phase 3/4 一次性交接或 preflight 目录；
- `~/.local/state/nix-config-backups/` 下两个已完成 Issue 的快照；
- 11 个精确 Trash artifacts，包括旧 OpenClaw retirement 备份、Codex DMG/tickets/repo assets、Raycast 集成残留与其他 Phase 4 文档/目录。

`~/.Trash/Codex_2026-06-30_18-49-28` 原为 root 所有；维护者运行精确 sudo 删除命令后，已复核该路径不存在。批准范围内共 26 个本地 artifacts，现已全部永久删除。

明确保留：

- Phase 2 nix-darwin backup 与 Phase 5 nixbox preflight 证据；
- `/etc/pam.d/sudo_local.before-nix-darwin` 与 `/etc/shells.before-nix-darwin`；
- `/private/tmp/codex-browser-use`；
- Nix system generations、Nix Store、PostgreSQL 16 数据与服务。

## 5. 主机与临时服务

- macbook 没有 Phase 10/11 LaunchAgent；PostgreSQL 16 正在运行且不属于本 Issue。
- server 当前运行 Phase 11 已验收 closure；没有迁移 helper 或 `/tmp` 入口，只保留预期的 `run-secrets.d.mount`。

## 6. 验证

- `nix fmt -- --check .`：PASS；
- `nix flake check --no-build --all-systems path:.`：PASS；
- `nix build --no-link path:.#checks.aarch64-darwin.sops-age-policy`：PASS；
- `nix build --no-link --print-out-paths path:.#darwinConfigurations.macbook.system`：PASS，输出为 `/nix/store/iwky2v6s9wp2543hc65nf2pxzspsrdlp-darwin-system-26.05.c3e90c8`；
- `git diff --check`：PASS。

曾从 server 针对不可变 GitHub commit 发起 x86_64-linux 的 server/nixbox closure 与长期恢复 tests 联合构建。求值显示 nixbox 桌面与 Zed 的冷缓存依赖会扩张为 3753 个 derivations，已主动中止这项超出本次清理所需的全量构建；没有 activation，也没有运行 GC，且不把全系统求值或部分缓存下载误报为同架构构建通过。本 Issue 不为关闭验证而扩大 builder、网络或垃圾回收边界。

## 7. 2026-08-05 后续状态同步

- 维护者明确当前 server 为个人使用的单管理员主机：macbook 上的 `ssh sayori` 是本地 Host alias，远端用户为 `root`；root SSH 保持 public-key-only；
- Contabo VNC 已由维护者完成当前 endpoint 的真实端到端连接验证；
- #99 与未合并 Draft PR #109 已以未计划实施关闭；关闭 root SSH 的配置从未 activation；
- #110 承接纯文档同步，不修改 Nix 配置或三台机器运行态；
- nixbox 仍是维护者的次级 NixOS 工作站及 server 的 `x86_64-linux` build/test/deploy 节点；其独立 deploy identity 不等于维护者交互身份，也不是 macbook 直连 server 的必经跳板；
- 当前开放主线跟踪为 #1；Phase 12 / #14 继续延后；独立候选为 #60（PostgreSQL 16 数据迁移）与 #67（broader AI/RTK 基线）；开放 PR #95 继续独立审阅；自动生成的 PR #108 误判仓库为 TypeScript 项目并引入第二套 Agent/ECC 配置，应由维护者单独裁决，推荐关闭而非并入当前基线。
