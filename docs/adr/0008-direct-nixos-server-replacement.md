# ADR-0008：Server 从 Ubuntu 直接替换为 NixOS

- **状态：** 已接受
- **日期：** 2026-07-29

## 决策

当前 server 运行 Ubuntu，但 Ubuntu 只是待替换的机器事实，不是长期架构角色。取消 standalone Home Manager 过渡配置，迁移顺序调整为：迁移前置盘点；最小 NixOS 与 disko 声明；隔离 VM 安装验证；经人工批准直接替换为只保证启动、网络、SSH、sudo 与救援能力的最小 NixOS；系统稳定后建立 sops-nix/age Secret 能力；最后恢复业务与数据。

nixbox 是与 server 同为 `x86_64-linux` 的预生产验证主机，负责构建和隔离验证可复用的 NixOS 能力，但不运行生产服务。配置一致性不能替代 server 的磁盘、启动、网络、SSH、Secret、生产服务和数据恢复关卡。

后续部署采用 closure 推送方向：nixbox 获取锁定输入、构建和验证 server closure，再将不可变 closure 推送给 server。macbook 保留到 server 的独立 SSH 管理与救援路径，使 nixbox 故障不会切断生产控制面；该路径不是另一套构建来源，也不绕过 nixbox 的主要验证职责。Server 不保存 GitHub 协作凭据，也不依赖 mutable checkout 自行拉取和构建；GitHub 不成为生产切换与回滚路径的运行时依赖。

## 第一性目标

Server 的首要收益是配置一致性：已经在 macbook 或 nixbox 通过相同 Nix 能力构建验证的配置，可以原样进入 server composition，减少重复实现和测试变量。该一致性只覆盖可复用能力；host-specific 的 disk、boot、network、SSH、Secret、production service 与 data recovery 仍需独立证据。

## 结果

- 不再为短命 Ubuntu 用户层支付实现、激活与清理成本；
- nixbox 与 server 同为 `x86_64-linux`，可以原生构建和验证 closure；
- server runtime 不依赖 GitHub 可用性或工作树状态；
- macbook 直连管理链路与 nixbox build/deploy 链路相互补充，避免单点控制面；
- 正式替换仍是高风险人工动作，必须经过 inventory、VM test、backup/restore 与 provider rescue 关卡。

## 被否决的方案

- Ubuntu standalone Home Manager：增加短命状态与第二套 activation 语义，不能推进最终 server 一致性；
- 让 server 自行 checkout/build：把 GitHub 凭据和 mutable source state 带入 production；
- 使用 OrbStack 充当额外 x86_64 builder：现有 OrbStack 是 `aarch64-linux` 容器环境，且 nixbox 已是目标同架构构建节点；
- macbook 只经 nixbox 才能管理 server：nixbox 故障会切断 production 控制面。
