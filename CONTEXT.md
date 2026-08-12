# 项目上下文（Context）

## 1. 项目领域

本仓库的领域是“个人基础设施配置管理”：用 Nix 声明机器应当具备的系统设置、软件、用户环境和服务定义，并通过 Git 与构建结果审计变化。

仓库不是远程控制平台，也不是备份系统。Agent 可以编写和审查声明，真实机器上的激活、重装和数据操作仍受人工关卡约束。

## 2. 当前机器拓扑

以下名称是 Phase 1 已确认的逻辑 output 名称，不要求与真实主机名相同：

| 逻辑角色 | 当前状态 | 目标状态 | 主要管理层 |
| --- | --- | --- | --- |
| `macbook` | Apple Silicon macOS 主工作站 | nix-darwin + Home Manager | 全量工作站能力、维护者交互控制面、Darwin 系统能力、Mac 专属兼容能力 |
| `nixbox` | `x86_64-linux` NixOS 次级工作站 | NixOS + Home Manager | 维护者的第二工作站、Linux 试验能力、Server 同平台预生产 build/test/deploy 节点 |
| `server` | `x86_64-linux` 最小 NixOS，Phase 10–11 已验收 | 按需增加 Headless 生产能力 | 单管理员 root key-only 交互管理、恢复能力与按需业务运行能力 |

脱敏后的已确认事实与明确延后项记录在 `docs/inventory/phase-1-hosts.md`。真实主机名、地址和其他不影响 output 组合的敏感值不进入仓库。

## 3. 核心概念

### 声明（Declaration）

存入 Git、可由 Nix 评估和构建的配置。声明描述期望状态，不等同于已经在机器上激活。

### 软件所有权（Software ownership）

对软件安装、稳定配置与可变状态分别由谁负责的明确划分。记录本地状态的位置不代表 Git 或 Nix 管理其内容。

### 基础配置（Configuration primitive）

实现某一项声明责任的细粒度配置材料。基础配置是能力模块内部的实现，不是主机直接选择的组合单位。

### 托管配置（Managed configuration）

由 Nix 对软件安装或稳定配置内容承担所有权的声明。它不因此取得数据库、缓存、登录态或用户内容的所有权。

### 状态路径声明（State path declaration）

只记录可变状态的位置、内容所有者与备份边界的声明。它不把路径内容链接到 Nix Store，也不代表 Nix 管理其中数据。

### 能力模块（Capability module）

主机可直接选择的纵向配置单位，由实现该能力所需的基础配置组成，并共同封装系统与用户层的托管配置、状态路径声明及平台 adapter。主机只选择一次能力，不重复组装其内部实现。

### 能力合同（Capability contract）

能力模块对主机公开的完整 interface，包括提供的行为、软件与配置所有权、状态路径、系统服务或网络影响，以及必要的人工关卡。安全影响必须明确可见，不能因纵向封装而隐藏。

### AI 辅助运维能力（AI-assisted operations capability）

为本地 coding agent 提供命令输出压缩、内容检查、不依赖项目环境的基础 Python
解释器，以及由 Home Manager 管理的简洁全局 Shell 策略。该策略
只固定 Nix 管理事实、Fish 登录入口、Python 入口和用户命令展示格式；Nix 管理 ax
与 RTK CLI，外部 `~/.codex/RTK.md` 则由 RTK 的 Codex init 生命周期生成、更新和卸载。
ax 的 `~/.cache/ax/fetch` 是由 ax 拥有的短期、owner-only 页面缓存，Home Manager
只声明路径边界，不管理缓存内容、请求凭据或 agent 状态。
Codex 的 PDF 解析与渲染依赖客户端自带 runtime，不形成系统级 Poppler 合同；未证明
调用者的 Graphviz 不进入全局 profile，未来需求应由对应项目 dev shell 或独立能力声明。
具体 AI 客户端及其凭据是否存在，由各主机组合决定；
项目语言版本、虚拟环境和依赖仍属于开发运行时能力。

### Nix 运维能力（Nix operations capability）

三台 Nix 管理主机共有的构建、检查、generation 检视与回滚操作界面。它是配置一致性的基础能力，而不是某个桌面角色的便利工具。

### 交互式 Shell 辅助能力（Interactive shell assistance capability）

三台主机共有的交互式命令行纠错与操作辅助能力。`pay-respects` 属于该能力；server 虽然没有 GUI，仍然是用户直接操作的终端环境，因此不应被排除。

### 终端文件工作流（Terminal file workflow）

