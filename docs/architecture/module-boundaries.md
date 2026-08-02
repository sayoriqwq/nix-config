# 模块与目录边界

本文定义能力化基线的路径职责。Agent 必须优先遵守当前 Issue 的允许范围；Issue 未说明时，以本文件为默认规则。

## 1. 目标目录结构

```text
.
├── flake.nix
├── flake.lock
├── hosts/
│   ├── macbook/
│   ├── nixbox/
│   └── server/                    # 只在对应 server Phase 建立
├── modules/
│   ├── home/
│   │   ├── capabilities/          # host 可直接 import 的用户能力
│   │   ├── common/                # 跨平台基础配置，不是 host bundle
│   │   ├── desktop/               # GUI 基础配置，不是 host bundle
│   │   └── darwin/                # Darwin 用户基础配置，不是 host bundle
│   ├── capabilities/
│   │   └── <cross-layer>/         # home.nix + 已证明的平台 adapter
│   ├── darwin/                    # 可复用 nix-darwin 系统模块
│   └── nixos/                     # 可复用 NixOS 系统模块
├── dotfiles/
├── secrets/
└── docs/
```

只有真实需求出现时才创建路径。不得为未来假设预建 `linux.nix`、`server.nix`、空 adapter 或 capability registry。

## 2. 两级组合模型

### 基础配置

基础配置只实现一项窄责任，例如安装 `gh`、配置 Git、声明 Fish integration、提供 Zed seed helper 或安装一个 GUI package。它可以放在现有 `home/common/`、`home/desktop/`、`home/darwin/` 内部目录，但不成为 host interface。

### 能力模块

能力模块是 host 的选择单位。它可以组合多个基础配置，并公开完整能力合同：

- 提供的用户行为；
- package 与稳定配置所有权；
- `sayori.statePaths` 中仅声明、不接管的可变状态；
- system service、network/firewall、login shell 等跨层影响；
- activation 或破坏性动作的人工关卡。

Host 显式 import 一项能力即表示采用。不得再要求 host 同时设置 `capabilities.<name>.enable = true`，也不得让 host 直接拼能力内部 primitives。

## 3. 路径职责矩阵

| 路径 | 允许内容 | 禁止内容 |
| --- | --- | --- |
| `flake.nix` | inputs、outputs、少量组合 helper、formatter/checks | 大量程序配置、主机硬件细节、明文机密 |
| `hosts/<host>/` | 主机事实、系统角色与显式 capability imports | 可被多主机复用的能力实现 |
| `modules/home/capabilities/` | 纯用户能力 interface 与内部 primitive imports | boot、磁盘、隐蔽 firewall 或系统 daemon |
| `modules/home/common/` | 跨平台 CLI、Shell 与用户配置 primitives | GUI、Homebrew、systemd、launchd、host bundle |
| `modules/home/desktop/` | GUI 应用、终端与编辑器 primitives | Server bundle、boot、GPU、系统桌面服务 |
| `modules/home/darwin/` | Darwin 用户配置 primitives 与现有 integration | nix-darwin system defaults、Linux 配置 |
| `modules/capabilities/<name>/home.nix` | 跨层能力的用户实现 | 平台系统选项 |
| `modules/capabilities/<name>/darwin.nix` | 已证明的 nix-darwin adapter 与 HM attachment | NixOS 选项、虚构的统一 interface |
| `modules/capabilities/<name>/nixos.nix` | 已证明的 NixOS adapter、HM attachment与公开安全副作用 | 未经 Issue 批准的 firewall/SSH/服务变化 |
| `modules/darwin/` | macOS defaults、系统设置、Shell 注册与通用 Darwin 服务 | 按应用需求选择的 Homebrew cask、NixOS 选项、主机硬件事实 |
| `modules/nixos/` | NixOS 基础、桌面或 server 系统能力 | 主机磁盘/GPU/网卡事实、生产数据 |
| `dotfiles/` | 稳定、静态、由程序读取的配置源 | 缓存、数据库、session、下载内容、私钥 |
| `secrets/` | SOPS 加密文件 | 明文 secret、age 私钥 |

旧的 `modules/home/common/default.nix`、`desktop/default.nix` 与 `darwin/default.nix` 聚合入口已在 Phase 5.5 删除。基础配置文件继续保留，但目录本身不再提供可被 host 误选的 bundle interface。

## 4. Import 方向

```text
flake output
  └── hosts/<host>
       ├── system modules
       ├── cross-layer capability adapters
       │    └── capability home implementation
       └── Home Manager capability imports
            └── configuration primitives
```

