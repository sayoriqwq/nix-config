# 整体架构

## 1. 目标与入口

nix-config 是个人工作站托管的统一入口，先满足 macOS 主工作站的日常使用，再按维护者的选择复用到 nixbox 或 server。Git 保存认可的软件版本与稳定配置，Nix 负责求值与构建；实际状态及变化证据由私有 Macwarden authority 保存。日常偏移、选择同步与记录边界见[主工作站管理](workstation-management.md)，术语见 [CONTEXT.md](../../CONTEXT.md)。

声明使用一个顶层 Flake、一个 lock file 和显式 import graph：

- 一个软件只有一个 package/config/service owner；
- 跨软件需求集中在 Intent，Host 保留最终选择；
- Check、Operation 与 production graph 单向依赖；
- 外部 state 和操作影响保持可见。

## 2. 当前目录

```text
flake.nix / flake.lock      inputs、outputs 与顶层 wiring
hosts/<host>/               最终选择、hardware 与 provider facts
software/<software>/        Software owner 与 owner-local package/assets
intents/<intent>/           跨 Software 的纯组合
modules/                    少量已证明复用的系统/Home primitive
checks/                     窄 contract checks
operations/                 明确、人工触发的安全操作
dotfiles/                   Nix 投影的稳定静态文件
docs/                       当前架构、ADR、runbook 与 Agent 规范
.macwarden/                 主 checkout 内被 Git 忽略的私有记录
```

`software/` 与 `intents/` 承担声明的主要业务结构。`modules/` 只保留有实际跨 owner consumer 或属于 System 层的基础能力；路径边界见[模块与目录边界](module-boundaries.md)。Macwarden 的工具源码和 Skills 仍由独立工具项目维护，私有 authority 不进入 Flake 或公开 Git 历史。

## 3. 组合模型

```text
Flake output
  └── Host
       ├── realized Intent lists
       │    └── public Software capabilities/extensions
       ├── independent Software platform modules
       └── host facts and proven system primitives

Check / Operation ──read──▶ production declarations
production declarations ──X──▶ Check / Operation
```

### 3.1 Software 纵轴

每个 `software/<name>/` 是该软件的局部 owner。Primary Capability 表达主要行为；Extension 表达 owner-local 的窄贡献。可供 Intent 使用的 owner 通过 `default.nix` 暴露公开接口，内部 capability 文件仍保持路径局部。

Software 不知道 Host，也不 import Intent。Package expression、固定数据、脚本与平台实现尽量与 owner 共置；只有 package、配置 API、service、network effect 或实际操作边界不同才形成 platform seam。

### 3.2 Intent 横轴

Intent 处理必须同时选择多个 Software 的需求，例如 terminal work、code development 或 Chinese input。Intent 使用 `intents/lib.nix` 从空 state 开始，依次应用公开 capability/extension，最后只返回 `darwinModules`、`nixosModules` 与 `homeModules` 三个显式列表。

Intent 不写软件私有 primitive，不建立 relation graph，也不根据目录内容自动发现 owner。一个真实需求只有一个 owner；不以 registry、workflow、substrate 或平台 bundle 建立第二套组合模型。

### 3.3 Host caller

Host 选择 Intent、无需横向组合的独立 Software platform module，以及机器和硬件事实，并把 Home Manager modules 放入目标用户。Home Manager 管用户层，nix-darwin 与 NixOS modules 分别管 macOS 与 NixOS 系统层。

三台 Host 互不继承。macbook 的完整桌面不是 nixbox/server 的基类，Linux 或 Darwin 名称也不自动携带软件集合。完整选择以 `hosts/<host>/default.nix` 为准，不另维护手写 capability matrix。

## 4. Flake outputs

生产 outputs：

- `darwinConfigurations.macbook`
- `nixosConfigurations.nixbox`
- `nixosConfigurations.server`

显式 package/app outputs 只为真实操作或独立验证提供稳定入口，例如 Zed binary package、Clash Verge Rev package 和 Zed 手动更新。按需的 `server-recovery-install` installation configuration 不是已经执行的恢复动作；任何 Output 也不表示已经 activation。

