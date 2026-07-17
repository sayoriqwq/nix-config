# Issue 与 Milestone 工作流

本仓库使用 GitHub Milestone、Issue 和 Draft PR 管理实施，不把聊天记录或 Agent 临时计划当作长期事实来源。

## 1. 层级模型

```text
Milestone：声明式个人基础设施 v1
  └── v1 跟踪 Issue
       ├── Phase 0 Issue ── Draft PR
       ├── Phase 1 Issue ── Draft PR
       ├── ...
       └── Phase 12 Issue ─ Draft PR
```

- Milestone 表示一个可以验收的长期结果。
- 跟踪 Issue 保存顺序、依赖、总体状态和决策摘要。
- 一个 Phase Issue 定义一个可交给 Codex 执行的工作单元。
- 一个 Draft PR 只实现一个 Phase Issue，或一个范围很窄的维护 Issue。
- PR 合并并记录人工验证后，才关闭对应 Issue 并推进下一阶段。

## 2. 开始工作的前提

Agent 只有在以下条件全部满足时才能开始实现：

1. 存在明确的 GitHub Issue；
2. Issue 包含目标、允许修改、禁止修改、验证、人工关卡、回滚和完成标准；
3. 前置 Issue 已关闭，或维护者明确批准并行；
4. Issue 没有未解决的 `needs-info` 或 blocker；
5. Agent 已阅读 `AGENTS.md`、`CONTEXT.md`、相关架构文档、ADR 和路线图阶段。

没有实施 Issue 时，只能检查、研究、补充计划或创建边界完整的 Issue，不得直接开始写配置。

## 3. Phase Issue 内容

使用 `.github/ISSUE_TEMPLATE/implementation-phase.md`。正文必须包含：

- 所属 Milestone、Phase 和跟踪 Issue；
- 目标与已知事实；
- 前置依赖和阻塞项；
- 允许修改与禁止修改；
- 实施任务；
- 准确的验证命令；
- 人工批准关卡；
- 风险、回滚与救援路径；
- 完成标准；
- 简短、规范性的英文 Agent Contract。

面向维护者的说明使用中文。英文 Agent Contract 用于减少 Agent 对 `must`、`never`、`only` 和 `stop` 等硬约束的误解。

## 4. Issue 生命周期

```text
needs-triage
    ↓ 范围和事实补齐
ready-for-agent
    ↓ Agent 领取并创建 Draft PR
in progress（通过 assignee / PR 表示）
    ↓ build 与 review 完成
ready-for-human
    ↓ 维护者真实机器验证/批准
completed
```

遇到缺失事实时使用 `needs-info`；存在前置依赖时使用 `blocked` 或在正文顶部写 `Blocked by: #<issue>`。不再实施的工作使用 `wontfix`，并在关闭评论中记录原因。

标签词汇和实际映射见 `docs/agents/triage-labels.md`。

## 5. 分支与 PR

- 计划阶段分支优先使用 `agent/phase-<number>-<short-name>`。
- 每个 PR 必须关联 Issue，并默认保持 Draft。
- PR 描述使用 `.github/PULL_REQUEST_TEMPLATE.md`，必须用中文报告范围、验证、风险、回滚和人工操作。
- Agent 不得自行合并、启用 auto-merge 或把 Draft 标记为 Ready for review。
- 工作树存在无关修改时，不得把它们一起提交。

## 6. 阻塞与顺序

Phase 默认按照 `docs/plans/migration-roadmap.md` 顺序推进。

优先使用 GitHub 原生 Issue dependency/sub-issue；不可用时，使用正文中的显式关系：

```md
Part of #<tracking-issue>
Blocked by: #<previous-phase>
```

跟踪 Issue 的 task list 是顺序和状态的可视化入口，但每个 Phase Issue 的正文才是实施范围的规范来源。

## 7. 使用 `gh` 的本地 Codex 工作流

Codex 在仓库 checkout 中可使用 GitHub CLI。多行正文必须使用 heredoc 或文件，避免换行和 Markdown 损坏。

```bash
# 阅读当前任务及评论
gh issue view <number> --comments

# 查看 Milestone 内开放 Issue
gh issue list \
  --state open \
  --milestone "声明式个人基础设施 v1 / Declarative Personal Infrastructure v1"

# 领取任务
gh issue edit <number> --add-assignee @me

# 创建 Draft PR
gh pr create --draft --fill

# 在人工验收后记录结果
gh issue comment <number> --body-file validation-summary.md
```

从 `git remote -v` 推断仓库；不在正确 checkout 中时，显式使用 `--repo sayoriqwq/nix-config`。

## 8. 人工批准如何记录

危险操作的批准必须：

- 出现在当前 Issue 或 PR；
- 明确目标机器、具体命令或动作、执行窗口和回滚方法；
- 只对当次动作有效；
- 不能用早期聊天中的泛化同意代替。

批准前，Agent 必须停在配置、构建、检查清单和命令准备完成处。

## 9. 完成与关闭

Phase Issue 只能在以下条件满足后关闭：

- 完成标准全部满足；
- PR 已由维护者合并；
- 相关 build/evaluation 结果已记录；
- 必要的真实机器验证已由维护者记录；
- 回滚步骤明确；
- 跟踪 Issue task list 已更新；
- 关闭评论包含变更摘要、验证结果和后续工作。

Milestone 只有在所有 v1 Phase 完成、服务器业务恢复与备份/救援手册验证后才关闭。