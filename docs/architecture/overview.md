# 整体架构

## 1. 架构目标

本仓库采用“**一个 Flake、多个主机输出、分层复用**”的结构。目标不是让三台机器拥有完全相同的软件，而是让共享部分只有一个定义，同时保留操作系统、硬件和角色差异。

Phase 1 已确认的 output 与平台边界如下：

| output | 平台 | 当前角色 |
| --- | --- | --- |
| `macbook` | `aarch64-darwin` | 首个接入目标，承载主要个人配置 |
| `nixbox` | `x86_64-linux` | NixOS 工作站，保留现有硬件与状态版本事实 |
| `server` | `x86_64-linux` | Ubuntu 过渡主机，最终迁移到 NixOS |

```text
flake.nix + flake.lock
│
├── darwinConfigurations.<mac-host>
│   ├── hosts/<mac-host>
│   ├── modules/darwin/*
│   └── Home Manager
│       ├── modules/home/common.nix
│       ├── modules/home/desktop.nix
│       └── modules/home/darwin.nix
│
├── nixosConfigurations.<workstation-host>
│   ├── hosts/<workstation-host>
│   ├── modules/nixos/base.nix
│   ├── modules/nixos/desktop.nix
│   └── Home Manager
│       ├── modules/home/common.nix
│       ├── modules/home/desktop.nix
│       └── modules/home/linux.nix
│
├── homeConfigurations."<user>@<ubuntu-host>"       # 过渡期
│   ├── modules/home/common.nix
│   ├── modules/home/linux.nix
│   └── modules/home/server.nix
│
└── nixosConfigurations.<server-host>               # 最终状态
    ├── hosts/<server-host>
    ├── modules/nixos/base.nix
    ├── modules/nixos/server.nix
    └── Home Manager
        ├── modules/home/common.nix
        ├── modules/home/linux.nix
        └── modules/home/server.nix
```

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

- `modules/darwin/`：macOS defaults、系统包、Homebrew 集成、系统用户和 Darwin 服务。
- `modules/nixos/`：Nix 设置、系统用户、SSH、基础防火墙、桌面、服务器服务与通用 Linux 系统行为。

系统模块应按角色复用，不得依赖某一台机器的磁盘名、网卡名或硬件事实。

### 3.4 用户模块层

- `common.nix`：真正跨平台、可用于 headless server 的基础用户环境；
- `desktop.nix`：桌面工作站共有的用户设置；
- `darwin.nix`：macOS 专属用户设置；
- `linux.nix`：Linux 专属用户设置；
- `server.nix`：服务器最小用户环境。

用户模块不配置 bootloader、系统防火墙、系统 daemon 或磁盘。

### 3.5 Dotfiles 层

优先顺序：

1. 使用 Home Manager 的 `programs.*` 模块；
2. 使用结构化模块选项；
3. 使用 `xdg.configFile` / `home.file` 链接静态配置；
4. 最后才使用自定义模块或 activation script。

会被程序持续写入的数据库、缓存、session 和 profile 目录不能整体链接到只读 Nix Store。

### 3.6 机密层

计划使用 sops-nix + age：

- Git 只保存加密文件；
- 解密在 activation 时发生；
- 服务通过文件路径读取机密；
- 明文不得作为普通 Nix 字符串进入 Store；
- 每台机器的解密身份按最小权限配置。

机密方案在专门阶段启用，不和第一次系统接入混在一起。

## 4. 工具选择与引入顺序

### 基础工具

| 工具 | 角色 | 引入阶段 |
| --- | --- | --- |
| Flakes | inputs、lock file、多主机 outputs | 仓库骨架 |
| Lix | `macbook` 的 Nix 实现与 bootstrap；见 ADR-0005 | macOS 最小接入 |
| nix-darwin | macOS 系统层 | macOS 最小接入 |
| Home Manager | 跨平台用户层 | macOS 用户层与后续主机 |
| nix-homebrew / nix-darwin Homebrew options | Mac 专属 GUI 与 Homebrew 声明 | Mac 基础稳定后 |
| `nh` | 友好的构建命令与 diff 展示 | 基础用户工具阶段 |
| sops-nix + age | 机密部署 | 两台本地机器稳定后 |
| disko | 服务器磁盘声明 | 服务器 NixOS 设计阶段 |
| nixos-anywhere | 通过 SSH 安装服务器 | VM 测试与人工批准后 |

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

服务器迁移时，系统声明和业务数据必须分别验证。不能把“系统能启动”与“业务数据已恢复”当作同一个成功条件。

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
| 服务器网络、磁盘、重装 | 否 | 完整备份、恢复验证、控制台与明确批准 |
| 生产数据恢复与迁移 | 否 | 维护者监督和业务验证 |

## 8. 成功标准

v1 完成时应达到：

- 三台机器的配置都来自同一个仓库；
- 每台机器可以独立 build 自己的 output；
- macOS 与 NixOS 共享真正可移植的 Home Manager 模块；
- Ubuntu 过渡配置可被最终 NixOS server output 替代；
- 机密不以明文进入 Git；
- 服务器具备可验证的备份、恢复和救援手册；
- 新机器或重装流程有文档，但破坏性执行仍保留人工关卡。
