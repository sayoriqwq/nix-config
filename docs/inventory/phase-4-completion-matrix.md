# Phase 4 完成矩阵

本矩阵把父 Issue #6 的任务和完成标准映射到仓库证据。Phase 4 的声明实现与旧 GUI
rollback bundle 清理均已完成；Issue #59 的文档 PR 合并并记录人工审阅后，#36 与 #6
才可关闭，之后才能进入 Phase 5 / #7。

## 1. 父 Issue #6 任务

| #6 任务 | 状态 | 证据 |
| --- | --- | --- |
| 将软件分为 Nixpkgs、Homebrew、MAS 与手工保留 | 完成 | [`phase-4-macos-software-ownership.md`](phase-4-macos-software-ownership.md) |
| CLI 优先使用 Nix，并记录例外 | 完成 | #41、#43、#55；[`phase-4-cli-static.md`](phase-4-cli-static.md)、[`mise-runtime-ownership.md`](mise-runtime-ownership.md)、[`uv-python-ownership.md`](uv-python-ownership.md) |
| 声明 Homebrew/tap/cask/formula 边界 | 完成 | #46、#55、#56；当前 `modules/capabilities/macos-legacy-applications/darwin.nix` 与总体 inventory |
| 逐项声明 defaults 并记录当前值、目标值和回滚 | 完成 | #37 / PR #40；[`phase-4-macos-defaults.md`](phase-4-macos-defaults.md) |
| 检查应用数据目录与登录态 | 完成 | 总体 inventory 的每类可变状态边界与各迁移记录 |
| 生成 activation 前后差异 | 完成 | 总体 inventory 第 9 节 |
| 更新 Mac runbook | 完成 | [`restore-macos-environment.md`](../runbooks/restore-macos-environment.md) |

## 2. 实施与合并证据

| 工作流 | Issue / PR | merge commit | 真实机器证据 |
| --- | --- | --- | --- |
| Ghostty | #22 / #26 | `04a4dfb2d477e015b93d3f40bbd0aa18e6240403` | 应用、配置与启动验收记录在 #22 |
| WezTerm 与 Shell | #23 / #27 | `6d58506210e64cfefa7979f9b145ac1453e6e136` | Fish/Zsh、应用与 PATH 验收记录在 #23/#27 |
| mise Node/Bun | #30 / #31 | `3072117bc6057cdc49029c10156c5a172c17087d` | 运行时所有权和 shell 验收记录在 #30 |
| VS Code 核心 | #24 / #32 | `ddee8b32a90d3bad2911722b974065b1a6644f66` | 1.119.0、设置、扩展与登录态验收记录在 #24/#32 |
| Zed Nightly 与编辑器模型 | #25 / #33 | `a0bd1e3540fec5f19017ee51cfd1903e61882fca` | Nightly、Cachix、GUI、`EDITOR/VISUAL` 验收记录在 #25 |
| uv/Python/PATH | #34 / #35 | `164d3fa9bfce8206cc6fafc14512f0f37bd46f3a` | uv 0.11.21、Python 3.12 与项目 `make dev` 验收记录在 #34 |
| 软件所有权基线 | #38 / #39 | `0244d3ef12246b2b87d71927c8d245f6fae06b89` | 维护者逐组批准，后续实施按 #36 分拆 |
| macOS defaults | #37 / #40 | `e832cd22203e07f6dbc48cd61560f40430dcc4b7` | Dock/Finder/输入/手势/菜单栏逐项实机体验记录在 #37 |
| 通用 CLI、Atuin 与 hushlogin | #41 / #42 | `6a3fc3abf9b9f17905dd1cd875cd965dc0e2b30b` | Atuin 冲突经私有备份处理，第二次 activation 完成 |
| Erlang/Elixir | #43 / #44 | `92fec5df905af47ec7f0732f25fbd3d4e7c6b7c4` | Erlang 29、Elixir/Mix 1.20.2 版本验收记录在 #43 |
| Nix GUI | #45 / #48 | `175c5867f5bb36008e0968127af329c3b0dddb45` | 应用 presence 与基础行为验收记录在 #45 |
| Homebrew cask 与 MAS | #46 / #49 | `dd82ea5a37b6b6626acff104e8a3b67615531e9e` | Bundle、身份、MAS receipts 与 OrbStack 验收记录在 #46 |
| Docker helper 残留 | #51 / #52 | `4117ecb68cd007af3bd3d3e1fc63cba43c9a47a8` | 精确链接删除后 `docker ps` 通过 |
| Typeless 与 Xcode 渠道 | #53 / #54 | `4397cd6e9db4459cb941298310b5bca72d45bc6a` | Typeless 已卸载；Xcode Beta 外部边界确认 |
| formula/tap 清理 | #55 | 无仓库实现 PR | 35 formula、3 tap 定向清理并完成替代入口验证 |
| cask 清理 | #56 | 无仓库实现 PR | 13 cask、2 tap 定向卸载；Nix 替代应用验证 |
| 退役应用与数据 | #57 | 无仓库实现 PR | Battery Buddy、Lark、Zed Preview 移入可恢复 Trash，保留共享 Zed 数据；Lark 后由 #74 恢复，并由 #81 更正为中国区 Feishu 渠道 |
| Chezmoi/dotfiles handoff | #58 | 无仓库实现 PR | Chezmoi 已卸载；旧仓库冻结，Nix 配置链接验证 |
| 旧 Nix GUI rollback bundle | #61 | 无仓库实现 PR | 七个旧 `/Applications` bundle 移入可恢复 Trash；Nix 应用与共享数据验证通过 |

