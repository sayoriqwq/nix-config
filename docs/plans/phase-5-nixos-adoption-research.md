# Phase 5：NixOS 工作站接入调研（已批准）

> 范围：为 Issue #7 的现有 NixOS 26.05 单用户 GNOME 工作站选择最小、可审计的接入路径。
> 本文是设计证据，不授权任何真实机器 activation、重启或网络/SSH 改动。
> 维护者于 2026-07-28 批准方案 A：UUID 入库、永久最小 SSH、启用 Flakes，Home Manager 与 LocalSend 延后。

## 1. 结论

**推荐方案：先做“原样导入的最小系统接入”，把 Home Manager、LocalSend 及任何安全/桌面改造留在后续阶段或真正需要时再处理。**

具体说，新增 `nixosConfigurations.nixbox`，由 `hosts/nixbox/default.nix` 导入经脱敏审阅的原始 `hardware-configuration.nix`，保留原有 boot、文件系统、swap（当前无）、GPU、NetworkManager、GNOME/GDM、PipeWire、CUPS、Bluetooth、Bash、`allowUnfree` 和 USTC substituter 行为；仅把已确认可复用的 Nix 基础设置、普通用户和最小 SSH 声明放入 `modules/nixos/base.nix`，把桌面角色服务放入 `modules/nixos/desktop.nix`。`system.stateVersion = "26.05"` 不变。

