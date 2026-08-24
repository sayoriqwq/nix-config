# ADR-0006：Zed 按平台选择 Preview 与 Stable

- **状态：** 已接受
- **日期：** 2026-07-24
- **决策范围：** 桌面编辑器、软件包所有权、二进制供应链与更新流程
- **关联 Issue：** [#25](https://github.com/sayoriqwq/nix-config/issues/25)、[#215](https://github.com/sayoriqwq/nix-config/issues/215)、[#241](https://github.com/sayoriqwq/nix-config/issues/241)
- **批准记录：** 维护者于 2026-08-24 决定 macbook 使用 Preview、nixbox 使用 Stable，继续禁止把 Zed 源码构建作为正常回退
- **历史修订：** 2026-08-20 移除定期更新 workflow；2026-08-23 从 source Flake 改为官方精确 Nightly 二进制；2026-08-24 以当前平台分流取代 Nightly 双平台方案

## 背景

仓库先后尝试过 Zed source Flake 和 owner-local Nightly 双平台二进制。source Flake 在
cache miss 时会由 Crane 抓取大量 Cargo Git dependencies 并回退到完整 Rust 构建，
违反维护者的 binary-first 要求。Nightly 官方 macOS DMG/Linux tarball 避免了源码编译，
但 Linux 顶层 store path 不在 USTC、NixOS 官方 cache 或 Zed Cachix 中。

nixbox 的预期网络模型是优先使用 USTC Nix binary cache，并不依赖通用外网或代理。
因此 Nightly Linux artifact 需要直连 `cloud.zed.dev`，或由 macbook 中继进入 store；
这可以偶发完成构建，却不是可重复的日常更新与恢复路径。macbook 则需要较新的编辑器
功能，且能可靠取得 Zed 官方 macOS artifact。

Darwin 与 Linux 已经按 ADR-0009 使用不同 nixpkgs cadence。Zed 也有真实的平台供应链
差异，不再强求两台工作站使用同一通道或版本。

## 决策

### 1. macbook 固定官方 Preview 二进制

macbook 通过 owner-local `software/zed/package.nix` 固定：

- 精确 Preview 语义版本；
- `cloud.zed.dev/releases/preview/<version>/download` 的 aarch64-darwin DMG；
- DMG 的固定 flat hash。

Darwin derivation 只解包官方 DMG并投影 `Zed Preview.app` 与 `zed` CLI。它不 checkout
Zed source，不引入 Cargo、Rust、Crane 或 source-build fallback。应用内自动更新关闭；
版本推进只由维护者按需运行 `sync-zed-preview`，审阅 package pin 的 Git diff，并完成
package/host build。

### 2. nixbox 使用 Linux release nixpkgs 的 Stable

Zed GUI editor capability 在 Linux 直接选择 host package set 的 `pkgs.zed-editor`。
nixbox 使用锁定的 `nixos-26.05` package set，因此 Zed Stable 随 Linux release input
更新，不复用 macOS Preview derivation，也没有独立 updater。

每次 Linux nixpkgs input 更新必须在合并前取得 `zed-stable` 精确 outPath，并确认 USTC
binary cache 命中；官方 cache 命中作为次级供应链证据。USTC 查询失败时停止更新，继续
使用上一个 lock，不在 nixbox 本地构建 Zed，也不临时增加 source Flake、Cargo/Rust、
Cachix、通用外网代理或 production server builder。

这一约束属于更新与 activation Gate：nixpkgs package expression 本身保留上游源码构建
能力，但仓库操作合同不允许在缓存缺失时实现它。已确认的 content-addressed store path
一旦在 USTC 命中，就可作为当前 lock 的可重复 substitution 证据。

### 3. server 不选择 Zed

server 不组合 code-development、GUI editor 或工作站软件。显式 `zed-preview`/
`zed-stable` package output 只提供独立验证入口，不表示 server closure 选择 Zed，也不
授权 server 代建桌面 package。

### 4. 两个平台的版本差异是有意策略

macbook Preview 与 nixbox Stable 不要求版本号相同。Preview 为 macbook 提供较新功能；
Linux release Stable 为 nixbox 提供可缓存、可恢复的保守路径。版本差异由 package owner
的显式 platform seam 表达，不建立 registry、自动平台选择框架或第二套 Intent。

### 5. 根 Flake 与更新入口保持窄边界

根 Flake 不包含 Zed source input，也不信任 Zed Cachix。输出为：

- `packages.aarch64-darwin.zed-preview` 与 `sync-zed-preview`；
- `packages.x86_64-linux.zed-stable`；
- 仅 Darwin 暴露 `apps.aarch64-darwin.sync-zed-preview`。

Preview helper 只修改 owner-local package pin，不提交、不 push、不创建 PR、不 merge、
不 activation。Linux Stable 只随独立的 Linux nixpkgs input PR 更新。

### 6. 配置与 mutable state 边界不变

Home Manager 仍管理 package、CLI、默认编辑器声明和 seed-only 配置。Preview、Stable、
已退休 Nightly 的 settings、keymap、tasks、extensions、登录态、History、workspace/
session、数据库与 cache 均为每台机器的外部可变状态。本决策不迁移、合并或删除它们；
generation rollback 也不恢复这些状态。

## 结果

### 正面

- macbook 保留比 Stable 更新、但比 Nightly 更经过测试的官方 Preview；
- nixbox 的 Zed 跟随 Linux release package set，并可从预期的 USTC 路径 substitution；
- nixbox 不再需要直连 Zed artifact、Mac store relay 或 Nightly Linux adapter；
- source Flake、Cargo/Rust/Crane 与 Zed Cachix 继续不进入根依赖图；
- server 不承担桌面软件求值、下载或构建成本；
- 平台版本差异与现有 Darwin rolling/Linux release cadence 对齐。

### 代价与风险

- 两台工作站运行不同 Zed channel/version，排障必须注明平台；
- Preview 与 Stable 的功能、配置 schema 或 extension compatibility 可能不同；
- Preview artifact 仍依赖 Zed 官方托管与签名；固定旧 artifact 可能被上游删除；
- nixpkgs Stable 的 outPath 若在未来 lock 更新时未进入 USTC，更新必须暂停；
- 第一次切换 channel 需要分别做真实机器 smoke，mutable state 不随 generation 回滚。

## 被否决的替代方案

### 两个平台继续使用 Nightly 官方 binary

macOS 可行，但 Linux Nightly outPath 不在 nixbox 的预期 cache 中，需要直连上游或
Mac relay，无法作为正常恢复路径。

### 两个平台都使用 nixpkgs Stable

供应链最简单，但不满足维护者在 macbook 使用较新功能的明确需求。

### nixbox 使用 Preview/Nightly source Flake 或 cache miss 后本地构建

会重新引入 Cargo Git fetch、Crane 与长时间 Rust build，正是本决策需要消除的故障。

### 让 server 或 macbook 长期代理/代建 nixbox Zed

会把桌面软件供应链耦合到另一台机器的在线状态和临时 transport。Mac relay 可用于一次性
诊断证据，不是生产声明或恢复合同；server 仍保持 headless。

### Homebrew、Zed 自更新或浮动 `latest`

会绕过固定 hash、Git 审阅和 generation rollback，不采用。

## 验证与人工关卡

实施 PR 至少需要：

- formatter、Flake check 与 Zed package selection seam check；
- 构建 aarch64-darwin Preview package 与 macbook system，读取 App 签名、bundle identity
  和版本，不 activation；
- 记录 x86_64-linux Stable 版本、outPath 及 USTC/官方 cache 命中；
- 在 nixbox 原生构建 Stable package 与 nixbox toplevel；
- 验证 server 最终 package/closure 不选择 Zed；
- 审阅 `flake.lock` 在本决策 PR 中保持不变。

Draft PR、离线 build、缓存命中或 ADR 修订均不授权 activation、Ready、merge、tag、
卸载旧应用或删除 mutable state。第一次采用新通道的 activation 与运行态 smoke 需要当次
维护者批准。

## 回滚

未 activation 时 revert 本决策 PR 并重新 build。已经 activation 时优先切回上一代
nix-darwin/NixOS generation，再 revert 声明。任何 Preview/Stable/Nightly 外部状态仍由
各自产品流程或仓库外私有备份恢复，不由 Git 回滚处理。

## 复审条件

- Zed 改变 Preview download API、bundle layout、签名或发布身份；
- 上游停止提供固定 Preview artifact；
- Linux Stable 目标长期不进入 USTC；
- Preview/Stable 的功能或配置差异产生不可接受的维护成本；
- 维护者需要为 Zed 设计自有二进制归档或重新统一通道。
