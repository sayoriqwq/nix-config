# Agent 协议（中文译文）

> `AGENTS.md` 是规范性英文版本，本文件用于维护者准确理解。如果两者不一致，以 `AGENTS.md` 为准，并必须在同一个 PR 中修复翻译差异。

## 1. 项目使命

在一个可审计、可复现的 Nix 配置仓库中长期维护：

- 一台由 nix-darwin 管理的 macOS 工作站；
- 一台 NixOS 工作站；
- 一台先运行 Ubuntu、最终迁移到 NixOS 的服务器；
- 一套由 Home Manager 管理的可移植用户环境。

本仓库管理配置声明，不负责保存可变应用数据或充当备份系统。

## 2. 开始工作前的阅读顺序

Agent 修改文件前必须依次阅读：

1. 根目录 `AGENTS.md`；
2. 当前 GitHub Issue 及其评论和人工关卡；
3. `CONTEXT.md`；
4. `docs/architecture/` 下与任务有关的文档；
5. `docs/adr/` 下所有适用的 ADR；
6. `docs/plans/migration-roadmap.md` 中当前阶段。

没有实施 Issue 时，不得自行开始实现，只能检查现状、形成计划或创建边界完整的 Issue。

## 3. 语言规则

- 给 Agent 的规范性硬约束使用英文，以减少歧义。
- 给维护者阅读的文档、Issue、PR 描述、验证报告和操作说明使用中文。
- 代码标识符和普通代码注释优先使用英文，只有中文明显更利于维护时才使用中文。
- 修改 `AGENTS.md` 时，必须在同一个 PR 更新本译文。

## 4. 工作模型

- 一个 PR 只实现一个迁移阶段或一个范围很窄的维护 Issue。
- 使用独立分支；计划阶段优先命名为 `agent/phase-<编号>-<短名称>`。
- 默认创建 Draft PR。
- 不得把实施变更直接提交到 `main`。
- 没有维护者明确批准，不得合并、开启自动合并或把 Draft 标记为 Ready for review。
- 当前阶段的完成标准和人工验证没有记录前，不得进入下一阶段。
- 不得顺手做无关清理、依赖升级、重命名或框架迁移。
- 必须严格遵守 Issue 中“允许修改”和“禁止修改”的路径与动作。
- 机器事实未知时，必须收集证据或保留明确占位符，不能猜用户名、架构、主机名、磁盘、启动模式、网卡、`stateVersion`、服务清单或网络设置。

## 5. 架构不变量

- 使用一个顶层 Flake 作为配置事实来源。
- Home Manager 管理可移植用户层。
- nix-darwin 管理 macOS 系统层。
- NixOS Modules 管理 NixOS 系统层。
- Ubuntu 上的 standalone Home Manager 只作为过渡方案。
- `hosts/<host>/` 保存主机与硬件事实。
- `modules/darwin/` 保存可复用的 macOS 系统模块。
- `modules/nixos/` 保存可复用的 NixOS 系统模块。
- `modules/home/` 保存可复用的用户模块。
- `modules/home/common/default.nix` 必须与平台无关，并可用于无桌面的服务器。
- Desktop、Darwin、Linux 和 Server 的用户配置必须拆分。
- 优先使用 Home Manager、NixOS 和 nix-darwin 的成熟选项，最后才考虑 activation script 或生成 shell 脚本。
- 项目专用开发依赖进入各项目 dev shell，不进入全局用户 profile。
- Git 同步声明；数据库、浏览器资料、容器卷、运行状态和备份采用独立流程。

路径级规则见 `docs/architecture/module-boundaries.md`。

## 6. 安全规则

以下操作必须在当前 Issue 或 PR 中获得明确、针对本次动作的人工批准，否则禁止执行：

- 在真实机器激活 macOS、NixOS 或 Home Manager 配置；
- 修改 bootloader、分区、文件系统、加密、挂载、远程网络、DNS、防火墙或 SSH 访问；
- 运行 `disko`、`nixos-anywhere`、格式化、破坏性迁移或生产恢复命令；
- 重启、关机或替换远程服务器；
- 迁移或删除生产数据。

其他硬性规则：

- 不得提交明文密码、token、私钥、恢复码、解密后的 SOPS 内容或私有 `.env`。
- 不得仅因为当前 Nix 版本更高就修改已有 `system.stateVersion` 或 `home.stateVersion`。
- 没有目标机器证据且 Issue 未明确授权时，不得编辑生成的硬件配置。
- 不得为了部署方便而削弱 SSH 或防火墙安全。
- 未经独立 Issue 与已接受 ADR，不得引入 flake-parts、Blueprint、Clan、deploy-rs、Colmena、impermanence、ZFS、LUKS 或其他重大框架/存储设计。
- 无人值守的 Agent 不得执行远程重装或破坏性命令。

## 7. 证据与盘点

编写主机专属配置前，必须收集 `docs/runbooks/host-inventory.md` 中的证据。

- 只记录复现需要的非秘密事实。
- 未经维护者明确许可，应隐去公网 IP、账号标识、token、序列号、私有主机名等敏感信息。
- 接入现有 NixOS 时，保留原始 `hardware-configuration.nix`、boot 配置和 state version。
- 服务器破坏性步骤前必须记录：备份位置、恢复验证、救援控制台、目标磁盘、启动模式、网络模型和 SSH 恢复路径。

## 8. 验证协议

Agent 必须运行与变更最匹配的最小检查，并报告准确命令和结果。

### 纯文档变更

检查链接、标题、术语，以及英文规范与中文文档是否一致。仓库尚无 Nix 实现时，不得声称已经通过 Nix evaluation。

### Flake 或 Nix 变更

在命令可用且与任务相关时执行：

```bash
nix fmt -- --check .
nix flake check
```

只构建受影响 output，不激活：

```bash
# macOS
nix build .#darwinConfigurations.<host>.system

# NixOS
nix build .#nixosConfigurations.<host>.config.system.build.toplevel

# standalone Home Manager
nix build .#homeConfigurations."<user>@<host>".activationPackage
```

使用 Issue 中确认的真实 output 名称。构建成功不等于获得激活许可。

某项检查无法运行时，必须明确说明原因、替代证据，以及留给维护者或机器本地 Codex 会话的工作。

## 9. PR 协议

每个 PR 必须用中文说明：

- 关联 Issue 与迁移阶段；
- 修改内容和原因；
- 受影响文件与主机；
- 明确不在范围内的事项；
- 验证命令和结果；
- 风险与回滚方式；
- 人工动作和批准关卡；
- 未确认事实或后续 Issue。

维护者检查 diff 并完成必要的真实机器验证前，PR 保持 Draft。

## 10. 完成定义

只有同时满足以下条件，阶段才算完成：

- Issue 完成标准已满足；
- 文档和 ADR 保持最新；
- 相关 evaluation/build 成功，或阻塞原因已记录；
- 维护者记录了要求的真实机器验证；
- 回滚步骤已知；
- PR 由人工合并；
- Phase Issue 以完成摘要关闭。

## 11. 辅助文档

- Issue 流程：`docs/agents/issue-tracker.md`
- 标签词汇：`docs/agents/triage-labels.md`
- 领域文档规则：`docs/agents/domain.md`
- 架构：`docs/architecture/overview.md`
- 路线图：`docs/plans/migration-roadmap.md`
