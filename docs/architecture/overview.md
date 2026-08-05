# 整体架构

## 1. 架构目标

本仓库采用“**一个 Flake、多个主机输出、按能力组合**”的结构。目标不是让三台机器拥有完全相同的软件，而是让同一项真实能力只有一个定义，并由各主机按角色显式选择。

Phase 1 已确认的 output 与平台边界如下：

| output | 平台 | 当前角色 |
| --- | --- | --- |
| `macbook` | `aarch64-darwin` | 主工作站，组合完整工作站、Darwin 与兼容能力 |
| `nixbox` | `x86_64-linux` | 次级工作站、Linux 试验站与 Server 预生产验证站 |
| `server` | `x86_64-linux` | 已验收的最小 Headless NixOS，后续能力按需引入 |

```text
flake.nix + flake.lock
│
├── darwinConfigurations.<mac-host>
│   ├── hosts/<mac-host>
│   ├── modules/darwin/*
│   ├── modules/capabilities/*/darwin.nix
│   └── Home Manager: 显式 capability imports
│
├── nixosConfigurations.<workstation-host>
│   ├── hosts/<workstation-host>
│   ├── modules/nixos/base.nix
│   ├── modules/nixos/desktop.nix
│   ├── modules/capabilities/*/nixos.nix
│   └── Home Manager: 已批准的 capability subset
│
└── nixosConfigurations.<server-host>               # 最终状态
    ├── hosts/<server-host>
    ├── modules/nixos/base.nix
    ├── modules/nixos/server.nix
    ├── modules/capabilities/*/nixos.nix
    └── Home Manager: headless capability subset
```

server 已通过只读盘点、最小 NixOS、隔离 VM 测试和人工批准的正式替换进入上述基线；旧 Ubuntu 层不恢复。

## 2. 配置事实来源

- Git 提交记录说明“配置为什么变化”。
- `flake.lock` 固定“依赖的准确版本”。
- 每台真实机器的 inventory 说明“主机事实来自哪里”。
- ADR 说明“重大架构选择为什么成立”。
- GitHub Issue 说明“当前阶段允许做什么、禁止做什么”。
- PR 与构建日志说明“变化是否经过验证”。

真实机器不是长期配置事实来源，但在接入阶段是硬件、网络、状态版本和已有服务事实的证据来源。

## 3. 分层模型

### 3.1 Flake 编排层

职责：

- 声明 inputs；
- 固定依赖关系；
- 组合各主机模块；
- 暴露明确、稳定的主机 output；
- 提供 checks、formatter 或开发工具入口。

不承担大量具体配置。避免把整套系统逻辑都塞进 `flake.nix`。

平台 input 采用独立更新节奏：macbook 的 `nixpkgs-darwin` 跟随
`nixpkgs-unstable`，nix-darwin 跟随 `master`；nixbox/server 的根 nixpkgs 继续跟随
`nixos-26.05`，Home Manager 继续跟随 `release-26.05`。所有 input 仍由同一份
`flake.lock` 固定精确 revision；详见 ADR-0009。

### 3.2 主机层

`hosts/<host>/` 保存只属于该机器的事实：

- host platform；
- 主机名；
- bootloader 与启动模式；
- 文件系统、swap 与磁盘布局；
- GPU 和硬件服务；
- 网络接口或 provider 特殊设置；
- 原有 `system.stateVersion`；
- 主机专属模块组合。

服务器的 `disko.nix` 也属于主机层，因为磁盘布局必须和目标机器一致。

### 3.3 系统模块层

- `modules/darwin/`：macOS defaults、系统用户、Shell 注册和通用 Darwin 系统行为；按需求选择的 Homebrew 应用进入对应 capability adapter。
- `modules/nixos/`：Nix 设置、系统用户、SSH、基础防火墙、桌面、服务器服务与通用 Linux 系统行为。

系统模块应按角色复用，不得依赖某一台机器的磁盘名、网卡名或硬件事实。

### 3.4 能力模块与基础配置

- `modules/home/capabilities/` 保存 host 可直接选择的纯用户能力，例如可移植 Shell、终端历史、Git 基础或编辑器；
- `modules/home/common/`、`modules/home/desktop/` 与 `modules/home/darwin/` 中的细粒度文件是基础配置实现，不再通过大 `default.nix` 作为 host bundle；
- `modules/capabilities/<name>/` 保存真实跨层能力，内部可同时提供 `home.nix` 与平台 adapter；
- host 显式 import 即表示采用能力，不再设置第二套 `capabilities.*.enable` 注册值。

能力 module 的 interface 必须公开其软件与稳定配置所有权、可变状态路径、系统服务或网络影响及人工关卡。只有两个真实平台行为确实不同，才形成 adapter seam。LocalSend 是当前示例：Home Manager 拥有 package；Darwin adapter 记录可写容器状态；Phase 6 的 NixOS adapter 还必须公开 TCP/UDP 53317 firewall 合同。纯用户能力不为了形式统一创建空 system adapter。

能力内部的 Home Manager 实现不配置 bootloader、磁盘或未公开的系统副作用。

### 3.5 Dotfiles 层

优先顺序：

1. 使用 Home Manager 的 `programs.*` 模块；
2. 使用结构化模块选项；
3. 使用 `xdg.configFile` / `home.file` 链接静态配置；
4. 最后才使用自定义模块或 activation script。

会被程序持续写入的数据库、缓存、session 和 profile 目录不能整体链接到只读 Nix Store。

### 3.6 机密层

Phase 11 建立了 SOPS + sops-nix + age 基础：

