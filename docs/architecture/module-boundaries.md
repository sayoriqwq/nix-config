# 模块与目录边界

本文定义 V3 Intent/Software 基线的路径职责。Agent 必须优先遵守当前 Issue 的允许范围；Issue 未说明时，以本文件为默认规则。

## 1. 目标目录结构

```text
.
├── flake.nix
├── flake.lock
├── hosts/
│   ├── macbook/
│   ├── nixbox/
│   └── server/
├── software/
│   └── <software>/
│       ├── default.nix            # owner 的显式公开函数 interface
│       └── capabilities/
│           └── <capability>/
│               ├── home.nix       # 只创建真实需要的平台文件
│               ├── darwin.nix
│               └── nixos.nix
├── intents/
│   ├── lib.nix                    # empty/addModules/realize
│   └── <intent>/default.nix       # lib.pipe 需求图
├── modules/
│   ├── home/                       # 尚未迁移的 V2 owners；按后续 Issue 退出
│   ├── capabilities/               # 尚未迁移的跨层 owners
│   ├── darwin/                    # 可复用 nix-darwin 系统模块
│   └── nixos/                     # 可复用 NixOS 系统模块
├── operations/
│   └── server-recovery/           # 隔离 VM Operation；可消费 production declarations
├── checks/
│   ├── terminal-work/             # 获批的窄 contribution seam
│   └── server-recovery/           # Operation 公开 policy seam
├── dotfiles/
├── secrets/
└── docs/
```

只有真实需求出现时才创建路径。不得为未来假设预建 `internal/`、`linux.nix`、`server.nix`、空 adapter、capability registry 或自动扫描入口。根目录不再存在 `tests/`；V2 tests 不迁移、不翻译。

## 2. 两轴组合模型

### Software Capability（纵轴）

一个 Software、CLI、daemon 或 data provider 拥有自己的 package、基础配置、状态边界与平台差异。`software/<software>/capabilities/<capability>/` 公开最小原子行为；同一 owner 内只有真实可独立选择的增量才形成 Extension Capability。

### Executable Intent（横轴）

`intents/<intent>/default.nix` 用 `lib.pipe` 表达经批准的用户结果。Intent 可以选择多个 Software Capabilities，并调用 Software 提供的窄 contribution interface；例如 `terminal-work` 同时选择 `bat.content-viewer`、`fd.file-finder`、`fzf.fuzzy-selector`，再调用 `fzf.configure` 组合默认 source 与 preview。

Intent pipeline 是需求选择和组合的唯一事实源，不另建 Workflow、Relation、contract schema、registry 或 manifest 清单。

### Host caller 与冻结 helper

`intents/lib.nix` 的冻结 public interface 只有：

- `empty`：三个原生 module list 的初始 state；
- `addModules`：返回同型 `IntentState -> IntentState` transform；
- `realize`：只公开 `darwinModules`、`nixosModules`、`homeModules`。

Host 在 system `imports` 中消费对应平台 list，在 Home Manager `imports` 中消费 `homeModules`。显式 list 与 Intent pipeline 就是选择机制；不得叠加 `capabilities.*.enable` 或把 `IntentState` 再交给第二套 Module System。

## 3. 路径职责矩阵