所有真实 `darwin-rebuild switch` 均由维护者执行。部分工作流经历了安全中止、修订 commit
和重新 activation；最终通过状态以对应 Issue/PR 的最新验收评论为准，不能只看首次命令。

## 3. 完成标准

| #6 / #36 标准 | 状态 | 结论 |
| --- | --- | --- |
| 每个应用有明确来源和保留理由 | 完成 | Nix、Homebrew、MAS、Setapp、Apple、厂商/手工与退役项均已分类 |
| 无 destructive cleanup/zap | 完成 | `cleanup = "none"`；清理使用窄 Issue 与精确目标 |
| 每项 defaults 有当前值、目标值和回滚 | 完成 | #37 与 defaults inventory 提供逐键证据 |
| 维护者记录 activation 与关键行为 | 完成 | 各子 Issue/PR 已记录真实机器输出和人工体验 |
| 旧 dotfiles 活动路径完成 handoff | 完成 | #58；Chezmoi 卸载，旧 source/仓库冻结 |
| 无重复配置所有权 | 完成 | 旧 bundle 不再拥有配置；Nix 是唯一声明所有者 |
| 无重复应用实体 | 完成 | 旧 cask、Preview 与七个 `/Applications` rollback bundle 均已清理 |
| 全部子项完成或明确延期 | 完成 | PostgreSQL 16 由 #60 明确延期；OrbStack 数据保持外部；#61 已完成 |
| 总体 runbook、差异和回滚完成 | 完成 | #59 的 inventory、runbook 与本矩阵 |
| 文档 PR 经维护者合并 | 由 PR #62 完成 | 本矩阵所在 PR 合并即满足；merge commit 记录在 #59、#36 与 #6 的完成摘要 |

## 4. 有意延期

- **PostgreSQL 16（#60）：** package、launchd service、数据目录、备份恢复与停机窗口是
  数据型迁移，不能混入 Phase 4 应用清理。当前 Homebrew 外部所有权明确，因此不阻塞
  #6，也不授权在 Phase 5 顺带迁移。
- **OrbStack 可变数据：** Homebrew 只声明应用。VM、镜像、容器、volume、网络、context
  与 credential 保持外部；这不是缺失的配置声明。
- **外部 formula/厂商应用：** 已有明确 owner 和恢复入口；未来换源或清理需新维护 Issue，
  不属于 Phase 4 未完成项。

## 5. Phase 5 关卡

只有满足以下顺序才可开始 #7：

1. #59 文档 PR 合并并记录人工审阅；
2. #59 关闭；
3. #36 更新为最终完成状态并关闭；
4. #6 写入完成摘要并关闭；
5. 从 ThinkPad 重新采集实时主机、boot、filesystem、GPU、service、generation 与回滚证据。

Phase 1 的旧 ThinkPad 快照不能直接部署，其中的 `trusted-public-keys` 等事实必须重新核对。

## 6. Phase 4 后续维护修正

Issue #74 在 Phase 4 已完成后纠正了 Lark 的退役决定，并完成旧应用与数据的保全和人工
验收；Issue #81 随后把当前声明从全球版 `lark` 更正为中国区 `feishu`。既有
`Lark.app`、`LarkSuite.app`、Trash 原件和私有备份继续作为迁移回滚入口保留。两项维护
都不重开 Phase 4、不改变 #57 当时执行过的历史事实，也不与 Server Phase 7/8 实现混合。
