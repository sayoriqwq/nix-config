# Agent 协议（中文译文）

[AGENTS.md](../../AGENTS.md) 是本仓库面向 Agent 的规范性英文版本。如果两者不一致，以英文为准，并在同一变更中修复翻译。

## 1. 项目使命

维护一个可审计、可复现的 Nix 配置仓库，服务于：

- 一台由 nix-darwin 与 Home Manager 管理的 macOS 主工作站；
- 一台作为次级工作站与 Linux 实验站的 NixOS 主机；
- 一台按当前需求增加生产能力的最小 NixOS 服务器；
- 由这些主机显式选择、按真实需求组合的 Software owner 与 Intent。

本仓库管理**配置声明**，不管理可变应用数据或备份。私有机器证据保存在 Macwarden，与用户选择纳入本仓库的稳定声明分开。

## 2. 从当前请求开始

修改文件前依次阅读：

1. AGENTS.md 和当前任务请求，包括工作范围与已有授权；
2. 已存在且相关的 Issue 或 PR，包括评论、允许修改的范围和安全条件；
3. [CONTEXT.md](../../CONTEXT.md) 中的领域词汇；
4. 相关架构文档、已接受 ADR，以及将要执行的操作所对应的 runbook。

清楚的当前请求足以开始工作。Issue 是可选工具，不为取得实施许可创建占位 Issue。

协作流程以本协议为准。辅助文档中旧有的 Issue、PR、独立 worktree 或 merged commit 要求，不再构成通用门槛；其中的架构决策、证据要求和具体操作安全条件继续保留。

## 3. 日常工作

1. 默认在当前 checkout 工作。并行任务需要隔离或用户明确要求时，再使用独立分支或 worktree；分支优先采用 `codex/<短名称>`，不要求 Issue 编号。
2. 在约定范围内完成必要修改。保留无关工作和已有未提交修改，不把它们混入提交或清理。
3. 运行最小相关验证，检查最终 diff。
4. 除非用户另有要求，为完成的变更创建本地提交，报告提交、验证结果及剩余操作或限制。

允许在当前分支（包括 main）创建本地提交。Push、创建或修改 GitHub 条目以及向外部发送消息需要用户授权；本地工作不意味着发布。

确有跨会话计划或协作需求时使用 Issue；需要审阅或用户要求时使用 PR。获得创建 PR 的授权后，除非用户明确要求其他状态，先创建 Draft。将 Draft 标记 Ready、merge 和开启 auto-merge 均需明确授权。通过 Issue 或 PR 协作时阅读 [issue-tracker.md](issue-tracker.md)；标签可选。

按真实依赖推进：下一步需要的前置动作完成后即可继续，不等待标签、PR 合并或 Issue 关闭。无关清理、升级、重命名和框架变更保持在范围外。

## 4. 语言

- 规范性 Agent 约束使用英文，以保证精度。
- 维护者文档、Issue 与 PR 描述、验证报告、提交信息和操作说明使用中文。
- 代码标识符与普通代码注释使用英文，只有中文明显更利于维护时才例外。
- 英文协议发生修改时，必须在同一变更中更新本译文。

## 5. 架构不变量

- 使用一个顶层 Flake 作为声明事实源。
- Nix 声明与 lock 是受管期望状态的权威来源。希望长期保留的受管变更进入声明，现场证据用于验证部署。改变所有权前先改善日常更新与应用流程；辅助命令仅组合现有 Git/Nix/nh 机制，不另建软件清单或声明格式。保证与例外见[主工作站管理](../architecture/workstation-management.md)。
- Home Manager 管理可移植用户层，nix-darwin 管理 macOS 系统配置，NixOS modules 管理 NixOS 系统配置。
- 最小 NixOS server 按需求演进，每项生产能力通过范围明确的请求引入，不恢复已退役的 Ubuntu server 层。
- 主机与硬件事实放在 `hosts/<host>/`。
- 每个软件的 package、稳定配置、服务和 owner-local asset 放在 `software/<software>/`。
- 跨软件可执行组合放在 `intents/<intent>/`；Intent 只使用公开的 Software Primary Capability 与 Extension。
- `modules/` 只保留已经证明可复用的 System 或 Home Manager primitive。
- 主机通过显式 Intent 结果、独立 Software platform module 和主机事实组合。Import 就是选择机制，不增加全局 capability registry 或自动发现。
- 主机不得用 common、desktop、Darwin、Linux 或 server bundle 代替需求选择。
- 只有已证明的行为差异才建立平台实现，并公开 package 所有权、受管配置、可变状态边界、服务、网络影响和人工关卡。
- 优先使用 Home Manager、NixOS 与 nix-darwin 的现有选项，最后才考虑自定义 activation script 或生成 shell 代码。
- 项目专用开发依赖进入各项目 dev shell，不进入全局用户 profile。
- Git 同步声明；可变数据、数据库、浏览器资料、服务状态和备份采用独立的数据管理流程。

