# Issue 标签词汇

标签用于表达工作状态和风险，不替代 Issue 正文中的范围、依赖和人工关卡。GitHub 中尚未创建的标签应由维护者或具备权限的工具按本文建立；Agent 不得因为标签缺失而猜测任务状态。

## 1. 核心状态标签

| 规范角色 | GitHub 标签 | 含义 |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | 目标或边界尚未由维护者确认 |
| `needs-info` | `needs-info` | 缺少主机事实、决策或人工输入，Agent 必须停止实现 |
| `ready-for-agent` | `ready-for-agent` | Issue 字段完整、前置依赖满足，可由 Codex 领取 |
| `ready-for-human` | `ready-for-human` | Agent 可完成部分已结束，等待真实机器验证或人工批准 |
| `blocked` | `blocked` | 被开放 Issue、外部条件或失败检查阻塞 |
| `wontfix` | `wontfix` | 明确不实施，关闭时必须记录原因 |

任何时刻只应有一个主要状态标签。Assignee 和关联 Draft PR 用于表示进行中，不额外要求 `in-progress` 标签。

## 2. 类型标签

| 标签 | 用途 |
| --- | --- |
| `type:maintenance` | 一个窄范围维护、重构或依赖更新 Issue |
| `wayfinder:map` | 当前 Wayfinder 主线 Goal map |
| `wayfinder:task` | Goal map 中可独立验收的任务 |
| `wayfinder:research` | 只做调查和证据收集，不实施 |
| `wayfinder:prototype` | 需要人工选择的原型决策 |
| `wayfinder:grilling` | 需要与维护者压力测试的决策 |

## 3. 范围标签

| 标签 | 范围 |
| --- | --- |
| `area:governance` | Agent 协议、Issue/PR 工作流、文档治理 |
| `area:darwin` | nix-darwin 与 macOS 系统层 |
| `area:home` | Home Manager 与用户配置 |
| `area:nixos` | NixOS 工作站或通用 NixOS 模块 |
| `area:server` | 当前 NixOS server 配置、验证与恢复 |
| `area:secrets` | secret consumer、部署机制与权限边界 |

一个 Issue 可以有多个范围标签，但应保持最小集合。

## 4. 风险标签

| 标签 | 含义 |
| --- | --- |
| `risk:activation` | 需要在真实机器激活配置 |
| `risk:remote-access` | 可能影响网络、DNS、SSH 或防火墙 |
| `risk:destructive` | 涉及磁盘、重装、重启或生产数据 |

带任何风险标签的 Issue 必须包含明确的人工作业清单、回滚方式和当次批准关卡。`risk:destructive` 的工作不得由无人值守 Agent 执行。

## 5. 使用规则

- 新 Issue 默认从 `needs-triage` 开始。
- 事实与边界补齐后，由维护者改为 `ready-for-agent`。
- Agent 遇到未知机器事实时改为 `needs-info`，而不是填入猜测值。
- Agent 完成 build、文档和 PR 后改为 `ready-for-human`。
- 合并与人工验证完成后关闭 Issue；不需要保留一个 `completed` 标签。
- 标签与 Issue 正文冲突时，按更严格的约束执行并请求维护者修正冲突。

## 6. 建议颜色

颜色只用于界面识别，不具有语义优先级：

| 标签组 | 建议颜色 |
| --- | --- |
| 状态 | 蓝/黄/红，按等待、可执行、阻塞区分 |
| `type:*` | 紫色 |
| `area:*` | 绿色 |
| `risk:*` | 橙色或红色 |

维护者可以调整颜色，但不应随意更改本文中的标签字符串，因为 Agent 协议和本地 `gh` 命令会引用这些名称。
