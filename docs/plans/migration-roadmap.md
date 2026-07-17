# 迁移路线图

## 1. GitHub Milestone

**名称：** `声明式个人基础设施 v1 / Declarative Personal Infrastructure v1`

**完成目标：** macOS、NixOS 工作站和服务器均由同一仓库提供可构建的配置；共享用户层经过两种平台验证；服务器完成可回滚迁移与业务恢复；机密、数据和危险操作均有明确边界。

该 Milestone 按“完成标准”而不是随意日期关闭。每个 Phase 使用一个独立 Issue 和一个 Draft PR。

## 2. 总体依赖关系

```text
Phase 0  治理协议
   ↓
Phase 1  主机盘点与 Flake 骨架
   ↓
Phase 2  macOS 最小 nix-darwin
   ↓
Phase 3  macOS Home Manager 用户层
   ↓
Phase 4  macOS 应用与系统偏好
   ↓
Phase 5  接入现有 NixOS 工作站
   ↓
Phase 6  跨平台共享层验证
   ↓
Phase 7  Ubuntu Server 过渡 Home Manager
   ↓
Phase 8  sops-nix 机密管理
   ↓
Phase 9  NixOS Server 最小配置与 disko
   ↓
Phase 10 nixos-anywhere VM 安装测试
   ↓
Phase 11 经批准的服务器正式迁移
   ↓
Phase 12 业务恢复、加固与 v1 收尾
```

默认按顺序推进。只有某阶段 Issue 明确证明无依赖并经维护者同意时，才允许并行。

## 3. Phase 定义

### Phase 0 — 建立治理协议与项目文档

**目标**

让维护者和 Codex 对架构、语言、范围、验证、人工关卡和完成定义拥有同一套可审计协议。

**允许修改**

- `AGENTS.md`
- `README.md`
- `CONTEXT.md`
- `docs/**`
- `.github/**`

**明确不做**

- 不创建可部署的 `flake.nix`；
- 不猜任何主机事实；
- 不触碰真实机器。

**完成标准**

- 英文规范协议与中文译文一致；
- 架构、模块边界、ADR、路线图、Issue/PR 模板齐全；
- GitHub 中建立 v1 跟踪 Issue 和各 Phase Issue；
- 维护者审阅并合并 Draft PR。

### Phase 1 — 主机盘点与最小 Flake 骨架

**目标**

收集三台机器的非秘密事实，确定逻辑 output 名称、用户名、平台、现有 Nix 安装和 state version，并建立只做 evaluation 的 Flake 骨架。

**允许修改**

- `flake.nix`、`flake.lock`
- inventory 文档中的脱敏结果
- 最小 `hosts/` 与 `modules/` 占位实现（必须可解释，不创建空壳目录）
- formatter/checks

**人工输入**

维护者或机器本地 Codex 按 `docs/runbooks/host-inventory.md` 收集输出并脱敏。

**验证**

- `nix flake metadata`
- `nix flake show`
- 可用时执行 formatter/check；
- 不激活任何配置。

**完成标准**

每个主机事实有来源；没有猜测的磁盘、网络或 state version；lock file 已提交。

### Phase 2 — macOS 最小 nix-darwin 接入

**目标**

建立只包含 Nix 基础设置、主用户与最小安全配置的 macOS output，并可离线构建。

**允许修改**

- macOS host 模块
- `modules/darwin/base.nix`
- Flake 中的 Darwin output

**明确不做**

- 不迁移全部 dotfiles；
- 不清理 Homebrew；
- 不改大量 `system.defaults`。

**验证**

先 build；真实 Mac 上第一次 `darwin-rebuild switch` 是人工关卡，必须记录回滚和当前配置备份。

### Phase 3 — 迁移 macOS Home Manager 用户层

**目标**

从最小集合开始声明 Git、shell、编辑器、tmux、direnv 和通用 CLI，建立未来共享层。

**允许修改**

- `modules/home/common.nix`
- `modules/home/darwin.nix`
- 静态 dotfiles 的最小集合
- macOS Home Manager integration

**明确不做**

- 不一次接管整个 `$HOME`；
- 不链接缓存、数据库、session 或会被程序写入的目录；
- 不引入服务器服务。

**验证**

构建 macOS output，人工比较迁移前后 shell、Git、编辑器与 PATH。

### Phase 4 — 声明 macOS 应用与系统偏好

**目标**

在基础稳定后，迁移 GUI 应用、Homebrew/cask/MAS 与明确需要的 `system.defaults`。

**安全要求**

- CLI 优先 Nixpkgs；
- 初期不启用 destructive cleanup/zap；
- 每项系统偏好应说明当前值、目标值和回滚方式。

**完成标准**

应用来源清晰，无意外卸载；Mac 重登/重启后关键行为经过人工验证。

### Phase 5 — 接入现有 NixOS 工作站

**目标**

