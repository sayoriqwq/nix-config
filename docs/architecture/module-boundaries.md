# 模块与目录边界

本文定义未来 Nix 实现中各路径的职责。Agent 必须优先遵守当前 Issue 的允许范围；Issue 未说明时，以本文件为默认边界。

## 1. 目标目录结构

```text
.
├── flake.nix
├── flake.lock
├── hosts/
│   ├── <mac-host>/
│   │   └── default.nix
│   ├── <nixos-workstation>/
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   └── <server-host>/
│       ├── default.nix
│       ├── disko.nix
│       └── hardware-configuration.nix 或 facter.json
├── modules/
│   ├── home/
│   │   ├── common/
│   │   │   ├── default.nix
│   │   │   ├── shell/
│   │   │   └── cli/
│   │   ├── desktop/
│   │   │   ├── default.nix
│   │   │   └── terminal/
│   │   ├── darwin/
│   │   │   └── default.nix
│   │   ├── linux.nix
│   │   └── server.nix
│   ├── darwin/
│   │   ├── base.nix
│   │   └── homebrew.nix
│   └── nixos/
│       ├── base.nix
│       ├── desktop.nix
│       └── server.nix
├── dotfiles/
├── secrets/
└── docs/
```

只有对应阶段真的需要时才创建路径。不要为了满足结构图而提前加入空模块。

## 2. 路径职责矩阵

| 路径 | 允许内容 | 禁止内容 |
| --- | --- | --- |
| `flake.nix` | inputs、outputs、少量组合 helper、checks/formatter | 大量程序配置、主机硬件细节、明文机密 |
| `hosts/<host>/` | 主机平台、硬件、boot、磁盘、主机名、专属网络、state version、模块组合 | 可被多主机复用的通用软件配置 |
| `modules/home/common/` | 跨平台且适用于 headless host 的 Shell、Git、编辑器、tmux、direnv 与通用 CLI | GUI、Homebrew、systemd、launchd、Linux/macOS 专属路径、服务器 daemon |
| `modules/home/common/shell/` | Fish/Zsh 自身的 history、颜色、编辑模式与原生键位 | 第三方 CLI 的安装、alias、hook 或配置 |
| `modules/home/common/cli/` | 跨平台 CLI 的软件、稳定配置及 Fish/Zsh integration；目录由 `default.nix` 显式导出 | GUI、平台应用、可变数据、项目私有版本文件 |
| `modules/home/desktop/` | 两台桌面机器共有的用户级桌面配置 | boot、GPU 驱动、系统桌面服务、服务器工具 |
| `modules/home/desktop/terminal/` | Ghostty + Fish 主环境、WezTerm + Zsh 兼容环境及共享终端语义 | 任意终端/Shell 交叉组合、编辑器配置 |
| `modules/home/darwin/` | macOS 专属用户设置与用户级应用 integration | nix-darwin 系统 defaults、Linux 配置 |
| `modules/home/linux.nix` | Linux 专属用户设置 | NixOS 系统服务、磁盘、bootloader |
| `modules/home/server.nix` | headless 用户工具、最小 shell/编辑环境 | 桌面软件、浏览器、系统 daemon、业务数据 |
| `modules/darwin/` | macOS defaults、系统设置、Homebrew 声明、Darwin 服务 | NixOS 选项、主机硬件事实 |
| `modules/nixos/base.nix` | 多台 NixOS 可复用的基础 Nix、用户、sudo、SSH 和安全默认值 | 某台主机的磁盘、GPU、网卡名 |
| `modules/nixos/desktop.nix` | NixOS 桌面角色的通用系统服务 | 某个桌面的私人 dotfiles、服务器业务 |
| `modules/nixos/server.nix` | NixOS 服务器角色的系统服务与 hardening | 生产数据、明文 `.env`、provider 专属磁盘名 |
| `dotfiles/` | 稳定、静态、由程序读取的配置源 | 缓存、数据库、session、下载内容、私钥 |
| `secrets/` | sops 加密后的文件 | 任何明文 secret、age 私钥 |
| `docs/` | 架构、ADR、计划、runbook、维护说明 | 真实 secret、未脱敏 inventory |

### Phase 3 首次采用范围

`macbook` 首次接入 Home Manager 时，共享用户层只声明 Git、Fish、Helix、tmux、direnv 和一组已在 Mac 使用的跨平台 CLI。Git 身份通过本机私有的 `~/.config/git/identity.inc` 提供，仓库不保存邮箱等账户标识。

Phase 3 曾通过 `modules/home/darwin.nix` 为 Homebrew Fish 补充 Nix profile 与未迁移工具路径。Issue #23 把登录 Shell 切到 Nix Fish，删除通用 Homebrew、OpenClaw、pnpm、Rust 与 Haskell PATH，只保留有独立所有权的 Darwin integration。Atuin 数据库与 key、GitHub CLI 登录状态、Fish universal variables、缓存、history 和其他运行时状态仍在可写目录中，由独立备份流程负责。

### 目录入口约定

