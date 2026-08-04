# 迁移路线图

## 1. GitHub Milestone

**名称：** `声明式个人基础设施 v1 / Declarative Personal Infrastructure v1`

**完成目标：** macOS、NixOS 工作站和 NixOS server 均由同一仓库提供可构建配置；主机按需求组合能力；server 完成可救援替换与业务按需重建；机密、数据和危险操作具有明确边界。

每个 Phase 使用一个独立 Issue 和一个 Draft PR。Phase 完成取决于验收，不取决于日期。

## 2. 总体依赖关系

```text
Phase 0   治理协议                         #2
   ↓
Phase 1   主机盘点与 Flake 骨架            #3
   ↓
Phase 2   macOS 最小 nix-darwin            #4
   ↓
Phase 3   macOS Home Manager               #5
   ↓
Phase 4   macOS 应用与系统偏好              #6
   ↓
Phase 5   接入现有 NixOS 工作站             #7
   ↓
Phase 5.5 能力模块与主机组合新基线          #66
   ↓
Phase 6   按能力组合 nixbox 用户环境         #8
   ↓
Phase 7   Ubuntu→NixOS 迁移前置盘点          #9
   ↓
Phase 8   NixOS Server 最小配置与 disko     #11
   ↓
Phase 9   nixos-anywhere VM 安装测试        #12
   ↓
Phase 10  经批准的 Ubuntu→NixOS 正式替换    #13
   ↓
Phase 11  最小 NixOS 稳定后引入 sops-nix    #10
   ↓
Phase 12  业务按需重建、加固与 v1 收尾       #14
```

默认按顺序推进。macOS AI 配置审计 #67 不阻塞主线，但在审计完成前 AI 能力只留在 macbook。

## 3. 已完成基线

### Phase 0 — 建立治理协议与项目文档

建立规范、上下文、架构、ADR、Issue/PR 流程与人工关卡。

### Phase 1 — 主机盘点与最小 Flake 骨架

确认三个逻辑 output、平台和非秘密事实，建立顶层 Flake 与 lock file，不激活机器。

### Phase 2 — macOS 最小 nix-darwin 接入

建立 macbook 的 Lix、nix-darwin 与最小安全基线；真实 activation 经过单独人工批准。

### Phase 3 — 迁移 macOS Home Manager 用户层

接入现有 Git、Shell、编辑器、终端与 CLI 配置，保留可变状态边界。

### Phase 4 — 声明 macOS 应用与系统偏好

声明现有 GUI、Homebrew/MAS 与系统 defaults，不启用 destructive cleanup。

### Phase 5 — 接入现有 NixOS 工作站

保留原始 `hardware-configuration.nix`、boot、filesystem 与 `system.stateVersion`，建立 GNOME/GDM 系统基线。

## 4. 当前与后续 Phase

### Phase 5.5 — 建立能力模块与主机组合新基线（#66）

**目标**

修复 Phase 6 暴露的复用边界错误：把 macbook 现有配置封装成 host 可显式 import 的纵向能力，并撤回 nixbox 对完整 desktop bundle 的错误 WIP。

**完成标准**

- 主机角色与能力矩阵固化；
- host 不再使用 `common`、`desktop` 或泛化 Linux bundle 作为需求接口；
- macbook 全量 package、稳定配置与软件所有权不回退；
- Git/GitHub、Atuin 本地历史/同步、Fish/Zsh 主兼容路径拆开；
- LocalSend 等跨层能力合同公开状态与安全影响；
- macbook build 与未改变的 nixbox Phase 5 build 通过；
- 不 activation、不触碰 server、不清理真实可变数据。

### Phase 6 — 按能力组合 nixbox 用户环境（#8）

**目标**

按 `docs/architecture/capability-matrix.md` 的批准清单，把 nixbox 作为 macbook 的需求驱动子集组合；不复制完整桌面。

**关键范围**

- Fish 主 Shell、Atuin 本地历史、Git、GitHub 协作、终端工具、Ghostty、Zed、Helix、Yazi、LocalSend、Obsidian、Chrome、Clash、Termius 与工作站开发运行时；
- nixbox 不参与 Atuin 跨设备同步，不接收 macbook 的 key、session 或历史数据库；
- LocalSend NixOS adapter 显式增加 TCP/UDP 53317，并保留 Home Manager package 单一所有权；
- 不安装 WezTerm、VS Code、Atuin Desktop 或已排除 GUI；
- build 后停在独立 activation 人工关卡前。

### Phase 7 — Ubuntu→NixOS 迁移前置盘点（#9）

**目标**

只读收集当前 Ubuntu server 的 boot、disk、network、SSH、provider、service、data disposition、backup/restore 状态与 rescue 事实。此阶段不建立 standalone Home Manager output，也不修改 server。

