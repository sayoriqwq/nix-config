# nix-config

保存认可过的 Mac 工作环境，让日常维护省事，并能从可取回的材料恢复到可用状态。

## 从这里开始

| 要做什么 | 入口 |
| --- | --- |
| 更新软件、应用配置、验证改动 | [日常 Nix 维护](docs/runbooks/daily-nix-maintenance.md) |
| 换 Mac、恢复环境或回滚 | [macOS 环境恢复与回滚](docs/runbooks/restore-macos-environment.md) |
| 调整组织层次、配置归属或维护范围 | [当前架构](docs/architecture.md) |
| 更新 Zed、处理其配置与任务 | [Zed 维护](docs/runbooks/zed-maintenance.md) |
| 查快捷键和常用入口 | [快捷键参考](docs/runbooks/shortcuts.md) |

## 当前维护路径

```text
flake.nix                  输入、锁定版本与输出
  └── hosts/macbook/       Mac 的软件选择与系统设置
       ├── intents/        一起选择的使用需求
       ├── software/       值得独立维护的软件配置与实现
       └── shared/         多个消费者复用的基础内容
```

具体选择直接读代码；组织规则与选择理由见[当前架构](docs/architecture.md)。协作约定集中在 [AGENTS.md](AGENTS.md)。

## 维护范围

当前只维护和验收 `macbook`（`aarch64-darwin`）。仓库仍保留 `nixbox`、`server` 的代码与相关手册作为历史参考，不承担三端同步和常规验证；重新使用时按实际需求评估。

历史方案从 Git 查阅；私有现场记录由独立 Macwarden 项目保存，应用数据与备份在仓库外维护。
