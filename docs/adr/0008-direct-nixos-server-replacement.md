# ADR-0008：Server 从 Ubuntu 直接替换为 NixOS

- **状态：** 已接受
- **日期：** 2026-07-29（2026-07-30 补充维护者决策）

## 决策

当前 server 运行 Ubuntu，但 Ubuntu 只是待替换的机器事实，不是长期架构角色。取消 standalone Home Manager 过渡配置，迁移顺序调整为：迁移前置盘点；最小 NixOS 与 disko 声明；隔离 VM 安装验证；经人工批准直接替换为只保证启动、网络、SSH、sudo 与救援能力的最小 NixOS；系统稳定后建立 sops-nix/age Secret 能力；最后按新需求从空白状态引入业务并建立相应运维能力，不恢复当前 Ubuntu 的业务与数据。

实施状态：Phase 10 已于 2026-08-03 完成正式替换，Phase 11 已于 2026-08-04 完成 Secret 基础验收；上述“当前 Ubuntu”是本 ADR 作出时的历史前提，不是现状。Phase 12 已明确延后。

维护者于 2026-08-05 进一步确定长期交互管理模型：当前 server 是个人使用的单管理员主机；macbook 上的 `ssh sayori` 是本地 Host alias，远端用户为 `root`。root SSH 保持 public-key-only，password 与 keyboard-interactive 继续关闭；不要求维护者先以 server 普通用户登录后再 `sudo`。Contabo VNC 已完成真实端到端连接验证。关闭 root SSH 的 Issue #99 / PR #109 因此以未计划实施关闭，且从未 activation。

nixbox 是与 server 同为 `x86_64-linux` 的预生产验证主机，负责构建和隔离验证可复用的 NixOS 能力，但不运行生产服务。配置一致性不能替代 server 的磁盘、启动、网络、SSH、Secret、生产服务和数据处置关卡。

后续部署采用 closure 推送方向：nixbox 获取锁定输入、构建和验证 server closure，再将不可变 closure 推送给 server。macbook 保留到 server 的独立 SSH 管理与救援路径，使 nixbox 故障不会切断生产控制面；该路径不是另一套构建来源，也不绕过 nixbox 的主要验证职责。Server 不保存 GitHub 协作凭据，也不依赖 mutable checkout 自行拉取和构建；GitHub 不成为生产切换与回滚路径的运行时依赖。

维护者于 2026-07-30 补充确认当前实例的 host-specific 决策：

- 当前 Ubuntu 的系统、服务、容器、数据库和数据全部可丢失；不创建 source backup、异机副本或 restore test，也不恢复旧业务；
- 该 waiver 只替代 source-data recovery gate。target disk、BIOS boot、static network、firewall、SSH、VNC/Rescue、VM test、精确命令与当次人工批准仍是强制关卡；
- public address、prefix、gateway 与 nameserver 是可版本化的非凭据 host facts；不为这些值建立第二个本地配置仓库；
- 首次 NixOS 使用 `sayori`、macbook maintenance public key、nixbox 专用 deploy public key、passwordless sudo 与 key-only root SSH；Phase 10 当时把 root 路径视为安装期 break-glass，维护者后来明确把 macbook→server root key-only 直连保留为当前单管理员长期模型；
- 在没有 compromise 证据时以 `--copy-host-keys` 保留既有 SSH host identity；失败恢复目标是重新建立可 SSH 的最小 NixOS。

Private key、passphrase、token、VNC/Rescue credential、host-key private material 和 production secret 即使位于本地仓库也仍不得提交 Git。

## 第一性目标

Server 的首要收益是配置一致性：已经在 macbook 或 nixbox 通过相同 Nix 能力构建验证的配置，可以原样进入 server composition，减少重复实现和测试变量。该一致性只覆盖可复用能力；host-specific 的 disk、boot、network、SSH、Secret、production service 与 data policy 仍需独立证据或明确 waiver。

## 结果

- 不再为短命 Ubuntu 用户层支付实现、激活与清理成本；
- nixbox 与 server 同为 `x86_64-linux`，可以原生构建和验证 closure；
- server runtime 不依赖 GitHub 可用性或工作树状态；
- macbook 直连管理链路与 nixbox build/deploy 链路相互补充，避免单点控制面；
- 维护者交互身份与 nixbox 机器部署身份明确分离：前者从 macbook 直达 root，后者只承担同架构 build/test 与获批部署；
- 正式替换仍是高风险人工动作，必须经过 inventory、VM test、记录的数据处置决定、provider rescue 与精确人工批准关卡；当前实例以已记录的全量数据丢失 waiver 取代 source backup/restore。

## 被否决的方案

- Ubuntu standalone Home Manager：增加短命状态与第二套 activation 语义，不能推进最终 server 一致性；
- 让 server 自行 checkout/build：把 GitHub 凭据和 mutable source state 带入 production；
- 为已批准公开的 routing facts 建第二个本地配置仓库：会拆分单一 Flake 的 source of truth，且没有解决真正 secret 不应进入 Git 的问题；
- 使用 OrbStack 充当额外 x86_64 builder：现有 OrbStack 是 `aarch64-linux` 容器环境，且 nixbox 已是目标同架构构建节点；
- macbook 只经 nixbox 才能管理 server：nixbox 故障会切断 production 控制面。
- 强制当前唯一管理员先登录 server 普通用户再 `sudo`：在 root 已限定为维护者公钥、且 provider VNC 已验收的个人单管理员场景中增加操作层级，但没有与当前需求相称的收益；未来多管理员或审计需求出现时再复审。