- Host 只选择 system module、cross-layer adapter 或用户 capability；不选择 primitive。
- 能力实现不得反向 import host。
- Home Manager primitive 不 import nix-darwin/NixOS system module。
- Darwin 与 NixOS adapter 不互相 import。
- import 必须显式列出，不使用递归扫描。
- 一个 adapter 表示假设，两个真实变化才证明 seam；但已经批准、将在下一 Phase 组合的第二平台 adapter 可以先在合同文档中记录，不能提前启用其副作用。

## 5. 状态、参数与共享值

- `sayori.statePaths` 只记录 path、内容 owner、backup 边界与原因；它不创建、链接、备份或清理该路径。
- 可变数据库、key、登录态、缓存、session、浏览器 profile 与用户内容不得整体链接到 Nix Store。
- 多个 module 确实需要的用户名或 input 可以通过 `specialArgs` / `extraSpecialArgs` 传入；secret 不通过 args 传递。
- Host 与硬件事实保留在 `hosts/<host>/`；不创建巨大、无类型的 `vars` 属性集。

## 6. 软件归属判断

1. 项目开发依赖进入项目 dev shell。
2. 只有 package 或单项稳定配置时，先建立细粒度 primitive。
3. Host 真正要选择的用户行为，由 `modules/home/capabilities/` 组合。
4. 同一能力同时需要用户与系统声明时，建立 `modules/capabilities/<name>/`。
5. 只有真实平台行为不同才增加 adapter；平台名称本身不是需求。
6. 硬件、boot、磁盘、网卡和 provider 事实进入 `hosts/<host>/`。
7. 可变数据与 secret 不作为普通配置提交，分别使用数据与机密流程。

## 7. Homebrew 边界

Mac 上遵循：

- Nix 能可靠管理的软件优先由 Nix 安装，稳定配置由 nix-config 管理；
- 无法由 Nix 可靠管理的应用可以完全外置，但仓库不接管其配置或 integration；
- Homebrew 是迁移期事实，不是新增软件的默认终态；现有 formula/cask 按独立 Issue 逐项退出；
- 迁移期不启用会批量删除软件的 cleanup/zap；
- 任何定向卸载都必须先在 Issue 中列出精确目标并由维护者当次批准。

### 7.1 语言运行时所有权

Node 与 Bun 的版本切换是 mise 的核心职责：

- Nix/Home Manager 安装 mise 本体，并通过生成的 `mise/conf.d` 声明稳定全局默认与
  shell integration；macbook 不再维护第二份可变全局默认文件；
- mise 按上述声明安装、解析和切换 Node、Bun 与 pnpm；项目版本继续由项目
  `mise.toml` 或不提交的 `mise.local.toml` 选择；
- `home.packages` 不得直接包含 `nodejs`、`nodejs-slim` 或 `bun`；
- mise runtime、cache、state 与已安装版本属于可变数据。

Python 使用不同模型：

- macbook 的 AI 辅助运维能力通过 Nix/Home Manager 提供一个裸 Python interpreter，
  作为 Codex 等 agent 不进入项目环境时的稳定基线；当前明确选择 `python314`；
- Home Manager profile 最多包含一个 Python interpreter，且不为它加入全局第三方包；
- uv 根据项目事实选择 Python，项目 `.venv`、依赖与 lock file 不进入全局 profile；
- mise 不声明 Python 或 uv；
- `~/.local/bin` 是用户可变工具的低优先级兼容路径，Nix 不扫描、同步或清理其内容。

详细证据见 `docs/inventory/mise-runtime-ownership.md` 与 `docs/inventory/uv-python-ownership.md`。

## 8. 服务与容器边界

Server 从 Ubuntu 直接替换为最小 NixOS，但系统替换与业务重构仍然分开：

- 首次替换只保证 boot、disk、network、SSH、sudo、基础 firewall 与救援能力；
- 最小系统稳定后，只按届时的新需求从空白状态逐项引入业务；不恢复当前 Ubuntu 的 Compose、容器与数据；
- 成熟 NixOS module 的采用另建 Issue，不顺带重写全部服务；
- 容器 image tag、volume、环境变量、备份与健康检查必须显式记录；
- production database upgrade 不作为 OS migration 的附带动作。

## 9. 示例

合法：

- macbook 在 Home Manager composition 中显式 import `git-foundation.nix` 与 `github-collaboration.nix`，server 只选择前者。
- LocalSend Darwin adapter 附加用户 package 与状态路径；Phase 6 的 NixOS adapter 还公开 TCP/UDP 53317 firewall 规则。
- Phase 5.5 重构 macbook 能力 interface，同时保持 nixbox Phase 5 output 不变。

不合法：

- nixbox import 完整 `desktop/default.nix`，再逐项排除 macbook 软件。
- 建立 `linux.nix` 后让所有 Linux host 自动继承。
- 为减少显式 imports 引入 capability registry 或自动目录扫描。
- 为通过 build 猜 `stateVersion`、disk、network 或 firewall 事实。
