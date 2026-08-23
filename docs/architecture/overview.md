# 整体架构

## 1. 架构目标

本仓库采用“**一个 Flake、多个主机输出、Intent 横向组合 Software Capability**”的结构。目标不是让三台机器拥有完全相同的软件，而是让软件原子行为只有一个 owner，让经批准的用户结果只在 Intent 中组合，并由各主机按角色显式选择。

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
│   └── hosts/<mac-host>
│       ├── Intent realized darwinModules
│       ├── Intent realized homeModules
│       └── 尚未迁移的显式 system/capability imports
│
├── nixosConfigurations.<workstation-host>
│   └── hosts/<workstation-host>
│       ├── Intent realized nixosModules
│       ├── Intent realized homeModules
│       └── 尚未迁移的显式 system/capability imports
│
└── nixosConfigurations.<server-host>
    └── hosts/<server-host>
        ├── Intent realized nixosModules
        ├── Intent realized homeModules
        └── 最小 production system modules
```

server 已通过只读盘点、最小 NixOS、隔离 VM 测试和人工批准的正式替换进入上述基线；旧 Ubuntu 层不恢复。

Server recovery 是独立 Operation：`operations/server-recovery/` 可以组合 production server declarations 与 test-only VM module，并通过 `checks`、`packages` 和 `apps` 暴露黑盒验证；`nixosConfigurations.server` 不得反向 import Operation、check 或 test-only implementation。

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

Operation output 只能从 validation graph 引用 production declarations。Production host output 不得依赖 `checks/` 或 `operations/`；server recovery 的隔离安装 configuration 只服务锁定的 nixos-anywhere `--vm-test`，不接受 production target。

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

### 3.4 Intent 与 Software Capability

- `software/<software>/` 是纵轴 owner：公开最小、可选择的 Software Capability，以及确有组合逻辑的窄 contribution interface；
- `intents/<intent>/default.nix` 是横轴需求图：使用 `lib.pipe` 显式选择 Software Capability 并调用 contribution；
- `intents/lib.nix` 只提供 `empty`、`addModules` 与 `realize`，累计并公开 Darwin、NixOS、Home Manager 三个原生 module lists；
- Host 是 composition root，在 system `imports` 与 Home Manager `imports` 两个原生位置消费 realized lists；无需横向组合的 Software Capability 仍可被 Host 直接选择；
- `modules/**` 中尚未迁移的能力按后续唯一 owner Issue 逐批退出，不形成第二套新 registry 或 bundle。

Software Capability 不知道具体 Intent。Intent pipeline 本身就是需求选择与组合的唯一事实源；不得再维护 capability registry、自动扫描、独立 contract、Workflow、Relation 或自定义冲突协议。若两个 Capability 争夺同一不可合并原子，应修正 owner 边界，而不是用 `mkForce`、`//` 或隐式优先级选择 winner。

跨层 Software Capability 必须公开 package ownership、managed configuration、mutable-state paths、services、network effects 与 human approval gates。只有真实平台行为不同才形成 adapter seam；纯用户行为不创建空 Darwin/NixOS 文件。

中文输入是真实的双平台 Intent：`software/fcitx5/` 拥有 frontend/framework，
`software/rime-ice/` 拥有 schema/addon/data package，`intents/chinese-input/` 只组合两者。
Darwin adapter 保留外部 Fcitx5.app frontend；NixOS adapter 使用锁定的原生
`i18n.inputMethod` 模块拥有唯一 package、daemon、session environment 与 XDG autostart。
Home Manager 只投影静态 leaves 并记录可写状态，不成为第二个 input-method owner。

nixbox 桌面由 `intents/hyprland-workstation/` 显式选择 Hyprland 会话、display manager、
network/audio/realtime scheduling 及用户桌面组件；常在行为由独立
`intents/always-on-workstation/` 组合。Avahi、BlueZ 与 Tailscale 是 Host 直接选择的原子
Software Capability，不存在 graphical/common bundle。

### 3.5 Dotfiles 层

优先顺序：

1. 使用 Home Manager 的 `programs.*` 模块；
2. 使用结构化模块选项；
3. 使用 `xdg.configFile` / `home.file` 链接静态配置；
4. 最后才使用自定义模块或 activation script。

会被程序持续写入的数据库、缓存、session 和 profile 目录不能整体链接到只读 Nix Store。

终端主题在外部设计源与本仓库运行时 adapter 之间建立一个 owner-local data seam：
`software/yume-design/capabilities/terminal-theme/home.nix` 一次读取并校验锁定非 Flake input
中的颜色、语义 Token 与 appearance，再通过 `_module.args.terminalTheme` 向 Ghostty、WezTerm、
Fish 与 Starship adapter 提供数据。本仓库继续拥有字体、透明度、窗口、Shell/prompt 行为
及部署声明。消费者显式选择同一个具名 provider module；不复制 HEX，也不维护全局 metadata
或从 ANSI 槽位反推语义 Token。

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
维护者 ──macbook maintenance identity──▶ server:sayori ──sudo / sudo -i──▶ root
   │                                         ▲
   └──Unix 用户 `sayori`──▶ nixbox ──────────┘
                           独立 deploy identity
```

- 维护者本人通过 macbook 直达 server 的实际 Unix 用户 `sayori`，不经过 nixbox；单条特权操作使用 `sudo`，连续 root 操作使用 `sudo -i`，不使用 `su` 或 root password；
- `ssh sayori` 中的 `sayori` 同时是 macbook 本地 Host alias 与该 Host 当前配置的远端 Unix username，文档必须分别说明，不能再把它解释为 `root`；
- root SSH、password 与 keyboard-interactive 保持关闭；Contabo VNC 提供已实连验证的带外恢复；
- 维护者在 nixbox 上使用实际 Unix 用户 `sayori`；nixbox 同时是 `x86_64-linux` build/test 节点，并以独立 deploy identity 登录 server 的实际 Unix 用户 `sayori`，只在获批部署中使用 `sudo -n` 应用 closure；
- nixbox 的机器身份不等于维护者本人，不获得 macbook maintenance private key，也不形成 macbook 管理 server 的必经 bastion；两把 key 共享远端 account 与 sudo policy，分离的是凭据生命周期和认证来源，不是 Unix 授权。

这一单管理员模型是维护者对当前个人 server 的明确取舍。若未来增加管理员、自动化主体或合规审计要求，应另建 Issue 重新评估 account、sudo 边界和 deploy identity，不从当前单用户前提外推。

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
| nixos-anywhere | `operations/server-recovery` 的隔离安装测试 engine | `server-recovery-test`，不暴露 production target 参数 |

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
