# Phase 4：Zed 与编辑器通用性调研

- **调研日期：** 2026-07-24
- **调研范围：** Zed 官方文档、Zed 官方源码、Nixpkgs 与 Home Manager 上游源码
- **约束：** 本文只形成设计输入，不修改 Nix 实现，不读取或改写本机 Zed 可变状态，不授权 activation、应用迁移或卸载
- **决策更新：** 维护者随后明确选择 Zed Nightly，并于 2026-07-24 接受 ADR-0006；本文关于 Stable / Preview / Nightly 的早期比较保留为决策证据，实施结论以 ADR-0006 与 Issue #25 为准

## 1. 结论

建议把“编辑器通用性”定义为**共享工作环境和使用意图**，不要定义成“让 VS Code 与 Zed 共用一份 settings 或扩展清单”。

仓库应采用三层模型：

1. **编辑器无关层**
   - `EDITOR` / `VISUAL` 的默认编辑器角色；
   - Git、Fish、direnv、mise、格式化器、语言服务器等外部工具；
   - 项目自己的 `.editorconfig`、formatter/linter 配置和 dev shell；
   - “格式化保存、缩进、字体、主题、常用动作”等经过文档化的体验意图。
2. **编辑器专属层**
   - Zed 与 VS Code 各自的 settings schema、keymap action、tasks/debug 格式；
   - 各自完全不同的扩展 ID、扩展能力和状态目录；
   - 各自的 CLI 名称与安装包。
3. **平台专属层**
   - macOS 与 Linux 的包变体、GUI 集成和应用数据路径；
   - 按平台确有差异的字体、快捷键和图形栈设置；
   - NixOS 上 Zed 扩展或语言服务器所需的 FHS / `PATH` 兼容策略。