| 路径 | 允许内容 | 禁止内容 |
| --- | --- | --- |
| `flake.nix` | inputs、outputs、少量组合 helper、formatter/checks | 大量程序配置、主机硬件细节、明文机密 |
| `hosts/<host>/` | 主机事实、Intent realized lists 与尚未迁移的显式 imports | 可被多主机复用的实现、registry 或自动扫描 |
| `intents/lib.nix` | `empty`、`addModules`、`realize` 三个窄 helper | schema、conflict protocol、registry、最终 Nix config merge |
| `intents/<intent>/` | `lib.pipe` 需求图与跨 Software 组合决定 | package/platform 实现、重复 contract、host facts |
| `software/<software>/default.nix` | owner-local public transforms/contributions | 全局 software registry、具体 Intent 或 host 依赖 |
| `software/<software>/capabilities/` | 原子 package/config/state/platform owner modules | 第二个 bundle、其他 Software 的隐式 ownership |
| `modules/home/capabilities/` | 尚未迁移的 V2 user owners | 新 V3 Software/Intent 实现、boot、磁盘、隐蔽系统副作用 |
| `modules/home/common/` | 跨平台 CLI、Shell 与用户配置 primitives | GUI、Homebrew、systemd、launchd、host bundle |
| `modules/home/desktop/` | GUI 应用、终端与编辑器 primitives | Server bundle、boot、GPU、系统桌面服务 |
| `modules/home/darwin/` | Darwin 用户配置 primitives 与现有 integration | nix-darwin system defaults、Linux 配置 |
| `modules/capabilities/<name>/home.nix` | 跨层能力的用户实现 | 平台系统选项 |
| `modules/capabilities/<name>/darwin.nix` | 已证明的 nix-darwin adapter 与 HM attachment | NixOS 选项、虚构的统一 interface |
| `modules/capabilities/<name>/nixos.nix` | 已证明的 NixOS adapter、HM attachment与公开安全副作用 | 未经 Issue 批准的 firewall/SSH/服务变化 |
| `modules/darwin/` | macOS defaults、系统设置、Shell 注册与通用 Darwin 服务 | 按应用需求选择的 Homebrew cask、NixOS 选项、主机硬件事实 |
| `modules/nixos/` | NixOS 基础、桌面或 server 系统能力 | 主机磁盘/GPU/网卡事实、生产数据 |
| `operations/server-recovery/` | test-only NixOS graph、隔离 VM runner、disko/nixos-anywhere 与 `runNixOSTest` wiring | production target 参数、真实网络/SSH/disk action、被 production host import |
| `checks/server-recovery/` | 从 production/Operation 公开配置观察 policy 与 runner 边界 | grep 源码、复制旧 test implementation、production 配置所有权 |
| `checks/terminal-work/` | 获批的 `fzf.configure` public contribution 行为 | `IntentState` shape、pipeline order、目录/import 数量 |
| `checks/code-development/` | 获批的 `zed.addTask` public contribution 行为 | `IntentState` shape、pipeline order、Intent 内部列表 |
| `dotfiles/` | 稳定、静态、由程序读取的配置源 | 缓存、数据库、session、下载内容、私钥 |
| `secrets/` | SOPS 加密文件 | 明文 secret、age 私钥 |

Phase 11 的机密部署 seam 位于 `modules/capabilities/secret-deployment/`：Darwin 与 NixOS adapter 只声明 sops-nix 和当前 host 的 SSH identity。具体 secret 的 source、运行时 owner/group/mode、服务依赖与 activation 人工关卡属于消费者的独立 Issue，不能用通用 demo 占位。编辑工具属于独立的纯用户机密管理能力，只由持有管理员 identity 的 macbook 组合。

工作站稳定访问的跨层 seam 位于 `modules/capabilities/stable-workstation-access/`：Darwin
adapter 只拥有官方 Standalone cask，NixOS adapter 只拥有 tailscaled service、稳定 overlay
machine name 与 NixOS firewall 的 UDP 41641 声明增量；运行中的 tailscaled 另按 vendor 默认
维护 overlay iptables chains。登录、MagicDNS、Grants、SSH alias 和 vendor state 内容不进入
能力声明，server 不组合该 seam。

