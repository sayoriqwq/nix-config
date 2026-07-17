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
│   │   ├── common.nix
│   │   ├── desktop.nix
│   │   ├── darwin.nix
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
| `modules/home/common.nix` | Git、shell、编辑器、tmux、direnv、通用 CLI 等跨平台基础 | GUI、Homebrew、systemd、launchd、Linux/macOS 专属路径、服务器 daemon |
| `modules/home/desktop.nix` | 两台桌面机器共有的用户级桌面配置 | boot、GPU 驱动、系统桌面服务、服务器工具 |
| `modules/home/darwin.nix` | macOS 专属用户设置与用户级应用配置 | nix-darwin 系统 defaults、Linux 配置 |
| `modules/home/linux.nix` | Linux 专属用户设置 | NixOS 系统服务、磁盘、bootloader |
| `modules/home/server.nix` | headless 用户工具、最小 shell/编辑环境 | 桌面软件、浏览器、系统 daemon、业务数据 |
| `modules/darwin/` | macOS defaults、系统设置、Homebrew 声明、Darwin 服务 | NixOS 选项、主机硬件事实 |
| `modules/nixos/base.nix` | 多台 NixOS 可复用的基础 Nix、用户、sudo、SSH 和安全默认值 | 某台主机的磁盘、GPU、网卡名 |
| `modules/nixos/desktop.nix` | NixOS 桌面角色的通用系统服务 | 某个桌面的私人 dotfiles、服务器业务 |
| `modules/nixos/server.nix` | NixOS 服务器角色的系统服务与 hardening | 生产数据、明文 `.env`、provider 专属磁盘名 |
| `dotfiles/` | 稳定、静态、由程序读取的配置源 | 缓存、数据库、session、下载内容、私钥 |
| `secrets/` | sops 加密后的文件 | 任何明文 secret、age 私钥 |
| `docs/` | 架构、ADR、计划、runbook、维护说明 | 真实 secret、未脱敏 inventory |

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
- `common.nix` 不通过运行时判断偷偷承载平台配置；平台差异应通过显式模块组合表达。
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
2. 是用户级且跨平台吗？放入 `modules/home/common.nix`。
3. 是桌面用户级且两台工作站共享吗？放入 `modules/home/desktop.nix`。
4. 只属于某个平台的用户吗？放入 `home/darwin.nix` 或 `home/linux.nix`。
5. 只属于服务器用户环境吗？放入 `home/server.nix`。
6. 是操作系统服务或全局设置吗？放入对应 Darwin/NixOS 系统模块。
7. 是硬件、boot、磁盘或 provider 事实吗？放入 `hosts/<host>/`。
8. 是可变数据或 secret 吗？不要作为普通 Nix 配置提交，使用对应数据/机密流程。

## 6. Homebrew 边界

Mac 上遵循：

- CLI 工具优先 Nixpkgs；
- cask、Mac App Store 应用和确有必要的 Mac 专用 formula 才使用 Homebrew；
- Homebrew 本身/taps 与 formula/cask 的声明职责分开；
- 迁移初期不启用会自动删除现有软件的 cleanup/zap；
- 任何清理策略必须先在 Issue 中列出受影响软件并由维护者批准。

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
- 把 `if isDarwin then ... else ...` 写满 `common.nix`，声称它仍是共享模块。
- 为通过构建而猜一个 `system.stateVersion` 或直接复制网上的 `disko.nix`。