换言之，推荐“**共享语义，分别表达**”，而不是建立一个试图生成两种编辑器完整配置的通用 schema。Zed 官方的 VS Code 迁移表证明一部分设置存在概念映射，但它也同时展示了字段名、值域和行为的差异；这适合做迁移参考，不足以成为长期双向抽象层。[Zed：从 VS Code 迁移](https://zed.dev/docs/migrate/vs-code)

对当前 Phase 4 最稳妥的终态是：

- Zed 成为桌面角色的主编辑器；
- Zed 使用官方 Flake 的 Nightly package，并由本仓库 `flake.lock` 固定精确 revision；
- VS Code 保留为明确的兼容/备用编辑器，安装与配置边界由 Issue #25 统一处理；
- 两者各自保留可写 live 配置；
- Git/Nix 只保存各自经过审查的基础基线；
- 不实现自动双向同步；
- 定期人工把 live 变化分类回流为 shared、Darwin、Linux、editor-specific 或 local-only；
- 在 Zed Settings Sync 正式发布并审查其同步范围前，不把 Zed 账户当作配置同步层。

## 2. Zed 的平台状态

### 2.1 macOS

Zed 官方把 macOS 描述为主要开发平台和完整支持的 first-class platform，支持 macOS 10.15.7 以上、Apple Silicon 与 Intel，并使用 Metal 渲染。官方提供 DMG，也列出 Homebrew cask 安装方式。[Zed on macOS](https://zed.dev/docs/macos)

这意味着当前 `aarch64-darwin` Mac 可以把 Zed 作为主编辑器，但“官方支持”并不决定本仓库的安装所有权；如果采用 Nixpkgs，则版本和更新应由 `flake.lock` 控制。

### 2.2 Linux 与未来 NixOS

Zed 已正式支持 Linux，并支持 X11 和 Wayland；官方二进制要求 Vulkan GPU，以及系统级 glibc。官方特别说明 NixOS 默认不具备这种 glibc 环境，若运行官方构建可考虑 `nix-ld`，也可使用第三方 Nix 包。[Zed on Linux](https://zed.dev/docs/linux) [Zed Linux packaging notes](https://zed.dev/docs/development/linux)

对未来 `nixbox` 的含义：

- 不能仅因 macOS 可运行就断言 NixOS 体验等价；
- 需要在 Phase 5/6 真实验证 GPU/Vulkan、Wayland/X11、CLI、语言服务器和扩展；
- 不应为了 Zed 单独提前启用全局 `nix-ld`；
- 优先评估 Nixpkgs 的源码构建包及其 FHS 变体，再决定是否需要系统级兼容层。

## 3. 安装和更新所有权

### 3.1 Zed 官方分发

- macOS：DMG 或 Homebrew；官方应用会检查更新。[Zed on macOS](https://zed.dev/docs/macos)
- Linux：官方推荐安装脚本，也提供 tarball；preview 可通过 channel 安装。[Zed on Linux](https://zed.dev/docs/linux)
- 默认情况下，Zed 会后台下载更新并在重启时应用；`auto_update` 可以关闭。[Update Zed](https://zed.dev/docs/update) [All Settings：`auto_update`](https://zed.dev/docs/reference/all-settings)

### 3.2 当前仓库锁定的 Nixpkgs

本仓库 `flake.lock` 固定的 Nixpkgs revision 为
`fd1462031fdee08f65fd0b4c6b64e22239a77870`。该 revision 的 `pkgs.zed-editor`：

- 版本为 `1.3.6`；
- 支持 `lib.platforms.linux ++ lib.platforms.darwin`；
- 从 Zed 官方 GitHub tag 源码构建；
- 主程序名为 `zeditor`；
- 许可证为 GPL-3.0-only，因此不是 unfree 软件；
- 通过 `ZED_UPDATE_EXPLANATION` 禁用应用自更新，交由 Nix 更新；
- Linux 侧提供 `passthru.fhs` / `fhsWithPackages`，用于兼容扩展携带的预编译动态链接程序。

来源：[Nixpkgs 固定 revision 的 Zed package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/ze/zed-editor/package.nix)

因此若进入实现，推荐由 Home Manager/Nixpkgs 管理应用版本，不同时保留 Zed 自更新作为第二个版本所有者。它也不需要复用当前只为 `vscode` 设置的 `allowUnfreePredicate`。

需要单独接受的代价是：当前锁定版本可能落后于官方发布；升级应表现为 `flake.lock`/Nixpkgs 变更和可审查构建，而不是应用自行漂移。

### 3.3 Zed Preview 与 Nixpkgs

#### 官方 Preview 如何表达

Zed Preview 是独立 release channel，不只是稳定版上打开一个运行时开关：

- 官方称 Preview 通常比 stable 提前约一周，并明确提醒会有更频繁的更新和更高的 bug 概率；
- macOS 官方提供独立的 `Zed Preview.app` 和 `zed@preview` Homebrew cask；
- Linux 官方安装命令是
  `curl -f https://zed.dev/install.sh | ZED_CHANNEL=preview sh`；
- Preview 的 GitHub release tag 为 `v<version>-pre`，例如调研时最新的
  [`v1.13.0-pre`](https://github.com/zed-industries/zed/releases/tag/v1.13.0-pre)；
- tag 内 `crates/zed/RELEASE_CHANNEL` 的内容是 `preview`，而相邻稳定版 tag
  `v1.12.0` 中是 `stable`；
- Preview tag 的 crate version 仍是 `1.13.0`，`-pre` 属于 release tag/channel 表达，不是 Cargo crate version；
- macOS Preview 使用独立 bundle metadata：应用名 `Zed Preview`、bundle ID
  `dev.zed.Zed-Preview` 和 preview 图标。

来源：[Zed Preview 下载页](https://zed.dev/download/preview)
[Zed on macOS](https://zed.dev/docs/macos)
[Zed on Linux](https://zed.dev/docs/linux)
[`v1.13.0-pre` 的 `RELEASE_CHANNEL`](https://github.com/zed-industries/zed/blob/v1.13.0-pre/crates/zed/RELEASE_CHANNEL)
[`v1.12.0` 的 `RELEASE_CHANNEL`](https://github.com/zed-industries/zed/blob/v1.12.0/crates/zed/RELEASE_CHANNEL)
[官方 tag 校验脚本](https://github.com/zed-industries/zed/blob/v1.13.0-pre/script/determine-release-channel)
[`v1.13.0-pre` 的 macOS bundle metadata](https://github.com/zed-industries/zed/blob/v1.13.0-pre/crates/zed/Cargo.toml)

Zed release-channel 源码还表明 channel 会影响显示名、应用 ID、更新查询参数和文档 channel；release build 直接编译 source tree 中的 `RELEASE_CHANNEL`，不能靠启动时设置环境变量安全地把 stable 二进制变成 Preview。[Zed release-channel 源码](https://github.com/zed-industries/zed/blob/v1.13.0-pre/crates/release_channel/src/lib.rs)

#### 固定 Nixpkgs 与当前 upstream 是否提供 Preview

结论是：**没有 first-class 的 `zed-editor-preview` package，也没有受支持的
`channel = "preview"` override。**

对本仓库固定 revision
`fd1462031fdee08f65fd0b4c6b64e22239a77870` 的检查结果：

```text
builtins.hasAttr "zed-editor" pkgs         = true
builtins.hasAttr "zed-editor-preview" pkgs = false
```

该 revision 只有稳定版 package；package 内部把 `channel = "stable"`、source tag
`v${version}`、macOS `package.metadata.bundle-stable` 和 remote-server channel
名称写死。[固定 revision 的 Zed package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/ze/zed-editor/package.nix)

调研时的 Nixpkgs `master`
`16611dafa6bd3de60c6ec430cf0e89205faadedb` 同样没有
`zed-editor-preview`，其唯一 Zed editor package 是 stable `1.11.3`，仍采用上述
hard-coded stable channel 与 bundle 逻辑。[调研时 upstream Nixpkgs package](https://github.com/NixOS/nixpkgs/blob/16611dafa6bd3de60c6ec430cf0e89205faadedb/pkgs/by-name/ze/zed-editor/package.nix)

这里的 “没有” 通过两种方式交叉确认：

1. 对固定 Flake output 执行上面的 `builtins.hasAttr` 求值；
2. 检查固定 revision 与调研时 `master` 的完整 Git tree，并检查对应
   `package.nix` 的参数与 `passthru`。

Nixpkgs package 唯一暴露的构建参数是 `buildRemoteServer`；`passthru` 提供
Linux FHS 包装器，但都不提供 release-channel override。

#### Zed 官方 Flake：跨平台，但不是 Preview package

Zed `v1.13.0-pre` source tree 自带官方 `flake.nix`。它：

- 通过 `packages.${system}.default` 暴露 Zed；
- 声明支持 `x86_64-linux`、`aarch64-linux`、`x86_64-darwin` 和
  `aarch64-darwin`；
- 同时提供 default overlay；
- 使用自己锁定的 Nixpkgs unstable；
- 直接依赖 `flake-parts`、Crane 和 `rust-overlay`；
- 在 `nixConfig` 中建议加入
  [`zed.cachix.org`](https://zed.cachix.org) 及其 trusted public key。

来源：[`v1.13.0-pre/flake.nix`](https://github.com/zed-industries/zed/blob/v1.13.0-pre/flake.nix)
[`v1.13.0-pre/flake.lock`](https://github.com/zed-industries/zed/blob/v1.13.0-pre/flake.lock)
[官方 packages module](https://github.com/zed-industries/zed/blob/v1.13.0-pre/nix/modules/packages.nix)

但这个 official Flake 的 default package **不是 Zed Preview**。尽管
`v1.13.0-pre` tag 自带的 `crates/zed/RELEASE_CHANNEL` 是 `preview`，官方 Nix
build 在 `preBuild` 中把该文件重写成 `nightly`，version 追加
`-nightly`，macOS 强制选择 `bundle-nightly`，Linux 也生成
`Zed Nightly` desktop entry 和 Nightly app ID。[官方 Nix build](https://github.com/zed-industries/zed/blob/v1.13.0-pre/nix/build.nix)

实际对官方 Flake 求值也确认了这一点：

```text
nix eval github:zed-industries/zed/v1.13.0-pre#packages.aarch64-darwin.default.version
=> "1.13.0-nightly+aaf5f57"

nix eval github:zed-industries/zed/v1.13.0-pre#packages.aarch64-linux.default.version
=> "1.13.0-nightly+aaf5f57"
```

求值时还会提示该 Flake 请求使用 `zed.cachix.org`，需要用户通过
`--accept-flake-config` 或系统配置显式接受；默认不能把上游建议的 binary cache
视为已受信任。

因此直接写：

```nix
inputs.zed.url = "github:zed-industries/zed/v1.13.0-pre";
```

并消费 `inputs.zed.packages.${system}.default`，得到的是“基于该 tag 源码的
官方 Nightly Nix build”，不能声称它等价于官方 Preview release。它可能适合
Zed 上游开发者验证源码，但不满足本仓库对应用 channel、身份和更新来源的精确
审计要求。

与自制 Nixpkgs `overrideAttrs` 相比，官方 Flake 的优点是：

- Zed 上游自己维护 Rust toolchain、Crane build 和 Darwin/Linux 分支；
- 一个 input 暴露四个 platform output；
- 官方 CI 至少定义了 Linux x86_64 和 macOS aarch64 的 Nix build；
- 若接受其 flake config，可尝试复用 Zed Cachix，降低本地源码构建成本。

来源：[Zed Nix build CI](https://github.com/zed-industries/zed/blob/v1.13.0-pre/.github/workflows/nix_build.yml)

但其代价和风险也更大：

- channel 身份是 Nightly，不是 Preview；
- 引入一套独立 Nixpkgs/Rust toolchain/build graph，除非用 `follows` 改写；
- 若让它 follow 本仓库 Nixpkgs，又偏离 Zed 自己锁定和测试的依赖集合；
- `flake-parts`、Crane、`rust-overlay` 都成为新的 transitive dependency；
- 接受 `zed.cachix.org` 需要新增 substituter 与 trusted public key，是新的
  binary-cache 供应链信任边界；
- 不接受该 cache 或 cache miss 时，仍需本地构建大型 Rust/WebRTC closure；
- 每次切换 Preview tag 都会更新 Zed source 及其 input lock，而不只是一个
  Nixpkgs package version。

本仓库 `AGENTS.md` 明确禁止在没有 dedicated Issue 和 accepted ADR 时引入
`flake-parts`。该限制不会因为 `flake-parts` 是 Zed Flake 的传递依赖而消失。
同时，新增第三方 Cachix key 也应在同一 ADR 中明确说明信任、禁用和回滚方式。

所以当前不能把官方 Flake 作为“无需设计即可采用”的捷径。若未来单独评估，
必须先决定：

1. 接受官方 Nightly 身份，还是 fork/override 官方 build 使其真正生成 Preview；
2. 是否让 Zed 的 Nixpkgs follow 根 Flake；
3. 是否接受 Zed Cachix 及其公钥；
4. stable/preview/nightly 是否允许并存；
5. 两个实际 host platform 是否都有可复现 build 和必要 cache。

#### 为什么不建议简单 `overrideAttrs`

只把 `version` 和 `src` 改为 `1.13.0-pre` / `v1.13.0-pre` 不足以得到正确的
Preview 包，还至少要处理：

- 新 source hash；
- 新 `cargoHash`；
- package 内 hard-coded `channel = "stable"`；
- macOS install phase 强制选择 `bundle-stable`；
- Linux desktop entry 强制使用稳定版应用名和 app ID；
- remote-server output 的稳定版 channel 文件名；
- Preview 与 stable 是否允许并存及其 CLI 名称；
- Home Manager remote-server symlink 是否匹配 Preview 客户端预期。

这些值散落在 Nixpkgs derivation 的闭包和 install phase 中。
`overrideAttrs` 若重写完整 install phase，实质上已经是在维护一个 Nixpkgs
package fork；它会对 Nixpkgs 上游实现细节敏感，并不是一个小型、稳定的
channel 参数覆盖。

#### macOS 与 Linux/NixOS 能否使用同一 Nix package

稳定版可以：`pkgs.zed-editor` 是同一个 package attribute，meta 同时声明
Darwin 与 Linux；Nix 按 host platform 构建不同输出。共享的是 package
定义和版本事实，不是同一个二进制或同一个 store path。[Nixpkgs Zed package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/ze/zed-editor/package.nix)

Preview 理论上也能由**一个正确参数化的自定义 Nix package**同时覆盖
Darwin 与 Linux，但它必须保留 Nixpkgs 现有的平台条件：

- macOS 构建 `.app` bundle，并选择 Preview bundle metadata；
- Linux 构建 editor/CLI、desktop entry 和图标；
- Linux/NixOS 还要保留 RPATH、Node、FHS wrapper 与扩展二进制兼容处理。

因此“一份 package expression 支持两平台”是可行目标，但不能把 macOS
官方 DMG 或 Linux 官方 tarball 当成跨平台同一 artifact。官方 Linux 二进制在
NixOS 上还需要 glibc compatibility layer；源码构建的 Nixpkgs package 才是
当前更一致的跨平台起点。[Zed on Linux](https://zed.dev/docs/linux)

#### 调研时的保守建议与后续决策

调研阶段的保守建议是优先使用固定 Nixpkgs 的 **stable `pkgs.zed-editor`** 作为 macOS
与未来 NixOS 的共同主编辑器 package：

- 不新增自制 package fork；
- channel、版本和应用身份一致；
- 更新通过 `flake.lock` / Nixpkgs 变更审查；
- 可沿用 Nixpkgs 对 Darwin、Linux、remote server 和 FHS 的维护；
- 两个平台分别 build/test 后才 activation。

如果 Preview 是不可退让的需求，原建议是另开专门 Issue 和 ADR，而不是在 Phase 4
顺手 override。可接受的实现应把 Zed package 正式参数化为 stable/preview，
或维护独立的 `zed-editor-preview` package，并至少满足：

- 精确 pin `v<version>-pre`、source hash 与 `cargoHash`；
- Preview 应用名、bundle ID、desktop entry、图标与 remote-server channel
  全部正确；
- stable 与 Preview 的并存/替换策略明确；
- Darwin 和 Linux 两个 output 都离线 build；
- NixOS 的 FHS/extension/language-server 行为另行验证；
- 更新脚本只选择 GitHub prerelease tag，不误选 stable。

官方 Zed Flake 可以作为该 dedicated Issue 的候选基础，但必须修正或明确接受
其 Nightly channel，且必须先解决 `flake-parts` 与 Cachix 信任关卡。它不是
当前即可直接替代上述专用 Preview package 的方案。

维护者随后明确表示 Nightly 才是目标通道，并在 Issue #25 与 ADR-0006 中完成
上述架构和供应链关卡。因此，**Stable 优先是已经被取代的调研阶段建议，不是
当前实施结论**。当前接受的选择是：

- 消费 Zed 官方 Flake 的默认 Nightly package；
- 由本仓库 `flake.lock` 固定精确 Zed revision；
- 保留上游独立 Nixpkgs、Rust、Crane 与 `flake-parts` 依赖图；
- 仅把上游 `flake-parts` 作为叶子 input 的内部实现，不改造本仓库顶层架构；
- 显式信任限定的 Zed Cachix URL 与公钥，不上传、不关闭签名校验，也不全局接受任意 Flake 配置；
- 由维护者按需要手动更新并审阅 Nightly 的 lock diff，不自动合并或激活。

不推荐把 macOS `zed@preview` cask 与 NixOS 自定义 Preview package 拼成长期
终态：它会重新产生两个安装/更新所有者，版本也不再由同一 Flake 统一。

#### Preview 的更新与构建代价

Preview 比 stable 更新更频繁。每次升级至少要更新并验证：

- Preview tag/version；
- `fetchFromGitHub` source hash；
- Rust dependency `cargoHash`；
- 可能随上游变化的 patch、native dependency 和 install phase；
- macOS 与 Linux 两个平台的 build；
- CLI、app identity、settings 路径、remote server 与扩展行为。

Zed 是大型 Rust workspace，Nixpkgs package 还构建 WebRTC、editor、CLI 和默认
remote server。自定义 Preview derivation 通常不能假设
`cache.nixos.org` 已有对应 binary cache，因此每个 host architecture 可能进行
完整本地源码编译，消耗显著的时间、CPU、内存和磁盘。Preview 的高频发布会把
这种成本从偶发升级变成持续维护工作。

所以若目标只是“尽快获得新功能”，调研阶段建议的顺序是：

1. 先确认所需功能是否已经进入本仓库下次 Nixpkgs stable 更新；
2. 必须提前使用时，把 Preview 作为有到期条件的临时实验，而不是默认跨平台
   基线；
3. 实验成功且长期价值明确后，再决定是否承担独立 package 的维护成本。

## 4. 配置文件、格式和层级

### 4.1 用户配置路径

当前 Zed 源码把用户配置放在：

- macOS：`~/.config/zed/`；
- Linux/FreeBSD：`$XDG_CONFIG_HOME/zed/`，通常为 `~/.config/zed/`；
- Windows：Roaming AppData 下的 `Zed`。

`settings.json`、`keymap.json`、`tasks.json` 和 `debug.json` 都位于该 config directory；扩展则位于独立的 data directory。[Zed `paths.rs`](https://github.com/zed-industries/zed/blob/8c7811ea7291dbfb59bf959400f385565e3dae77/crates/paths/src/paths.rs)

官方 FAQ 和 keymap 文档也把 macOS/Linux 的用户配置列为 `~/.config/zed/settings.json` 与 `~/.config/zed/keymap.json`。[Zed FAQ](https://zed.dev/faq) [Zed key bindings](https://zed.dev/docs/key-bindings)

注意：remote-development 页面仍出现 macOS `~/.zed/settings.json` 的旧描述，与当前源码及其他文档不一致。因此实现时应以当前锁定版本源码和构建结果为准，并在真实机器上验证，不应照抄该旧路径。[Zed remote development](https://zed.dev/docs/remote-development)

### 4.2 JSON 与 UI 写入

Zed 的配置文件名虽然是 `.json`，解析器支持注释；官方默认 settings 本身使用注释和 trailing comma 风格，settings UI 会更新用户设置文件。[Zed 默认 settings](https://github.com/zed-industries/zed/blob/main/assets/settings/default.json) [Zed settings store](https://github.com/zed-industries/zed/blob/8c7811ea7291dbfb59bf959400f385565e3dae77/crates/settings/src/settings_store.rs)

这与当前已批准的 VS Code 原则一致：如果希望 UI 和扩展继续写配置，就不能把 live 文件永久链接成只读 Nix Store 文件。

### 4.3 配置层级

Zed 至少存在以下层级：

- 应用默认 settings；
- extension/global settings；
- 用户 settings；
- macOS/Linux/Windows 与 release-channel 覆盖；
- remote server settings；
- 工作区及子目录中的 `.zed/settings.json`；
- `.editorconfig` 项目设置；
- 可临时叠加的 settings profile。

源码中的合并顺序表明默认值先合并 extension/global，再合并用户与用户的 OS/release-channel 覆盖，之后合并 server，最后按工作区路径叠加 project settings。[Zed settings store 合并逻辑](https://github.com/zed-industries/zed/blob/8c7811ea7291dbfb59bf959400f385565e3dae77/crates/settings/src/settings_store.rs)

官方 remote-development 文档给出的职责边界很适合本仓库：

- UI 字体等放 local/user settings；
- formatter、indent、language server 等项目行为优先放 `.zed/settings.json` 或 `.editorconfig`；
- 远端路径、proxy 等放 server settings；
- 本地与远端不会自动读取彼此的主 settings。[Zed remote development](https://zed.dev/docs/remote-development)

因此不要把项目专属 formatter/LSP 选择强行提升为所有主机共享的 Home Manager 用户配置；项目自己的 dev shell 和项目配置仍应是事实来源。

## 5. CLI

官方 Zed CLI 支持：

- `zed <path>`；
- `--wait`；
- `--new`、`--add`、`--reuse`；
- `--diff`；
- `--user-data-dir`；
- shell completions；
- 作为 `EDITOR="zed --wait"` / `VISUAL="zed --wait"`。

macOS 官方 app 通过 command palette 把 CLI 安装到 `/usr/local/bin/zed`；Linux 包通常自带 CLI，但名称可能是 `zed` 或 `zeditor`。[Zed CLI Reference](https://zed.dev/docs/reference/cli)

Nixpkgs 明确把主程序命名为 `zeditor`，Home Manager 的 `programs.zed-editor.defaultEditor` 会基于 package main program 生成 `EDITOR`/`VISUAL`，而不是假设命令叫 `zed`。[Nixpkgs Zed package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/ze/zed-editor/package.nix) [Home Manager Zed module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/programs/zed-editor.nix)

这说明可跨编辑器抽象的是“默认编辑器必须提供阻塞式 CLI”这一契约，不应抽象具体可执行文件名。选择 Zed 为主编辑器时，也应只让一个模块拥有 `EDITOR` 和 `VISUAL`，避免 Helix、VS Code 和 Zed 多处竞争。

## 6. 扩展与语言工具

### 6.1 扩展状态

Zed 扩展安装位置为：

- macOS：`~/Library/Application Support/Zed/extensions`；
- Linux：`$XDG_DATA_HOME/zed/extensions` 或 `~/.local/share/zed/extensions`。

目录内有 `installed` 和 `work`；后者可包含扩展下载的 language server 等文件。它们属于可变状态，不应整体链接进 Nix Store。[Installing Extensions](https://zed.dev/docs/extensions/installing-extensions)

### 6.2 声明式“自动安装”并不是版本锁

Zed 的 `auto_install_extensions` 可以把扩展 ID 标为 `true`（自动安装）或 `false`（不要安装）；已安装扩展默认在启动时自动更新，也可通过 `auto_update_extensions.<id> = false` 固定在当前已安装版本。[All Settings：extensions](https://zed.dev/docs/reference/all-settings)

这不是完整的 Nix 式锁定：

- `true` 只表达安装意图，不包含扩展版本或内容 hash；
- 扩展实体和 work 目录仍是 live 可变状态；
- Zed 自身或扩展可能下载 language server 和其他工具。

因此建议：

- Phase 4 先保留扩展可变；
- 把确属所有桌面主机的少量扩展 ID 作为未来可选基线；
- macOS-only、Linux-only 和 local-only 扩展分别分类；
- 不尝试把 VS Code Marketplace ID 转换为 Zed 扩展 ID；
- 不把扩展目录复制进 Git。

### 6.3 NixOS 的额外边界

Zed 会从项目环境的 `PATH` 查找部分 language server，找不到时可能自行安装。官方列举了 Go、Zig、Rust、C、TypeScript 等查找场景。[Zed environment](https://zed.dev/docs/environment)

当前 Home Manager Zed module 提供 `extraPackages`，会包装 Zed 并把指定包追加到 `PATH`；当前 Nixpkgs package 则提供 FHS 变体，专门缓解扩展所带预编译二进制在 NixOS 上的动态链接问题。[Home Manager Zed module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/programs/zed-editor.nix) [Nixpkgs Zed package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/ze/zed-editor/package.nix)

未来 NixOS 应在真实 build/test 后，从以下方案中选择：

1. 优先让项目 dev shell 提供 language server；
2. 少量通用工具通过 `extraPackages` 暴露；
3. 扩展确需通用 Linux 二进制时评估 `pkgs.zed-editor.fhs`；
4. 只有前述路径不足时，才另开 Issue 评估 `nix-ld`。

## 7. Zed 账户与 Settings Sync

Zed 登录目前只被官方列为实时协作，以及使用 Zed 托管 LLM 时的必要条件；普通编辑功能和 BYOK AI 不要求登录。[Authenticate with Zed](https://zed.dev/docs/authentication)

截至 2026-07-24，Zed 官方 roadmap：

- 仍把 “Settings Sync: Built-in synchronization support” 列为开放计划；
- 同时把具体的 “Settings Sync” 实现项列为 **In progress**。

来源：[Zed Roadmap](https://zed.dev/roadmap) [Settings Sync tracking issue #5010](https://github.com/zed-industries/zed/issues/5010) [Settings Sync implementation issue #59978](https://github.com/zed-industries/zed/issues/59978)

所以当前不能把 Zed 登录等同于 VS Code Settings Sync，也不能假设 settings、keymaps 或扩展已经跨设备同步。即使未来功能发布，也需要先查清：

- 同步哪些文件和字段；
- 是否同步扩展及版本；
- macOS/Linux 是否支持排除项；
- 与 Nix 基线冲突时谁获胜；
- 是否能关闭或删除云端数据。

在此之前，Git 基线 + 人工配置回流仍是唯一可审计的跨机器机制。

## 8. Home Manager 当前能力及其语义

本仓库固定的 Home Manager revision
`4ce190229c73d44536caa7072f6308fb2d8feeb3` 已提供
`programs.zed-editor`，包括：

- `package`；
- `defaultEditor`；
- `extraPackages`；
- `userSettings`；
- `userKeymaps`；
- `userTasks`；
- `userDebug`；
- `extensions`；
- `themes`；
- `installRemoteServer`；
- settings/keymap/tasks/debug 各自的 `mutableUser*` 开关。

来源：[固定 revision 的 Home Manager Zed module](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/programs/zed-editor.nix)

这里最重要的不是“有模块”，而是 mutable 模式的准确行为：

- `mutableUserSettings = false`：生成只读 `xdg.configFile`，不符合本次允许 UI 写入的要求；
- `mutableUserSettings = true`（默认）：activation 读取 live JSON5/JSONC，再执行 `$dynamic * $static`；
- 未声明的 live 键可以保留；
- Nix 声明的 static 键每次 activation 都覆盖同名 live 键；
- `extensions` 被转换为 `auto_install_extensions.<id> = true`；
- keymap/tasks/debug 也会在 activation 合并，而不是只在首次缺失时 seed。

因此它虽然允许 Zed 写文件，却**不是**当前 VS Code 已批准的“缺失时 seed、此后绝不覆盖”模型。

如果维护者坚持同一套边界，则未来实现可以：

- 使用 Home Manager 模块管理 package、`defaultEditor` 和必要的 `extraPackages`；
- 不通过 `userSettings` 声明需要自由修改的 live 键；
- 对 settings/keymap/tasks/debug 采用经过审查的 seed-only 机制，或暂不 seed；
- 定期人工回流时更新各编辑器自己的基线。

如果维护者愿意接受“声明键由 Nix 强制，未声明键可写”的模型，则可直接使用 `mutableUserSettings = true`，但这是一项新的所有权决策，不能因为选项名叫 mutable 就默认接受。

## 9. 哪些可以跨编辑器抽象

| 能力 | 建议 | 原因 |
| --- | --- | --- |
| 默认编辑器角色 | 抽象 | 只需要统一 `EDITOR`/`VISUAL` 与 `--wait` 契约 |
| 外部 CLI、Git、shell | 共享 | 本来就属于 `home/common` 或项目 dev shell |
| direnv/mise 环境 | 共享 | Zed 会读取登录 shell 和项目环境；编辑器不应重新拥有 runtime |
| 项目格式化/lint 规则 | 项目共享 | 应留在项目配置，不复制到个人编辑器 settings |
| `.editorconfig` | 项目共享 | Zed 原生读取；它比个人 UI 配置更接近跨工具标准 |
| 字体/主题/缩进偏好 | 只共享“意图” | 两个编辑器的字段、值域、主题生态不同 |
| 常用快捷键语义 | 只共享文档/验收 | Zed action/context 与 VS Code command/when clause 不同 |
| 应用安装 | 共享桌面角色组合 | 具体 package 与 CLI 仍各自拥有 |

Zed 预置 VS Code base keymap，并支持 `secondary-` 映射 macOS Command 与 Linux/Windows Control；这有助于保持操作习惯，但自定义 action 和 context 仍是 Zed 专属语法。[Zed key bindings](https://zed.dev/docs/key-bindings)

## 10. 哪些不应跨编辑器抽象

以下内容应明确分开：

- VS Code `settings.json` 与 Zed `settings.json`；
- VS Code extension IDs 与 Zed extension IDs；
- VS Code `keybindings.json` 与 Zed `keymap.json`；
- VS Code tasks/debug schema 与 Zed tasks/debug schema；
- VS Code Profiles/Settings Sync 与 Zed settings profiles/未来 Settings Sync；
- VS Code `code` CLI 与 Nixpkgs Zed 的 `zeditor` CLI；
- 各自的 authentication、AI provider、token、database、history、workspace state；
- 平台专属 GUI、GPU、FHS、app bundle 和 data path。

不要建立类似：

```nix
editors.commonSettings = {
  fontSize = 15;
  formatOnSave = true;
  extensions = [ "nix" ];
};
```

然后自动生成完整 VS Code/Zed 配置。它会迅速遇到值域差异、语言级覆盖、插件能力差异和平台例外，最终成为比两份小配置更难审计的翻译层。

## 11. 推荐的仓库边界

后续实现可考虑以下职责，不代表本调研授权创建这些文件：

```text
modules/home/common/
└── cli/                         # Git、direnv、mise、LSP/formatter 的共享所有权

modules/home/desktop/editors/
├── default.nix                  # 只组合桌面编辑器角色
├── zed/                         # Zed package、基线和 editor-specific 意图
│   ├── default.nix
│   └── settings.jsonc
└── vscode/                      # VS Code package、基线和 editor-specific 意图
    ├── default.nix
    └── settings.jsonc

modules/home/darwin/editors/     # 只有确有 macOS path/UI 差异时才放 adapter
modules/home/linux/              # 未来放 Zed FHS/GPU/desktop integration 差异
hosts/<host>/                    # 只选择主编辑器或主机例外，不复制通用配置
```

设计原则：

- “Zed 是主编辑器”应只有一个事实来源；
- “VS Code 是否仍安装”是独立布尔决策，不应隐含在 Zed 模块中；
- `common` 保持 headless-safe，不安装 Zed 或 VS Code GUI；
- 桌面层可复用 package 与真正相同的 Zed 基线；
- 平台层只保存被证据证明的平台差异；
- local-only、登录态、API key、数据库、history、扩展 work directory 不进入 Git。

## 12. 对当前 Phase 4 的实施步骤

1. 在 Issue #25 的独立分支提交已接受的 ADR-0006 与本调研记录。
2. 盘点脱敏的 Zed 与 VS Code 事实：安装来源、版本、CLI、settings/keymap/tasks/debug 是否存在、扩展 ID；不记录 token 或账号标识。
3. 由维护者按真实用途确认扩展的保留、排除和 shared / Darwin / Linux / local 分类，不把历史扩展清单整体声明到 Nix。
4. 让 Zed 成为唯一的主编辑器角色；VS Code 与 Helix 可以保留，但不得竞争 `EDITOR` / `VISUAL`。
5. 两种编辑器都采用 seed-only writable baseline：只在 live 配置不存在时初始化，后续通过人工配置回流维护，不在 activation 时覆盖声明键。
6. 引入锁定的官方 Zed Nightly package 与限定 Cachix，只做离线求值和 build；验证 Nightly identity、CLI、macOS bundle 和不覆盖边界。
7. 对官方 `x86_64-linux` Nightly package 至少完成求值或可行性验证；NixOS GPU、FHS、Wayland/X11、扩展和 language server 的真实集成留到 Phase 5/6。
8. 按需要手动更新 Zed lock，不自动合并或激活。真实迁移、旧应用卸载和默认编辑器切换分别保留人工 approval gate。

## 13. 最终判断

Zed 官方 Flake 的 Nightly package 可以成为 macOS 与未来 NixOS 的共同主编辑器来源。但最好的“通用性”不是把 VS Code 与 Zed 压成一套配置，而是：

- 共享工具链、项目规则和默认编辑器契约；
- 分离每个编辑器的声明和 live state；
- 显式分离 macOS/Linux 差异；
- 用人工回流维持可审计基线；
- 等 Zed Settings Sync 正式发布后再重新评估云同步边界。

这与仓库“Git 同步声明、可变数据另行管理”的既有架构一致，也避免为两个快速演进的 settings schema 创建新的自制同步系统。