Clash Verge Rev 的跨层 seam 位于 `modules/capabilities/clash-verge-rev/`。Darwin adapter
继续只拥有既有 Homebrew cask；NixOS adapter 是 Linux package 与 systemd Service Mode 的
唯一所有者，通过窄、精确锁定的 package source seam 提供 2.5.2，而不改变 Linux 根
`nixpkgs` cadence。Home Manager attachment 只记录可写 profile/state path，不重复安装
package。NixOS adapter 声明 root service、专用 `clash-verge` socket group 并只把已确认的
交互用户 `sayori` 加入该组；`tunMode = false`，因此不创建 root-owned GUI capability wrapper，
应用内 TUN 留给绑定 exact commit 的人工关卡，由维护者在 GUI 中开关并通过声明式 service 验证。该 seam 不声明
firewall、Tailscale、SSH、DNS、route、network interface 或 system proxy，server 不组合。
不得恢复 GUI 的 DEB/RPM installer sidecar、写入 mutable `/usr/bin` 或
`/etc/systemd/system`，也不得用 activation script 绕过 NixOS module。

工作站中文输入的跨层 seam 位于 `modules/capabilities/chinese-input/`：内部
`rime-data-package.nix` 只发布经过可变名称过滤并合入 overlay 的 `$out/share/rime-data`；
`home.nix` 只投影静态 leaves 并声明 Fcitx/Rime 可写状态。Darwin adapter 只附加该用户实现与
macOS installer/cache 状态边界，不安装 frontend；NixOS adapter 单一拥有 Fcitx framework、
Rime addon、system defaults、session environment 与 package XDG autostart。Host 只能 import
对应 adapter，不直接 import data-package 或 home primitive；server 不组合该 seam。

旧的 `modules/home/common/default.nix`、`desktop/default.nix` 与 `darwin/default.nix` 聚合入口已在 Phase 5.5 删除。Issue #196 又删除 `terminal-toolkit` 与其 terminal primitives；其余 V2 owner 只能由后续唯一 owner Issue 迁移，不能作为新 V3 bundle 复活。

## 4. Import 方向

```text
flake output
  └── hosts/<host>
       ├── Intent realized darwinModules / nixosModules
       │    └── Software Capability platform modules
       ├── Intent realized homeModules
       │    └── Software Capability Home Manager modules
       └── 尚未迁移的显式 modules
```

- Host 选择 Intent 或无需横向组合的独立 Software Capability；不直接拼 owner 私有 primitive。
- Software Capability 不得 import Intent 或 host；Intent 不得 import host。
- Home Manager primitive 不 import nix-darwin/NixOS system module。
- Darwin 与 NixOS adapter 不互相 import。
- import 必须显式列出，不使用递归扫描。
- Validation graph 可以 import production declarations；production host 不得反向 import `checks/`、`operations/` 或 test-only module。
- 一个 adapter 表示假设，两个真实变化才证明 seam；但已经批准、将在下一 Phase 组合的第二平台 adapter 可以先在合同文档中记录，不能提前启用其副作用。

`terminal-work` 是首个真实 Intent：三台 Host 都在两个原生 import 位置消费同一 realized result。`code-development` 随后让两个工作站显式选择 Zed、Git 与 LazyGit，并通过 `zed.addTask` 贡献 LazyGit task；Software 不反向依赖 Intent。后续 Wave 3 task 可提交自己的窄 host integration hunk，但不得修改 `intents/lib.nix`、现有 Intent caller 约定或其他 task 的 Software owner；共享 import-list 冲突由 Lead 合并。

## 5. 状态、参数与共享值

- `sayori.statePaths` 只记录 path、内容 owner、backup 边界与原因；它不创建、链接、备份或清理该路径。
- 可变数据库、key、登录态、缓存、session、浏览器 profile 与用户内容不得整体链接到 Nix Store。
- 多个 module 确实需要的用户名或 input 可以通过 `specialArgs` / `extraSpecialArgs` 传入；secret 不通过 args 传递。
- Host 与硬件事实保留在 `hosts/<host>/`；不创建巨大、无类型的 `vars` 属性集。

## 6. 软件归属判断

