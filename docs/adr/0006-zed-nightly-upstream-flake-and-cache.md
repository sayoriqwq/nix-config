# ADR-0006：使用 Zed 官方精确 Nightly 二进制

- **状态：** 已接受
- **日期：** 2026-07-24
- **决策范围：** 桌面编辑器、软件包所有权、二进制供应链与更新流程
- **关联 Issue：** [#25](https://github.com/sayoriqwq/nix-config/issues/25)、[#215](https://github.com/sayoriqwq/nix-config/issues/215)
- **批准记录：** 维护者于 2026-07-24 接受 Nightly 通道；2026-08-23 明确要求禁止 Zed 源码构建回退
- **后续修订：** 维护者于 2026-08-20 决定移除定期更新 workflow；2026-08-23 改用官方精确版本预构建产物

## 背景

维护者选择 Zed Nightly 作为 macOS 与 NixOS 工作站的主编辑器。仓库最初把
Zed 官方源码 Flake 作为 package owner，并信任其 Cachix，希望避免本地编译。

真实故障证明这条路径不满足预期：只求值 Zed package 就会由 Crane 对大量
Cargo Git dependencies 执行 refs/submodule 抓取；当前固定版本的 Darwin 与
Linux 顶层 store path 又不在 Zed Cachix、NixOS 官方缓存或 USTC 缓存中。
缓存未命中后，Nix 合法地回退到完整 Rust 源码构建。生产 server 上误构建
`nixbox` output 时因此长时间抓取仓库，最终在真正开始构建前由 daemon 断开。

同一 commit 对应的 Zed 官方 Nightly 发布同时提供 macOS aarch64 DMG 与 Linux
x86_64 tarball。因此本仓库不需要把“使用 Nightly”与“自行编译 Nightly”绑定。

## 决策

### 1. 只消费官方精确版本的 Nightly 二进制

macbook 与 nixbox 使用 owner-local `software/zed/package.nix` derivation。每次固定：

- 完整官方 release identity，包含版本、Nightly run number 与 40 位 commit SHA；
- `cloud.zed.dev/releases/nightly/<exact-release>/download` 的双平台 URL；
- macOS aarch64 DMG 的 flat hash；
- Linux x86_64 tarball 解包后的 recursive hash。

不使用浮动 `latest` 作为 package source。Darwin derivation 只解包官方 DMG 并
投影 `.app` 与 CLI；Linux derivation 只解包官方 tarball，执行 NixOS 所需的 ELF
interpreter/RPATH 适配和必要 wrapper。两边都不得 checkout Zed source，也不得
引入 Cargo、Rust、Crane 或 source-build fallback。

### 2. 根 Flake 不再包含 Zed source Flake

根 `flake.nix` 与 `flake.lock` 删除 `zed` input 及只由它引入的 Nixpkgs、Crane、
Rust overlay 和 `flake-parts` 节点。显式 package outputs 与两个 workstation host
共同调用 owner-local package；server 不选择 Zed capability，也不获得 Zed package。

本仓库顶层继续使用普通 Flake。删除 Zed 叶子 input 不改变 ADR-0001 的模块组织
决策，也不影响其他仍有自身传递图的 inputs。

### 3. artifact 缺失必须失败，不得改走源码

“binary-only”表示固定版本的任一官方产物不存在、hash 不符或无法解包时，更新和
build 都应立即失败。失败时继续使用上一个已固定版本，不引入临时源码 package，
不把 production server 当作桌面包 builder，也不等待 Rust 编译完成。

Nix 仍会实现一个很小的本地 derivation 来解包、patch ELF 或创建 wrapper；这不是
Zed 源码构建。不得把“没有 Rust 编译”误写成“完全没有 Nix derivation realization”。

### 4. 删除 Zed Cachix 信任

官方发行包通过固定 URL 与内容 hash 进入 store，不再请求 Zed source derivation 的
store path。Darwin 与 NixOS 配置因此删除 `zed.cachix.org` substituter 与 trusted key：

- 不上传本机构建结果；
- 不配置 Cachix token 或签名私钥；
- 不关闭 Nix 签名检查；
- server/nixbox 的通用缓存优先级由各 host 自己声明，与 Zed capability 解耦。

固定 hash 保证下载内容与审阅版本一致，但不能消除 Zed 官方发布流水线、签名证书
或托管账号被攻破的供应链风险。macOS build 还应验证上游 App 的代码签名。

### 5. Nightly 更新只能由维护者手动触发

仓库不运行定期 Zed update Action。维护者需要更新时，在专用分支运行：

```fish
nix run .#sync-zed-nightly
```

该入口解析官方 `latest` redirect 得到精确 release identity，先确认双平台产物都
存在并计算固定 hash，再只修改 owner-local package 文件。它不提交、不 push、
不创建 PR、不 activation，也不编译 Zed。维护者必须审阅 diff、完成双平台适用的
package/host build，再通过普通 Draft PR 推进。

应用内自动更新继续关闭。Git 中固定的 release/hash、Nix build 与 generation 是
唯一版本推进和声明式回滚路径。

### 6. 编辑器配置与可变状态边界不变

本次只替换 package source 与更新流程。Home Manager 仍管理 package、CLI、默认
编辑器声明和 seed-only 配置；Zed settings、keymap、tasks、extensions、登录态、
History、workspace/session 与 cache 继续属于每台机器的可变状态。

## 结果

### 正面

- 冷求值不再扫描 Zed Cargo Git refs；
- cache miss 不再触发 Zed Rust 源码编译；
- macOS 与 Linux 固定同一官方 release identity；
- source Flake 的独立 Nixpkgs/Rust/Crane/`flake-parts` 图退出根 lock；
- 不再保留实际上不能保证 cache hit 的 Zed Cachix 信任；
- 手动更新有一个短入口，并在写入前验证双平台官方产物。

### 代价与风险

- 每次更新需要下载两个官方产物来计算 hash，并分别验证两个平台；
- Linux 官方 bundle 仍需 NixOS ELF/RPATH 适配和真实桌面 smoke；
- Nightly 可能崩溃、回归或改变配置格式；
- 上游托管对象带生命周期策略，固定的旧 artifact 未来可能被删除；更新应在产物
  仍可获取时推进。若需要永久保留，必须另开 Issue 设计自有归档与签名边界；
- generation 回滚不恢复 Zed 的可变状态。

## 被否决的替代方案

### 继续使用官方 source Flake 与 Zed Cachix

上游维护 package logic，但实际固定 store path 未命中缓存；求值会扫描大量 Git
dependencies，完整 build 会回退 Rust 编译，与维护者的 binary-only 要求冲突。

### 通过 `--no-build-output` 或只调整 substituter 顺序规避

这只能改变失败时机或查询顺序，不能让缺失的 store path 出现在缓存中，也不能
消除 source Flake 求值时的 Git fetch。

### macOS 使用 DMG，Linux 保留 source Flake

会留下两个 package owner 与两套版本推进方式，不能保证两台工作站使用同一 release。

### Homebrew、Zed 自更新或浮动 `latest`

会绕过固定 hash、Git 审阅和 generation 回滚，并让两台工作站产生版本漂移。

### production server 代建 nixbox 的 Zed

server 是 headless host，不应为桌面 package 承担求值、下载或构建成本。跨 host
build 必须明确选择并审阅；Linux 原生验收等待 nixbox 恢复。

## 验证与人工关卡

实施 PR 至少需要：

- `nix fmt -- --check .` 与 `nix flake check`；
- 构建 aarch64-darwin Zed package 与 macbook system，不 activation；
- 验证 macOS App 代码签名、版本与 CLI projection；
- 求值 x86_64-linux derivation，证明没有 Cargo/Rust/Crane/source inputs；
- nixbox 恢复后原生构建 Linux package 与 nixbox toplevel；
- 验证 server 不选择 Zed package；
- 更新演练必须先取得两个官方 artifact，任何一个缺失都失败。

Draft PR、离线 build 或 ADR 修订不授权 activation、merge、Ready、卸载旧应用或
删除可变状态。第一次采用新 package 的真实机器验证仍需当次维护者批准。

## 复审条件

出现以下情况时重新评估：

- Zed 官方改变精确版本 download API、bundle layout、签名或发布身份；
- 官方停止提供任一受支持平台产物；
- artifact 生命周期导致已固定版本无法可靠恢复；
- Linux bundle 的运行时依赖或 NixOS patch 超出窄 adapter；
- Nightly 稳定性或手动更新成本不再可接受；
- 维护者决定设计自有二进制归档或回到 Preview/Stable。