以终端界面浏览、预览和操作文件的用户能力。低使用频率不等于无需求；是否组合取决于明确的未来迁移方向。

### 终端历史能力（Terminal history capability）

跨三台机器一致的交互式命令历史记录与搜索体验。历史数据库、key 和 session 是每台机器各自的可变状态。

### 跨设备历史同步能力（Cross-device history sync capability）

在明确选择的工作站之间同步终端历史记录的附加能力。它不默认应用于 production server，也不等同于终端历史能力本身。

### 开发运行时能力（Development runtime capability）

供工作站选择语言版本、创建项目环境和进入开发上下文的能力。Production server 的运行时由 Nix closure、容器或服务声明提供，不继承工作站的可变运行时管理器。

### 主机组合（Host composition）

一台主机通过显式 `import` 对能力模块、系统能力与主机事实作出选择。`import` 本身就是采用该能力的唯一组合接口，不再增加全局 `capabilities.*.enable` 注册层。macbook 使用全量工作站能力；nixbox 和 server 按各自需求选择子集并增加自身能力。

### 配置一致性（Configuration consistency）

同一个能力模块在本地工作站构建和验证后，被 server 原样组合使用。它不表示磁盘、启动、网络、Secret、生产服务和数据恢复可以跳过主机级验证。

### Closure 推送部署（Closure push deployment）

nixbox 拉取锁定输入、构建并验证 server closure，再把不可变 closure 推送给 server。Server 是运行者，不依赖带 GitHub 写权限的工作树或自行拉取构建。

### 维护者交互管理身份（Maintainer interactive administration identity）

维护者本人从 macbook 执行 `ssh sayori` 管理 server；其中 `sayori` 是 macbook 本地 SSH Host 别名，远端用户固定为实际 Unix 用户 `sayori`。macbook maintenance identity 只提供 SSH 认证；登录后以 `sudo` 执行单条特权命令，确需连续 root 操作时使用 `sudo -i`。不使用 `su`，不依赖 root password，也不允许 root 经 SSH 登录。Password 与 keyboard-interactive 继续关闭，Contabo VNC 作为已实连验证的带外恢复路径。

### Nixbox 机器部署身份（Nixbox machine deployment identity）

nixbox 上的维护者交互用户仍是实际 Unix 用户 `sayori`。nixbox 另以独立 deploy identity 登录 server 的实际 Unix 用户 `sayori`，构建、验证并仅在获批部署中使用 `sudo -n` 应用 server closure；该 identity 是机器到机器的凭据边界，不代表维护者本人，也不获得 macbook maintenance private key。两把 key 映射到同一个远端 Unix 用户和同一套 sudo policy，因此它们不是权限隔离边界；分开保存是为了能够独立撤销、轮换并从 SSH 认证日志追溯凭据来源。nixbox 不是 server 的必经 bastion，故障时不影响 macbook 直达 server 的管理链路。

### Server 直接管理链路（Direct server management path）

macbook 使用 maintenance identity 直接登录 `server:sayori`，再经 sudo 边界完成管理与救援；该链路用于查看状态、处理故障以及在 nixbox 不可用时保持控制面可达。它不允许 root SSH，不让 server 获得 GitHub 凭据，也不取代 nixbox 对 server closure 的主要构建与验证职责。

### Git 基础能力（Git foundation capability）

三台机器共有的版本读取、差异检查与稳定 Git 行为。它不包含 GitHub 登录态、PR/Issue 操作或可写远程仓库凭据。

### GitHub 协作能力（GitHub collaboration capability）

工作站用于认证 GitHub、操作远程仓库与参与协作流程的能力。它不默认组合到 production server。

### 主机概览能力（Host overview capability）

让用户在登录后快速识别主机、系统、架构与资源概况的能力。它不替代服务状态、日志、端口、容量趋势或告警等运行状态检查。

### 主机输出（Host output）

Flake 为一台具体机器提供的构建入口，例如 `darwinConfigurations.<host>` 或 `nixosConfigurations.<host>`。

### 可移植用户能力（Portable user capability）

由 Home Manager 实现、可被多个主机显式选择的用户能力。可移植表示能力实现没有平台假设，不表示所有主机必须采用，也不形成强制全选 bundle。

### 可移植 Shell 环境（Portable shell environment）

跨主机一致的 Fish 交互体验。Zsh 是 macOS 的兼容能力，不属于可移植 Shell 环境。

### 桌面用户能力（Desktop user capability）