1. 项目开发依赖进入项目 dev shell。
2. 只有 package 或单项稳定配置时，在 Software owner 内建立 Primary Capability。
3. 需要跨 Software 共同选择或 contribution 时建立 Intent；不要建立第二个 bundle。
4. 同一 Software Capability 同时需要用户与系统声明时，在 owner 目录中增加已证明的平台文件。
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

- 两台工作站各自明确批准的 AI 辅助运维能力通过 Nix/Home Manager 提供一个裸
  Python interpreter，作为 Codex 等 agent 不进入项目环境时的稳定基线；当前明确选择
  `python314`；
- Home Manager profile 最多包含一个 Python interpreter，且不为它加入全局第三方包；
- uv 根据项目事实选择 Python，项目 `.venv`、依赖与 lock file 不进入全局 profile；
- mise 不声明 Python 或 uv；
- `~/.local/bin` 是用户可变工具的低优先级兼容路径，Nix 不扫描、同步或清理其内容。

两台工作站的 AI 辅助运维能力分别通过 Nix/Home Manager 提供 ax 与其他已批准的 AI
CLI，并各自管理唯一的稳定全局 Agent 策略入口 `~/.codex/AGENTS.md`。macbook 与
nixbox 分别使用 `dotfiles/codex/AGENTS.md` 和 `dotfiles/codex/AGENTS.linux.md`，只固定
各自主机的 Nix 管理事实、Fish 登录入口、Python 入口和面向用户的命令格式。文件首行引用的
`~/.codex/RTK.md` 仍是外部可写依赖：RTK CLI 本体由 Nix 管理，该文件由
`rtk init -g --codex` 生成、更新和卸载，不链接到 Nix Store。Home Manager 不在
activation 中运行客户端 init；锁定 CLI 的隔离 dry-run check 负责验证生成合同。
新组合该能力的工作站完成真实 activation 后，由维护者手动运行 `rtk init -g --codex`，
再以 `rtk init -g --codex --show` 验收生成内容；这两个命令都不属于自动 activation。
`~/.codex` 中的 auth、session、history、plugins、hooks、cache、数据库及其他可变配置
继续外部可写，不进入 Nix Store。
ax 的 `~/.cache/ax/fetch` 同样是外部可写、可重建的短期缓存；上游负责 owner-only
权限和过期清理，Nix 只声明状态路径，不复制缓存、请求凭据或上游 agent skill。

详细证据见 `docs/inventory/mise-runtime-ownership.md` 与 `docs/inventory/uv-python-ownership.md`。

## 8. 服务与容器边界

Server 已从 Ubuntu 直接替换为最小 NixOS，系统基线与业务能力仍然分开：

- 当前基线只保证 boot、disk、network、SSH、sudo、基础 firewall 与救援能力；
- 后续只按届时的新需求从空白状态逐项引入业务；不恢复旧 Ubuntu 的 Compose、容器与数据；
- 成熟 NixOS module 的采用另建 Issue，不顺带重写全部服务；
- 容器 image tag、volume、环境变量、备份与健康检查必须显式记录；
- production database upgrade 不作为 OS migration 的附带动作。

## 9. 示例

合法：

- macbook 与 nixbox 通过 `code-development` Intent 选择 `git.version-control`，server 则直接选择同一个 Software Capability；GitHub collaboration 保持工作站专属。
- LocalSend Darwin adapter 附加用户 package 与状态路径；Phase 6 的 NixOS adapter 还公开 TCP/UDP 53317 firewall 规则。
- Phase 5.5 重构 macbook 能力 interface，同时保持 nixbox Phase 5 output 不变。

不合法：

- nixbox import 完整 `desktop/default.nix`，再逐项排除 macbook 软件。
- 建立 `linux.nix` 后让所有 Linux host 自动继承。
- 为减少显式 imports 引入 capability registry 或自动目录扫描。
- 为通过 build 猜 `stateVersion`、disk、network 或 firewall 事实。
