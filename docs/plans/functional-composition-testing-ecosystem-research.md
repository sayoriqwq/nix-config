# 函数式组合与关键 seam 测试的 Nix 生态研究

> 对应决策票：[调研函数式组合与关键 seam 测试的成熟 Nix 生态](https://github.com/sayoriqwq/nix-config/issues/189)。资料与 GitHub 元数据核对日期为 2026-08-23。
>
> 本文是 V3 implementation issues 的技术输入，不修改 Flake、lock file、测试或运行中的机器，也不授权 activation、server 安装或生产操作。

## 1. 结论先行

推荐的最小组合不是引入一个新的“函数式 Nix 框架”，而是充分使用仓库已经锁定的原生接口：

```text
函数式 Intent
  nixpkgs.lib.pipe + 普通纯函数

最终组合
  nixosSystem / darwinSystem + 显式 module imports

默认 Host seam
  直接构建三个既有 host system derivation

少量 contribution seam（逐项批准后）
  lib.debug.runTests + lib.debug.throwTestFailures

Operation seam（逐项批准后）
  pkgs.testers.runNixOSTest
  + 已锁定的 disko / nixos-anywhere --vm-test（仅 server recovery）
```

这组能力全部来自当前已经存在的 Nixpkgs、nix-darwin、Home Manager、disko 和 nixos-anywhere inputs；**无需新增 Flake input、lock node、测试框架、registry、自动目录扫描或第二套 Module System application**。

面向本仓库的最终分类是：

- **直接采用**：`nixpkgs.lib.pipe`、普通 `lib` list/attrset 函数、各平台已有 system constructor、直接 host derivation checks、按需 `lib.debug.runTests`/`throwTestFailures`、按需 `pkgs.testers.runNixOSTest`；server recovery 继续复用已经锁定的 disko 与 nixos-anywhere `--vm-test`。
- **仅借鉴**：`nix-unit` 的 `{ expr; expected; }` 测试形状和逐项报错目标；不引入其 runner。
- **暂缓**：`nix-fast-build`。只有 V3 的少量显式 checks 出现可测量的串行评估/构建瓶颈时，才把它作为开发或 CI 调用工具评估；不让它参与配置语义。
- **拒绝**：flake-parts、flake-utils、Blueprint、Snowfall Lib、Flakelight、divnix/std、Haumea、import-tree，以及面向本问题的 Namaka、NixTest、nix-unit/lix-unit、nix-std、Yants、nix-effects。拒绝原因不是质量差，而是无法比原生基线删除更多真实代码，或直接违反显式 imports、无 discovery、无 schema/registry/额外组合层的已批准约束。

## 2. 已批准边界与研究判据

本文不重新讨论以下决定：

- Host 是 composition root；Flake 只实例化 host；host 通过显式 imports 选择 Intent 或独立 Software Capability。
- `IntentTransform = IntentState -> IntentState`，组合顺序用 `lib.pipe` 从左到右表达。
- 不建立 capability registry、自动目录扫描、Workflow/Relation、独立 `contract.nix`、`internal/` namespace 或 Composition test layer。
- Host 是唯一默认测试 seam。Software contribution 与 Operation 只有逐项通过删除测试并获批后才增加窄测试。
- V3 删除全部旧测试并按 TDD 从零开始；旧测试实现不是迁移资产。

候选必须依次通过四个问题：

1. 它替代哪一段**真实且仍需要**的本仓库代码？
2. 删除它后，复杂度是否会实质回到仓库，而不只是少一个品牌名？
3. 它是否保持显式 host imports 和公开 seam，而不是引入 discovery、registry 或第二套 schema？
4. 相比已经锁定的 `nixpkgs.lib`，新增 input、lock、构建、缓存、CI 和学习成本是否更小？

文中“事实”来自上游文档、源码或 GitHub 元数据；“本仓库判断”是把这些事实投影到上述约束后的推论。

## 3. 零新增依赖基线：只用已经锁定的原生能力

### 3.1 `lib.pipe` 已经是需要的 Intent 组合器

**上游事实：** Nixpkgs 的 `lib.pipe` 把一个值从左到右依次传给函数列表。仓库 root inputs 当前分别锁定 Linux Nixpkgs `fd14620` 与 Darwin Nixpkgs `104240a`；两者的实现都是 `builtins.foldl' (x: f: f x)`，并明确劝阻再增加 `compose = flip pipe` 一类容易混淆方向的接口。[Linux root input 源码](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/lib/trivial.nix#L152-L157)，[Darwin root input 源码](https://github.com/NixOS/nixpkgs/blob/104240a772428cc2e20d8fd86c9ddbb886bbaff2/lib/trivial.nix#L152-L157)，[Nixpkgs `lib` 手册](https://nixos.org/manual/nixpkgs/stable/#function-library-lib.trivial.pipe)

`lib` 还已经提供 `map`、`filter`、`concatMap`、`foldl'`、`genAttrs`、`mapAttrs`、`optional`、`optionals`、`unique` 等普通 list/attrset 变换，以及固定点函数；这些都是纯 Nix 值上的普通函数，不要求额外框架。[Nixpkgs Library Functions](https://nixos.org/manual/nixpkgs/stable/#sec-functions-library)

**本仓库判断：** `IntentTransform` 本身就是 Nix 函数，不需要 class、effect system、monad library 或自建 compose combinator。V3 的 `intentLib` 最多只保留真正属于本仓库领域的两个窄职责：构造最小初始 state，以及把最终 state 降为平台原生 module imports。凡是只包装 `pipe`、`map`、`foldl'`、list append 或 attrset traversal 的 helper 都应删除。

删除测试：若删除第三方函数库，下面的权威表达仍完整成立，且不会损失类型或执行语义，因此第三方库不通过删除测试。

```nix
lib.pipe initialIntentState [
  software.zed.guiEditor
  software.git.versionControl
  software.lazygit.gitTui
  (software.zed.addTask { /* approved contribution */ })
]
```

### 3.2 不为 IntentState 再启动一套 Module System

**上游事实：** `lib.evalModules` 把 module list 合并为带 option declaration、类型检查和扩展能力的配置；官方文档说它通常是一个 application 只调用一次的入口。`specialArgs` 可参与 imports 求值，但官方警告不要用 `specialArgs.lib` 注入自定义库，以免破坏 module interoperability。[Module System：`lib.evalModules`](https://nixos.org/manual/nixpkgs/stable/#module-system-lib-evalModules)，[锁定 Linux root input 源码](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/lib/modules.nix#L83-L108)

Nixpkgs 的 `lib.nixosSystem`、nix-darwin 的 `lib.darwinSystem` 和 Home Manager 的 `lib.homeManagerConfiguration` 都已经建立在各自的 Module System application 上。[锁定 Nixpkgs `nixosSystem` 源码](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/flake.nix#L58-L82)，[锁定 nix-darwin `darwinSystem` 源码](https://github.com/nix-darwin/nix-darwin/blob/15abb8c98f336cd8bd840d71059adebabe60bf04/flake.nix#L18-L31)，[锁定 Linux Home Manager library 源码](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/lib/default.nix#L1-L40)，[锁定 Darwin Home Manager library 源码](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/lib/default.nix#L1-L20)

**本仓库判断：** V3 应继续让原生 Module System 负责最终 option 合并、类型、assertions 和冲突诊断，但不应用 `evalModules` 再把 `IntentState` 变成一套 options/schema。那会创建被否定的 Composition layer，并把一个简单 state pipeline 变成第二个 fixed point。`intentLib.realize` 应产生普通、显式的 NixOS/nix-darwin/Home Manager module lists，然后交给既有 constructors。

### 3.3 Host seam 不需要测试框架

**上游事实：** `nix flake check` 会求值标准 flake outputs，并构建 `checks.<system>.<name>` 中的 derivations；它也会检查 `nixosConfigurations.<name>.config.system.build.toplevel` 的输出形状。[Nix reference：`nix flake check`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-check.html)

本仓库已经有三个 production composition outputs：

- `darwinConfigurations.macbook.system`；
- `nixosConfigurations.nixbox.config.system.build.toplevel`；
- `nixosConfigurations.server.config.system.build.toplevel`。

**本仓库判断：** Host seam 的 red/green 目标就是这些真实 derivations。开发中直接构建受影响 host；若希望 `nix flake check` 聚合，`checks` 只需给同一 derivation 一个显式名字，不需要 wrapper、registry 或 framework。Host interface 测试也不应另造一个假的 `evalModules` fixture，因为 production constructors 已经是更真实且已经存在的 caller。

这意味着 V3 的默认测试 harness 是 **0 行**；可选的 checks 映射只是约 3 个显式属性，而不是一个 framework。

### 3.4 窄 Software contribution 可以使用 `lib.debug.runTests`

**上游事实：** 当前锁定的两套 root Nixpkgs 都提供 `lib.debug.runTests` 与 `lib.debug.throwTestFailures`；前者接受以 `test` 开头的 `{ expr; expected; }` 测试 attrset 并返回失败列表，后者可以格式化失败并抛错。[锁定 Linux `runTests` 源码](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/lib/debug.nix#L512-L538)，[锁定 Linux `throwTestFailures` 源码](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/lib/debug.nix#L619-L672)，[锁定 Darwin `runTests` 源码](https://github.com/NixOS/nixpkgs/blob/104240a772428cc2e20d8fd86c9ddbb886bbaff2/lib/debug.nix#L512-L538)

**本仓库判断：** 只有 `zed.addTask` 这类已经逐项批准的纯 contribution interface 需要 eval-time equality test 时，才使用这两个函数。测试直接输入公开函数并比较公开结果；不比较 `IntentState` 内部字段、pipeline 顺序或目录布局。一次失败可能阻止同一 suite 的其余求值，这是原生基线的限制，但在“极少数、窄 suite”下不足以证明需要额外 runner。

### 3.5 Operation seam 使用 `pkgs.testers.runNixOSTest`

**上游事实：** NixOS 的官方 test driver 启动一个或多个 QEMU VM 或 systemd-nspawn container，用 Python `testScript` 操作机器；仓库外的项目应调用 `pkgs.testers.runNixOSTest`，其返回值就是可放入 Flake checks 的 derivation。[NixOS Manual：NixOS Tests](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)，[锁定 Linux root input 的 `runNixOSTest` 源码](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/build-support/testers/default.nix#L194-L210)，[nix.dev VM integration tutorial](https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html)

测试 VM 可组合与 production 相同的 NixOS modules；test-only network、ephemeral credentials 和故障注入留在 test module 内，production graph 不反向 import 测试。

**本仓库判断：** 这是 server boot/service/network/SSH/firewall 等必须运行才能证明的 Operation seam 首选。它只适用于 NixOS guest，不会证明 macOS GUI、launchd 或实体硬件运行态；这些仍由最终人工 activation/smoke 关卡证明。

### 3.6 Server recovery 继续使用已经锁定的 disko 与 nixos-anywhere

**上游事实：** disko 把 disk partition、format 和 mount 声明为 Nix 配置，并明确支持和 nixos-anywhere 配合；nixos-anywhere 的 `--vm-test` 会在 VM 内构建系统并测试 disk 配置，不接触真实 target。[disko 官方仓库](https://github.com/nix-community/disko)，[nixos-anywhere 官方仓库](https://github.com/nix-community/nixos-anywhere)，[`--vm-test` reference](https://github.com/nix-community/nixos-anywhere/blob/main/docs/reference.md#L79-L80)

两者已经是当前 lock graph 的 inputs；当前分别锁定到 [disko `ff8702b`](https://github.com/nix-community/disko/commit/ff8702b4de27f72b4c78573dfb89ec74e36abdf1) 和 [nixos-anywhere `5887f1c`](https://github.com/nix-community/nixos-anywhere/commit/5887f1c72fbf0e88000716237194de414d2299ee)。

**本仓库判断：** 新 recovery Operation 应从需求重新写测试，不迁移旧 runner；但无需重写 partition/install VM engine。最小组合是：`--vm-test` 证明 disko/install，`runNixOSTest` 证明启动后的 service/network/SSH/firewall 行为。是否还需要一个无 target 参数的薄命令入口，应由 recovery implementation issue 的删除测试决定，不由本研究预建通用 operation framework。

## 4. 社区候选评估

### 4.1 采用与维护信号快照

Stars、push 和 release 是采用/维护信号，不代表架构适配性。以下数字来自 2026-08-23 的 GitHub repository API 快照；“最近提交”链接到当时 HEAD 或本仓库锁定 revision。

| 候选 | Stars | License | 最近 release / commit | 解决的问题 | 本仓库分类 |
| --- | ---: | --- | --- | --- | --- |
| [Nixpkgs](https://github.com/NixOS/nixpkgs) | 25,902 | MIT | root inputs：[Linux `fd14620`](https://github.com/NixOS/nixpkgs/commit/fd1462031fdee08f65fd0b4c6b64e22239a77870)、[Darwin `104240a`](https://github.com/NixOS/nixpkgs/commit/104240a772428cc2e20d8fd86c9ddbb886bbaff2) | lib、Module System、testers、NixOS | 直接采用 |
| [Home Manager](https://github.com/nix-community/home-manager) | 10,270 | MIT | [2026-08-22 HEAD](https://github.com/nix-community/home-manager/commit/ec1a8fdf74ed3f276148ee106299a2ba0e65d51f)；本仓库另锁 release/master inputs | 用户层 Module System | 继续采用 |
| [nix-darwin](https://github.com/nix-darwin/nix-darwin) | 5,861 | MIT | [2026-08-16 HEAD](https://github.com/nix-darwin/nix-darwin/commit/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48) | Darwin system constructor/modules | 继续采用 |
| [disko](https://github.com/nix-community/disko) | 3,274 | MIT | [v1.13.0](https://github.com/nix-community/disko/releases/tag/v1.13.0)；[锁定 `ff8702b`](https://github.com/nix-community/disko/commit/ff8702b4de27f72b4c78573dfb89ec74e36abdf1) | 声明式 disk/install seam | recovery 直接采用 |
| [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) | 3,393 | MIT | [1.13.0](https://github.com/nix-community/nixos-anywhere/releases/tag/1.13.0)；[锁定 `5887f1c`](https://github.com/nix-community/nixos-anywhere/commit/5887f1c72fbf0e88000716237194de414d2299ee) | 安装与 `--vm-test` | recovery 直接采用 |
| [flake-utils](https://github.com/numtide/flake-utils) | 1,621 | MIT | [v1.0.0](https://github.com/numtide/flake-utils/releases/tag/v1.0.0)，[2024-11-13 commit](https://github.com/numtide/flake-utils/commit/11707dc2f618dd54ca8739b309ec4fc024de578b) | per-system output 生成 | 拒绝 |
| [flake-parts](https://github.com/hercules-ci/flake-parts) | 1,449 | MIT | [2026-08-01 commit](https://github.com/hercules-ci/flake-parts/commit/427bf4bd9435fdf21321c8cc628c24efc14c0f7a) | 用 Module System 组织 Flake | 拒绝 |
| [Snowfall Lib](https://github.com/snowfallorg/lib) | 627 | Apache-2.0 | [2026-07-17 commit](https://github.com/snowfallorg/lib/commit/6ee3542cb459ca4b038cfe50ceb8797f05cdabad)；README 公开征集 maintainer | host/module/package 自动组织 | 拒绝 |
| [nix-fast-build](https://github.com/Mic92/nix-fast-build) | 534 | MIT | [2.0.0](https://github.com/Mic92/nix-fast-build/releases/tag/2.0.0)，[2026-08-21 commit](https://github.com/Mic92/nix-fast-build/commit/c65830739d075c82b01470058adc4846e9cb7f62) | 并行 evaluate/build checks | 暂缓；可作外部工具 |
| [divnix/std](https://github.com/divnix/std) | 484 | REUSE 多许可证，核心多为 Unlicense | [2025-08-17 commit](https://github.com/divnix/std/commit/4177882c378184b795fa97594b5effd062213891) | Cells/Blocks/SDLC framework | 拒绝 |
| [Blueprint](https://github.com/numtide/blueprint) | 469 | MIT | [2026-04-15 commit](https://github.com/numtide/blueprint/commit/56131e8628f173d24a27f6d27c0215eff57e40dd)；上游标记 experimental | 目录约定映射 flake outputs | 拒绝 |
| [Haumea](https://github.com/nix-community/haumea) | 417 | MPL-2.0 | [v0.2.2](https://github.com/nix-community/haumea/releases/tag/v0.2.2)，[2026-08-16 commit](https://github.com/nix-community/haumea/commit/3c4496e076bf4f85ebffe196df1419f13273d076) | filesystem-based module loading | 拒绝 |
| [Flakelight](https://github.com/nix-community/flakelight) | 409 | MIT | [2026-08-17 commit](https://github.com/nix-community/flakelight/commit/57e75ff8032ad9aa997a1c082c18f32f30e0ee7e) | Flake module framework/autoload | 拒绝 |
| [import-tree](https://github.com/denful/import-tree) | 323 | Apache-2.0 | [v0.2.0](https://github.com/denful/import-tree/releases/tag/v0.2.0)，[2026-07-17 commit](https://github.com/denful/import-tree/commit/4ebb10ae17d5f1ad366e7aef5b92cb8eecf24f69) | 递归 import module tree | 拒绝 |
| [nix-unit](https://github.com/nix-community/nix-unit) | 136 | GPL-3.0 | [v2.35.1](https://github.com/nix-community/nix-unit/releases/tag/v2.35.1)，[2026-07-24 commit](https://github.com/nix-community/nix-unit/commit/b3d16367c54621fd073aa8c1dd510042f771f624) | Nix eval unit test、隔离求值错误 | 仅借鉴形状；runner 拒绝 |
| [Namaka](https://github.com/nix-community/namaka) | 144 | MPL-2.0 | [v0.2.1](https://github.com/nix-community/namaka/releases/tag/v0.2.1)，[2026-08-16 commit](https://github.com/nix-community/namaka/commit/f33032966ce67bb9740278c0b7215e2fe47ca25b) | snapshot testing | 拒绝 |
| [NixTest](https://github.com/jetify-com/nixtest) | 54 | Apache-2.0 | [2024-04-09 commit](https://github.com/jetify-com/nixtest/commit/cdd1c7ed6cfb49e3c06702cd21f90924378f2083) | pure-Nix unit test discovery | 拒绝 |

另行发现但未进入主表的候选包括 [nix-std](https://github.com/chessai/nix-std)（141 stars，2024-03 后无提交）、[Yants](https://github.com/divnix/yants)（42 stars，API 自称未稳定，2023-06 后无提交）和 [nix-effects](https://github.com/kleisli-io/nix-effects)（43 stars，[v0.16.0](https://github.com/kleisli-io/nix-effects/releases/tag/v0.16.0)）。它们分别提供 no-Nixpkgs stdlib、runtime type checker、typed effect/DSL kernel；本仓库已经依赖 Nixpkgs，且明确不要额外 schema/DSL，因此都不进入采用集。

### 4.2 `nix-unit`：功能真实，但跨 Nix/Lix 边界不成立

**上游事实：** nix-unit 与 `lib.debug.runTests` 使用同一测试形状，并能通过 Nix evaluator C++ API 让某个测试发生求值错误时仍继续报告其他测试。上游同时明确写明：nix-unit 支持 Nix、不支持 Lix；Lix 需要独立 fork。[nix-unit README](https://github.com/nix-community/nix-unit#why-use-nix-unit)

它接入普通 Flake checks 时并不是一个零胶水函数：官方示例需要把 nix-unit binary 放进 `nativeBuildInputs`、在 sandbox 内设置 eval store、override input，再调用 `nix-unit --flake`。[官方 Flake check 示例](https://github.com/nix-community/nix-unit/blob/main/lib/flake-checks/flake.nix)

Lix fork [adisbladis/lix-unit](https://github.com/adisbladis/lix-unit) 只有 16 stars，已归档，最近源码 commit 为 [2024-12-08](https://github.com/adisbladis/lix-unit/commit/ff4bfb24cf423c1427adbf62a28f76796f96de7d)。

**本仓库判断：** MacBook 明确由 Lix 管理，而两个 Linux host 使用 Nix；引入 nix-unit 会迫使同一测试 seam 使用两个 runners，或者只在 Linux 执行，从而扩大而非缩小认知面。当前批准的 contribution tests 很少，`runTests + throwTestFailures` 足够。分类：测试形状和“独立失败报告”目标仅借鉴，runner 拒绝；若未来上游出现同一 runner 同时可靠支持锁定 Nix/Lix，且窄 eval suites 已多到原生 fail-fast 明显妨碍开发，再重新评估。

### 4.3 Flake framework 与 per-system helper

#### flake-parts

**上游事实：** flake-parts 用 Module System 表达标准 Flake attributes，提供 `perSystem` 和可扩展 module ecosystem。[官方 README](https://github.com/hercules-ci/flake-parts)

**本仓库判断：** 它能整理复杂 Flake，但 V3 的目标恰好是删除约两百行旧 tests/check wiring 后只保留三个显式 host derivations 和极少数 Operation checks。为十几行显式 outputs 引入第二个 Module System application、input 和选项词汇，没有净删除；仓库规范也要求大型框架有独立 Issue/ADR。分类：拒绝。

#### flake-utils

**上游事实：** `eachSystem`/`eachDefaultSystem` 生成 per-system attributes；默认 systems 是四个平台，也可通过额外 systems input 覆盖。[官方 README](https://github.com/numtide/flake-utils#usage)

**本仓库判断：** 本仓库不是“同一 package 在四个平台”的矩阵，而是三个具名 host，且 `aarch64-darwin` 与 `x86_64-linux` 使用不同 Nixpkgs inputs。`lib.genAttrs` 已能覆盖少量 formatter/check attrset；显式写两个 platform keys 更清楚。额外 input 只隐藏了系统列表，没有删除领域代码。分类：拒绝。

#### Blueprint、Snowfall Lib、Flakelight、divnix/std

**上游事实：**

- Blueprint 按特殊目录自动映射 packages、hosts、modules 和 checks，并自标 experimental。[官方 README](https://github.com/numtide/blueprint)
- Snowfall Lib 统一发现 systems、packages、modules、shells 等；其 README 当前直接说明项目长期缺少维护者并征集接手者。[官方 README](https://github.com/snowfallorg/lib)
- Flakelight 默认可从 `./nix` 自动导入 attributes，并自动生成 per-system outputs/checks。[官方 README](https://github.com/nix-community/flakelight)
- divnix/std 以 Cells、Cell Blocks 和 SDLC targets 组织 Flake。[官方 README](https://github.com/divnix/std)

**本仓库判断：** 四者会把已经批准的 `software/`、`intents/`、显式 host imports 和原生 output constructors改写为框架目录约定、autoload 或 block type。它们删除的是显式 wiring，却新增更大的隐式规则集；同时直接违反无自动 discovery/registry/大型 framework 的约束。分类：拒绝。

### 4.4 Filesystem loaders：Haumea 与 import-tree

**上游事实：** Haumea 把目录树自动加载为 attrset，并提供 visibility、fixed point、loader 和 transformer；它明确不是 NixOS Module System。[官方 README](https://github.com/nix-community/haumea)。import-tree 会递归导入目录里的 Nix modules，并提供 filter/match/map API，主打 dendritic pattern。[官方 README](https://github.com/denful/import-tree)

**本仓库判断：** 两者确实能删除手写 import list，但本仓库把 import list 视为 host 的权威选择和可审计 interface，而不是 boilerplate。删除显式 imports 会删除需求信息；框架并不能恢复它。分类：拒绝。

### 4.5 Snapshot 与其他 unit runners

**上游事实：** Namaka 用 Haumea 自动加载 expression，并把输出保存为需要 review 的 snapshots。[官方 README](https://github.com/nix-community/namaka)。NixTest 递归查找 `_test.nix` 并比较 `actual`/`expected`；其 README 自己建议已经依赖 Nixpkgs 的项目优先使用 `lib.debug.runTests`。[官方 README](https://github.com/jetify-com/nixtest)

**本仓库判断：** Snapshot 最适合稳定的大结构输出，而 V3 明确不冻结完整 config、IntentState、package matrix 或目录。NixTest 的自动扫描冲突于无 discovery 约束，且功能少于已经锁定的 Nixpkgs baseline。分类：均拒绝。

### 4.6 `nix-fast-build`：不参与架构，只在出现瓶颈后评估

**上游事实：** nix-fast-build 使用 nix-eval-jobs 并行 evaluate/build flakes，默认针对 `.#checks`，支持 systems filter、远端 store、cache 状态跳过和 CI 结果输出。[官方 README](https://github.com/Mic92/nix-fast-build)

**本仓库判断：** 它不会减少 Intent、test 或 Flake wiring，只会改变执行速度。V3 预期 checks 数量很少，现阶段没有性能事实。分类：暂缓；若最终三端 build 的 wall-clock 形成真实瓶颈，可先作为不进入 `flake.lock` 的 maintainer/CI tool 试用，再决定是否声明 package。它不能替代 `nix flake check` 的语义合同，也不授权远端 build/deploy。

## 5. 平台适用范围与成本

| 能力 | Darwin host | NixOS host | Home Manager | 新 lock/input | CI/cache 成本 |
| --- | --- | --- | --- | --- | --- |
| `lib.pipe` 与普通 `lib` | 是，使用 Darwin 锁定 Nixpkgs | 是，使用 Linux 锁定 Nixpkgs | 是 | 0 | 纯求值，无额外 package |
| `darwinSystem` | 是 | 否 | 可在其中组合 HM module | 0（已有） | build macOS system derivation |
| `nixosSystem` | 否 | 是 | 可在其中组合 HM module | 0（已有） | build NixOS toplevel |
| `homeManagerConfiguration` | 可跨平台，但本仓库不需要新增 standalone root | 可跨平台 | 是 | 0（已有） | build HM activation package；当前由 system output覆盖 |
| `runTests` / `throwTestFailures` | 是；兼容 Lix，因为是纯 Nix library expression | 是 | 可测试纯 contribution | 0 | 只有求值；暴露为 check 时需一个微小 derivation shell |
| `runNixOSTest` | 本仓库不用于 Darwin host；recovery runner 继续放在已有 KVM 证据的 x86_64-linux nixbox，guest 是 NixOS | 是 | 只间接测试 guest 中 HM | 0 | QEMU closure 和 VM runtime 较重；应只用于 approved Operation |
| disko / nixos-anywhere `--vm-test` | source 可来自任意 Nix host，实际 recovery runner 仍按现有证据放在 x86_64 nixbox | 是 | 无 | 0（已有） | disk/install VM 重；按需运行，不放入所有轻量开发循环 |

新增社区 framework 通常至少增加一个 direct input、对应 transitive lock nodes 和一套更新兼容性；CLI runner 还会增加各平台 package 构建/下载。Pure-Nix loader 虽没有运行时 derivation，也会增加 source fetch、lock 与新的求值规则。对当前只有两个真实 platform keys、三个 hosts 的仓库，这些固定成本高于它们能删除的显式代码。

## 6. 删除测试与可量化收益

### 6.1 函数式组合

当前批准的方向只需要：

- 一个 `IntentState` 初始值；
- Software Capability / contribution 提供同型纯函数；
- `lib.pipe`；
- 一个把结果接到原生 module lists 的 realization boundary。

因此：

- 自建 `pipe`、`compose`、transform runner、list traversal、generic attrset merge：**0 行目标**；
- 第三方 FP/type/effect library：**0 个 input**；
- `intentLib` 只允许保留领域特有 constructor/realizer，具体行数由首个 TDD slice 证明，不能预建通用 framework。

### 6.2 默认 Host seam

当前 V2 有 3,282 行 `tests/**/*.nix`；`flake.nix` 共 334 行，其中 `checks` attrset 本身约 100 行，前置 test imports/wiring 另占约百行。已批准决议要求这些全部删除，而不是迁移。

V3 原生基线的目标认知面是：

- 三个既有 host output；
- 开发时三条已知 build target；
- 若需要 Flake 聚合，约三个直接 derivation aliases；
- 每个获批 Operation 一项显式 check。

采用 flake-parts、flake-utils 或 Blueprint 顶多把这十几行改写成框架 options/目录，不会继续删除 3,282 行旧 tests，因为那批代码已经由架构决议删除。它们因此没有增量收益。

### 6.3 Contribution seam

`runTests + throwTestFailures` 已提供数据结构、比较、失败列表和错误输出。第一次获批的纯 contribution test 可以直接使用；在至少两个真实测试文件出现相同 derivation wrapper 前，不建立 `mkEvalTest` harness。重复真实出现后，helper 也应保持约一个表达式的窄封装，不发展为 test registry。

`nix-unit` 能增加逐测试隔离，但要付出 Nix/Lix 双 runner 和 Flake sandbox wiring；在当前预计的极少量 contribution tests 下，删除它不会让复杂度回到仓库，因此不采用。

### 6.4 Operation seam

`runNixOSTest` 删除了自建 QEMU 生命周期、VM network plumbing、启动等待、命令执行和日志收集的必要；disko/nixos-anywhere 删除了自建 partition/install VM engine 的必要。这是真实通过删除测试的生态复用。

测试中的具体 nodes、拓扑、assertions 和 ephemeral credentials 仍然是本仓库的需求知识，不能由通用 framework 删除。V3 应重写这些窄需求，而不是寻找一个会替仓库猜测 recovery contract 的 fleet framework。

## 7. V3 implementation 的最小采用建议

1. **不新增任何生态 input。** 首个 TDD slice 只使用每个平台已经锁定的 `nixpkgs.lib`。
2. **函数式组合直接写 `lib.pipe`。** `IntentTransform` 保持普通函数；不要包装为 class、module option、effect 或 registry item。
3. **让原生 Module System 只负责最终 configuration。** Intent realization 产出显式 module lists；host 是唯一 caller；不要对 IntentState 另跑 `evalModules`。
4. **Host red test 直接指向真实 host output。** 实现前先让受影响的真实 host build 因缺少新 seam 失败，再写最小结构使其通过；不建立 Composition fixture。
5. **Contribution test 先用 `runTests`。** 只有具体公开函数已获批为 seam 时才写；若原生 fail-fast 后来成为可测量痛点，再重开 runner 选择。
6. **Recovery Operation 用 `runNixOSTest` + `--vm-test`。** 不迁移旧测试源码；复用上游 engine，重写本仓库自己的行为需求。
7. **Flake outputs 保持显式。** 两个 platform keys、三个 host checks 和少量 Operation checks 直接写出；不使用 per-system/discovery framework。
8. **暂不引入 nix-fast-build。** V3 checks 稳定后先测量 eval/build 时间；只有并行收益真实存在才另行评估调用方式。

这一建议最大限度使用社区已经维护的深层能力，同时把本仓库自己的代码限制在不可外包的领域知识：用户 Intent、Software ownership、host 选择和具体 Operation acceptance。它符合函数式 taste，但不为了“更函数式”再引入一套 DSL。

## 8. 仍需在 implementation 中用事实回答的事项

这些不是新的架构 gate，而是实现时自然得到的测量：

- 首个真实 `IntentState` 经 deletion test 后，是否真的还需要独立 `intentLib.empty`/`realize` 文件，还是局部普通函数已经足够；
- 首个获批 contribution test 是否只需一个 suite；若只有一个，不创建共享 test helper；
- 新 recovery Operation 的 `runNixOSTest` 与 `--vm-test` 是否应是两个独立 checks，还是由一个无 target runner 聚合；以失败隔离和实际运行时长决定；
- 三端最终 checks 的 wall-clock、memory 与 cache 命中是否足以证明需要 nix-fast-build；没有测量前保持零新增工具。

以上事实均可在窄 implementation issue 中通过 TDD 和构建得到，不需要在 execution gate 前继续抽象讨论。