由 Home Manager 管理的图形用户能力集合。macbook 与 nixbox 分别选择所需能力，不把 macbook 的完整桌面应用集合自动复制到 nixbox，也不应用于 headless 主机。

### 桌面终端环境（Desktop terminal environment）

桌面用户能力中的终端体验，以 Ghostty + Fish 为两台工作站的主路径。WezTerm + Zsh 只作为 macOS 兼容能力保留。

### macOS 中文输入能力（macOS Chinese input capability）

只由 `macbook` 选择的纯 Home Manager 用户能力。Home Manager 消费当前 Darwin nixpkgs
锁定的 `pkgs.rime-ice` 2026.06.30，从 `$out/share/rime-data` 构造一个薄 data view：排除整个
`build` 子树并拒绝 userdb、sync、installation/user state 等可变名称，再合入只启用
`rime_ice`、并把左右 Shift 都声明为 Rime 内部中文/ASCII 切换键的本地
`default.custom.yaml` overlay。合并结果以 recursive leaf semantics 投影到
`~/.local/share/fcitx5/rime`，但不接管用户目录根节点或任何可写状态。

`Fcitx5.app`、Rime plugin payload、macOS 输入源注册、`~/.config/fcitx5` 与全部 GUI/runtime
偏好均由官方 installer/updater、macOS、Fcitx 和维护者外部拥有。Nix 不再自动收敛或审计
`ShareInputState`、`AppDefaultIM`、`StatusBar`、`TriggerKeys`、`AltTriggerKeys`、`InputState` 等
字段，也不提供行为 journal、CAS rollback helper 或阻塞 activation 的 runtime preflight。
Issue #145 的外部偏好目标是：`Default` group 只含 `rime`，同时保持 `DefaultIM=rime` 与
`Default Layout=us`；`TriggerKeys`、`AltTriggerKeys` 均为空，普通左右 Shift 只交给 Rime
切换中文/ASCII。该偏好仍由维护者通过 Fcitx GUI/官方 API 设置和 smoke test，不是 Nix
Desired/Keep；文档合入不表示 live profile 已修改或真人验收已完成。

输入状态仍需区分 macOS 外层与 Rime 内层：macOS 外层选择“小企鹅”，其菜单内只应出现
“中州韵”；普通 Shift 只切换 Rime 内部中文/ASCII mode，不再提供可人工切到
`keyboard-us` 的 Fcitx 菜单或完整 trigger 通道。底层 keyboard addon 与 `Default Layout=us`
并未删除：密码/安全输入在 `AllowInputMethodForPassword=False` 时仍可由 core 使用
`keyboard-us`；配置无效时 core 也可能重建默认 group。这些是组件安全或自愈机制，不是用户
可选择的恢复通道。

Rime `build` 和 Fcitx cache 是可重建、备份排除的状态；
`luna_pinyin.userdb`、`rime_ice.userdb`、`installation.yaml`、`user.yaml` 与
`~/.config/fcitx5` 必须保护；`sync` 与 `~/Library/fcitx5` 使用独立备份策略。#127 的首次
静态所有权交接已在配置提交
`87d801c85bc3f6f1b5334a00aefccfbe3ecefe73` 完成：system generation 从 42 切换到 43，
65/65 个静态叶子均成为有效 Store symlink，9/9 个可变状态边界保持可写且不在 Store，Rime
重新部署与真实输入验收均为 PASS；这是历史证据，不是新 data view 已 activation 的声明。
仅服务该次交接的写入型 helper 已按 #131 退役。未来新机器若再次出现
unmanaged regular leaves，必须另开 Issue 按届时事实重新建立窄交接入口，不能复用历史工具。
声明和构建成功仍不表示未来 activation、Rime 重新部署或输入验收已获授权，这些动作始终受
exact commit 的人工批准约束。data view 中的 `squirrel.yaml` 只是 `pkgs.rime-ice` 静态发行
内容，不代表启用或接管 Squirrel。Squirrel app、receipt、preference 与 cache 不进入中文输入
capability；其中 Issue #147 列出的四个精确遗留对象只可由该独立维护项按分离人工关卡退役。
`squirrel.custom.yaml` 保持外部，`~/Library/Rime` 是永久 opaque 排除树，任何操作都不得
遍历、列举、读取、stat、hash、copy、move 或 delete 其内容。

### 主编辑器角色（Primary editor role）

桌面用户环境中唯一负责默认编辑器契约的应用角色。其他编辑器可以继续安装为备用工具，但不得同时竞争该角色。

### 编辑器配置基线（Editor configuration baseline）