把 NixOS 现有的硬件和系统配置原样纳入 host 层，再逐步抽出可复用 NixOS 模块。

**必须保留**

- `hardware-configuration.nix`
- 原始 bootloader 与文件系统事实
- 现有 `system.stateVersion`

**验证顺序**

1. build；
2. 人工在目标机执行 `nixos-rebuild test`；
3. 验证登录、网络、桌面、音频、GPU 与回滚；
4. 再决定是否 `boot`/`switch`。

### Phase 6 — 验证跨平台共享用户层

**目标**

让 macOS 与 NixOS 工作站使用同一个 `home/common.nix`，把平台差异移入明确模块。

**完成标准**

- 共享模块不包含平台路径、GUI 或系统服务；
- 两台机器都能 build；
- Git、shell、编辑器和通用 CLI 行为一致或差异有文档；
- 没有为了“共享”而堆积大量隐式平台判断。

### Phase 7 — Ubuntu Server 过渡期 Home Manager

**目标**

在不改变 Ubuntu boot、apt、systemd 系统服务和网络的前提下，让服务器用户使用共享的最小 CLI 环境。

**允许范围**

- standalone `homeConfigurations."<user>@<server>"`
- `home/common.nix`、`home/linux.nix`、`home/server.nix`

**明确不做**

- 不用 Home Manager 接管 nginx、Docker daemon、数据库、防火墙或内核；
- 不重装系统。

### Phase 8 — 引入 sops-nix 与 age

**目标**

建立管理员 key、每机 recipient、`.sops.yaml`、加密文件和权限模型，不提交真实明文。

**安全要求**

- age 私钥独立离线备份；
- PR 中只出现 public recipient 与加密内容；
- 先用非生产示例验证解密路径与 owner/mode；
- 不把 secret 插值为普通 Nix Store 字符串。

### Phase 9 — NixOS Server 最小配置与 disko

**目标**

根据真实服务器 inventory 编写最小可 SSH 的 NixOS output 与声明式磁盘布局。

**首轮仅包含**

- boot、磁盘和挂载；
- 网络；
- SSH、公钥、管理用户与 sudo；
- 基础防火墙；
- provider 必需设置；
- 最小监测/救援能力。

**明确不做**

不同时迁移数据库、反向代理、业务容器和复杂存储方案。

### Phase 10 — nixos-anywhere VM 安装测试

**目标**

在虚拟机中验证 Flake、disko、启动和 SSH 最小系统，形成正式迁移 runbook。

**验证**

- nixos-anywhere `--vm-test`；
- 检查分区、挂载、用户、SSH 和启动；
- 记录构建日志与已知差异；
- 演练失败后的修复路径。

此阶段不对生产服务器运行安装。

### Phase 11 — 经批准的服务器正式迁移

**目标**

在完整人工关卡后，把 Ubuntu Server 安装为最小 NixOS，并确认可通过 SSH 与 provider console 恢复。

**执行前必须全部满足**

- 独立备份完成；
- 数据库原生 dump 已验证可读；
- 至少一个异机副本；
- provider snapshot/rescue/VNC 可用；
- 目标磁盘和 boot mode 二次确认；
- 网络、SSH key 与防火墙审阅；
- VM test 通过；
- 维护者在当前 Issue 明确批准执行窗口。

Agent 默认停在命令与检查清单准备完成处。实际清盘、重装、重启由维护者执行或实时监督。

### Phase 12 — 业务恢复、加固与 v1 收尾

**目标**

先原样恢复现有业务，再把适合的服务分批声明化；验证备份、监控、更新和回滚。

**顺序**

1. 恢复原有容器/Compose 与数据；
2. 验证业务功能和数据完整性；
3. 再为简单服务创建独立迁移 Issue；
4. 配置备份、恢复演练、监控和安全更新；
5. 更新最终 runbook 与架构文档；
6. 关闭 v1 Milestone。

**明确不做**

不在操作系统迁移同一变更中顺带升级数据库大版本或重写整个业务栈。

## 4. v1 之后的候选工作

以下内容进入后续 Milestone，不作为 v1 必需条件：

- Clan、deploy-rs 或 Colmena 等 fleet deployment 层；
- flake-parts 或其他 Flake 组织框架；
- 自动更新 PR 与二进制缓存；
- impermanence、ZFS、LUKS 或更复杂的服务器存储；
- 多用户、多服务器和灾备自动化。

每项候选工作必须以当前痛点和可量化收益为依据，不因为“社区流行”直接引入。

## 5. Phase Issue 必备字段

每个阶段 Issue 必须包括：

- 目标；
- 背景与已知事实；
- 前置依赖和阻塞项；
- 允许修改；
- 禁止修改；
- 实施任务；
- 验证命令；
- 人工关卡；
- 回滚方式；
- 完成标准；
- 简短、规范性的英文 Agent Contract。

模板位于 `.github/ISSUE_TEMPLATE/implementation-phase.md`。
