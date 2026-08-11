# macOS 中文输入维护边界与拆分研究

- **状态：** 研究结论已采纳，Issue #140 实施中；不构成真实机器操作授权
- **关联 Issue：** [#139](https://github.com/sayoriqwq/nix-config/issues/139)
- **日期：** 2026-08-11
- **范围：** Fcitx5 macOS、Rime、rime-ice、nixpkgs、Home Manager 的所有权与模块边界

## 1. 结论先行

**结论：当前实现确实过度复杂，但原因不是单纯的“上游没有 Nix package”。**

- `nixpkgs` 已提供 `rime-ice`，而且它正是一个无编译步骤的 Rime 静态数据包；本仓库继续自己固定上游 source、枚举 65 个 leaf、维护 release/revision/hash 三重合同，已经重复承担了一部分 nixpkgs 的 package 职责。
- `nixpkgs` 的 `fcitx5-rime` 明确只支持 Linux；Home Manager 的 `i18n.inputMethod.fcitx5` 也明确只允许 Linux，并创建 Linux session variables、GTK glue 和 `systemd.user` service。它们不能安装或声明 macOS 的 `Fcitx5.app`、plugin payload 或输入源注册。
- Fcitx5 macOS 官方把主程序与插件交给自身 installer/updater，把配置和 Rime 用户目录视为运行时可写状态。上游提供 GUI、数据导入导出与本地命令接口，但没有提供 nix-darwin/Home Manager 的字段级声明模块。
- 因而，当前约 2,794 行 capability/test 代码中的两类复杂度性质不同：
  - **可交给 nixpkgs package：** rime-ice 的获取、过滤、版本更新和静态 package 输出；
  - **本仓主动选择：** 三个 Fcitx 字段的 activation-time reconcile、事务 journal、CAS rollback、故障 fixture 和逐字段长期审计。

**建议：采用“静态声明与运行态偏好拆开”的窄 capability。**

1. `nix-config` 只拥有 `rime-ice package + 一个排除 build 并合并本地 default.custom.yaml 的薄 data view + Home Manager leaf projection + 最小结构安全检查`；
2. `Fcitx5.app`、Rime plugin、macOS input source、Fcitx 配置文件和三个行为偏好交回官方 app/updater/GUI；
3. 删除 activation-time behavior reconciler、journal/CAS rollback 和大部分行为 fixture；
4. 保留只验证 Nix 自己所有内容的 package/overlay check，以及不覆盖 userdb、sync、build 和 Fcitx 可写根的边界测试；
5. 暂不新建独立 Git 仓库。只有 overlay 形成独立版本节奏、被多个 Rime frontend/host 复用，或需要独立发布时，再把静态 Rime 配置提升为 leaf Flake repo。

这仍然是声明式配置：Nix 声明并拥有自己能够稳定拥有的**静态输入方案**；它不再把外部应用的可写偏好伪装成 Nix 原生声明。

## 2. 研究口径

本文用以下标记区分结论性质：

- **事实：** 由上游文档、源码或当前锁定源码直接证明；
- **推断：** 从事实推导出的维护边界，不冒充上游承诺；
- **建议：** 面向本仓库的设计选择，需另开实施 Issue 才能执行。

本文没有读取 userdb、sync 或 `~/Library/Rime` 内容，没有 activation、restart、deploy 或修改 input source。

## 3. 周边生态事实

### 3.1 nixpkgs 已经提供 `rime-ice` 静态数据包

**事实：** 当前 macbook 锁定的 nixpkgs revision `104240a772428cc2e20d8fd86c9ddbb886bbaff2` 中，`pkgs.rime-ice` 版本为 `2026.06.30`。它使用 `stdenvNoCC`，删除 `others`、README 和 Git 元数据，将上游 `default.yaml` 重命名为 `rime_ice_suggestion.yaml`，再把剩余内容安装到 `$out/share/rime-data`。package 没有限定 `meta.platforms`，当前 macbook package set 将它判断为 aarch64-darwin available，因此静态数据输出可在 Darwin 消费。[nixpkgs `rime-ice` package](https://github.com/NixOS/nixpkgs/blob/104240a772428cc2e20d8fd86c9ddbb886bbaff2/pkgs/by-name/ri/rime-ice/package.nix)

**事实：** 该重命名不是无意义处理。nixpkgs package 明确要求消费者在自己的 `default.custom.yaml` 中通过 `__include: rime_ice_suggestion:/` 选择上游建议默认值。这把“上游数据包”与“用户选择/overlay”分开了。[同一 package 的 `longDescription`](https://github.com/NixOS/nixpkgs/blob/104240a772428cc2e20d8fd86c9ddbb886bbaff2/pkgs/by-name/ri/rime-ice/package.nix#L34-L49)

**事实：** 当前 `2026.06.30` 上游树包含空的 `build/.gitkeep`；nixpkgs package 只删除根层的 `others`、README 和 `.git*` 后执行 `cp -r .`，因此该占位 leaf 会进入 `$out/share/rime-data/build/.gitkeep`。[rime-ice `build/.gitkeep`](https://github.com/iDvel/rime-ice/blob/2026.06.30/build/.gitkeep)，[nixpkgs install phase](https://github.com/NixOS/nixpkgs/blob/104240a772428cc2e20d8fd86c9ddbb886bbaff2/pkgs/by-name/ri/rime-ice/package.nix#L19-L30)

**推断：** `pkgs.rime-ice` 应作为 packaging source，而不是原样成为最终 Home Manager source。nix-config 仍需一个很薄的 data-view derivation：从 package output 复制静态数据、删除整个 `build` 子树、在 package 尚未提供 `default.custom.yaml` 时加入本地 overlay，并对该名称冲突失败关闭。这个 adapter 只吸收 package 与 Rime 可写目录之间的布局差异，不重新枚举或验证上游 65 个 leaf。

**建议：** 同时向 nixpkgs 提交一个窄修复，让 `rime-ice` package 不再安装 `build/.gitkeep`。在该修复进入本仓锁定 revision 前，本地薄 data view 是必要兼容层；进入后仍保留 overlay 冲突检查，但不应继续维护已经由 package 吸收的过滤逻辑。

**推断：** 本仓库当前 non-Flake input、65-leaf allowlist、release/revision/narHash 常量和逐 leaf 类型断言，承担的是一个本地 `rime-ice` packaging policy。它曾为首次从遗留 regular files 交接到 Nix 提供强证据，但不是长期消费 `pkgs.rime-ice` 的必要组成。

**注意：** 切换到 nixpkgs package 会从当前固定的 rime-ice `2025.04.06` 升到当前 nixpkgs 的 `2026.06.30`，且 package 重命名了 `default.yaml`。这不是可顺带进行的机械重构；实施 Issue 必须把 package 迁移、行为差异和一次 Rime deploy 当作显式升级审阅。

### 3.2 `fcitx5-rime` 的 Nix package 是 Linux plugin，不是 macOS app

**事实：** nixpkgs 的 `fcitx5-rime` 会编译 Fcitx addon，并通过 `rimeDataPkgs` 把一个或多个 Rime 数据包合并到自己的 `$out/share/rime-data`；默认数据包是 `rime-data`。但 package 的 `meta.platforms = lib.platforms.linux`。[nixpkgs `fcitx5-rime`](https://github.com/NixOS/nixpkgs/blob/104240a772428cc2e20d8fd86c9ddbb886bbaff2/pkgs/by-name/fc/fcitx5-rime/package.nix) 它依赖的 nixpkgs Fcitx5 core package 同样以 Linux 为平台边界，不是 `Fcitx5.app` 的 Darwin package。[nixpkgs `fcitx5`](https://github.com/NixOS/nixpkgs/blob/104240a772428cc2e20d8fd86c9ddbb886bbaff2/pkgs/by-name/fc/fcitx5/package.nix)

**事实：** NixOS 的 Fcitx5 module 也把 `rimeDataPkgs` 的旧独立选项标为已迁移到 `fcitx5-rime.override { rimeDataPkgs = ...; }`。这证明 nixpkgs 已有“引擎 package 组合数据 package”的 Linux 输出模型，而不是 macOS bundle 输出模型。[NixOS Fcitx5 module](https://github.com/NixOS/nixpkgs/blob/104240a772428cc2e20d8fd86c9ddbb886bbaff2/nixos/modules/i18n/input-method/fcitx5.nix#L90-L101)

**推断：** 在 macOS 上不能通过 `fcitx5-rime.override { rimeDataPkgs = [ pkgs.rime-ice ]; }` 替换官方 Fcitx5 Rime plugin。这条漂亮的声明式组合只属于 Linux build graph；强行移植意味着本仓库开始维护 Fcitx5 macOS bundle/package，责任会比现在更大。

### 3.3 Home Manager 的 Fcitx5 module 明确不适用于 Darwin

**事实：** macbook 使用的 `home-manager-darwin` input 锁定在 revision `a7c70cc290290f373f50cd820403833d250459ac`；它对整个 `i18n.inputMethod` 使用 `assertPlatform ... lib.platforms.linux`。[Home Manager input-method platform assertion](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/i18n/input-method/default.nix#L120-L123)

**事实：** `i18n.inputMethod.fcitx5` 的实现会构造 `fcitx5-with-addons` package、设置 GTK/Qt/XMODIFIERS 等 Linux session 环境，并创建 `systemd.user.services.fcitx5-daemon`。它提供 `settings.globalOptions`、`settings.inputMethod`、`settings.addons`，并将生成结果作为 `xdg.configFile.fcitx5` 目录链接。[Home Manager Fcitx5 module](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/i18n/input-method/fcitx5.nix)

**事实：** Home Manager 普通 file option 在 source 是目录时，`recursive = false` 会把目标根直接链接到 source；`recursive = true` 才会创建相同目录树并仅把 leaves 链到 Store。这是把静态 package 投影到含有额外可写状态的 Rime 用户目录时可复用的通用能力。[Home Manager file type](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/lib/file-type.nix#L88-L119)

**事实：** recursive source 与单独 regular file 声明重叠时，当前 Home Manager 的 `home.fileOverlapResolution` 默认是 `ignore`；实现会保留 recursive source 中已有的 leaf，而不是为本地 overlay 自动失败。[Home Manager overlap option](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/files.nix#L68-L80)，[冲突处理实现](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/files.nix#L514-L528)

**推断：** 本仓库不应启用 Home Manager Fcitx5 module，也不应复制它的 Linux service/config ownership 到 Darwin；但可以把上述**已过滤并合并 overlay 的单一 data view**交给 `xdg.dataFile.<name>.recursive = true`，从而删除手写的 65 个 leaf 列表，同时保持 Rime 用户目录根节点为真实可写目录。不能把 raw package source 与 overlay 作为两个默认冲突策略下的声明叠加，否则未来 package 新增同名文件时可能静默遮蔽本地 overlay。

### 3.4 rime-ice 与 Rime 的官方定制/更新模型

**事实：** rime-ice 官方普通安装流程是把发布内容复制到 Rime 用户目录后重新部署；更新/还原重复该流程。技术用户可使用 Plum，并为非默认 frontend 显式指定 `rime_dir`。[rime-ice README 安装段](https://github.com/iDvel/rime-ice#安装)

**事实：** Rime 官方建议不要直接修改发行版配置，而使用同名 `.custom.yaml` 的 `patch` 保存用户定制；这样升级发行版时不需要合并整份 fork。[Rime customization guide](https://github.com/rime/home/wiki/CustomizationGuide)

**事实：** Fcitx5 macOS 官方说明 Rime 用户目录是 `~/.local/share/fcitx5/rime`，共享目录是 `~/Library/fcitx5/share/rime-data`，并明确不应修改 `~/Library/fcitx5`。方案通过用户目录中的 schema/dict 和 `default.custom.yaml` 启用。[Fcitx5 macOS Rime 文档](https://fcitx-contrib.github.io/docs/im/rime.html#目录)

**事实：** 同一文档警告不得让 Fcitx5 Rime 用户目录与 Squirrel 的 `~/Library/Rime` 相互 symlink，因为 LevelDB 不支持这种并发共享，可能损坏用户词库。[Fcitx5 macOS Rime 目录警告](https://fcitx-contrib.github.io/docs/im/rime.html#目录)

**推断：** 最自然的声明 seam 是“上游静态 data package + 很小的本地 `.custom.yaml` overlay”。这与 Rime 自己的定制模型一致；把 65 个上游文件逐个提升为本仓库 domain contract 反而降低 locality——上游加删一个实现文件会迫使本仓合同、测试和文档同步变化。

### 3.5 Fcitx5 macOS 的 app、updater、配置与控制面

**事实：** 官方安装文档要求从 Fcitx5 macOS GitHub release 获取适用安装包；对 Rime 用户，方案导入到用户目录。官方 FAQ 说明“关于 Fcitx5 macOS”会同时更新主程序和所有插件，插件管理器可单独更新插件。[Fcitx5 macOS 简介](https://fcitx-contrib.github.io/docs/)，[FAQ 更新段](https://fcitx-contrib.github.io/docs/faq.html#如何更新)

**事实：** 官方 GUI 把状态栏、应用默认输入法、Vim mode、剪贴板等视为 macOS frontend 设置。默认进入 Terminal 时切换英文就是上游提供的应用默认输入法行为，不是 Rime scheme 内容。[macOS frontend 文档](https://fcitx-contrib.github.io/docs/advanced/macosfrontend.html)

**事实：** Fcitx 的配置写入使用临时文件、`fsync` 和 rename 的 `safeSaveAsIni`；周期 autosave 会保存 profile 并调用 addon 的 `save()`，macOS frontend 也会保存自己的配置。[Fcitx `standardpaths.cpp`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx-utils/standardpaths.cpp#L291-L324)，[Fcitx `iniparser.cpp`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx-config/iniparser.cpp#L184-L203)，[Fcitx autosave](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/instance.cpp#L1958-L1973)，[macOS frontend `save()`](https://github.com/fcitx/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/macosfrontend/macosfrontend.h#L78-L114)

**事实：** Fcitx5 macOS 提供基于 Beast 的本地交互服务，官方推荐更安全的 Unix socket，默认路径 `/tmp/fcitx5.sock`；官方文档公开支持 Rime deploy/sync 和输入状态切换，Rime deploy 也有 `fcitx5-curl` 命令。[Beast 文档](https://fcitx-contrib.github.io/docs/advanced/beast.html)，[Rime CLI](https://fcitx-contrib.github.io/docs/im/rime.html#命令行接口)

**推断：** 本地 API 是有效的运维/control-plane seam，但官方并没有把它包装成一个具有版本化 schema、generation rollback 和 nix-darwin module 语义的 declarative configuration provider。当前 adapter/journal/CAS 是本仓库在这个 imperative control plane 上自行建立的事务系统，而不是上游 package 缺失后必然产生的实现。

## 4. 当前复杂度从哪里来

当前 production capability 与四个直接测试面合计约 2,794 行：

| 层 | 当前责任 | 性质 |
| --- | --- | --- |
| `contract.nix` + `default.nix` | pin 上游、枚举 65 leaf、过滤危险路径、部署 overlay、登记状态 | 一半是 package 消费，一半重复 packaging/audit |
| config adapter | 探测 bundle CLI/socket，限制 endpoint 和 POST payload | 本仓自建 Darwin runtime adapter |
| behavior reconciler | desired/keep、锁、原子 journal、事务状态、CAS rollback | 本仓自建事务配置系统 |
| policy/preflight | 同时证明 package、host scope、live app/plugin、行为、安全设置、mutable metadata | 把 declaration test 与运行态审计混在一起 |
| fault fixtures | 模拟 partial write、并发值、旧 journal、rollback failure | 为本仓事务系统服务，而非 Rime package 所需 |

**推断：** 这套 capability 对 host 暴露的 interface 很小，但并不是一个健康的 deep module：

- **Depth：** 隐藏了大量复杂度，但复杂度主要用于维护自身事务机制，并没有为多个消费者提供相称的 domain leverage；
- **Seam：** “静态 Rime data”是稳定 seam，“外部 Fcitx 三字段的 activation-time CAS transaction”则把 Nix generation 和 app mutable state 两套生命周期绑在一起；
- **Locality：** 修改一个输入偏好会同时波及 contract、adapter、reconciler、journal schema、fixture、preflight、rollback 和恢复文档；相关知识没有集中在变更点附近；
- **Information hiding：** 65-leaf manifest 暴露 rime-ice 源树的内部文件拓扑，导致 nixpkgs package 本应吸收的变化传播到本仓。

**结论：** 复杂度不是因为“声明式一定复杂”，而是 capability 同时承担了 package maintainer、Home Manager file projector、Fcitx 配置 provider、事务恢复器和合规审计器五种角色。

## 5. 四种可选架构

### 方案 A：保留当前深度 capability

**所有权：** nix-config 继续拥有 65+1 静态 leaf、三个 Desired、两个 Keep、journal/CAS/rollback 和完整 preflight。

**优点：** activation 自动修复 Fcitx 漂移；故障与回滚语义最强；现状已经过实机验证。

**缺点：** 继续重复 package 职责；任何 app/API/schema 变化都由本仓适配；Nix rollback 与外部 mutable state 仍非同一事务，只能靠 journal 模拟；测试维护面最大。

**适用条件：** 三个 Fcitx 行为是必须自动强制的机器策略，且维护者愿意长期把 app API 兼容性当作 nix-config 的核心产品责任。

### 方案 B：nix-config 只消费 package + 管理小型 overlay（推荐）

**所有权：** nixpkgs 拥有 rime-ice packaging；nix-config 选择 package 版本，构造一个只排除 `build`、拒绝 overlay 冲突并合入 `default.custom.yaml` 的薄 data view，再用 Home Manager recursive leaf projection 放入 Fcitx Rime 用户目录。Fcitx app、plugin、输入源和偏好均外部管理。

**最小 interface：** host 仍只 import `macos-chinese-input`；内部只表达 `rimeDataPackage`、filtered/merged data view、target root 和 state boundaries，不暴露 65 个文件或通用 key/value adapter。

**优点：** 真正声明式地拥有静态内容；上游增加 leaf 不再扩大本仓 diff；删除大部分 runtime transaction 代码；变更集中在 package version 与 overlay。

**缺点：** Fcitx 三项偏好漂移时不会自动修复；rime-ice 更新默认跟随 Darwin nixpkgs lock 更新，需要在 update policy 中显式审阅；切换 package 输出模型需要一次受监督迁移和 deploy。

**风险控制：** 保留 root-not-symlink、mutable path non-Store、package output shape、`build` 排除、overlay 冲突失败关闭/内容校验和真实输入 smoke test；不再验证未拥有的每个 Fcitx preference。

### 方案 C：独立 `rime-config` leaf repo

**所有权：** 独立 repo pin/消费 rime-ice，维护 local overlays，并导出一个静态 Rime data package/Flake output；nix-config 只锁定并投影该 output。Fcitx 仍外部管理。

**优点：** Rime 配置具有独立版本、发布和测试节奏；可以同时供 Fcitx5 macOS、Squirrel、Linux Fcitx5 等多个 frontend 消费；nix-config 的 locality 最好。

**缺点：** 多一个 repo、lock 更新和兼容合同；如果当前只有 3 行 overlay 和一个 macbook 消费者，repo interface 比内部内容更重；还必须防止误把 userdb/sync 当作跨 frontend 共享配置。

**启用门槛：** 满足至少一项再拆：

1. overlay/自定义词典成长为独立配置产品；
2. 两个以上 host/frontend 复用同一静态配置；
3. rime-ice 需要独立于 nixpkgs 的更新/回滚节奏；
4. 需要独立发布、CI 或上游贡献工作流。

#### 最大灵活性 interface（Design It Twice）

这个方案不应暴露 repo 内文件拓扑，而应定义一个很小的发布 interface：

```nix
{
  packages.aarch64-darwin.default = <immutable Rime data tree>;
  packages.x86_64-linux.default = <same logical Rime data tree>;
  checks.<system>.rime-config = <static schema/overlay/collision checks>;
}
```

**Interface：** 消费者只得到一个 package，其稳定 output contract 是
`$out/share/rime-data`。nix-config adapter 只接受这个 package 和一个 target root，用 Home Manager
recursive leaf projection 安装；host 不知道上游 repo、release、leaf 数量或 overlay 文件名。

**Invariants：**

- output 只含可发布的静态 Rime data；
- 不含 `build`、`sync`、`*.userdb`、`installation.yaml`、`user.yaml` 或 frontend 运行态；
- package build 不读 `$HOME`，不访问 live Rime/Fcitx，不执行 deploy；
- package 的 `default.custom.yaml`/include 必须能启用目标 schema；
- 不同时承诺 Fcitx、Squirrel 的可写目录布局，只承诺 Rime data tree。

**Error modes：**

- 上游 package layout 改变或 include 目标缺失：leaf repo check 失败，不发布新 revision；
- 静态 output 出现 forbidden mutable basename：build/check 失败；
- nix-config target 已有同名 unmanaged regular file：Home Manager activation fail closed，进入人工 handoff；
- frontend plugin 不兼容新 scheme：build 不能证明，必须在 consumer 的 deploy/smoke gate 发现；
- input lock 更新但 consumer 未更新：继续运行旧 closure，不会隐式漂移。

**Usage：** nix-config 将 leaf repo 作为普通 locked Flake input，只消费
`packages.${system}.default`，不 follow 它的内部 nixpkgs、不调用其 helper、不读取其 source tree。
macOS adapter 负责 Home Manager target projection 与人工 deploy gate；未来 Linux consumer 可把同一
package 传给 `fcitx5-rime.override { rimeDataPkgs = [ ... ]; }`。两个 adapter 各自负责 frontend seam，
leaf repo 不假装统一它们。

**隐藏的 implementation：** leaf repo 内可以选择直接复用 `pkgs.rime-ice`、pin 上游 release、应用
overlay 或生成派生配置；这些决定不得泄漏成 consumer 的 65-leaf allowlist。consumer 只审阅 package
revision 和公开 output contract。

**依赖 adapter：**

- macOS：nix-config 的 Home Manager recursive leaf adapter + external Fcitx app/updater；
- Linux：nixpkgs `fcitx5-rime` 的 `rimeDataPkgs` adapter；
- Squirrel：若未来需要，建立独立 consumer adapter，绝不复用 Fcitx 用户数据库目录。

**取舍：** 这是四案中 locality 与跨 frontend 灵活性最高的设计，也是 source/lock/CI/release 成本最高
的设计。它在第二个真实 consumer 出现时会成为 deep module；在只有一个 macbook 和 3 行 overlay
时则只是把一个浅模块搬到另一个 repo。

### 方案 D：全部外部管理，nix-config 仅 reference / preflight-only

**所有权：** Fcitx updater、Rime 导入/Plum 和 GUI 管理全部内容；nix-config 只记录安装来源、数据边界与恢复说明，最多提供只读诊断。

**优点：** 仓库最简单；完全跟随官方工作流；不会因 Store links 与 app 写回冲突。

**缺点：** rime-ice 版本与 overlay 不再由 Flake 锁定；新机恢复依赖人工步骤；“当前输入方案是什么”无法由 build 证明。

**适用条件：** 维护者更重视官方 GUI 的可变性，且愿意接受 Rime 静态方案也不属于机器 declaration。

### 5.1 depth / locality / seam 对比

| 方案 | Depth | Locality | Seam 质量 | 长期维护判断 |
| --- | --- | --- | --- | --- |
| A 当前深度方案 | host interface 小，但内部复杂度主要服务自身事务 | 低；一个偏好跨多层变化 | static/runtime/generation 三种生命周期耦合 | 只有行为必须自动强制时合理 |
| B package + overlay | 小 interface 隐藏上游 package 拓扑，复杂度与收益相称 | 高；版本在 package，偏好在 app | static data 与 mutable app state 分离 | 当前单 host 的最佳平衡 |
| C leaf repo + adapter | 有多 consumer 时最深；单 consumer 时偏浅 | 最高；Rime 产品知识独立集中 | package contract 与 frontend adapter 明确 | 达到启用门槛后最佳 |
| D external/reference | nix-config 几乎无 module | app 内 locality 高，Git 中低 | 完全遵循官方 runtime seam | 最省维护但复现性最低 |

## 6. 推荐所有权模型

| 对象 | 推荐 owner | nix-config 做什么 | nix-config 不做什么 |
| --- | --- | --- | --- |
| `Fcitx5.app` 主程序 | Fcitx5 官方 installer/updater | 记录来源与人工恢复入口 | 不自建 Darwin package，不自动升级 |
| Rime plugin/shared payload | Fcitx5 plugin manager/updater | 记录外部依赖 | 不用 Linux `fcitx5-rime` 替代 |
| macOS input source registration | macOS + Fcitx installer | 记录人工验收项 | 不自动增删 input source |
| rime-ice 静态发行内容 | nixpkgs `pkgs.rime-ice` | 锁定 nixpkgs revision并把 package output 作为 data-view 输入 | 不枚举上游内部 leaf |
| 本地 `default.custom.yaml` | nix-config | 在过滤后的单一 data view 中合入小型、可审阅 overlay；同名冲突失败关闭 | 不 fork 完整 `default.yaml` |
| Rime 用户目录根 | Rime/Fcitx | 从不含 `build` 的单一 data view 做 recursive leaf projection | 不把根或可写子树链接到 Store |
| build/userdb/sync/install/user state | Rime | 只记录 owner/backup boundary | 不读取、hash、复制、覆盖 |
| Fcitx `~/.config/fcitx5` | Fcitx | 只记录状态边界和恢复说明 | 不整文件模板、不 raw patch |
| ShareInputState/AppDefaultIM/StatusBar/Shift/InputState | 用户通过 Fcitx GUI | 在 runbook 记录期望体验和复核步骤 | 不在 activation 自动 POST，不做 generation journal |

**建议：** 把“期望体验”与“受 Nix 所有的 declaration”分开命名。前者可以作为维护者 reference/checklist，但只有后者进入 build/policy 的强制合同。这样不会把“我希望 GUI 当前是 Hidden”误表述为“Flake 能完整重建这个 app-owned 状态”。

## 7. 可以删除与必须保留的边界

### 7.1 采用方案 B 后可退役

- 独立 non-Flake `rime-ice` input，以及 contract 中的 owner/repo/release/revision/narHash 重复常量；
- 65 个 `managedPaths` 清单、`expectedManagedPathCount`、逐 leaf regular-file/type/path 断言；
- `fcitx5-config-adapter.nix`；
- `fcitx5-behavior-reconciler.nix`；
- activation-time `reconcileFcitx5Behavior`；
- behavior journal state path、journal schema、archive、锁和 CAS rollback helper；
- partial write、旧 journal、并发第三值、rollback-incomplete 等事务 fixture；
- 针对全部外部 Fcitx 行为/安全偏好的 production audit；
- 文档中把三个字段描述为 Nix-owned Desired 的内容。

这些删除不是降低 Rime 数据安全，而是删除一个不再拥有外部行为后失去存在理由的本地事务系统。

### 7.2 最小安全边界必须保留

- package output 必须来自锁定的 Flake/nixpkgs revision；更新时审阅 rime-ice version 和 output layout；
- raw package output 先形成薄 data view：排除整个 `build` 子树，并拒绝任何 `sync`、`*.userdb`、`installation.yaml`、`user.yaml` 等可变名称；
- local overlay 由仓库拥有，在同一 data view 中合入；package 出现同名 leaf 时失败关闭，不能依赖 Home Manager 默认的 overlap `ignore`；
- 单一 data view 使用 recursive leaf semantics 投影，`~/.local/share/fcitx5/rime` 根节点和可写子树不得成为 Store symlink；
- mutable/user data 不进 Git、不读正文、不 resolve 到 Store；
- `~/Library/fcitx5` 与 `~/Library/Rime` 保持外部且不与 Fcitx Rime 用户目录互链；
- package/overlay 变化后，activation、Rime deploy 与真实输入验收继续是独立人工关卡；
- 新机首次接管既有 regular files 仍需独立迁移 Issue，不能把 `force = true` 当作通用更新策略。

### 7.3 最小测试面

推荐将测试收敛为三个层次：

1. **evaluation check：** macbook 只选择一次 capability；package 是 `pkgs.rime-ice`；overlay 是预期内容；无 package/service/network 副作用；
2. **file-layout fixture：** raw package 的 `build/.gitkeep` 不进入 data view；package/overlay 同名时失败；recursive projection 不链接用户目录根或 `build`；静态 leaves 可读；其他 mutable 名称无 collision；
3. **人工 smoke test：** package升级或 overlay 变化后，受监督 deploy，并在飞书、浏览器、Terminal、原生应用验证中文输入和左右 Shift。

不再为 external GUI preference 建 fault-injection transaction suite。若未来某字段重新成为必须自动强制的策略，应为它单独证明稳定 API/provider seam，而不是恢复通用 adapter。

## 8. 推荐迁移顺序

本研究不授权下列动作。维护者接受方向后，应另建一个窄实施 Issue，并按顺序执行：

1. **冻结现状证据：** 记录当前 package version、overlay、generation 和人工体验；不读取用户数据正文。
2. **先做 build-only prototype：** 在隔离 fixture 中验证 `pkgs.rime-ice/share/rime-data` 的 output、过滤 `build/.gitkeep`、overlay 同名失败、`rime_ice_suggestion.yaml` include 语义、单一 data view 的 recursive projection 与 mutable collision；不连接 live target。
3. **明确升级决策：** 单独审阅 `2025.04.06 → 当前 nixpkgs 版本` 的 rime-ice release 差异。若不接受升级，先停止，不用本地 override 偷偷维持第二套 package。
4. **替换静态 source ownership：** 从 65-leaf input 改为 nixpkgs package + filtered/merged data view；build macbook system，不 activation。
5. **删除行为 ownership：** 同一窄 Issue 或后续独立 Issue 中删除 adapter/reconciler/journal/fixtures，并同步把三项 Desired 降为 external reference。为降低故障面，推荐拆成两个可独立 review 的 commit，但保持一个明确迁移 Issue。
6. **受监督 activation：** 只在 exact commit/current-window 获批后执行；验证用户目录根、mutable paths 和 Fcitx app 仍可写/可用。
7. **人工 deploy 与 smoke test：** package/overlay 内容变化才需要 deploy；deploy 与 activation 分开批准。完成飞书、Terminal、浏览器、原生应用和左右 Shift 测试。
8. **观察窗口后清理：** 确认无需旧 journal rollback 后，另行决定仓库外 journal evidence 的归档/删除；不自动清理 userdb、sync 或 Squirrel。

## 9. 回答维护者的三个核心问题

### “是不是因为上游没有 Nix package？”

不是。rime-ice 已有合适的 nixpkgs 静态数据 package；缺的是 **Fcitx5 macOS app/plugin 与可写偏好的 Nix provider**。前者让 65-leaf packaging 可以简化，后者决定了三字段自动声明若保留，就必须继续维护本地 runtime adapter。

### “我们是否做成了完整 build？”

对 rime-ice 而言，基本是：本仓自己获取 source、定义精确文件输出、过滤状态路径、验证 source tree，并把这些策略锁进大量测试。nixpkgs 现在已经提供这一 package boundary，本仓没有必要继续重复。

对 Fcitx 行为而言，更像是自建了一个小型 configuration provider/transaction manager，而不是 build。它解决了真实 bug，但其长期治理强度高于“个人机器上三个 GUI 偏好”的当前需求。

### “拆开是否合理？”

合理，但推荐先做**责任拆分**，不是立即做**Git 仓库拆分**：

- 静态 Rime 配置：Nix-owned、可 build、可锁定；
- Fcitx app 与偏好：updater/GUI-owned、可恢复但不由 activation 强制；
- 用户数据：Rime-owned、独立备份；
- 独立 rime-config repo：等到出现第二消费者或独立发布节奏再建立。

这会得到一个更深、更小且更诚实的 module：它只声明自己真正能够重建的静态能力，把外部应用状态留在外部生命周期内。

## 10. 已采纳决策与后续实施

维护者已在 [#139 的决策评论](https://github.com/sayoriqwq/nix-config/issues/139#issuecomment-5251189601)
中接受以下方向：

1. 采用方案 B：nix-config 只拥有 rime-ice package、薄 data view、本地 overlay、
   recursive leaf projection 与最小 mutable collision 边界；
2. 接受从 pinned `2025.04.06` 显式升级到实施时已锁定的 nixpkgs `pkgs.rime-ice`；
3. Fcitx5 app、plugin、input source 与全部 GUI/runtime preference 回归外部所有；
4. 不保留 activation-time behavior reconcile、事务 journal、CAS rollback 或阻塞 activation 的
   runtime audit；
5. 当前不建立独立 rime-config repo，只有达到本文列出的多 consumer 或独立发布门槛时再复审。

实施范围已由独立 [Issue #140](https://github.com/sayoriqwq/nix-config/issues/140) 固定，并已
进入独立分支实施。研究结论被采用不表示新声明已经 activation；真实 activation、Fcitx restart、
Rime deploy 与 input source 操作仍需绑定 exact commit/current window 的新人工批准。