这是最符合 Phase 5“先保持行为、再抽取”的目标和 Issue 禁止项的方案。NixOS 官方将配置描述为模块化的声明；文件系统通过 `fileSystems` 定义，且建议用拓扑无关的 `/dev/disk/by-uuid` 或 `/dev/disk/by-label` 路径 [官方手册：配置与文件系统](https://nixos.org/manual/nixos/stable/#sec-changing-config)、[官方手册：File Systems](https://nixos.org/manual/nixos/stable/#sec-file-systems)。**据此推论**：接入现有系统时复制已验证的硬件模块、而不重新生成或抽象磁盘事实，是风险最低的路径。

为避免“分层”掩盖行为变化，实施顺序应当是：先在 `hosts/nixbox/` 建立与实时配置逐项对应的可构建 host output；确认求值后，再把相同选项机械移动到 `base.nix` / `desktop.nix`，再次构建并比较关键选项。模块拆分不能与设置优化混在同一步。

## 2. 已知事实与判断边界

下列事实来自 Issue #7 的 2026-07-28 脱敏实时盘点：`x86_64-linux`、NixOS 26.05、Nix 2.34.7、UEFI/systemd-boot、vfat `/boot`、ext4 `/`、无 swap、Intel i915/iwlwifi、GNOME/GDM、PipeWire、NetworkManager、CUPS、Bluetooth、Bash、无 Home Manager、无 failed units；系统 profile generation 4，已启动的永久 generation 为 3，当前运行态另有可重启撤销的 SSH `test` generation。不得把真实 hostname、地址、SSID、MAC、SSH 指纹或 filesystem UUID 写入本文。

“保留”表示首次 Flake 输出须复现经验证的当前行为；不表示这些选项已被证明是长期最佳实践。因而本调研不建议在同一 PR 顺带缩小 unfree 范围、替换镜像、切换 shell、升级 GNOME、重做磁盘、添加 swap 或调整 GPU/Wi-Fi。

## 3. 官方事实、推论与本仓库建议

### 3.1 `/etc/nixos` 接入 Flake 的最小路径

- **官方事实：** `nixos-rebuild` 可用 `--flake path#hostname` 选择一个 flake 输出；Home Manager 的 NixOS 集成示例也以 `nixpkgs.lib.nixosSystem` 和模块列表定义 `nixosConfigurations.<hostname>`。[NixOS 手册：Changing the Configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config)，[Home Manager 官方手册：NixOS module](https://home-manager.dev/manual/unstable/nix-flakes/nixos.html)。
- **推论：** 没有必要把 Git 仓库复制到 `/etc/nixos`，也不必修改 `NIX_PATH`；目标机可显式用仓库路径与 `#nixbox` 运行 rebuild。把部署入口的位置和输出名称显式写出，反而减少真实 hostname 与仓库逻辑 output 的耦合。
- **本仓库建议：** `flake.nix` 新增 `nixosConfigurations.nixbox = nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = [ ./hosts/nixbox ./modules/nixos/base.nix ./modules/nixos/desktop.nix ]; };`。`hosts/nixbox/default.nix` 只组合主机模块、导入硬件文件并保留主机事实；不要为了目录图预建空模块。该布局与 ADR-0001、`docs/architecture/module-boundaries.md` 一致。

### 3.2 filesystem UUID 是应提交的硬件事实，不是 secret

- **官方事实：** NixOS 用 `fileSystems` 生成 `/etc/fstab` 和相应 mount unit；官方建议 device 采用 `/dev/disk/by-label` 或 `/dev/disk/by-uuid`，因为它们不随磁盘拓扑变化而变化。[NixOS 手册：File Systems](https://nixos.org/manual/nixos/stable/#sec-file-systems)。
- **推论：** 对现有的根与 EFI 文件系统，UUID 是可重建、可启动的硬件绑定事实；它通常不构成凭据。若不提交它，Flake 无法独立描述当前挂载，必须依赖未版本化的本地文件或在 activation 前手动替换，牺牲审计性与可复现性。
- **本仓库建议：** 在维护者明确同意后，将原始 `hardware-configuration.nix` 的两个 UUID 原样纳入 `hosts/nixbox/`，并在 PR 审阅中确认无序列号、真实 hostname 或其他敏感内容。替代方案及其真实代价如下：

| 替代 | 代价 | Phase 5 结论 |
| --- | --- | --- |
| `/dev/disk/by-label` | 需要现有分区已有稳定 label；改 label 是文件系统变更，且仍是主机事实 | 不为避免 UUID 而改 |
| `/dev/nvme…` 等内核路径 | 官方明确偏好拓扑无关别名；设备枚举可变化 | 不采用 |
| 不提交硬件文件、机器本地 import | 输出不能由仓库独立 build/审计，且路径部署耦合 | 不采用 |
| 启动时探测或自定义 activation | 增加非声明式逻辑与启动风险 | 不采用 |

### 3.3 永久 SSH：最小安全模型与范围

- **官方事实：** NixOS 的 OpenSSH 服务及其认证、监听和防火墙选项均由 `services.openssh` 模块声明；26.05 中 `openFirewall` 默认为 `true`，启用服务时会自动把默认 SSH 端口加入全局 TCP allowlist。`PasswordAuthentication`、`KbdInteractiveAuthentication` 与 `PermitRootLogin` 是传给 sshd 的独立安全语义。[Nixpkgs 26.05 OpenSSH 模块源码](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/networking/ssh/sshd.nix)，[NixOS 26.05 选项：`services.openssh.openFirewall`](https://search.nixos.org/options?channel=26.05&show=services.openssh.openFirewall)。
- **推论：** `enable = true` 只管理 sshd；`openFirewall = true` 只在 NixOS firewall 中允许服务端口，二者不能互相替代。禁用 password 与 keyboard-interactive 分别关闭两条交互认证路径；`PermitRootLogin = "no"` 只禁止 root 经 SSH 登录。三项合起来仍不等于“只允许某人”，因此还要只给已确认普通用户声明 `openssh.authorizedKeys.keys`，并保持 key 私钥在仓库外。
- **本仓库建议：** 若维护者把临时 LAN key-only 通道升级为永久声明，最小集合是：启用 sshd、对普通用户声明现有公钥、`PasswordAuthentication = false`、`KbdInteractiveAuthentication = false`、`PermitRootLogin = "no"`。首轮使用模块自己的 `openFirewall = true` 默认值，不重复声明，也不添加接口规则。当前系统只有一个普通用户、且只声明这一把登录公钥，额外设置 `AllowUsers` 收益很小，却会在以后增加第二个经批准用户时形成隐藏限制，因此首轮不添加。

**不建议第一轮按接口限制。** NixOS firewall 确实支持按接口设置规则，[Nixpkgs 26.05 firewall 模块源码](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/networking/firewall.nix)；但这会把网卡名和网络拓扑引入一个当前并不需要的安全模型。对这个仅 LAN、单用户桌面，模块默认的服务级端口开放 + key-only + root 禁用已经满足需求。若未来出现公网暴露、多个网络接口或严格零信任需求，再用实时证据和单独 Issue 评估接口级规则。

### 3.4 Flakes 与安全的 rebuild 顺序

- **官方事实：** Flakes 仍是实验性功能；Nix 可通过 `nix.settings.experimental-features = [ "nix-command" "flakes" ]` 持久启用，或在单次命令以 `--experimental-features 'nix-command flakes'` 启用。[nix.dev：Flakes](https://nix.dev/concepts/flakes.html)，[Nix 2.34 参考手册：experimental-features](https://nix.dev/manual/nix/2.34/command-ref/conf-file.html#conf-experimental-features)。
- **官方事实：** `test` 会切换当前运行系统但不设为默认启动项，重启可回到之前工作状态；`boot` 更新下次启动的配置但不激活当前运行态；`switch` 同时更新启动默认项并尝试切换运行系统。`dry-activate` 只显示 `test` 会做的动作。[NixOS 手册：Changing the Configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config)，[NixOS 手册：What happens during a system switch?](https://nixos.org/manual/nixos/stable/#sec-what-happens-during-a-system-switch)。
- **本仓库建议：** 在 Phase 5 的系统声明中永久启用两项 feature，使锁定的 Flake 能被正常命令使用；不执行 `nix flake update`，不改变 `flake.lock`。目标机人工关卡顺序为：

  1. CI/维护者先 `nix flake check` 与 `nix build .#nixosConfigurations.nixbox.config.system.build.toplevel`；
  2. 目标机先可选 `sudo nixos-rebuild dry-activate --flake <repo>#nixbox`，审阅服务、mount 和 firewall 影响；
  3. 经当次明确批准，`sudo nixos-rebuild test --flake <repo>#nixbox`；验证登录、NetworkManager、GNOME/GDM、PipeWire、Bluetooth、CUPS、GPU、睡眠/唤醒、外设和 SSH；
  4. 记录 test 结果并确认可从 systemd-boot 选择当前已知好的 generation；
  5. 只有人工决定持久化时，另行选择 `boot`（下次启动验证）或 `switch`（立即且持久）。

发生问题时，`test` 直接重启回永久 generation；持久化后先在 systemd-boot 菜单选择已知好的 generation，再在可登录系统中按 NixOS 官方回滚说明恢复。不得把“build 成功”描述为 activation 已获授权。

### 3.5 Home Manager：遵守长期架构，但延后到 Phase 6

- **官方事实：** Home Manager 的 NixOS module 会随系统 rebuild 一同构建用户环境，并可用 `home-manager.useGlobalPkgs` / `useUserPackages` 与 `extraSpecialArgs` 集成。[Home Manager 官方手册：NixOS module](https://home-manager.dev/manual/unstable/nix-flakes/nixos.html)。
- **推论：** 这支持 ADR-0002 的长期选择（NixOS 上使用集成 HM），但不会要求第一次 NixOS 接入必须同时迁移用户文件、shell 或 profile。
- **本仓库建议：** **留到 Phase 6。** Issue #7 明确禁止重构共享 HM；目标机也还没有 HM。Phase 5 如同时引入，会把系统 adoption 的 boot/网络/桌面验证与 Bash、Fish、dotfiles、文件冲突和用户 profile activation 风险混在一起，失去可归因性。Phase 6 再以集成 module 接入，并先 build、人工检查文件所有权与 shell 行为。

### 3.6 当前桌面和 Nix 设置的“先保留”规则

- **官方事实：** `users.mutableUsers` 在 NixOS 26.05 中默认为 `true`；系统 activation 会把声明用户与现有账户合并，并保留现有用户密码，而不是因为 Nix 配置没有密码字段就清空或替换密码。[Nixpkgs 26.05 users-groups 模块源码](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/config/users-groups.nix)。
- **本仓库建议：** 首轮不声明任何 password、hash 或 password file，也不把 `/etc/shadow` 纳入备份或仓库；保留现有 `sayori` 本地登录和 sudo 密码。Phase 8 再讨论声明式机密，不把密码迁移塞进 Phase 5。

| 当前事实 | Phase 5 动作 | 理由 |
| --- | --- | --- |
| GNOME/GDM、PipeWire/WirePlumber、CUPS、Bluetooth、NetworkManager | 按实时 `/etc/nixos` 证据逐项复现；桌面共性才放 `modules/nixos/desktop.nix` | 已知可工作，重构会扩大登录/音频/网络风险 |
| systemd-boot、EFI variables、vfat `/boot`、ext4 `/`、无 swap | 原样保留在 host + hardware 模块 | 均是启动或硬件事实；路线图要求保留 |
| Intel i915、iwlwifi | 原样保留所在模块，不换驱动/内核栈 | 当前正常；Issue 禁止 GPU/网卡推测性重写 |
| Bash | 不接入 HM、不切 Fish/Zsh | 用户默认 shell 是已验证事实；共享 shell 属 Phase 6 |
| `allowUnfree` | 暂保留当前宽泛行为 | 收紧 predicate 可能令未盘点的软件消失；另开可验证 Issue |
| USTC substituter | 暂保留当前行为和现有 trusted-key 证据；不复用 Phase 1 过时快照 | 镜像可用性与信任键是供给链事实，不能猜或“顺手修复” |

上表的“原样复现”是仓库建议；其依据是 Issue #7、路线图和主机实时证据，不把当前设置包装为官方唯一推荐配置。NixOS 的模块系统允许以模块组合保留这些选项，[NixOS 手册：Configuration Syntax / Modularity](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax)，但具体启用值必须来自目标机原始文件而非本文臆测。

### 3.7 LocalSend：不纳入 Phase 5

- **官方事实：** Nixpkgs 26.05 包集合包含 LocalSend 的打包定义；这只说明可以由 Nix 安装，并不自动配置其网络发现或防火墙。[Nixpkgs 26.05 LocalSend 包源码](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/by-name/lo/localsend/package.nix)。
- **推论：** LocalSend 的系统级安装、用户级安装和 LAN 端口开放是三个不同决定；即使安装包可用，也不能据此假设它应获得系统 firewall 例外。
- **本仓库建议：** **不纳入 Phase 5。** 当前 SSH/scp 已覆盖 Mac 与 NixOS 之间的迁移文件传输。若后续仍需要手机或图形界面互传，在 Phase 6 接入 Home Manager 桌面层时再决定是否复用现有 `modules/home/desktop/` 声明，并同时审阅 NixOS 的 LAN 端口；不需要仅为“延后”机械创建新 Issue。按模块边界，它更接近后续 Linux desktop 用户层，而非 Phase 5 必需系统服务。

## 4. 候选方案比较

| 方案 | 内容 | 风险与人工关卡 | 结论 |
| --- | --- | --- | --- |
| A：原样最小接入（推荐） | host hardware + boot/filesystem + 现有系统/桌面行为；最小 Nix/用户/SSH；启用 flakes；无 HM、无 LocalSend | build 后人工 `test` 验证桌面与网络；持久 `boot`/`switch` 另批 | 最小变更，可将失败归因于接入 |
| B：A + Home Manager 首次迁移 | 同时接入共享 common/Linux/desktop 用户层、改 shell/链接 dotfiles | 额外 profile、文件冲突、PATH、shell 与可写状态风险；难区分系统或用户层失败 | 不符合 #7 禁止项，Phase 6 再做 |
| C：A + 强化网络/安全/LocalSend | Tailscale、接口级 SSH firewall、复杂 hardening、LocalSend 及端口 | 需要更多网络事实、恢复验证与独立威胁模型；可能破坏 LAN/登录 | 过度设计，拒绝 |
| D：重新设计工作站 | 新分区/加密/swap、desktop/GPU/Wi-Fi/boot 重做 | 高启动、数据和可用性风险；完全偏离 adoption | 明确不做 |

## 5. 过度设计清单

以下均不是“更安全的默认补丁”，而是需要独立动机、证据和批准的架构或行为变更：

- Tailscale：当前批准边界是 LAN 临时 SSH，且无公网暴露需求；引入新的身份、网络与运维面。
- 接口级 SSH firewall：技术上可行，但当前未保存可靠接口名；服务级 firewall 加 key-only 已满足当前边界。
- fail2ban、端口改写、`AllowUsers`、额外算法策略、自动更新：当前都没有对应需求；各自还有维护和恢复语义，不能和首次 adoption 混合。
- 重做 boot、磁盘、swap、加密、桌面、GPU、Wi-Fi、音频或替换 USTC 镜像：这些会改变已验证事实，且 Issue #7 禁止或未授权。
- flake-parts、Clan、deploy-rs、Colmena、impermanence、ZFS/LUKS：与 ADR-0001 和路线图的延后决策冲突。

## 6. 落地前的人工关卡、回滚与未决项

1. **公开性关卡：** 维护者确认两个 filesystem UUID 可作为必要硬件事实提交；若不同意，Phase 5 不能宣称仓库具备完整可重建的主机输出，需先决定私有仓库/替代托管边界。
2. **SSH 关卡：** 维护者明确决定是否将临时 SSH 变为永久声明；若批准，首轮采用 OpenSSH 模块默认的服务级 firewall 行为，不增加接口规则。
3. **构建关卡：** 先离线/CI build；build 不授权 activation。
4. **真实机器关卡：** 维护者执行一次 `test` 并记录完整桌面、网络、SSH、generation 回滚证据；test 失败则重启回永久 generation，不做临场架构改造。
5. **持久化关卡：** 只有 test 通过且维护者明确批准时，才选择 `boot` 或 `switch`。systemd-boot 中已知好的 generation 与安装介质救援是最后恢复路径。

仍不确定但不会由 Agent 猜测的项目：原始 `/etc/nixos/configuration.nix` 中每个当前启用项应归入 host、base 还是 desktop 的逐行映射；两个 UUID 的公开策略；永久 SSH 是否接管；LocalSend 的真实长期需求和端口。USTC substituter 首轮只原样保留实时配置，并由实际 build 验证可用性，不在 Phase 5 对其做供应链重设计。

## 7. 一手来源清单

本调研的结论只采用以下一手资料（9 组来源，均在正文对应判断处链接）：

1. [NixOS 官方手册：Changing the Configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config)
2. [NixOS 官方手册：File Systems](https://nixos.org/manual/nixos/stable/#sec-file-systems)
3. [NixOS 官方手册：What happens during a system switch?](https://nixos.org/manual/nixos/stable/#sec-what-happens-during-a-system-switch)
4. [Nix 官方文档：Flakes](https://nix.dev/concepts/flakes.html)
5. [Nix 2.34 参考手册：experimental-features](https://nix.dev/manual/nix/2.34/command-ref/conf-file.html#conf-experimental-features)
6. [Home Manager 官方手册：NixOS module](https://home-manager.dev/manual/unstable/nix-flakes/nixos.html)
7. [Nixpkgs 26.05：OpenSSH NixOS module](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/networking/ssh/sshd.nix) 与 [firewall module](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/networking/firewall.nix)
8. [Nixpkgs 26.05：LocalSend package](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/by-name/lo/localsend/package.nix)
9. [Nixpkgs 26.05：users-groups module](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/config/users-groups.nix)