Darwin 使用 rolling nixpkgs/nix-darwin/Home Manager inputs；Linux 使用 26.05 release inputs。两条 cadence 共享同一 lock file；现有平台版本差异不表示维护者已经要求同步。显式同步选中软件时，仍须满足[主工作站管理](workstation-management.md)中的版本要求。

`system.stateVersion` 与 `home.stateVersion` 保留首次采用值，不随 channel 升级。

## 5. Check 与 Operation

Check 验证窄接口和最终 host output，例如 FZF/Zed contribution、Pinshift host selection、Tailscale SSH fragment 与主机 closure。构建成功不能替代现场行为验证，也不能证明未选中的目标状态没有改变。

Operation 只在确实存在需要维护者运行的流程时建立。Server recovery 当前只保留按需的 `server-recovery-install` installation configuration；仓库不提供默认 VM runner，完整 VM 演练也不是日常验证的必经步骤。磁盘、启动、网络或 SSH 声明发生相关变化时，再明确目标、执行器、停止条件与回滚，并按当前协议执行对应验证。

## 6. 配置与数据边界

Git/Nix 可以拥有 package 选择、稳定设置、systemd/launchd 声明、静态文件、明确 firewall rule 与可构建 Operation。它们不自动拥有数据库、history、userdb、cache、browser profile、应用账号、token、private key、workspace、容器 volume、云端数据与备份。

必要的可变状态边界保留在最近的 Software owner 或当前 runbook。项目开发依赖属于项目 dev shell；工作站可变运行时属于明确选择的 Software/Intent；server workload 运行时属于服务 closure 或容器合同。Secret 机制由真实 consumer 引入，当前没有预置 secret framework。

可复现所需的 host/hardware facts 保存在 `hosts/<host>/`。Credential、账号标识及其他不影响构建的敏感事实不进入公开文档；已获准版本化的非凭据主机事实遵循对应主机合同。

## 7. 主机角色与控制关系

| Host | 角色与主要管理层 | 组合重点与边界 |
| --- | --- | --- |
| `macbook` | 主工作站与维护者控制面；nix-darwin + Home Manager | 完整工作站 Software、开发/AI/终端 Intents；不承担 Linux closure 原生构建 |
| `nixbox` | 次级工作站、Linux 实验站、server 同架构验证节点；NixOS + Home Manager | Hyprland、核心开发/AI/终端 Intents 与预生产验证；不镜像 macbook GUI，不持有 maintenance private key |
| `server` | 最小 headless NixOS production host；NixOS + Home Manager | 终端、Git、基础运维、诊断与 recovery；无 GUI、GitHub credential、工作站 runtime、Tailscale mesh 或旧 Ubuntu workload |

逻辑 output 名称不要求等于真实 hostname。Server 只按当前需求引入生产能力，并为实际服务明确运行、备份、恢复与 rollback 边界。

维护者从 macbook 直接登录 `server:sayori`，经 `sudo` 或获准的 `sudo -i` 管理；root SSH、password 与 keyboard-interactive 关闭。nixbox 使用独立机器凭据登录同一个远端 `sayori`，负责 `x86_64-linux` closure 的构建、测试与获准部署；两把 key 划分凭据保管和撤销边界，不提供 Unix 权限隔离。

nixbox 不是 server 的 bastion。macbook 直达链路与 provider VNC/Rescue 共同保留恢复能力；server 接收已构建 closure，运行时不依赖 GitHub 或 mutable checkout。macbook 到 nixbox 的稳定 transport 使用 Tailscale，用户与 host 认证由 native OpenSSH 承担，tmux 保留断线后的工作现场。技术决策见 [ADR-0008](../adr/0008-direct-nixos-server-replacement.md) 和 [ADR-0010](../adr/0010-tailscale-stable-workstation-access.md)。

## 8. 变更归属与当前协议

单软件行为进入 Software，跨软件选择进入 Intent，硬件/provider facts 进入 Host。检查、构建、真实机器操作与协作方式以当前 [AGENTS.md](../../AGENTS.md)、[协作流程](../agents/issue-tracker.md)和适用 runbook 为准。

历史 ADR 保留技术选择与当时证据；其中迁移期的 Issue/PR、合并后激活等协作要求按当前协议执行。流程简化不自动更改软件来源、固定版本、供应链或数据安全边界。
