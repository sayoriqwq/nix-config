# 领域文档使用规则

## 1. 阅读顺序

实施前依次阅读：

1. 根目录 `AGENTS.md`；
2. 当前 GitHub Issue 与评论；
3. `CONTEXT.md`；
4. 相关 `docs/architecture/`；
5. 所有适用 ADR；
6. 当前会实际执行的 runbook。

缺少会影响实现的机器事实时，在 Issue 记录 blocker；不得从历史聊天、别的 Host 或旧报告猜测。

## 2. 权威来源

| 内容 | 权威来源 |
| --- | --- |
| 规范性 Agent 约束 | `AGENTS.md`，中文译文必须同步 |
| 领域词汇与当前拓扑 | `CONTEXT.md` |
| 结构与依赖规则 | `docs/architecture/` |
| 长期决策与被否决方案 | `docs/adr/` |
| 当前操作与 rollback | `docs/runbooks/` |
| 实际实现与 Host 选择 | `software/`、`intents/`、`hosts/`、`operations/` |
| 计划、依赖与完成证据 | GitHub Issues、PR 与 Milestone |
| 历史追溯 | Git history、closed Issues/PR 与 tags |

不在当前 tree 保留迁移 inventory、研究计划或手写 capability matrix 作为第二事实源。

## 3. 术语

使用 `CONTEXT.md` 的 Software、Primary Capability、Extension、Intent、Host、Check、Operation、mutable state、activation 与 human gate。不要重新引入 `common` bundle、workflow、relation、substrate、platform registry 或“Phase”作为当前架构对象。

需要新长期概念时，在同一 PR 更新 `CONTEXT.md`；若改变已接受决策，先建立新 ADR。

## 4. 事实、决策、计划

- 事实来自真实机器、当前代码或可靠命令输出；
- 决策由 ADR 或维护者明确批准；
- 计划与顺序由当前 GitHub Issue/Milestone 承担。

不得把 build 写成 activation，把建议写成决策，或把历史运行态写成现状。

## 5. 冲突

发现文档与代码、ADR 或 Issue 冲突时，按更严格、更安全的规则停止相关实现，并记录冲突位置、影响、建议 owner 与是否需要英中协议同步。普通实现 PR 不得静默推翻长期决策。
