# nix-config

保存认可过的工作环境，让 macOS 日常维护省事，并能从可取回的材料恢复到可用状态。其他机器按实际需要复用配置。

## 从这里开始

| 要做什么 | 入口 |
| --- | --- |
| 更新软件、应用配置、验证改动 | [日常 Nix 维护](docs/runbooks/daily-nix-maintenance.md) |
| 换 Mac、恢复环境或回滚 | [macOS 环境恢复与回滚](docs/runbooks/restore-macos-environment.md) |
| 调整组织层次、配置归属或复用边界 | [当前架构](docs/architecture.md) |
| 更新 Zed、处理其配置与任务 | [Zed 维护](docs/runbooks/zed-maintenance.md) |
| 查快捷键和常用入口 | [快捷键参考](docs/runbooks/shortcuts.md) |

## 代码层次

```text
flake.nix                  输入、锁定版本与输出
  └── hosts/               每台机器的选择与硬件事实
       ├── intents/        一起选择的使用需求
       ├── software/       值得独立维护的软件配置与实现
       └── shared/         多个消费者复用的基础内容
```

具体选择直接读代码；组织规则与选择理由见[当前架构](docs/architecture.md)。协作约定集中在 [AGENTS.md](AGENTS.md)。

## 其他主机

| Output | 平台 | 角色与操作入口 |
| --- | --- | --- |
| `macbook` | `aarch64-darwin` | macOS 主工作站与维护入口 |
| `nixbox` | `x86_64-linux` | 次级工作站、Linux 实验与 server 预生产验证；[稳定访问](docs/runbooks/stable-workstation-access.md)、[桌面恢复](docs/runbooks/nixbox-desktop-recovery.md) |
| `server` | `x86_64-linux` | 最小 NixOS 生产主机，按真实需求增加服务；[恢复](docs/runbooks/server-recovery.md)、[终端排障](docs/runbooks/server-terminal-troubleshooting.md) |

当前目录只保留有效实现与操作材料。历史方案从 Git 查阅；私有现场记录由独立 Macwarden 项目保存，应用数据与备份在仓库外维护。