经审阅、可复现的编辑器初始配置声明。基线不等同于持续强制的运行态，也不包含登录态、扩展工作目录或工作区状态。

### 人工配置回流（Manual configuration backflow）

定期审阅编辑器可变配置，并把适合跨机器复用的变化分类纳入声明的维护流程。它不是自动双向同步，也不会未经审阅地写入 Git。

### 外部应用（Externally managed application）

无法由 Nix 可靠管理、因而完全位于仓库声明范围之外的应用。仓库不管理其安装、配置、内容或集成，最多记录一份不参与构建的事实说明。

### 平台 Adapter（Platform adapter）

能力在已证明的平台 seam 上提供的具体适配。平台名称本身不构成需求；adapter 不能隐藏 system service、network、firewall、login shell 或其他安全副作用。

### 系统层（System layer）

由 nix-darwin 或 NixOS Modules 管理的操作系统设置、系统软件、服务、用户、网络和启动配置。

### 主机层（Host layer）

只属于一台机器的硬件、磁盘、启动、主机名、GPU、网络接口和状态版本等事实。

### 可变状态（Mutable state）

数据库、容器卷、浏览器资料、缓存、上传文件、运行时密钥和服务数据。它们不由 Git 配置同步，需要独立的备份、恢复和迁移方案；仓库可以在 inventory 中记录其位置和所有权，但不因此管理数据内容。

### 机密（Secret）

密码、token、私钥、恢复码、私有环境变量等敏感材料。加密后的机密文件可以按策略提交；明文机密不得进入 Git 或 Nix Store。

### 机密部署能力（Secret deployment capability）

由 sops-nix 在 activation/boot 阶段使用当前主机自己的 age 解密身份，把已加密声明转换成受 owner、group、mode 控制的运行时文件。它不授予主机编辑其他主机机密的权限，也不把管理员恢复 identity 或 GitHub 凭据下发到目标机。

### 机密管理能力（Secret administration capability）

只由 macbook 选择的 SOPS、age 与 SSH-to-age 编辑/recipient 管理工具。管理员 identity 与恢复副本都由维护者在仓库外自行管理，Agent 不读取或验证其内容；nixbox 与 server 都不组合该能力，也不持有管理员 identity。

### 激活（Activation）

把已构建配置应用到真实机器，例如 `darwin-rebuild switch`、`nixos-rebuild switch` 或 Home Manager switch。构建成功不代表 Agent 获得激活权限。

### 破坏性操作（Destructive operation）

可能导致数据、网络连通性或启动能力丢失的动作，包括重新分区、格式化、修改远程网络/防火墙/SSH、远程重装、重启和生产数据迁移。

### 人工关卡（Human approval gate）

Issue 或 PR 中明确记录、针对当前具体动作的维护者批准。以前的泛化同意不能自动视为对新的破坏性动作授权。

### 迁移阶段（Migration phase）

路线图中的一个独立、可验证工作单元。一个阶段对应一个 Issue 和一个 Draft PR，不跨阶段实现。

## 4. 不变量

1. Git 仓库是配置事实来源，`flake.lock` 是依赖事实来源。
2. 现有 NixOS 的 `system.stateVersion` 与硬件配置在缺乏证据时保持不变。
3. 主机以能力模块为组合单位；基础配置不得直接泄漏为主机必须理解的接口。
4. 系统配置与用户配置分层，平台特有内容不得泄漏到可移植能力。
5. Agent 不猜测主机事实，不自主执行激活或破坏性动作。
6. Server 已从 Ubuntu 直接替换为最小可 SSH 的 NixOS，并已建立 Secret 部署基础；macbook maintenance identity 与 nixbox deploy identity 都只登录远端 `sayori`，经 sudo 边界提权，root SSH 关闭；旧 Ubuntu 业务与数据不恢复，后续只按新需求从空白状态引入独立能力。
7. 每项重大工具或架构变化必须通过 Issue 与 ADR 解释，而不是顺手引入。

## 5. 不属于本仓库的职责

- 完整数据备份仓库；
- 密码管理器；
- 数据库 dump 的长期存储；
- 浏览器同步；
- 自动批准和执行服务器清盘；
- 在没有真实机器证据时生成“看起来能用”的硬件或网络配置。

## 6. 术语使用规则

Issue、PR、代码和文档应优先使用本文件定义的概念。需要新增概念时，先判断它是否真的属于本项目；若属于，应在同一 PR 中更新本文件或对应 ADR，避免同一概念出现多套名称。
