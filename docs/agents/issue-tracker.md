# Issue 与 Pull Request 工作流

GitHub Issue、PR 与 Milestone 管理计划和完成证据；聊天和 Agent 临时计划不是长期事实源。

## 1. 实施前提

开始写入前必须存在边界完整的 Issue，至少说明：

- 目标与已知事实；
- owned paths / objects；
- frozen / forbidden；
- 前置依赖与 blocker；
- 验证命令；
- 风险、rollback 与人工关卡；
- 完成标准；
- 简短、规范性的英文 Agent Contract。

没有实施 Issue 时，只能只读检查、研究或准备 Issue，不能直接改配置。

## 2. 粒度与顺序

- 一个 PR 只实现一个 Issue 或一个可独立验收的窄 child Issue。
- 依赖顺序以 GitHub sub-issue/dependency、`Blocked by` 和维护者批准为准，不维护第二份路线图。
- 前置未关闭时不实施，除非 Issue 明确允许并行且 owned paths 不冲突。
- 缺少机器事实使用 `needs-info`；外部依赖使用 `blocked`；不再实施使用 `wontfix` 并记录理由。

## 3. 分支与 Draft PR

- 使用独立 branch/worktree；默认分支前缀为 `codex/`。
- 默认创建 Draft PR，并关联 Issue。
- PR 使用中文记录范围、文件/Host、明确不在范围、验证原始结果、风险、rollback、人工动作与未决事实。
- 未获维护者当前明确批准，不标 Ready、不 merge、不启用 auto-merge。
- Dirty worktree 中的无关修改属于维护者，不得一起提交或清理。

## 4. 人工批准

Activation、remote access、network/DNS/firewall/SSH、boot/disk、reboot、Rescue、Reinstall 与 production data 动作的批准必须：

- 出现在当前 Issue/PR 或当前会话；
- 绑定 exact target、commit、动作和执行窗口；
- 包含停止条件、readback 与 rollback；
- 只对当次动作有效。

早期泛化同意、build 成功或 PR merge 不能替代上述批准。

## 5. 完成

只有完成标准满足、验证记录完整、必要实机验收完成且 PR 已由维护者批准合并，Issue 才能关闭。关闭摘要应说明最终 commit/PR、验证、未执行动作与 follow-up。

标签词汇见 [triage-labels.md](triage-labels.md)。
