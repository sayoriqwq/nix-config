# 整体架构

## 1. 目标与入口

当前运行环境是实际状态的唯一事实来源。nix-config 的声明与 lock 保存维护者选定的配置和输入，按需复用到其他机器；Nix 负责求值、构建和所选写入机制，现场读回验证实际部署。私有历史证据由独立 Macwarden 项目维护。日常维护、偏移、选择同步与记录边界见[主工作站管理](workstation-management.md)，术语见 [CONTEXT.md](../../CONTEXT.md)。

声明使用一个顶层 Flake、一个 lock file 和显式 import graph：

- 一个软件只有一个 package/config/service owner；
- 一起选择的使用需求集中在 Intent，Host 保留最终选择；
- 外部 state 和操作影响保持可见。

## 2. 目录与组合

Software、Intent、Host 的接口与 import 方向统一见[模块与目录边界](module-boundaries.md)。

Macwarden 的模型、工具和 Skills 由独立项目维护，本仓库不复制其合同或接管跨 Agent 管理。

### 核心工作环境的选择

| Intent | macbook | nixbox | server |
| --- | --- | --- | --- |
| `shell-work`：Fish 与共同 CLI／TUI | ✓ | ✓ | ✓ |
| `primary-terminal`：Ghostty + Fish | ✓ | ✓ | — |
| `terminal-compatibility`：WezTerm + Zsh | ✓ | — | — |
| `code-development`：Zed 与开发接线 | 加选 VS Code | Zed | — |
| `development-runtime`、`github-collaboration` | ✓ | ✓ | — |
| `container-development`：OrbStack | ✓ | — | — |
| `server-diagnostics`：服务端诊断工具 | — | — | ✓ |

工具的 Zsh 接线随所属使用需求一起选择，仅在 Host 已选择 Zsh 时生效。兼容终端不再决定 IDE 或容器是否存在。IDE 内置交互终端沿用现有设置；任务按自己的执行环境运行。其他 App 托管范围另行盘点，本轮保留原选择。

## 3. Flake outputs

生产 outputs：

- `darwinConfigurations.macbook`
- `nixosConfigurations.nixbox`
- `nixosConfigurations.server`

显式 package/app outputs 只为真实操作或独立验证提供稳定入口，例如 Linux Zed Stable 与 Clash Verge Rev package。任何 Output 也不表示已经 activation。

当前 Darwin 使用 rolling nixpkgs/nix-darwin/Home Manager inputs；Linux 使用 26.05 release inputs。两条 cadence 共享同一 lock file；现有平台版本差异不表示维护者已经要求同步。显式同步选中软件时，仍须满足[主工作站管理](workstation-management.md)中的版本要求。

`system.stateVersion` 与 `home.stateVersion` 保留首次采用值，不随 channel 升级。

## 4. 验证

Nix 修改格式化并求值相关 Host，必要时通过 nh 或原生命令构建候选；激活后验收本次涉及的 Shell、终端启动、编辑器命令与任务等功能。仓库不维护独立 checks 层。构建成功不能替代现场行为验证，也不能证明未选中的目标状态没有改变。

## 5. 配置与数据边界

Git/Nix 可以拥有 package 选择、稳定设置、systemd/launchd 声明、静态文件、明确 firewall rule。它们不自动拥有数据库、history、userdb、cache、browser profile、应用账号、token、private key、workspace、容器 volume、云端数据与备份。

必要的可变状态边界保留在最近的 Software owner 或当前 runbook。项目开发依赖属于项目 dev shell；工作站可变运行时属于明确选择的 Software/Intent；server workload 运行时属于服务 closure 或容器合同。Secret 机制由真实 consumer 引入，当前没有预置 secret framework。

可复现所需的 host/hardware facts 保存在 `hosts/<host>/`。Credential、账号标识及其他不影响构建的敏感事实不进入公开文档；已获准版本化的非凭据主机事实遵循对应主机合同。

## 6. 主机角色与控制关系

| Host | 角色与主要管理层 | 组合重点与边界 |
| --- | --- | --- |
| `macbook` | 主工作站与维护者控制面；nix-darwin + Home Manager | 完整工作站 Software、开发/终端 Intents；不承担 Linux closure 原生构建 |
| `nixbox` | 次级工作站、Linux 实验站、server 同架构验证节点；NixOS + Home Manager | Hyprland、核心开发/终端 Intents 与预生产验证；不镜像 macbook GUI，不持有 maintenance private key |
| `server` | 最小 headless NixOS production host；NixOS + Home Manager | Shell、CLI／TUI、基础运维、诊断与 recovery；无 GUI、GitHub credential、工作站 runtime、Tailscale mesh 或旧 Ubuntu workload |

逻辑 output 名称不要求等于真实 hostname。Server 只按当前需求引入生产能力，并为实际服务明确运行、备份、恢复与 rollback 边界。

维护者从 macbook 直接登录 `server:sayori`，经 `sudo` 或获准的 `sudo -i` 管理；root SSH、password 与 keyboard-interactive 关闭。nixbox 使用独立机器凭据登录同一个远端 `sayori`，负责 `x86_64-linux` closure 的构建、测试与获准部署；两把 key 划分凭据保管和撤销边界，不提供 Unix 权限隔离。

nixbox 不是 server 的 bastion。macbook 直达链路与 provider VNC/Rescue 共同保留恢复能力；server 接收已构建 closure，运行时不依赖 GitHub 或 mutable checkout。macbook 到 nixbox 的稳定 transport 使用 Tailscale，用户与 host 认证由 native OpenSSH 承担，tmux 保留断线后的工作现场。技术决策见 [ADR-0008](../adr/0008-direct-nixos-server-replacement.md) 和 [ADR-0010](../adr/0010-tailscale-stable-workstation-access.md)。
