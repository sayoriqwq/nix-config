# macOS 副作用偏移协调讨论记录

> 状态：持续追加中的讨论日志，不是规范、ADR、实施授权或真实机器变更记录。

本文保存问题原文、已经取得的证据、当前判断和仍待讨论的方向，避免后续只剩彼此不一致的结论文档。实施范围和安全关卡仍以对应 Issue、PR、能力合同与仓库规范为准。

## 1. 来源任务

- `019ff9f2-f61c-71b2-a2de-e6bd52c12c19`：试验 macOS AeroSpace 工作区
- `019ffe79-7397-74c3-9c65-0172381621c8`：定位 macOS 窗口切换配置

这两个任务共同暴露了同一类问题：单个应用的 settings 不是完整边界。应用声明的行为还依赖 macOS 的全局快捷键、系统偏好和外部运行态；只分别描述应用与系统，会留下没有 owner、无法 readback、也无法调控的副作用偏移。

## 2. 用户问题原文

以下内容按收到时原样保存，不对术语、标点或判断作修订。

### 2026-08-14：初始问题

> [@试验 macOS AeroSpace 工作区](thread://019ff9f2-f61c-71b2-a2de-e6bd52c12c19) [@定位 macOS 窗口切换配置](thread://019ffe79-7397-74c3-9c65-0172381621c8)  这里出现了一个共性，即我们的某应用对应到了 macOS 上的一个能力。我现在想让你和我一起设计，利用 [$improve-codebase-architecture](/Users/sayori/Desktop/skills-ruler/skills/improve-codebase-architecture/SKILL.md) 的模块设计理念，只不过甚至可以跨仓库，主要梳理关系核心观点为：副作用。我认为这里其实涉及到了一个很真实的使用场景，也就是我们对 app 的 settings，只有一部分是单独的，更多的其实是会和系统本身有强耦合关系，正如当前这两个 session 遇到的情况一致。单独考虑哪一个都是搞笑的。我现在有一些初步的模糊的想法，大概是这样的：nix-config继续保持 “能力” 概念，但我们是否需要单开一个 macOS 的专门仓库，因为我的主工作区是 macOS，然后这里只负责收集和处理 副作用，其他的都无关紧要，然后 nix-config 提供接口把信息接进来。你也可以看到现有 issue 里有个 terminal 的 theme 被我拆出去了，因为这种开口实际上是默认被允许的。我们的 nix-config 的第一性目标是复现环境，以及协调 macos、nixos、server 三端，而不是一个 macOS 全量的工作站，这个职责我理解是缺失的。我目前的初步想法是一个转向 macOS 配置仓（当然也可以用 nix！），在这里协调和处理所有的副作用，后续有一个更关键的扩展需求，也就是基于当前已经大部分都以 nix 配置好的情况下（静态），把动态的副作用迁移到这个新仓去调配和管理，比如说一些用户数据等，我们现在不就是头疼这个吗？而且在雾凇拼音的小企鹅输入法迁移的时候也遇到了这个 case

### 2026-08-14：关于“偏移”的补充

> 对，为什么要显示管理副作用呢，也是这里体现到的“偏移”问题。现在的两份文档和真实情况是有差异的，且无法调控

### 2026-08-14：转为实现导向

> 先把我们讨论到的这些点，还有我的问题原文记录下来，这个后续还会追加讨论。然后现在转为实现导向，准备对刚才的两个 case 里提到的问题，你按照 1 统一收一版本出来。 [$land](/Users/sayori/.agents/skills/land/SKILL.md)

## 3. 问题拆解

当前讨论把一个 app setting 分成至少四类事实：

1. 用户希望获得的行为，例如统一的键盘导航方式；
2. 应用自身保存的设置，例如 Raycast Hyper Key 与 AeroSpace bindings；
3. macOS 同时拥有的全局设置，例如 `AppleSymbolicHotKeys`；
4. 真实机器上的当前运行态，以及从声明到运行态所需的 readback、control、rollback 和人工关卡。

如果只有前两类声明，应用配置即使各自正确，macOS 仍可能保留冲突键位。反过来，只改系统设置也无法证明应用已经采用同一份意图。这种“能力合同的期望与外部运行态事实不一致”在本仓库中称为“副作用偏移（Side-effect Drift）”。

显式管理副作用不等于把所有外部状态自动收敛。更窄的要求是：每项外部效果必须有明确 owner；能安全读取时提供 readback；能安全修改时提供边界清晰的 control 与 rollback；不适合自动修改时保留明确 human gate。

## 4. 已确认事实

### 4.1 Raycast 与 macOS symbolic hotkey

- Raycast 当前 Hyper Key 运行态启用 `Control+Option+Command`，不包含 Shift。
- macOS symbolic hotkey ID `27` 仍保存旧的四修饰键值 `[32, 49, 1966080]`，与 Raycast 当前意图不一致；目标值为 `[32, 49, 1835008]`。
- Spotlight 的 symbolic hotkey ID `64` 与 `65` 保持禁用，为 Raycast 的 `Command+Space` launcher 让出入口。
- Raycast 来源清单继续是独立声明；macOS 侧的系统快捷键副作用属于 nix-config 中的 macOS 能力边界。

### 4.2 AeroSpace 与 macOS Mission Control/Spaces

- 已确认的目标不是把 AeroSpace 合并进 Raycast Hyper Key，而是使用裸 `Control`：`Control+方向键` 聚焦、`Control+1…0` 切换工作区、`Control+Shift+1…0` 移动窗口。
- AeroSpace 还使用 `Control+V` 切换 floating/tiling，`Control+Escape` 执行 `enable off` 并关闭接管。
- macOS 原生 Mission Control/Spaces 的冲突 `Control` 快捷键必须保持禁用；触控板手势仍是系统 fallback，不由 AeroSpace 拥有。
- 当前声明中仍存在旧的合并 Hyper 版本，因此“文档/声明已写”不能替代真实意图与运行态回读。

### 4.3 架构边界

- `nix-config` 的第一性目标仍是复现环境，并协调 macOS、NixOS 与 server 三端的 requirement-driven capabilities；它不是未经边界定义的 macOS 全量状态管理器。
- 两个已经证明的真实 case 足以建立一个 macOS 键盘导航协调 seam；不需要为此先建立全局能力 registry。
- 历史上的 Fcitx/Rime 迁移说明静态配置与 vendor-owned mutable state 必须分开。它是副作用偏移的相关证据，但不自动授权复用旧的写入 helper 或建立通用动态状态执行器。

## 5. 当前 v1 Land 范围

实现范围与安全关卡由维护 Issue
[#173](https://github.com/sayoriqwq/nix-config/issues/173) 约束。

v1 只统一收口两个已经证明的 macOS 全局快捷键副作用：

- Raycast ↔ macOS symbolic hotkey；
- AeroSpace ↔ macOS Mission Control/Spaces 快捷键。

期望通过一个纵向、需求驱动的 deep module 和同一 policy test surface 暴露这份行为合同。主机只选择一次能力，模块内部协调应用层声明、macOS 系统侧 owner、readback/control 边界、状态路径和 human gate。

v1 明确不包含：

- 创建通用或全量的独立 macOS 配置仓库；
- 创建通用副作用 registry、动态状态执行器或后台自动 reconcile 服务；
- 迁移、同步、备份或恢复用户数据；
- 接管所有第三方应用偏好；
- 未获单独授权的真实机器 activation 或偏好写入。

## 6. 待后续讨论

以下问题保持开放，不由本次 v1 预先决定：

- 是否需要独立 macOS 仓库；若需要，它是权威声明源、平台执行层，还是由 `nix-config` 锁定的 leaf input？
- 跨仓库 interface 如何表达 capability intent、package ownership、managed configuration、mutable-state paths、readback、control、rollback 与 human gates，且不形成第二个相互漂移的事实源？
- 哪些动态副作用适合自动 reconcile，哪些只能审计或由维护者批准后修改？
- 用户数据、数据库、输入法 userdb、浏览器 profile 等内容应如何与配置副作用分域，并建立独立备份/恢复合同？
- terminal theme 这类已经允许拆出的 leaf 与系统强耦合副作用，在所有权和版本锁定上是否需要不同模式？
- 如何把雾凇拼音/Fcitx 的历史经验提炼成可复用边界，而不恢复已经证明过度复杂的通用 transaction system？
- 如何让讨论文档、能力合同、外部 app settings 和真实运行态之间的偏移可被持续发现，而不是再次依赖人工记忆？

## 7. 追加约定

后续讨论按日期追加，至少保留：用户原话、当时证据、临时判断、被推翻的判断及原因。已经进入实现的决定应链接对应 Issue、ADR、能力文档或 PR；本日志本身始终不替代这些规范性材料，也不表示真实机器已被修改。