路径级规则见 [module-boundaries.md](../architecture/module-boundaries.md)。

## 6. 安全与授权

以下动作需要用户在当前会话或相关 Issue、PR 中给出明确、具体的授权：

- 在真实机器激活 macOS、NixOS 或 Home Manager 配置；
- 修改 bootloader、分区、文件系统、加密、挂载、远程网络、DNS、防火墙或 SSH 访问配置；
- 运行 disko、nixos-anywhere、磁盘格式化、破坏性迁移或生产恢复命令；
- 重启、关机或替换远程服务器；
- 迁移或删除生产数据。

为这些动作明确目标、精确动作、相关 revision 或 build、执行窗口、停止条件、读回验证和回滚。在已授权的范围和条件仍有效时继续使用已有授权；只有拟执行动作超出范围时才重新询问。Build、本地提交、PR 合并或泛化的改进意愿，不授权另一个机器操作。

其他硬性规则：

- 不得提交明文 secret、token、密码、私钥、恢复码、解密后的 SOPS 内容或私有 .env。
- 不得仅为匹配当前版本而改变已有 `system.stateVersion` 或 `home.stateVersion`。
- 只有具备目标机器证据且任务明确包含该范围时，才能编辑生成的硬件配置。
- 不得为了部署方便而削弱 SSH 访问或防火墙安全。
- 引入 flake-parts、Blueprint、Clan、deploy-rs、Colmena、impermanence、ZFS、LUKS 或其他重大框架/存储设计，需要明确范围和已接受 ADR；该决策不强制采用 Issue 形式。
- 无人值守 Agent 不得执行远程安装或破坏性命令。
- 按维护者在目标机器上的输入能力设计人工命令，不要求手打 hash、store path、公钥或长参数列表。精确动作无法表达为短命令时，传输并验证范围收窄的临时 helper，提供短入口，并在使用后删除 helper。

## 7. 证据

编写主机专属配置前，按 [host-inventory.md](../runbooks/host-inventory.md) 收集与变更有关的事实。已验证且仍适用的事实可以复用；事实缺失或相互矛盾时，收集新证据或明确记录未知项。不得猜测用户名、架构、主机名、磁盘、启动模式、网卡、state version、服务清单或网络设置。

- 只记录复现所需的非秘密事实。
- 未经维护者明确批准存储，隐去公网 IP、账号标识、token、序列号、私有主机名等敏感值。
- 接入现有 NixOS 时，保留原始硬件配置、boot 配置和 state version。
- 服务器破坏性步骤前，记录备份位置、恢复验证、救援控制台、目标磁盘、启动模式、网络模型与 SSH 恢复路径。

## 8. 验证与完成

运行最小相关检查，并报告精确命令和结果：

- 文档变更：检查链接、标题、术语及英中一致性；不声称未运行的 Nix evaluation 或 build 已通过。
- Nix 变更：格式化修改的文件、求值受影响声明并运行相关合同检查。需要验证集成时构建受影响 package 或 host output。根据影响范围选择完整 `nix flake check` 或 system build，不为每次编辑固定执行全套检查。
- 临时构建优先使用 `--no-link`，确需结果链接时例外。Output 名称取自实际声明。Build 和 activation 是不同动作。
- 某项检查无法执行时，说明原因、已获得的替代证据和仍未验证的内容。

完成边界来自用户请求，不取决于 GitHub 状态。记录本地提交、验证以及相关风险或回滚方式。如实报告尚未执行的实机验证；若它属于用户要求的结果，该部分在实际执行前保持待完成。普通本地维护不依赖 PR 合并或 Issue 关闭。

## 9. 辅助文档

- 通过可选 Issue/PR 协作时：[issue-tracker.md](issue-tracker.md)。
- 选择 Issue 标签时：[triage-labels.md](triage-labels.md)。
- 修改领域文档或处理来源冲突时：[domain.md](domain.md)。
- 处理日常工作站管理、偏移、私有记录和选择同步时：[主工作站管理](../architecture/workstation-management.md)。
- 查看拓扑与组合时：[架构概览](../architecture/overview.md)。
- 执行真实机器操作时：`docs/runbooks/` 下适用的文件。
