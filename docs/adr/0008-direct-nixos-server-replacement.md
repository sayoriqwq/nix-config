# ADR-0008：Server 从 Ubuntu 直接替换为 NixOS

- **状态：** 已接受
- **日期：** 2026-07-29（2026-07-30、2026-08-05 与 2026-08-10 补充维护者决策）

## 决策

当前 server 运行 Ubuntu，但 Ubuntu 只是待替换的机器事实，不是长期架构角色。取消 standalone Home Manager 过渡配置，迁移顺序调整为：迁移前置盘点；最小 NixOS 与 disko 声明；隔离 VM 安装验证；经人工批准直接替换为只保证启动、网络、SSH、sudo 与救援能力的最小 NixOS；系统稳定后建立 sops-nix/age Secret 能力；最后按新需求从空白状态引入业务并建立相应运维能力，不恢复当前 Ubuntu 的业务与数据。

实施状态：Phase 10 已于 2026-08-03 完成正式替换，Phase 11 已于 2026-08-04 完成 Secret 基础验收；上述“当前 Ubuntu”是本 ADR 作出时的历史前提，不是现状。Phase 12 已明确延后。

维护者于 2026-08-05 曾确定单管理员 root public-key-only 直连模型，因此关闭 root SSH 的 Issue #99 / PR #109 当时以未计划实施关闭，且从未 activation。该段只记录决策演变，不再表示当前目标。

维护者于 2026-08-10 复审后取代上述选择：macbook maintenance identity 与 nixbox deploy identity 使用两把既有、彼此独立的 key，都登录 server 的实际 Unix 用户 `sayori`；维护者日常使用 `sudo`，确需连续 root 操作时使用 `sudo -i`，不使用 `su` 或 root password。Root SSH、password 与 keyboard-interactive 全部关闭，Contabo VNC 继续作为已实连验证的带外恢复路径。Issue #99 因而重新打开，负责声明、隔离测试与操作文档；production activation 仍需独立行动卡和当次批准。

独立 key 只划分凭据的保管、撤销、轮换和认证来源：macbook private key 不复制到 nixbox，nixbox deploy private key 也不承担维护者身份。由于两把 key 都映射到 `server:sayori` 并共享同一套 passwordless sudo policy，它们不是 Unix 权限隔离边界；需要不同授权时必须拆分远端 account 或 sudo policy，而不能只靠换 key 名称。

nixbox 是与 server 同为 `x86_64-linux` 的预生产验证主机，负责构建和隔离验证可复用的 NixOS 能力，但不运行生产服务。配置一致性不能替代 server 的磁盘、启动、网络、SSH、Secret、生产服务和数据处置关卡。

后续部署采用 closure 推送方向：nixbox 获取锁定输入、构建和验证 server closure，再将不可变 closure 推送给 server。macbook 保留到 server 的独立 SSH 管理与救援路径，使 nixbox 故障不会切断生产控制面；该路径不是另一套构建来源，也不绕过 nixbox 的主要验证职责。Server 不保存 GitHub 协作凭据，也不依赖 mutable checkout 自行拉取和构建；GitHub 不成为生产切换与回滚路径的运行时依赖。

维护者于 2026-07-30 补充确认当前实例的 host-specific 决策：

- 当前 Ubuntu 的系统、服务、容器、数据库和数据全部可丢失；不创建 source backup、异机副本或 restore test，也不恢复旧业务；
- 该 waiver 只替代 source-data recovery gate。target disk、BIOS boot、static network、firewall、SSH、VNC/Rescue、VM test、精确命令与当次人工批准仍是强制关卡；
- public address、prefix、gateway 与 nameserver 是可版本化的非凭据 host facts；不为这些值建立第二个本地配置仓库；
- 首次 NixOS 使用 `sayori`、macbook maintenance public key、nixbox 专用 deploy public key、passwordless sudo 与 key-only root SSH；Phase 10 当时把 root 路径视为安装期 break-glass，2026-08-05 曾短暂把它保留为长期模型，2026-08-10 最终恢复为双 key 登录 `sayori`、经 sudo 提权并关闭 root SSH；
- 在没有 compromise 证据时以 `--copy-host-keys` 保留既有 SSH host identity；失败恢复目标是重新建立可 SSH 的最小 NixOS。

Private key、passphrase、token、VNC/Rescue credential、host-key private material 和 production secret 即使位于本地仓库也仍不得提交 Git。

## 第一性目标

Server 的首要收益是配置一致性：已经在 macbook 或 nixbox 通过相同 Nix 能力构建验证的配置，可以原样进入 server composition，减少重复实现和测试变量。该一致性只覆盖可复用能力；host-specific 的 disk、boot、network、SSH、Secret、production service 与 data policy 仍需独立证据或明确 waiver。

## 结果

- 不再为短命 Ubuntu 用户层支付实现、激活与清理成本；
- nixbox 与 server 同为 `x86_64-linux`，可以原生构建和验证 closure；
- server runtime 不依赖 GitHub 可用性或工作树状态；
- macbook 直连 `server:sayori` 的管理链路与 nixbox build/deploy 链路相互补充，避免单点控制面；
- 维护者交互凭据与 nixbox 机器部署凭据明确分离：前者供 macbook 人工管理，后者只承担同架构 build/test 与获批部署；两者共享远端 account 与 sudo 权限，因此不把凭据分离误报为授权隔离；
- 正式替换仍是高风险人工动作，必须经过 inventory、VM test、记录的数据处置决定、provider rescue 与精确人工批准关卡；当前实例以已记录的全量数据丢失 waiver 取代 source backup/restore。

## 被否决的方案

- Ubuntu standalone Home Manager：增加短命状态与第二套 activation 语义，不能推进最终 server 一致性；
- 让 server 自行 checkout/build：把 GitHub 凭据和 mutable source state 带入 production；
- 为已批准公开的 routing facts 建第二个本地配置仓库：会拆分单一 Flake 的 source of truth，且没有解决真正 secret 不应进入 Git 的问题；
- 使用 OrbStack 充当额外 x86_64 builder：现有 OrbStack 是 `aarch64-linux` 容器环境，且 nixbox 已是目标同架构构建节点；
- macbook 只经 nixbox 才能管理 server：nixbox 故障会切断 production 控制面。
- 继续把 root SSH 作为日常入口：减少一次 sudo 边界，但会让每次成功 SSH 都直接获得最高权限，也使交互式环境归属与审计语义偏离 server 的 `sayori` 用户能力；2026-08-10 复审后不再采用。
- 在 macbook 与 nixbox 之间复制同一 private key：无法独立撤销或轮换，机器凭据泄露还会同时影响人工维护身份；两端继续使用既有独立 key。
