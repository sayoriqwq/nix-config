# 项目上下文

## 1. 领域与边界

本仓库管理个人基础设施的声明式配置：系统设置、软件、稳定用户配置、服务定义与可重复验证。Git 保存声明和审计历史，Nix 负责求值与构建。

本仓库不拥有应用数据库、浏览器资料、账号登录态、凭据、用户内容或备份。Agent 可以修改声明并完成非激活验证；真实机器 activation、外部控制面和破坏性动作受人工关卡约束。

## 2. 当前主机

| 逻辑 output | 已声明角色 | 主要管理层 |
| --- | --- | --- |
| `macbook` | 主工作站与维护者控制面 | nix-darwin + Home Manager，Darwin rolling inputs |
| `nixbox` | 次级工作站、Linux 实验站、server 同架构验证节点 | NixOS + Home Manager，Linux release inputs |
| `server` | 最小 headless NixOS production host | NixOS + Home Manager，只组合基础运维、诊断与 recovery 所需能力 |

逻辑 output 名称不要求等于真实 hostname。地址、账号标识、credential 和其他不影响构建的敏感事实不进入文档；可复现所需的 host/hardware facts 直接保存在 `hosts/<host>/`。

## 3. 统一语言

### Declaration

进入 Git、可由 Nix 求值或构建的期望状态。Declaration 不表示真实机器已经 activation。

### Software

`software/<software>/` 下的软件 owner。它拥有该软件的 package、稳定配置、服务、平台实现与必要安全边界，不把可变应用数据据为 Nix 所有。

### Primary Capability

Software 对外提供的主要行为，例如 Git version control、Zed GUI editor 或 Tailscale stable workstation access。供 Intent 使用时，由 owner 的 `default.nix` 暴露为对组合 state 的窄变换。

### Extension / Contribution

Software 对另一个已选择行为的窄扩展，例如 Zsh integration、Zed task 或 FZF configure。Extension 仍由提供它的 Software owner 定义；它不形成通用 relation、registry 或 contribution framework。

### Intent

`intents/<intent>/` 下跨多个 Software 的可执行需求组合。Intent 只调用 Software 的公开 Primary Capability 或 Extension，最终产生 `darwinModules`、`nixosModules` 与 `homeModules` 三个显式列表。

### Host

`hosts/<host>/` 下的最终 caller。Host 选择 Intent、无需横向组合的独立 Software platform module，以及机器和硬件事实。Host import graph 就是最终选择事实；不存在第二份 capability registry 或自动发现。

### System primitive

`modules/` 下少量不属于单个 Software、且被实际消费者复用的系统或 Home Manager primitive。它不是 host bundle，也不能替代 Intent 或 Software owner。

### Check

`checks/` 下的窄、确定性合同验证。Check 可以引用 production declaration；production graph 不得反向依赖 check。

### Operation

`operations/` 下供维护者显式调用的安全操作入口。Operation 必须固定边界、拒绝隐式 target，并把 production mutation 留在单独的人工作业卡。当前 server recovery Operation 只运行隔离验证，不接受 production target。

### Managed configuration

由 Nix 拥有的软件安装或稳定配置。它不因此拥有数据库、缓存、登录态、history、workspace、userdb 或用户文件。

### Mutable / external state

应用或维护者在 Nix Store 外拥有的可写状态。必要 owner 边界应靠局部注释、runbook 或服务合同表达，不建立无人消费的全局路径清单。

### Activation

把已构建 generation 应用到真实机器。Build、evaluation、PR merge 与 activation 是不同关卡。

### Human approval gate

对真实机器或外部控制面动作的当前、具体授权。高风险批准必须写明 target、动作、执行窗口、停止条件、验证与 rollback；早期泛化同意不能自动复用。

### Side-effect drift

声明合同与外部运行态事实不一致。处理 drift 必须明确 owner、readback 与 control/human gate，不推导为“所有外部状态都应自动 reconcile”。

## 4. 组合关系

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

- 一个真实需求只有一个 owner；不要用 platform、workflow、relation、substrate、internal 或 bundle 建第二套架构语言。
- 一个 Software 可以有多个平台文件，但只有行为真的不同才形成 platform seam。
- Host 明确选择，不从 macbook、Linux 或 desktop 角色隐式继承。
- 项目开发依赖属于项目 dev shell；工作站可变运行时属于明确选择的 Software/Intent；server workload 运行时属于服务 closure 或容器合同。
- Secret 机制只由真实 consumer 引入；当前没有预置 secret framework。

## 5. 控制与恢复关系

- 维护者从 macbook 直接登录 `server:sayori`，再经 `sudo` 或获批的 `sudo -i` 管理；root SSH、password 与 keyboard-interactive 关闭。
- nixbox 使用独立机器凭据登录同一个远端 `sayori`，负责 `x86_64-linux` closure 的构建、测试与获批部署。两把 key 是凭据保管和撤销边界，不是 Unix 权限隔离。
- nixbox 不是 server 的 bastion；macbook 直达链路与 provider VNC/Rescue 共同保留恢复能力。
- macbook 到 nixbox 的稳定 transport 使用 Tailscale；用户与 host 认证仍由 native OpenSSH 承担，tmux 负责断线后的工作现场。

## 6. 不变量

1. 一个顶层 Flake 和一个 lock file 管理三台主机。
2. Host/hardware facts 留在 `hosts/`；Software ownership 留在 `software/`；横向需求留在 `intents/`。
3. 明确 import 优先于 registry、自动扫描和平台 bundle。
4. Home Manager 管用户层；nix-darwin 与 NixOS modules 管系统层。
5. `system.stateVersion` 与 `home.stateVersion` 保留首次采用值，不随 channel 升级。
6. 外部 state、secret 和数据恢复不由 Git 或 generation 隐式接管。
7. Server 不恢复旧 Ubuntu 业务；新 production 能力必须按当前需求独立建立运行、备份、恢复与 rollback 合同。
