# ADR-0006：使用 Zed 官方 Flake、Nightly 通道与限定 Cachix

- **状态：** 已接受
- **日期：** 2026-07-24
- **决策范围：** 桌面编辑器、Flake input、二进制缓存与更新流程
- **关联 Issue：** [#25](https://github.com/sayoriqwq/nix-config/issues/25)
- **批准记录：** 维护者于 2026-07-24 审阅草稿后明确接受本 ADR

## 背景

维护者长期使用 Zed Preview，随后明确选择比 Preview 更新的 Zed Nightly
作为 macOS 与未来 NixOS 工作站的主编辑器。当前 Nixpkgs 只提供稳定版
`pkgs.zed-editor`，不能满足 Nightly 需求。

Zed 官方源码仓库提供 Flake，并将默认 package 构建为 Nightly。该 Flake
支持 Darwin 与 Linux，但内部使用自己的 Nixpkgs、`flake-parts`、Crane 和
Rust overlay，并建议使用 Zed 官方 Cachix。直接采用这些能力可以避免在本仓库
维护一份高频变化的大型 Rust package；同时也会新增上游依赖图、二进制供应链
信任和更新治理成本。

本仓库已有以下约束：

- 顶层保持一个普通 Flake，不在 v1 中顺带改用 `flake-parts` 组织仓库；
- `flake.lock` 是依赖版本的事实来源；
- Home Manager 管理可复用的桌面用户层；
- Git/Nix 管理声明，不接管编辑器的登录态、History、workspace/session、
  缓存和扩展运行状态；
- 自动更新 PR 原本属于 v1 之后的候选能力，若在 Phase 4 提前引入，必须作为
  范围明确的窄例外。

## 决策

### 1. 使用官方 Nightly package

把 Zed 官方 Flake 作为顶层 Flake 的一个命名 input，只消费其当前平台的
`packages.${system}.default` Nightly package。

- 不使用 Nixpkgs stable package 冒充 Nightly；
- 不维护自制 Preview/Nightly derivation；
- 不使用 Homebrew、DMG 或 Zed 自更新作为终态版本所有者；
- `flake.lock` 固定 Zed 的精确 Git revision 和完整上游 input graph。

“使用最新 Nightly”定义为：更新 PR 最近一次锁定并通过验证的 Zed `main`
revision，而不是每台机器在 build 时绕过锁文件获取不同的最新提交。

### 2. 把上游 `flake-parts` 限制在叶子 input 内

Zed 官方 Flake 内部使用 `flake-parts`，不等于本仓库采用 `flake-parts`
组织顶层 outputs：

- 本仓库的 `flake.nix` 继续使用现有普通 Flake 结构；
- 不调用 Zed input 暴露的 `flake-parts` library；
- 不把 Zed 的模块组织方式扩散到 host、Home Manager 或其他 inputs；
- 只通过公开 package output 消费 Zed；
- 将来若要让本仓库本身采用 `flake-parts`，仍需新的独立 Issue 和 ADR。

该边界是对既有 ADR-0001 的补充，不取代其“一个普通顶层 Flake、多个主机
output”决策。

### 3. 保留 Zed 上游构建依赖图

初始实现不让 Zed 的 Nixpkgs 强制 `follows` 本仓库根 `nixpkgs`。Zed 官方
Flake 负责选择与其 Nightly 源码匹配的 Nixpkgs、Rust toolchain、Crane 和
patch/build logic，本仓库把这组版本作为 Zed package 的封装构建依赖。

这会在 `flake.lock` 中增加独立节点和更新 diff，但比强行统一 Nixpkgs 后承担
Nightly 编译失败、工具链不匹配或平台 patch 漂移更符合上游支持边界。若锁文件
体积、求值成本或安全更新重复成为实际问题，再以 build 证据评估 `follows`，
不能只为减少 lock 节点改变上游构建图。

### 4. 显式信任限定的 Zed Cachix

维护者批准使用 Zed 官方公开二进制缓存，以避免 macOS 和 NixOS 频繁完整编译
大型 Zed/Rust closure。仓库只声明：

```text
substituter:
  https://zed.cachix.org

trusted public key:
  zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU=
```

信任边界如下：

- 继续要求 store path 签名，不设置 `require-sigs = false`；
- 不全局设置 `accept-flake-config = true`；
- 不因其他 Flake 的 `nixConfig` 自动增加缓存或公钥；
- 不配置 Cachix 账号、认证 token、签名私钥或上传能力；
- 不把本机构建结果上传到 Zed Cachix；
- 缓存未命中时允许 Nix 回退到本地源码构建；
- 缓存 URL、公钥或信任范围变化必须经过新的 Git diff、风险说明和维护者批准。

该授权信任 Zed 缓存签名方提供与请求 store path 对应的二进制结果。TLS 与 Nix
签名可以防止普通传输篡改，但不能消除 Zed 构建流水线或签名密钥被攻破的供应链
风险。

### 5. Nightly 更新使用锁文件 PR

在 #25 范围内允许为 Zed input 建立每日一次的更新检查，作为 Phase 4 的窄例外：

1. 只更新 Zed 命名 input 及其必要的传递 lock nodes；
2. 生成可审阅的锁文件 diff 和 Nightly revision/version 摘要；
3. 运行可用的 formatter、Flake check 和受影响 package/host build；
4. 仅创建或更新 Draft PR，不自动批准、合并或激活真实机器；
5. 构建失败时保留当前已锁定版本，并让失败保持可见；
6. 允许维护者暂停定时检查，避免持续失败或上游事故产生噪声。

Zed 应用自身的自动更新必须关闭。Git PR、`flake.lock` 与 Nix generation 是
唯一版本推进和回滚路径。

### 6. 编辑器共用语义，不共用原生配置

Zed 与 VS Code 在同一个 #25 中推进，因为它们共享默认编辑器角色、外部工具链、
项目规则和人工配置回流流程；但二者不共享一份完整 settings 或扩展 schema。

- `modules/home/desktop/` 保存编辑器基础配置；host 通过 `zed-editor`、`macos-vscode-compatibility` 等能力模块选择编辑器角色；
- Zed 与 VS Code 分别保留原生 settings、keymap、task、debug 与 extension ID；
- Darwin、Linux 和 local-only 差异显式分类；
- live settings 与扩展状态保持可写；
- Git/Nix 保存经审阅的基线，只在目标不存在时初始化，不自动覆盖 live 文件；
- 变化通过定期人工审查回流，不实现 watcher、双向 reconciler 或自动 Git 写入；
- 登录态、History、workspace/session、缓存和扩展工作目录仍属于可变状态。

## 结果

### 正面

- 使用 Zed 上游维护的 Nightly 构建逻辑，减少自制 package 的持续维护；
- macOS 与未来 NixOS 可以锁定同一 Zed revision，同时构建各自平台输出；
- Cachix 命中时显著降低每日 Nightly 更新的本地编译成本；
- 更新、失败和回滚都有 Git 与锁文件记录；
- 上游 `flake-parts` 被限制在叶子依赖内，不改变本仓库顶层架构；
- VS Code 与 Zed 的共用关系被显式建模，而不是靠复制或自动同步维持。

### 代价与风险

- `flake.lock` 增加 Zed 独立 Nixpkgs、Rust overlay、Crane 和 `flake-parts`
  等传递节点；
- Nightly 未经过 Preview/Stable 同等级测试，可能崩溃、回归或改变配置格式；
- 每日更新会增加 PR、构建资源和维护噪声；
- 缓存未命中时仍可能触发耗时的本地源码构建；
- 信任 Zed Cachix 意味着接受其构建流水线和签名密钥的供应链风险；
- Zed 的 live settings、扩展和 workspace 状态不随 Nix generation 自动回滚；
- `nixbox` 的 GPU、Wayland/X11、扩展二进制和远程开发行为仍需在 Phase 5/6
  使用真实主机证据验证。

## 被否决的替代方案

### 使用 Nixpkgs Stable

维护成本最低，但不满足维护者明确选择最新 Nightly 的需求。

### 继续使用 Preview 或自制 Preview package

不满足最新通道选择，而且需要自行维护 channel identity、source/Cargo hash、
Darwin bundle、Linux desktop integration 和 remote server。

### macOS 使用 Homebrew/官方 DMG，NixOS 使用另一套 package

会产生两个安装与更新所有者，破坏同一锁文件的跨主机版本事实。

### 强制 Zed 的 Nixpkgs 跟随根 Nixpkgs

可以减少 lock nodes，但会偏离上游测试的构建图，并把 Nightly 工具链兼容责任
转移到本仓库；在没有实际问题和双平台 build 证据前不采用。

### 自动接受所有 Flake 的 `nixConfig`

操作简单，但会让未来任意 input 提议的缓存进入信任流程，超出本次只信任 Zed
固定 URL 与公钥的授权范围。

### 不使用二进制缓存

供应链信任面更小，但每日 Nightly 和双平台验证可能频繁触发大型源码构建，
不符合预期更新频率。

### 应用自行更新

可以更快获得版本，但会绕过 `flake.lock`、构建检查、Git 审计和 generation
回滚，并让两台工作站产生版本漂移。

## 验证与人工关卡

实施 PR 至少需要：

- 确认 `flake.lock` 固定 Zed 的精确 revision；
- 检查根 Flake 仍未采用 `flake-parts`；
- 验证配置只增加批准的 substituter 和公钥，签名检查保持开启；
- 构建 macOS host output，并确认 closure 中是 Zed Nightly；
- 在可行范围内求值或构建 `x86_64-linux` Nightly package；
- 验证缓存命中与缓存未命中回退不会改变 derivation identity；
- 记录 Preview → Nightly 的私有备份、双安装验收和回滚步骤；
- 记录每日更新失败、暂停和恢复流程。

ADR 接受和离线 build 不授权 activation。第一次切换到 Nightly、改变默认编辑器、
卸载 Zed Preview、信任配置实际生效、合并或将 Draft PR 标记 Ready，仍需 Issue
或 PR 中针对当次动作的维护者批准。

## 复审条件

出现以下情况时重新评估：

- Zed 官方停止维护 Flake、Nightly package 或 Cachix；
- Zed Cachix URL、公钥、所有权或安全状态发生变化；
- 上游依赖图导致不可接受的锁文件、求值或安全维护成本；
- 缓存长期缺少 `aarch64-darwin` 或 `x86_64-linux` 输出；
- Nightly 持续不稳定，维护者决定回到 Preview 或 Stable；
- Zed 官方提供更简单、稳定且跨平台的 Nix channel interface；
- 每日更新 PR 的噪声或资源消耗高于其收益；
- 本仓库另行决定采用 `flake-parts` 作为顶层组织框架。