- 目录模块只通过 `default.nix` 暴露，不使用 `index.nix`；
- 不允许同一路径同时存在 `name.nix` 与 `name/`；
- import 必须显式列出，不使用递归目录扫描；
- 简单能力使用单个 `.nix`，只有确实存在多个稳定子域或 Shell adapter 时才创建目录；
- 能力模块负责软件、稳定配置、集成与状态边界；快捷键元数据只是生成使用指南的最小投影。

## 3. Import 方向

允许的依赖方向：

```text
flake.nix
  └── host output
       ├── hosts/<host>/
       ├── modules/<platform-or-role>/
       └── Home Manager integration
            └── modules/home/*
```

推荐规则：

- 主机组合通用模块；通用模块不反向 import 某台主机。
- Home Manager 模块不 import 系统模块。
- Darwin 模块不 import NixOS 模块，反之亦然。
- `common/default.nix` 不通过运行时判断偷偷承载平台配置；平台差异应通过显式模块组合表达。
- 可使用少量 `lib.optionals pkgs.stdenv.isDarwin` 处理真正细小的包可用性差异，但不能借此绕过模块边界。
- 不建立循环 import，不依赖隐式递归扫描来决定安全关键主机配置。

## 4. 参数与共享值

共享用户名、inputs 或仓库级常量可以通过 `specialArgs` / `extraSpecialArgs` 传入，但应遵循：

- 只有多个模块确实需要的值才提升为参数；
- secret 不通过 args 传递；
- 主机硬件事实优先留在主机模块；
- 不创建无类型、无文档的巨大 `vars` 属性集；
- 当共享数据增长到需要校验时，创建带 options 的正式 Nix module，而不是继续传任意 attrset。

## 5. 软件归属判断

新增一个软件或配置时按以下顺序判断：

1. 是项目开发依赖吗？放入项目自己的 dev shell。
2. 是用户级且跨平台吗？放入 `modules/home/common/`。
3. 是桌面用户级且两台工作站共享吗？放入 `modules/home/desktop/`。
4. 只属于某个平台的用户吗？放入 `home/darwin/` 或 `home/linux.nix`。
5. 只属于服务器用户环境吗？放入 `home/server.nix`。
6. 是操作系统服务或全局设置吗？放入对应 Darwin/NixOS 系统模块。
7. 是硬件、boot、磁盘或 provider 事实吗？放入 `hosts/<host>/`。
8. 是可变数据或 secret 吗？不要作为普通 Nix 配置提交，使用对应数据/机密流程。

## 6. Homebrew 边界

Mac 上遵循：

- Nix 能可靠管理的软件优先由 Nix 安装，稳定配置由 nix-config 管理；
- 无法由 Nix 可靠管理的应用可以完全外置，但仓库不接管其配置或 integration；
- Homebrew 是迁移期事实，不是新增软件的默认终态；现有 formula/cask 按独立 Issue 逐项退出；
- 迁移期不启用会批量删除软件的 cleanup/zap；
- 任何定向卸载都必须先在 Issue 中列出精确目标并由维护者当次批准。

### 6.1 语言运行时所有权

Node 与 Bun 的版本切换是 mise 的核心职责，不按普通全局 CLI 处理：

- Nix/Home Manager 只安装 mise 本体、管理稳定默认值和 shell integration；
- Node、Bun 的安装、全局默认和项目版本切换全部由 mise 管理；
- `home.packages` 不得直接包含 `nodejs`、`nodejs-slim` 或 `bun`，违反时必须在求值阶段失败；
- 共享默认值放在 Nix 管理的 mise `conf.d` 文件，`mise use -g` 的个人可写结果留在 `~/.config/mise/config.toml`；
- 项目版本事实由项目自己的 `mise.toml` 管理，个人项目覆盖使用不提交的 `mise.local.toml`；
- mise 的 runtime、cache、state 和已安装版本属于可变数据，不进入 Nix Store，也不因切换安装来源而删除。

当前机器证据、清理关卡与验收命令见 `docs/inventory/mise-runtime-ownership.md`。

## 7. 服务与容器边界

服务器迁移初期优先恢复现有、已验证的容器/Compose 服务，不在同一阶段重写全部服务：

- 系统迁移与业务重构分开；
- 有成熟 NixOS module 且迁移收益明确的服务，可在后续独立 Issue 迁移；
- 复杂第三方栈继续使用 Compose 是可接受的；
- 容器镜像 tag、volume、环境变量、备份和健康检查必须显式记录；
- 生产数据库升级不得作为操作系统迁移的顺带动作。

## 8. 变更边界示例

### 合法

- Phase 2 只新增 macOS output、Darwin base module 和最小构建检查。
- Phase 5 导入 NixOS 原有硬件配置，并把可复用系统设置移到 `modules/nixos/base.nix`。
- Phase 8 只引入 sops-nix、加密策略和非生产演示 secret。

### 不合法

- 做 macOS shell 迁移时顺便修改服务器磁盘布局。
- 为减少三行 Flake 代码引入大型自动发现框架。
- 把 `if isDarwin then ... else ...` 写满 `common/default.nix`，声称它仍是共享模块。
- 为通过构建而猜一个 `system.stateVersion` 或直接复制网上的 `disko.nix`。
