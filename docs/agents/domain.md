# 领域文档使用规则

阅读顺序、工作范围、授权和验证遵循 [AGENTS.md](../../AGENTS.md)。本文用于选择文档落点、区分事实来源和处理文档冲突。

## 1. 权威来源

| 内容 | 权威来源 |
| --- | --- |
| 规范性 Agent 约束 | AGENTS.md，中文译文同一变更同步 |
| 当前工作范围与授权 | 当前任务请求及明确授权；已存在且相关的 Issue/PR 正文与评论 |
| 领域词汇 | CONTEXT.md |
| 主工作站管理、偏移、记录与选择同步约定 | docs/architecture/workstation-management.md |
| 当前拓扑、结构与依赖规则 | docs/architecture/；实际选择仍以代码为准 |
| 长期架构决策与被否决方案 | docs/adr/ |
| 当前操作、读回与 rollback | docs/runbooks/ 和执行 Agent 针对本次动作形成的方案 |
| 用户选定的稳定声明与 Host 选择 | flake.nix、flake.lock、software/、intents/、hosts/、modules/、dotfiles/、operations/ |
| 私有机器现场与历史变化证据 | Macwarden 私有记录与带时间、范围的现场读回；不等同于仓库声明 |
| 本次变更与验证结果 | 本地提交及任务完成报告；使用 Issue/PR 协作时可在那里补充必要记录 |
| 需要跨会话保存的计划与依赖 | 按需使用的 Issue、PR 或 Milestone |
| 历史追溯 | Git history、已有 Issues/PR 与 tags |

稳定声明表达用户选择保留的版本和配置，不证明机器此刻已经采用。Macwarden 的私有证据与公开声明独立；只有用户选定且适合公开的稳定内容进入本仓库。临时会话、历史运行态、盘点清单和手写 capability matrix 不成为第二套配置事实源。

## 2. 词汇与文档落点

领域词汇沿用 CONTEXT.md。它只承担词汇表；当前拓扑和组合说明进入 docs/architecture/overview.md，实现与 Host 选择由源码拥有，必要操作步骤进入 runbook。

新增长期概念时，在同一变更更新词汇表和实际消费者；不为单次聊天建立长期对象。改变已接受架构决策时，用明确范围和 ADR 记录决定，不强制采用 Issue 或 PR 形式。common bundle、通用 relation/workflow、platform registry 等仍受现有架构边界约束。

## 3. 处理冲突

先辨别是过时流程、源码与文档不符，还是实质架构或安全条件冲突，再按上表定位权威来源。历史事实注明观察时间与适用范围；建议、已接受决定和已执行操作分别表述。

涉及架构、安全或未知机器事实的冲突，说明位置、影响与需要的决定。实质改变已接受架构决策时更新适用 ADR，不能借普通维护静默改变其含义。