**完成标准**

- 目标 disk、boot mode、network model、SSH recovery path 与 provider console 有证据；
- backup location、异机副本与 restore test 状态或维护者明确的数据丢失 waiver 已记录；当前实例采用全量 source-data loss waiver；
- production service、container、volume、database 与入口清单脱敏记录；
- 未知事实保持显式 blocker，不猜测。

### Phase 8 — NixOS Server 最小配置与 disko（#11）

**目标**

根据 Phase 7 证据编写最小 NixOS output 与 disko，只包含 boot、disk、mount、network、SSH、管理用户、sudo、基础 firewall 与 provider 必需设置。

在 nixbox 原生 build server closure；不修改 production server，不恢复业务，不引入 Secret。

实现证据映射见 [`Phase 8 server 最小声明`](../inventory/phase-8-server-minimal.md)，后续 VM 与 production 人工关卡见 [`Server 替换 runbook`](../runbooks/replace-server-with-nixos.md)。

### Phase 9 — nixos-anywhere VM 安装测试（#12）

在 nixbox 的隔离 VM 中验证 Flake、disko、启动、用户与 SSH，形成正式迁移 runbook。此阶段不对 production server 运行安装，也不为构建扩大 OrbStack 或 macOS builder 边界。

Phase 9 的测试结构、固定版本、资源/秘密边界与验证记录见 [`Server 隔离 VM 安装演练`](../inventory/phase-9-server-vm-test.md)。唯一维护者入口为不接受 target 参数的 `nix run .#phase9-test`；演练通过不构成 Phase 10 授权。

### Phase 10 — 经批准的 Ubuntu→NixOS 正式替换（#13）

只有数据恢复方案或明确 waiver、provider console/rescue、target disk、boot mode、network、SSH key、firewall、VM test 与执行窗口全部确认后，才可在维护者实时监督下替换为最小 NixOS。当前实例已记录全量 source-data loss waiver，因此不创建 Ubuntu/业务 backup、dump 或 restore test；失败恢复目标是重新建立最小 NixOS。

Issue 必须列出精确 target、disk、命令、窗口和回滚步骤并获得当次批准。Agent 默认停在执行关卡前，不无人值守运行 disko、nixos-anywhere、format、reboot 或 production restore。

### Phase 11 — 最小 NixOS 稳定后引入 sops-nix 与 age（#10）

先用非 production secret 验证 recipient、解密、owner/mode、轮换与恢复，再接入真实服务。明文不得进入 Git、Issue、PR、log 或 Nix Store。

当前实现采用管理员恢复 recipient 加每机独立 SSH-host-derived recipient；只有 macbook 提供编辑工具，nixbox 与 server 只有本机解密能力。管理员 identity 的仓库外恢复副本由维护者自行管理且不由 Agent 验证。macbook、nixbox 与 server 的首次 activation、public fingerprint、运行时 owner/group/mode、非生产内容、system health 与临时入口清理均已由维护者逐机验收；Phase 11 不引入 production secret，当前只剩 PR 合并与 Issue completion summary 关卡。

### Phase 12 — 业务按需重建、加固与 v1 收尾（#14）

不恢复当前 Ubuntu 的 Compose、容器、数据库、volume 或用户数据。最小 NixOS 与 sops-nix 稳定后，只按维护者届时的新需求从空白状态逐项引入业务；每个新 stateful service 在进入 production 前独立确定 backup、restore、monitoring、update 与 rollback contract。若没有业务需要，Phase 12 只完成系统加固、运维与 v1 收尾。

## 5. 控制链路与部署方向

```text
macbook ──SSH 管理/救援──▶ server
   │
   └──remote development──▶ nixbox ──build/test/push closure──▶ server
```

- nixbox 是 server closure 的主要构建与验证节点；
- macbook→server 直连保证 nixbox 故障时仍有 production 控制面；
- server 不保存 GitHub 协作凭据，不依赖 mutable checkout 自行构建；
- 配置一致性提高复用与测试置信度，但不取消 host-specific 的 disk、boot、network、SSH、Secret、service 与 data 验证。

## 6. v1 之后候选工作

Clan、deploy-rs、Colmena、flake-parts、impermanence、ZFS、LUKS、自动更新与额外 fleet abstraction 都必须从真实需求与可量化收益出发，另建 Issue 与 ADR；不得因为社区惯例盲目扩大边界。

## 7. Phase Issue 必备字段

每个阶段 Issue 必须包括目标、已知事实、依赖、允许/禁止修改、任务、验证、人工关卡、回滚、完成标准和英文 Agent Contract。模板位于 `.github/ISSUE_TEMPLATE/implementation-phase.md`。
