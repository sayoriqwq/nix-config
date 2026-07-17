# 领域文档使用规则

本文说明 Agent 在探索和修改仓库前，如何读取项目上下文与架构决策。此仓库当前采用单一上下文模型。

## 1. 开始前必须阅读

按以下顺序读取与当前 Issue 有关的内容：

1. 根目录 `AGENTS.md`；
2. 当前 GitHub Issue 及评论；
3. 根目录 `CONTEXT.md`；
4. `docs/architecture/` 下相关文档；
5. `docs/adr/` 下所有适用 ADR；
6. `docs/plans/migration-roadmap.md` 中当前阶段。

某个辅助文档不存在时，不得自行猜测它应当包含的机器事实。若缺失内容会影响实现，应把它记录为 Issue 中的 `needs-info` 或规划任务。

## 2. 当前文件结构

```text
/
├── AGENTS.md                  # 规范性 Agent 约束（英文）
├── CONTEXT.md                 # 项目领域、拓扑与术语（中文）
└── docs/
    ├── agents/                # 协作协议和中文译文
    ├── architecture/          # 架构与模块边界
    ├── adr/                   # 已接受或待讨论的重大决策
    ├── plans/                 # Milestone 与阶段路线图
    └── runbooks/              # 需要人工执行/验证的操作手册
```

如果未来出现多个相互独立的基础设施上下文，再通过独立 ADR 决定是否引入 `CONTEXT-MAP.md`；当前不提前增加多上下文抽象。

## 3. 使用统一术语

Issue、PR、代码和文档应使用 `CONTEXT.md` 定义的词汇，例如：

- 主机输出（Host output）；
- 共享用户层（Portable user layer）；
- 平台用户层（Platform user layer）；
- 系统层（System layer）；
- 主机层（Host layer）；
- 可变状态（Mutable state）；
- 人工关卡（Human approval gate）；
- 迁移阶段（Migration phase）。

不要为同一概念随意创造近义词。需要新增概念时，应在同一 PR 更新 `CONTEXT.md`，或通过 ADR 解释它为什么属于长期架构。

## 4. ADR 规则

开始修改某个领域前，必须阅读影响它的 ADR。当前至少包括：

- 单一 Flake 与多主机输出；
- Home Manager 的层级边界；
- sops-nix 机密管理；
- 服务器分阶段迁移。

如果提案与已接受 ADR 冲突，不能静默覆盖。必须在 Issue 和 PR 中明确写出：

> 与 ADR-XXXX 冲突；若仍需推进，应先建立新的决策 Issue，并用 supersede/reject 关系更新 ADR。

普通实现 PR 不得顺带推翻重大决策。

## 5. 事实、决策和计划的区别

- **事实**：来自真实机器或可靠命令输出，例如 CPU 架构、boot mode、现有 state version。
- **决策**：团队/维护者选择的长期方案，由 ADR 记录，例如使用一个 Flake。
- **计划**：尚未完成的工作及顺序，由 Milestone、Issue 和路线图记录。

Agent 不得把计划写成已经存在的事实，也不得把未经接受的建议写成已决定架构。

## 6. 发现文档冲突时

按更严格、更安全的规则暂停实施，并在当前 Issue 或 Draft PR 中指出：

- 冲突的文件与段落；
- 哪项实现会受到影响；
- 建议由哪个文件成为规范来源；
- 是否需要同步修改英文 Agent 协议与中文译文。

未经维护者确认，不要自行选择一个更宽松的解释继续执行。