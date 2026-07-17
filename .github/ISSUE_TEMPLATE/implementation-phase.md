---
name: 迁移阶段 / Migration phase
about: 为路线图中的一个阶段建立边界明确、可交给 Codex 执行的 Issue
title: "[Phase N] "
labels: ""
assignees: ""
---

<!--
使用前请替换所有占位符。面向维护者的部分使用中文；最后的 Agent Contract 使用英文并作为规范性约束。
-->

## 所属计划

- Milestone：`声明式个人基础设施 v1 / Declarative Personal Infrastructure v1`
- 路线图阶段：Phase N
- 跟踪 Issue：#
- 前置 Issue：#

## 目标

用一段话说明本阶段唯一需要达到的结果。

## 背景与已知事实

- 已确认事实：
- 事实来源：
- 当前未知项：

## 允许修改

- `path/**`

## 禁止修改

- 与本阶段无关的主机和模块；
- `system.stateVersion` / `home.stateVersion`，除非本 Issue 根据原始证据明确要求；
- 磁盘、boot、远程网络、SSH、防火墙和生产数据，除非本 Issue 专门处理且已到人工关卡；
- 明文 secret；
- 未经 ADR 接受的新框架。

## 实施任务

- [ ] 阅读 `AGENTS.md`、`CONTEXT.md`、相关架构文档和 ADR
- [ ] 收集并记录缺失证据
- [ ] 完成本阶段最小实现
- [ ] 更新必要文档
- [ ] 创建 Draft PR 并关联本 Issue

## 验证

列出准确命令；默认只 build/evaluate，不激活。

```bash
# 按本阶段填写
```

需要记录：

- 命令；
- 返回结果；
- 未能运行的检查及原因；
- 需要维护者在真实机器完成的验证。

## 人工关卡

- [ ] 当前阶段是否需要真实机器激活？
- [ ] 是否涉及 boot、磁盘、网络、防火墙、SSH、重启或生产数据？
- [ ] 批准的具体命令、目标机器和执行窗口是否已记录？
- [ ] 回滚或救援路径是否已验证？

未勾选并记录明确批准前，Agent 必须停在关卡之前。

## 风险与回滚

- 风险：
- 回滚步骤：
- 救援路径：

## 完成标准

- [ ] 本阶段目标满足
- [ ] 没有越过允许范围
- [ ] 相关检查通过或阻塞项已记录
- [ ] 文档与 ADR 保持一致
- [ ] 必要的真实机器验证已由维护者记录
- [ ] Draft PR 已审阅并由维护者合并
- [ ] Issue 有完成摘要

## Agent Contract (normative)

```text
Implement only the scope explicitly allowed by this issue.
Do not guess machine facts or silently choose placeholder values.
Do not activate configurations or perform destructive/remote operations.
Keep the pull request in draft until the maintainer explicitly approves otherwise.
Report exact validation commands, results, blockers, risks, and required human actions.
Stop at every human approval gate defined above.
```