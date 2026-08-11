# macOS 中文输入稳定性研究（历史快照）

- **状态：** 已由 [#139](https://github.com/sayoriqwq/nix-config/issues/139) 的维护边界研究和
  [#140](https://github.com/sayoriqwq/nix-config/issues/140) 的静态声明实现取代；其中 Shift
  ownership 决策又由 [#143](https://github.com/sayoriqwq/nix-config/issues/143) 明确取代
- **当前入口：** [`restore-macos-environment.md`](../runbooks/restore-macos-environment.md#25-恢复-macos-中文输入能力)

本文保留 2026-08-11 输入状态事故的诊断证据，以及 #132/#134 当时采用的 65-leaf、
Desired/Keep、官方 API adapter、semantic journal 与 CAS rollback 设计。它们均是**已退役的历史
架构**，不是当前 Nix ownership 或可执行运维指令。#140 之后，nix-config 只声明
`pkgs.rime-ice` 的薄静态 data view 与本地 overlay；Fcitx GUI/runtime preference 完全外部所有。

## 1. 结论

本次问题不是雾凇拼音静态方案消失，而是输入链路同时存在三层容易混淆的状态：

1. macOS 外层是否选择“小企鹅”输入源；
2. Fcitx5 核心当前是 `keyboard-us` 还是 `rime`（菜单分别显示“键盘 - 英语（美国）”或
   “中州韵”）；
3. 只有 Fcitx 保持 `rime` 时才存在的 Rime 会话内部「中文/ASCII、简/繁、中/英标点、方案」
   状态。

因此 Rime ASCII mode 仍会让 Fcitx 菜单勾选保持“中州韵”；勾选移动到“键盘 - 英语（美国）”
则表示 Fcitx 已切换 engine，不是同一个英文状态。

Fcitx5 官方对“切换应用后沿用前一应用输入法”的明确建议是：不要为目标应用设置应用默认输入法，并将全局 `ShareInputState` 设为 `All`；Rime 的 `InputState` 又优先于全局设置。[Fcitx5 macOS FAQ](https://fcitx-contrib.github.io/docs/faq.html#如何在切换应用时保留前一个应用的输入法)，[Fcitx5 macOS Rime 文档](https://fcitx-contrib.github.io/docs/im/rime.html#共享输入状态)。

根因已经由运行时 red/green 探针确认：macOS frontend 的 Terminal `AppDefaultIM` 先把 Fcitx
从 active Rime 切到 `keyboard-us`，全局 `ShareInputState=All` 再把 inactive 状态传播到其他
input context。修复前为 `Rime(2) → Terminal(1) → Codex(1)`；维护者批准窗口内通过 bundle
自带的官方 `fcitx5-curl` 清空 live `AppDefaultIM` 后为 `Rime(2) → Terminal(2) → Codex(2)`。
该操作没有 raw patch、restart、deploy 或 activation；它是已验证的 live mitigation，不代表
本研究提出的声明式配置已经激活。

当时面向这台机器提出的稳定目标如下；其中关于 Shift 的两项 Keep/只读验证已被 #143
明确取代，不再是现行目标：

- 全局 `ShareInputState=All`、Rime `InputState=All`、`ActiveByDefault=True`、
  `resetStateWhenFocusIn=No`，有效 `AppDefaultIM` 为空；
- **历史、已取代：** 左右 Shift 继续由 Fcitx `AltTriggerKeys` 同时切换；现行目标改为
  Fcitx `AltTriggerKeys` 为空、左右 Shift 由 Rime 内部中文/ASCII 切换拥有；
- `StatusBar=Hidden`，菜单栏只保留 macOS“小企鹅”输入源图标；密码框继续禁用输入法和预编辑；
- 65 个锁定上游静态叶子保持不变，另加 1 个本地 `default.custom.yaml`，只公开 `rime_ice`；
- Fcitx/Rime 用户数据继续可写且不进入 Git；`~/.config/fcitx5` 及其中配置文件由 Fcitx5
  外部拥有，不使用 Store symlink 或整文件模板接管；
- **历史、已退役：** Nix 通过官方本地配置 API 收敛 `ShareInputState=All`、空
  `AppDefaultIM` 与 `StatusBar=Hidden`，并把 Fcitx 左右 Shift 与 Rime `InputState=All` 作为
  Keep gate。#140 已退役整个 runtime provider；#143 只在静态 Rime overlay 声明 Shift，Fcitx
  `AltTriggerKeys` 继续是 external GUI/API preference。

Issue #132 的初始自动化只把 `StatusBar=Hidden` 当作 Keep gate；维护者随后确认该 live 值来自
本人点击“隐藏输入法名称”，并在 Issue #134 中批准把它升级为 Desired。升级后 Keep gate 只
覆盖左右 Shift 与 Rime `InputState=All`。这是历史实现：#140 已将这些 Fcitx 字段全部退回
external ownership，#143 又取代了左右 Shift 的旧 Keep 语义；本节列出的其他现状仍只是审计
快照，不因此扩大 Nix 的字段所有权。

## 2. 范围、证据与限制

### 2.1 一手来源

本研究只使用官方文档、官方源码和本机只读事实：

| 组件 | 研究基准 | 用途 |
| --- | --- | --- |
| Fcitx5 core | 本机动态库报告 `5.1.16`；对应 tag commit `8bdc4ec023d8d3d33b8882b5938511d00a0b0b94` | 全局状态、快捷键、密码框、配置保存、自动保存 |
| fcitx5-rime | 官方源码快照 commit `0735a79e83d0f44f18d914d9014d90ac7f39550e` | Rime `InputState`、预编辑、部署与同步 |
| fcitx5-macos | 官方源码快照 commit `363566b5cd622dfeefa207735e7b41110d6a2445` | macOS 前端、应用默认输入法、密码输入源、预编辑兼容、状态栏、候选窗 |
| rime-ice | 仓库已经锁定的 release 2025.04.06 commit `a5f5404e369100fcfc5562f86f1205827453e31c` | 实际部署的 Shift、方案、开关、标点与候选配置 |
| Rime | 官方 Wiki 与 librime | 数据边界、部署产物、`.custom.yaml` 定制方法 |

本机 `/Library/Input Methods/Fcitx5.app/Contents/Info.plist` 不含 bundle version；因此无法仅从文件元数据证明 macOS 前端的精确 source commit。真实版本/更新状态必须由维护者在“关于 Fcitx5 macOS”界面确认并记录。这不影响对当前配置格式和本机实际行为的只读审计，但它是升级兼容性验收的人工作业。

### 2.2 本机检查边界

本次读取了以下非敏感配置及元数据：

- `~/.config/fcitx5/config`
- `~/.config/fcitx5/profile`
- `~/.config/fcitx5/conf/macosfrontend.conf`
- `~/.config/fcitx5/conf/rime.conf`
- `~/.config/fcitx5/conf/webpanel.conf`
- `~/.config/fcitx5/conf/macosnotifications.conf`
- `~/.config/fcitx5/conf/cached_layouts`
- Fcitx5 app、plugin manifest、进程和动态库版本元数据。

未读取任何 `*.userdb`、`sync`、词典正文或输入日志。`cached_layouts` 只用于确认它是公开键盘布局目录缓存；其 90,514 字节正文不应进入仓库。

## 3. 官方行为模型

### 3.1 Fcitx5 全局状态

**官方事实：** `ShareInputState` 的枚举是 `All`、`Program`、`No`，用于决定输入上下文属性是否复制到其他输入上下文。[`inputcontextmanager.h` at Fcitx5 5.1.16](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/inputcontextmanager.h#L22-L66)。`InputState` 保存 active/current IM，并在传播时复制，而预编辑缓冲本身不应跨输入上下文复制。[`inputcontextproperty.h`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/inputcontextproperty.h#L20-L41)。

**官方事实：** 非 Android 平台的上游默认值是 `ShareInputState=No`；`resetStateWhenFocusIn` 默认 `No`；`ActiveByDefault` 是新输入上下文的默认激活值。[`globalconfig.cpp`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/globalconfig.cpp#L174-L198)。这说明“每个应用记住各自状态”是上游通用默认，但不是 Fcitx5 macOS 针对“跨应用保持”的推荐配置。

**官方事实：** 当 `resetStateWhenFocusIn=All`，每次 focus-in 都按 `ActiveByDefault` 重置；为 `Program` 时只在程序变化时重置；为 `No` 时不重置。[`instance.cpp`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/instance.cpp#L1068-L1092)。因此 `ShareInputState=All` 与 `resetStateWhenFocusIn=No` 是“全局沿用当前选择”的一致组合；将 reset 设为 `All` 或 `Program` 会引入另一套抢占状态的规则。

### 3.2 Rime 状态

**官方事实：** fcitx5-rime 的 `InputState` 有 `FollowGlobalConfig`、`All`、`Program`、`No` 四种值，上游默认是 `All`。[`rimeengine.h`](https://github.com/fcitx/fcitx5-rime/blob/0735a79e83d0f44f18d914d9014d90ac7f39550e/src/rimeengine.h#L55-L90)。若不是 `FollowGlobalConfig`，Rime 的会话池直接使用自己的策略，所以官方 FAQ 才强调 Rime 设置优先于全局。[`rimeengine.cpp`](https://github.com/fcitx/fcitx5-rime/blob/0735a79e83d0f44f18d914d9014d90ac7f39550e/src/rimeengine.cpp#L761-L784)。

**官方事实：** Rime 用户目录是 `~/.local/share/fcitx5/rime`；不得把它和 Squirrel 的 `~/Library/Rime` 互相链接，因为 LevelDB 不支持两个前端并发访问，可能破坏用户词库。[Fcitx5 macOS Rime 文档](https://fcitx-contrib.github.io/docs/im/rime.html#目录)。

### 3.3 应用默认输入法

**官方事实：** macOS 前端默认只有一个 `AppDefaultIM`：进入 Terminal 时使用 `keyboard-us`。[`macosfrontend.h`](https://github.com/fcitx-contrib/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/macosfrontend/macosfrontend.h#L23-L64)。前端在切换程序时应用该规则；若全局 reset 为 `All`，同一应用不同输入框的 focus-in 也会再次套用应用默认值。[`macosfrontend.cpp`](https://github.com/fcitx-contrib/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/macosfrontend/macosfrontend.cpp#L272-L309)。

**官方事实：** 官方文档警告：应用默认英文与默认的临时 Shift 切换组合可能让用户无法用 Shift 回到中文，需要使用完整 trigger key 或重新设计快捷键。[macOS 前端文档](https://fcitx-contrib.github.io/docs/advanced/macosfrontend.html#应用默认输入法)。因此应用默认值必须是显式例外，不能当作“自动稳定性”手段。

**本机实证：** 在 `ShareInputState=All` 下聚焦 Terminal 会把状态从 `2` 变为 `1`，返回
Codex 后仍为 `1`；用官方 API 清空 `AppDefaultIM` 后，同一路径保持 `2 → 2 → 2`。因此本次
批准的长期目标是有效 `AppDefaultIM` 为空，而不是只增加一条飞书例外。

### 3.4 快捷键与 Shift 冲突

**官方事实：** Apple 平台 Fcitx5 的默认 toggle 是 `Control+Shift_L`，临时 toggle 默认是 `Shift_L`；临时 toggle 只在当前 active、或此前正是被该键 deactive 时有效。[`globalconfig.cpp`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/globalconfig.cpp#L36-L92)。

**官方事实：** 锁定的雾凇拼音 `default.yaml` 又定义 `Shift_L: commit_code`、`Shift_R: noop`、`Caps_Lock: clear` 和 `good_old_caps_lock: true`。[pinned `default.yaml`](https://github.com/iDvel/rime-ice/blob/a5f5404e369100fcfc5562f86f1205827453e31c/default.yaml#L45-L68)。但审计快照中的 Fcitx `AltTriggerKeys` 同时接管左右 Shift，这会让 Shift 先作用于 Fcitx 层，Rime 自己的左右 Shift 规则不再是唯一解释。

**#132 历史决策，已由 #143 取代：** 当时保留 Fcitx ownership，让 `AltTriggerKeys` 同时包含
`Shift+Shift_L` 与 `Shift+Shift_R`，并且不在 local overlay 改写 Rime Shift。后续复现证明这会
把“Fcitx 在 `rime`/`keyboard-us` 之间切换”与“Rime 内部中文/ASCII 切换”压在同一对按键上。
#143 的现行目标改为：Fcitx `AltTriggerKeys` 为空；local overlay 将 `Shift_L`、`Shift_R` 都
声明为 `commit_code`；普通 Shift 不改变 Fcitx 当前引擎，`Control+Shift_L` 继续作为完整的
Fcitx 引擎层恢复键。Fcitx 字段仍为 external GUI/API preference，不恢复 Nix runtime provider。

### 3.5 密码框与预编辑

**官方事实：** Fcitx5 core 在 `AllowInputMethodForPassword=False` 时把密码输入上下文强制降级到 fallback keyboard；`ShowPreeditForPassword=False` 时即使有 preedit 也只输出遮蔽点。[`instance.cpp` fallback](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/instance.cpp#L132-L151)，[`instance.cpp` input method selection](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/instance.cpp#L1738-L1757)，[`instance.cpp` password preedit](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/instance.cpp#L2366-L2388)。

**官方事实：** Fcitx5 macOS 同时注册英文、简体中文和繁体中文三个 input mode；英文注册允许浏览器/Terminal 密码框使用，中文注册让 macOS 在这些密码框禁用它。[`MacOSXBundleInfo.plist.in`](https://github.com/fcitx-contrib/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/cmake/MacOSXBundleInfo.plist.in#L35-L61)。本机当前选择的是简体中文 input source，因此密码框切到系统 ABC/英文是预期安全行为，不应通过开启 password IM 来“修复”。

**官方事实：** macOS 前端为 Terminal、iTerm、JetBrains、VSCode、Chrome 地址栏、SwiftUI 输入框等兼容性问题使用 dummy preedit；关闭应用内 preedit 会绕过这条经过专门测试的路径。[`macosfrontend.swift`](https://github.com/fcitx-contrib/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/macosfrontend/macosfrontend.swift#L92-L135)。因此全局 `PreeditEnabledByDefault=True` 和 Rime `PreeditMode="Composing text"` 应保留。

### 3.6 状态栏与候选窗

**官方事实：** macOS 前端状态栏可设为 Menu、Toggle Input Method 或 Hidden；文字会展示当前 IM/submode，而不是只有 macOS 的“小企鹅”外壳名称。[macOS 前端文档](https://fcitx-contrib.github.io/docs/advanced/macosfrontend.html#状态栏)，[`updateStatusItemText`](https://github.com/fcitx-contrib/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/macosfrontend/macosfrontend.cpp#L42-L70)。

**维护者决策：** 保持 `StatusBar=Hidden`，不新增 Fcitx 文本状态栏；菜单栏只保留 macOS
“小企鹅”输入源图标。该 live 值最初由维护者点击“隐藏输入法名称”形成，Issue #134 已批准
由官方配置 API 声明收敛。可观测性通过语义 preflight、API 回读与真实应用验收提供。

**官方事实：** 候选窗默认不跟随 caret，而固定在 preedit 开头，避免输入时频繁移动。[主题调整文档](https://fcitx-contrib.github.io/docs/theme/adjust.html#跟随光标)。当前 `FollowCaret=False` 与官方默认一致。

## 4. 本机逐项审计

除明确标注的 2026-08-11 live mitigation 外，以下“本机事实”来自 2026-08-10 的只读快照；
它描述审计时状态，不代表事故发生前的历史值。

### 4.1 `~/.config/fcitx5/config`

| 配置 | 本机值 | 目标 | 理由 |
| --- | --- | --- | --- |
| `EnumerateWithTriggerKeys` | `False` | Keep | 避免按住修饰键继续轮换 IM。 |
| `TriggerKeys` | `Control+Shift_L`、日文/韩文硬件键 | Keep | `Control+Shift_L` 是 macOS 官方引擎层恢复键；未使用的硬件键无害，不为整洁而扩大变更。 |
| `AltTriggerKeys` | 左、右 Shift | 历史 Keep，已由 #143 取代 | 现行目标为空；普通 Shift 交给 Rime，Fcitx 字段仍由 GUI/API 外部维护。 |
| activate/deactivate keys | 韩文专用键 | External / unchanged | 未获批准，不因审计而清理。 |
| group forward/backward | `Super+space` 组合 | External / unchanged | 未获批准，不因只有一个 group 而清理。 |
| fallback page/candidate | Up/Down、Shift+Tab/Tab | Keep | 与上游 fallback 一致；Rime 自己可覆盖。 |
| `TogglePreedit` | `Control+Alt+P` | External / unchanged | 未获批准；preflight 继续验证默认 preedit 行为。 |
| `ModifierOnlyKeyTimeout` | `250` | Historical / external | 该值与旧 Fcitx modifier-only Shift 方案相关；#143 不接管或清理其他外部字段。 |
| `ActiveByDefault` | `True` | Keep | 新上下文默认进入 active Rime。 |
| `resetStateWhenFocusIn` | `No` | Keep | 避免 focus-in 与共享状态争抢。 |
| `ShareInputState` | `All` | Desired | 官方跨应用保留建议；是飞书问题的核心策略，并由官方 API 收敛。 |
| `PreeditEnabledByDefault` | `True` | Keep | macOS 编辑器兼容所需。 |
| IM information flags | switch 时显示、focus 时不显示、compact | Keep | 与隐藏文本状态栏并不冲突，切换提示保持现状。 |
| `DefaultPageSize` | `5` | Keep | 与 pinned Rime `menu/page_size=5` 一致。 |
| password flags | 两项均 `False` | Keep | 安全默认。 |
| `AutoSavePeriod` | `30` 分钟 | Keep | 保存/同步用户数据；不能为保护 Nix symlink 而设为 0。 |

### 4.2 `~/.config/fcitx5/profile`

本机只有一个 `Default` group，layout 为 `us`，顺序为 `keyboard-us`、`rime`，`DefaultIM=rime`。

| 决策 | 结果 |
| --- | --- |
| Keep | 保持一个 group、fallback `keyboard-us` 和唯一中文引擎 `rime`。 |
| Change | 无；但应在 activation 后语义校验顺序与 `DefaultIM`。 |
| External | 当前 active/last state 不写入此声明；由运行中 input context 管理。 |

### 4.3 `~/.config/fcitx5/conf/macosfrontend.conf`

| 配置 | 本机值 | 目标 | 理由 |
| --- | --- | --- | --- |
| `StatusBar` | `Hidden` | Desired | 维护者明确只保留“小企鹅”，并在 Issue #134 批准由官方 API 收敛。 |
| `AppDefaultIM` | 审计时 Terminal → `keyboard-us`；live 已清空 | Change → empty | 已确认回归根因；官方 API live 缓解已通过 `2 → 2 → 2` 验证，声明式 activation 尚未完成。 |
| `VimMode` | MacVim | External / unchanged | 未获批准，不删除或改写。 |
| simulated key release | `False`, 100ms | Keep | 仅并击方案需要；雾凇全拼不需要。 |
| monitor pasteboard | `False` | Keep | 隐私与最小能力；无需把剪贴板交给 IM。 |
| remove tracking params | `True` | Keep | monitor 关闭时无作用；未来启用时保持保护。 |
| polling interval | 2s | Keep | monitor 关闭时无作用。 |

Terminal 默认英文、VimMode 和状态栏占位原本都是主观选择。Issue #132 只批准清空全部
`AppDefaultIM`；Issue #134 随后批准 `StatusBar=Hidden` 为 Desired。MacVim 继续保持
external/unchanged。

### 4.4 `~/.config/fcitx5/conf/rime.conf`

| 配置 | 本机值 | 目标 | 理由 |
| --- | --- | --- | --- |
| `PreeditMode` | `Composing text` | Keep | 应用内 preedit；兼容 macOS 文本控件。 |
| `InputState` | `All` | Keep | Rime 自己的共享策略优先于全局。 |
| cursor at beginning | `False` | Keep | macOS 不需要固定；`FollowCaret=False`。 |
| switch behavior | `Commit commit preview` | Keep | fcitx5-rime 上游默认，避免切换时丢失组成文本；具体提交语义是主观选择。 |
| Deploy | `Control+Alt+grave` | Keep | Fcitx5 macOS 官方默认、与 Squirrel 习惯一致。 |
| Synchronize hotkey | empty | Keep | 不设置误触同步快捷键；周期 autosave 仍可能调用 Rime sync。 |
| latin name from schema | `False`/未显式写出 | Keep | 非稳定性关键。 |

### 4.5 `~/.config/fcitx5/conf/webpanel.conf`

| 区域 | 本机值 | 目标 |
| --- | --- | --- |
| Basic | `FollowCaret=False`, `Theme=System`, `DefaultTheme=macOS 26` | Keep / unchanged；视觉字段不在本 Issue 修改。 |
| Light/Dark | 自定义绿高亮、浅/深色配色 | Keep；纯视觉偏好，不影响状态稳定性。 |
| Typography | horizontal + horizontal top-bottom，Rime awareness 开启 | Keep；也是卷轴模式生效的官方组合。 |
| Scroll | enabled，6×6，数字键选词，Hyper 优化 | Keep；属于既有交互偏好。若数字键或 `-`/`=` 冲突，真实验收后单独调整。 |
| Background | system blur + shadow | Keep；视觉偏好。 |
| Fonts/Caret/Highlight/Size | 当前完整值 | Keep；保留现状，不与本次状态修复混改。 |
| Plugins | notice false、列表 empty | Keep | 不加载候选窗 JS 插件。 |
| Unsafe API | curl false | Keep | 维持最小网络/执行能力。 |

Webpanel 源码将 `conf/webpanel.conf` 读入并通过配置接口完整写回；unsafe curl 只有显式打开时才暴露。[`webpanel.cpp`](https://github.com/fcitx-contrib/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/webpanel/webpanel.cpp#L295-L321)，[`webpanel.h`](https://github.com/fcitx-contrib/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/webpanel/webpanel.h#L81-L92)。

### 4.6 notifications 与 cache

| 文件 | 本机事实 | 分类 | 原因 |
| --- | --- | --- | --- |
| `conf/macosnotifications.conf` | `HiddenNotifications` 为空 | External / mutable | 用户点“不要再显示”后插件会写回该列表；不是输入策略。[`macosnotifications.cpp`](https://github.com/fcitx-contrib/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/macosnotifications/macosnotifications.cpp#L15-L59)。 |
| `conf/cached_layouts` | 90,514 字节，公开 XKB layout 描述缓存 | External / excluded | keyboard engine 有布局时自动完整写入；无布局时才回读 fallback。它可重建，不应进 Git。[`keyboard.cpp`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/im/keyboard/keyboard.cpp#L300-L350)。 |

### 4.7 clipboard、Beast 与网络边界

| 项目 | 本机事实 | 目标 | 理由 |
| --- | --- | --- | --- |
| clipboard monitoring | `MonitorPasteboard=False` | Keep / semantic guard | 关闭时 macOS frontend 的轮询直接返回，不采集系统剪贴板；这是最重要的隐私不变量。[剪贴板文档](https://fcitx-contrib.github.io/docs/advanced/clipboard.html)，[macOS frontend 文档](https://fcitx-contrib.github.io/docs/advanced/macosfrontend.html#监视剪贴板)。 |
| `conf/clipboard.conf` | 不存在，使用上游默认；其中 `IgnorePasswordFromPasswordManager=False` | External | 当前监控关闭，密码历史设置不可达。本 Issue 不为防御纵深新建配置文件；若未来明确启用剪贴板，应另行把 ignore-password 设为 true，并理解它仍依赖密码管理器正确标记敏感内容。 |
| Beast API | 无 `beast.conf`，effective config 为 `Communication=Unix Socket`、`Path=/tmp/fcitx5.sock`；审计时无 TCP listener/connection | Keep / preflight-only | 官方将 Unix socket 标为更安全，TCP 仅适合调试；当前 socket 属于维护者且没有 IP 暴露。本 Issue 不新建 `beast.conf`，只在 preflight 中拒绝 TCP 漂移。[Web 服务器文档](https://fcitx-contrib.github.io/docs/advanced/beast.html)。 |
| cloud input | 未加载 cloud pinyin addon | Keep / preflight-only | 官方说明未主动开启云拼音时不会上传输入数据；应用/plugin payload 仍由官方 updater 外部管理。[Fcitx5 macOS 官网](https://fcitx-contrib.github.io/)。 |

WebPanel 的 `Plugins` 为空且 `EnableUnsafeCurlAPI=False`；这两项与 `PluginNotice=False` 应作为语义安全前置条件，但不因此接管主题、颜色和布局。当前 app/plugin 使用 ad-hoc 签名且 bundle metadata 无可靠语义版本；更新只能在独立维护窗口通过官方 updater 完成，不能在本 Issue 自动升级或把签名当作完整供应链证明。

### 4.8 pinned rime-ice 行为

锁定版本的关键默认值如下：

| 行为 | pinned 值 | 决策 |
| --- | --- | --- |
| schema list | 全拼、九宫格和 6 种双拼 | Change：通过本地 `default.custom.yaml` 只保留 `rime_ice`。 |
| page size | 5 | Keep。 |
| schema switcher | F4、Ctrl+grave、Ctrl+Shift+grave | Keep / unchanged；本 Issue 不修改未批准快捷键。 |
| `Shift_L` | `commit_code` | #143 local overlay 明确保持 `commit_code`，作为 Rime 内部中文/ASCII 切换。 |
| `Shift_R` | `noop` | #143 local overlay 覆盖为 `commit_code`，使右 Shift 与左 Shift 采用相同的 Rime 内部语义。 |
| CapsLock | `good_old_caps_lock=true`, `clear` | Keep；macOS 系统 CapsLock input-source 设置仍优先。 |
| `ascii_mode` | 中文/ASCII，无 `reset` | Keep；会话共享而不是每次窗口强制重置。 |
| `ascii_punct` | 中文/英文标点，无 `reset` | Keep；方案选单记忆。 |
| `traditionalization` | 简/繁，无 `reset` | Keep；默认简体但允许方案选单记忆。若要求永远简体，需另做主观 patch。 |
| emoji | default enabled (`reset: 1`) | Keep。 |
| full shape | 默认半角 | Keep。 |
| punctuation | 中文逗号句号等；URL/email 有 recognizer 例外 | Keep。 |
| candidate/preedit | 拼音权重高于英文，preedit 显示标准化拼音 | Keep。 |
| candidate page keys | `-`/`=`；Tab 用于拼音光标 | Keep；与现有 webpanel scroll 设置一起验收。 |
| simplified conversion | `s2t.json` 仅在 traditionalization 开启时运行 | Keep；默认简体。 |

来源：[`default.yaml` at pinned release](https://github.com/iDvel/rime-ice/blob/a5f5404e369100fcfc5562f86f1205827453e31c/default.yaml)，[`rime_ice.schema.yaml` at pinned release](https://github.com/iDvel/rime-ice/blob/a5f5404e369100fcfc5562f86f1205827453e31c/rime_ice.schema.yaml)。

Rime 官方建议不要直接修改发行版文件，而应以同名 `.custom.yaml` patch 定制，避免升级覆盖和错过上游修复。[Rime Customization Guide](https://github.com/rime/home/wiki/CustomizationGuide)。#132 当时新增的 declarative `default.custom.yaml` 只 patch `schema_list`；#143 在同一 local overlay 继续保留唯一 `rime_ice` schema，并以叶级 patch 把 `Shift_L`、`Shift_R` 都声明为 `commit_code`，不直接改写上游 `default.yaml`。

## 5. Keep / Change / External / Human-only 总表

| 分类 | 项目 |
| --- | --- |
| Keep | `ActiveByDefault=True`、`resetStateWhenFocusIn=No`、Rime `InputState=All`、profile 只有 keyboard-us+rime 且默认 rime、`Control+Shift_L` 完整恢复键、应用/Rime preedit、密码保护、30 分钟 autosave、Rime deploy key、FollowCaret false、当前候选/配色、webpanel plugins/unsafe API 关闭、monitor pasteboard 关闭、Beast 仅 Unix socket、无 cloud input。 |
| Change / Desired | 静态 Rime overlay：只公开 `rime_ice` schema，并把左右 Shift 都声明为 Rime `commit_code`。Fcitx `ShareInputState=All`、有效 `AppDefaultIM` 为空、`StatusBar=Hidden` 与 `AltTriggerKeys` 为空仅为 external GUI/API 推荐值，不是 Nix Desired。 |
| External | Fcitx5.app、plugin payload/updater、macOS input source registration、整个 `~/.config/fcitx5` 及配置文件所有权、MacVim `VimMode`、缺失的 `clipboard.conf`/`beast.conf`、`macosnotifications.conf`、`cached_layouts`、Rime `build`、`*.userdb`、`sync`、`installation.yaml`、`user.yaml`、Fcitx cache。 |
| Human-only | activation、Rime deploy、真实应用输入验收、Fcitx5 app/plugin 更新，以及未来任何新的视觉/快捷键/简繁/标点策略变更。 |

## 6. 配置加载、写回与可声明 seam

### 6.1 为什么不能把全部 Fcitx 配置做成 Store symlink

**官方事实：** Fcitx 使用 `safeSaveAsIni` 写配置；实现先写临时文件、`fsync`，再用 `std::filesystem::rename` 覆盖目标路径。[`standardpaths.cpp`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx-utils/standardpaths.cpp#L291-L324)，[`iniparser.cpp`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx-config/iniparser.cpp#L184-L203)。原子 rename 会替换 Home Manager 在目标位置建立的 symlink，而不是修改 Store 文件。

**官方事实：** Fcitx 的周期 autosave 会保存 `profile`，并调用所有 addon 的 `save()`；macOS frontend 的 `save()` 会写 `macosfrontend.conf`，notifications 也会写自己的配置。[`Instance::save`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/instance.cpp#L1958-L1973)，[`AddonManager::saveAll`](https://github.com/fcitx/fcitx5/blob/8bdc4ec023d8d3d33b8882b5938511d00a0b0b94/src/lib/fcitx/addonmanager.cpp#L310-L327)，[`macosfrontend.h`](https://github.com/fcitx-contrib/fcitx5-macos/blob/363566b5cd622dfeefa207735e7b41110d6a2445/macosfrontend/macosfrontend.h#L78-L114)。当前 `AutoSavePeriod=30`，所以即使用户不打开设置 UI，长期 symlink 所有权也不可靠。

### 6.2 历史推荐 seam（已退役）

以下内容只解释 #132/#134 当时为何采用 runtime adapter；#140 已将整套 seam 退役，不能作为
#143 的实现或恢复入口。

**仓库设计推断：** capability 应拥有少量已列明的**行为结果**，而不是拥有完整 Fcitx 文件。
Home Manager 的 host interface 仍只有一次 capability import，不暴露任意 path/value 的通用
配置编辑器。production adapter 调用 `/Library/Input Methods/Fcitx5.app` bundle 自带的
`fcitx5-curl`，通过 `/tmp/fcitx5.sock` 的官方本地配置通道读取、写入和回读语义；不得 raw
编辑 INI，也不得用 Store symlink 或整文件模板接管 Fcitx-owned regular files。

内部合同分为三类：

- owned behavior：全局 `ShareInputState=All`、有效 `AppDefaultIM` 为空与
  `StatusBar=Hidden`；只有这三个字段允许 adapter 经官方 API 收敛；
- Keep verification：当时把左右 Shift 的 Fcitx `AltTriggerKeys` 与 Rime `InputState=All` 等
  已批准现状做只读验证；该 runtime gate 已由 #140 退役，Shift 语义又由 #143 取代；
- local managed file：`~/.local/share/fcitx5/rime/default.custom.yaml` 当时作为 65 个 upstream
  leaves 之外的独立第 66 个静态 leaf只声明 `rime_ice` schema；#143 继续在这个 overlay 中声明
  左右 Shift 的 Rime 内部 `commit_code` 语义。

adapter 先读取全部目标；若语义已经满足则严格 no-op。CLI/socket 缺失、返回错误、配置结构
歧义、Keep 字段漂移或写后回读失败时全部失败关闭，不自动 kill、restart 或 deploy。发生真实
外部字段修改时记录 mode 0600 的 owner-only semantic journal；generation rollback 不得假装
已经逆转 Fcitx-owned 配置。journal 固定在
`~/.local/state/nix-config/macos-chinese-input/fcitx5-behavior/last-change.json`，恢复时必须先验证
当前语义，再通过同一官方 API 定向写回。
Issue #134 将 owned frontend 结果扩展为 `AppDefaultIM+StatusBar` 后，journal schema 升级为
v3；它记录 transaction、逐项 applied 状态及
`prepared` / `committed` / `rolled-back` / `rollback-incomplete`，固定 rollback helper 只在全部
当前值仍等于 before/after 之一时继续；第三值一律失败关闭。
validator 同时保留 v2 兼容：legacy 终态 journal 可保留或归档；v2 的 frontend entry 只恢复
当时拥有的 `AppDefaultIM`，并通过官方 partial API 保留当前 `StatusBar`；若 journal 还记录了
已应用的 global entry，同一事务也恢复 `ShareInputState`。v2 `prepared` 在任何 POST 前失败
关闭，要求进入绑定原实施 revision 的受监督恢复窗口，不能由新版本猜测续跑。
后续再次漂移时，终态 journal 先以 transaction/status 命名原子归档，未完成 journal 则阻止
新事务，避免“只可收敛一次”或覆盖恢复证据。

以下文件不能纳入 managed source 或整文件模板：

- `macosnotifications.conf`：用户交互状态；
- `cached_layouts`：自动重建 cache；
- `build`、`user.yaml`、`installation.yaml`、`*.userdb`、`sync`：Rime runtime/user data。

候选窗主题、字号、通知隐藏记录等非稳定性字段继续由应用拥有；preflight 只验证少数批准的
安全/行为标量。`cached_layouts` 只检查路径类型，不读正文。这是一条已由上游配置 API 和写回
机制证明的跨层 seam，属于使用 activation adapter 的正当例外；不能用“Home Manager 能建立
symlink”代替持久可写性证据。

## 7. 数据边界

Rime 官方把用户词典、sync snapshot、`installation.yaml`、`user.yaml` 标为用户资料；`build` 是由部署生成、运行时读取的编译结果。[Rime 数据文件说明](https://github.com/rime/home/wiki/RimeWithSchemata#rime-中的數據文件分佈及作用)。由此得到：

- Git/Nix 可以拥有 scheme、dictionary source、Lua、OpenCC 和明确的 `.custom.yaml`；
- `build` 可删除重建，但不备份；
- userdb、sync、installation/user state 不读正文、不覆盖、不提交；
- 配置 activation 不等于用户数据备份；
- Squirrel `~/Library/Rime` 保持独立，不能链接或迁入 Fcitx 数据目录。

## 8. Activation、restart、deploy 与 rollback

### 8.1 安全顺序

1. 在 activation 前记录回滚与可变状态边界；若是首次接管既有 65 个 regular leaves，由 handoff
   helper 内置的 static-only preflight 验证它们。完整公开 preflight 此时会因本地 overlay 尚未
   链接而失败，这是预期结果，不把它当作 activation 前置条件。
2. 构建并在获得 exact commit/current-window 批准后激活新的 Darwin/Home Manager generation；
   adapter 通过官方 API 收敛三个 owned 字段，不在 build 阶段触碰 live 状态。
3. activation 后运行公开只读 preflight，验证 app/plugin、官方 CLI/socket、Fcitx owned/Keep
   语义、65+1 static leaf、mutable data 类型和备份边界。
4. activation 不自动退出或重启 Fcitx5；官方 API 会 safe-save 并即时 reload 目标配置。只有出现
   独立证据并获得当前批准时才重启。
5. 仅在首次引入、恢复或实际变更 `default.custom.yaml` 时，另获人工批准后触发 Rime deploy；
   Issue #134 的 StatusBar/preflight 增量不执行新的 deploy。需要 deploy 时，当前 bundle 已确认存在：

   ```fish
   /Library/Input\ Methods/Fcitx5.app/Contents/bin/fcitx5-curl /config/addon/rime/deploy -X POST -d '{}'
   ```

   ⌨️ 通过 Fcitx5 官方本地 API 部署本地 Rime overlay；该动作仍需当前窗口人工批准。

   来源：[Fcitx5 macOS Rime CLI 文档](https://fcitx-contrib.github.io/docs/im/rime.html#命令行接口)。
   早期“本机 bundle 不存在 `fcitx5-curl`”的判断已由现场文件与成功 API 调用证伪。部署期间
   短暂不能输出中文是 Rime 官方声明的正常现象；完成后应检查 compiled schema 再开始验收。
   [Rime 定制指南](https://github.com/rime/home/wiki/CustomizationGuide#重新佈署的操作方法)。
6. 完成第 9 节真实应用验收后，才清理一次性交接 helper。

### 8.2 已退役的回滚设计

#132/#134 曾提供基于 semantic journal 的字段级 rollback helper；#140 已删除该 package/app、
activation-time behavior provider 与 journal/CAS 生命周期，因此本节不再提供可执行命令。不要尝试
从旧提交运行该 helper，也不要把 generation rollback 误认为只会恢复静态文件：切回 #140 之前的
generation 可能重新带回旧 provider，并通过官方 API POST 当时的 Desired。

当前回滚必须遵循
[`restore-macos-environment.md` 的“macOS 中文输入”回滚顺序](../runbooks/restore-macos-environment.md#42-macos-中文输入)：
先审阅候选旧 generation 的行为副作用并单独取得批准，再恢复 Nix-owned 静态声明；Fcitx 偏好通过
GUI 人工复核。始终保留 userdb、sync、installation/user state，Rime deploy 与 Fcitx restart 仍是
独立人工关卡。

## 9. 真实应用验收矩阵

命令行 preflight 不能证明 InputMethodKit 与具体 App 编辑器的交互。以下为 merge/清理前必须由维护者执行并记录的 human gate：

| 场景 | 操作 | 通过标准 |
| --- | --- | --- |
| 飞书日报 | 在日报正文、标题和可能的富文本/弹窗字段分别输入 `nihao` 并选词 | 每个字段都出现雾凇候选并上屏“你好”；不会只在该字段停留英文。 |
| 跨应用 | 飞书中文 → TextEdit/备忘录 → 浏览器 contenteditable → 回飞书 | 所有普通文本框保持同一个 active Rime 状态。 |
| 同应用多字段 | 在飞书日报不同输入框来回点击 | 不因新 InputContext 退回 `keyboard-us`。 |
| 菜单栏 | 观察 macOS 输入源菜单与图标 | `StatusBar=Hidden`，不出现额外 Fcitx 文本状态栏，只保留“小企鹅”。 |
| 快捷键 | 连续快速输入、分别单按左右 Shift、按 Ctrl+Shift_L | 左右 Shift 均只切换 Rime 内部中文/ASCII mode，菜单勾选保持“中州韵”；完整 trigger key 仍可恢复 Fcitx 引擎层。 |
| 候选/预编辑 | 输入、Backspace、左右箭头、Tab、`-`/`=`、Esc | 应用 preedit、候选位置和翻页无双处理、吞键或光标跳动。 |
| Browser/Electron | Chrome 地址栏、网页输入框、飞书富文本 | Backspace、箭头和候选上屏均正常。 |
| Terminal/IDE | 从 Rime 聚焦 Terminal，再返回其他应用；另测 Esc/Ctrl+C/Backspace | 保持 active Rime，运行时路径为 `2 → 2 → 2`；控制键不双处理。 |
| 密码框 | 浏览器密码框和 Terminal sudo prompt | 使用系统 ABC/fallback，不显示中文候选或明文 preedit；退出密码框后恢复 Rime 共享状态。 |
| 简繁/标点 | 确认为简体、中式逗号句号；切换一次再跨应用 | 记忆策略与批准结果一致，不出现应用间随机差异。 |
| deploy/session | deploy 完成后重新登录或切换用户会话再复测 | schema 只有 rime_ice，候选和用户学习仍存在；无 Squirrel 并发访问。 |

## 10. 最终实施决策

1. 清空全部 `AppDefaultIM`；live mitigation 已验证，声明式 activation 尚未完成。
2. **历史、已由 #143 取代：** Fcitx `AltTriggerKeys` 保持左右 Shift。现行目标为
   `AltTriggerKeys` 为空，普通 Shift 不再切换 Fcitx engine；`Control+Shift_L` 保留为完整恢复键。
   `StatusBar=Hidden` 与只保留“小企鹅”的目标不变。
3. 增加独立 `default.custom.yaml`，schema list 只包含 `rime_ice`；#143 又在同一 overlay 将左右
   Shift 都声明为 Rime `commit_code`。旧 65-leaf 计数只属于本历史架构，#140 已改为薄 data view。
4. MacVim、剪贴板/Beast、密码框、候选窗视觉、简繁与标点等未批准项不修改。
5. activation、Rime deploy、真实应用验收和任何 restart 都保留人工关卡；generation rollback
   不自动逆转 Fcitx 外部字段。#140 已退役 semantic journal；#143 调整 `AltTriggerKeys` 前必须
   记录旧值，回滚时通过 Fcitx GUI/官方 API 精确恢复，不从旧提交复活 helper。