- Git 只保存按真实消费者批准的加密文件；当前没有 production secret；
- 解密在 activation 时发生；
- 服务通过文件路径读取机密；
- 明文不得作为普通 Nix 字符串进入 Store；
- 每台机器使用现有 Ed25519 SSH host identity 派生的独立 age recipient；
- 每个 host 文件只授予管理员恢复 recipient 和该 host recipient；
- 管理员 identity 和编辑工具只留在 macbook；恢复副本由维护者在仓库外自行管理，nixbox 与 server 不获得编辑能力。

机密部署 adapter 只声明身份与解密基础；具体 secret 的 source、path、owner、mode 与服务合同由后续独立 Issue 的消费者声明。

### 3.7 控制身份与机器关系

维护者、macbook 与 nixbox 不能被折叠成同一个“管理员”身份：

```text
维护者 ──macbook 本地 Host alias `sayori`──▶ server:root
   │                                           ▲
   └──Unix 用户 `sayori`──▶ nixbox ────────────┘
                           独立 deploy identity
```

- 维护者本人通过 macbook 直达 server 的 `root`，不经过 nixbox，也不先登录 server 普通用户再 `sudo`；
- `ssh sayori` 中的 `sayori` 是 macbook 本地 Host alias，不能误写成 server 的 Unix username；
- root SSH 只允许维护者公钥，password 与 keyboard-interactive 保持关闭；Contabo VNC 提供已实连验证的带外恢复；
- 维护者在 nixbox 上使用实际 Unix 用户 `sayori`；nixbox 同时是 `x86_64-linux` build/test 节点，并以独立 deploy identity 登录 server 的实际 Unix 用户 `sayori`，只在获批部署中使用 `sudo -n` 应用 closure；
- nixbox 的机器身份不等于维护者本人，不获得 macbook maintenance private key，也不形成 macbook 管理 server 的必经 bastion。

这一单管理员模型是维护者对当前个人 server 的明确取舍。若未来增加管理员、自动化主体或合规审计要求，应另建 Issue 重新评估 root 直连、sudo 边界和 deploy identity，不从当前单用户前提外推。

## 4. 工具选择与引入顺序

### 基础工具

| 工具 | 角色 | 引入阶段 |
| --- | --- | --- |
| Flakes | inputs、lock file、多主机 outputs | 仓库骨架 |
| Lix | `macbook` 的 Nix 实现与 bootstrap；见 ADR-0005 | macOS 最小接入 |
| nix-darwin | macOS 系统层 | macOS 最小接入 |
| Home Manager | 能力模块中的用户配置实现 | macOS 用户能力与后续主机组合 |
| nix-homebrew / nix-darwin Homebrew options | 迁移期遗留 Homebrew 声明；终态逐项退出 | Mac 基础稳定后 |
| `nh` | 友好的构建命令与 diff 展示 | 基础用户工具阶段 |
| sops-nix + age | 机密部署 | 两台本地机器稳定后 |
| disko | 服务器磁盘声明 | 服务器 NixOS 设计阶段 |
| nixos-anywhere | 服务器恢复演练的内部安装测试依赖 | `server-recovery-test`，不暴露生产 target 参数 |

### 延后工具

flake-parts、Blueprint、Clan、deploy-rs、Colmena、impermanence、ZFS、LUKS 等会显著改变抽象或风险面。它们不是被永久禁止，而是必须等 v1 运行稳定后，通过独立 Issue 和 ADR 证明收益大于复杂度。

## 5. 状态与数据边界

```text
Git / Nix 管理
  软件包选择
  系统和用户选项
  服务定义
  静态 dotfiles
  加密后的 secret 声明

独立数据流程管理
  数据库内容与 dump
  容器 volume
  浏览器 profile
  用户上传文件
  缓存和 session
  运行时日志
  备份与异地副本
```

服务器迁移时，系统声明和业务数据必须分别验证。不能把“系统能启动”与“业务数据已恢复”当作同一个成功条件。若维护者明确声明 source data 全部可丢失，必须记录 waiver，并把失败恢复目标收敛为可救援的最小系统；该 waiver 不能放宽 boot、network、SSH、console/rescue 或精确 destructive approval。

## 6. 日常变更流程

```text
选择当前 Phase Issue
        ↓
阅读规则、上下文、ADR 和允许范围
        ↓
在独立分支修改
        ↓
格式化、evaluate、build（不激活）
        ↓
创建中文 Draft PR
        ↓
Agent/人工 review
        ↓
维护者在目标机器执行批准的 test/boot/switch
        ↓
记录结果、合并、关闭 Issue
```

## 7. 部署风险等级

| 变更 | Agent 可完成 | 需要人工操作 |
| --- | --- | --- |
| 文档、ADR、Issue 规划 | 是 | 审阅与合并 |
| Nix 代码编写与离线 build | 是 | 最终审阅 |
| 在 Mac/NixOS 上执行 `test` | 仅在明确授权的机器本地会话 | 确认登录、网络、桌面与回滚 |
| `switch` / `boot` | 否，默认停在关卡前 | 维护者当次批准并执行/监督 |
| 服务器网络、磁盘、重装 | 否 | 完整备份/恢复验证或明确的数据丢失 waiver，以及控制台与精确批准 |
| 生产数据恢复与迁移 | 否 | 维护者监督和业务验证 |

## 8. 成功标准

v1 完成时应达到：

- 三台机器的配置都来自同一个仓库；
- 每台机器可以独立 build 自己的 output；
- 三台主机通过需求驱动的能力模块复用配置，不从 macbook 继承整套 bundle；
- server 已按人工关卡从 Ubuntu 直接替换为可恢复的 NixOS output；
- 机密不以明文进入 Git；
- 服务器具备可验证的数据处置与失败恢复策略：stateful data 使用备份/恢复手册，或 source data 已有明确丢失 waiver；控制台与救援手册始终存在；
- 新机器或重装流程有文档，但破坏性执行仍保留人工关卡。
