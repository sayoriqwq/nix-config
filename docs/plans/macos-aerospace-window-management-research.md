# macOS AeroSpace 平铺窗口管理试验研究

## 1. 范围与结论

本文为 Issue [#171](https://github.com/sayoriqwq/nix-config/issues/171) 的实现前研究，目标是只在
`macbook` 上以可回滚方式试验 AeroSpace，同时保留 Raycast 与 macOS 原生菜单栏。本文不表示
AeroSpace 已安装、启动、获得 Accessibility 权限或通过真人验收，也不授权 activation、logout、
restart、原生 Spaces/显示器设置变更或 SIP 变更。

当前锁定的 Darwin nixpkgs 提供 `pkgs.aerospace` `0.21.3-Beta`。该 derivation 下载上游同版本
release zip，安装 `AeroSpace.app`、CLI、man page 与 Fish/Bash/Zsh completion；包的
`sourceProvenance` 是 `binaryNativeCode`。证据见锁定的
[nixpkgs package 定义](https://github.com/NixOS/nixpkgs/blob/104240a772428cc2e20d8fd86c9ddbb886bbaff2/pkgs/by-name/ae/aerospace/package.nix)
与仓库 [`flake.lock`](../../flake.lock)。AeroSpace 上游仍将项目标为 Public Beta，因此试验必须固定
版本、审阅生成配置并保留即时暂停和 generation 回滚入口。[上游 README](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/README.md#project-status)

锁定的 Home Manager Darwin revision 已提供 `programs.aerospace`，可以同时拥有 package 与
TOML 配置，不需要自写 activation script。该 module 在 `xdg.enable = true` 时生成
`~/.config/aerospace/aerospace.toml`，否则生成 `~/.aerospace.toml`；这与 AeroSpace 官方的两个
配置搜索位置一致，且避免两处并存导致的歧义。[锁定 Home Manager module](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/programs/aerospace.nix)
[上游配置路径](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#config-location)

本试验的最小安全所有权建议是：

- Home Manager 安装 `pkgs.aerospace` 并生成稳定 TOML；
- `programs.aerospace.launchd.enable = false`，不创建 Home Manager launchd agent；
- 生成配置中的 `start-at-login = false`，不让 AeroSpace 注册自身的登录项；
- 首次启动、Accessibility 授权、真人按键验证与后续是否启用登录启动均留在独立人工关卡；
- Raycast 继续拥有 Caps Lock/Hyper 的产生方式及其全部可变快捷键状态，Nix 不接管 Raycast
  settings/database；
- 不修改 SIP、原生 Spaces、“Displays have separate Spaces”、Mission Control、Dock 或显示器排列。

锁定 Home Manager module 无论用户输入为何，都会把生成配置的 `start-at-login` 强制为
`false`，并在 `launchd.enable = false` 时不声明 agent。它只有在 `launchd.enable = true` 时才会
配置 `RunAtLoad = true` 与默认 `KeepAlive = true` 的 agent；这不是本次试验目标。
[Home Manager launchd 实现](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/programs/aerospace.nix#L61-L192)
上游自身的 `start-at-login` 使用 `SMAppService.mainApp.register()`/`unregister()`；保持 false 会走
unregister 路径。[上游 start-at-login 实现](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/Sources/AppBundle/config/startAtLogin.swift)

## 2. Hyper 直接键位

### 2.1 精确 TOML

维护者已在 Raycast UI 中把 Caps Lock Hyper 设置为同时按下 `cmd-alt-ctrl`；这是仓库外可变的
前置事实，不由 Nix 声明或收敛。
AeroSpace 的绑定语法只识别四类标准修饰键；本方案的 Hyper 按下前三类 `cmd-alt-ctrl`，只有移窗
绑定再额外加入 `shift`。本方案不要求 AeroSpace 识别 `capsLock`，也不区分左右侧 modifier。
上游 v0.21.3-Beta 的 parser 只接受 `cmd`、`alt`、`ctrl`、`shift` 四种 modifier，
并支持 `left/down/up/right`、`0..9`、`w`、`f`、`esc` 等 key notation。
[keysMap.swift](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/Sources/AppBundle/config/keysMap.swift)

建议的原生 TOML 如下：

```toml
[mode.main.binding]
cmd-alt-ctrl-left  = 'focus left'
cmd-alt-ctrl-down  = 'focus down'
cmd-alt-ctrl-up    = 'focus up'
cmd-alt-ctrl-right = 'focus right'

cmd-alt-ctrl-1 = 'workspace 1'
cmd-alt-ctrl-2 = 'workspace 2'
cmd-alt-ctrl-3 = 'workspace 3'
cmd-alt-ctrl-4 = 'workspace 4'
cmd-alt-ctrl-5 = 'workspace 5'
cmd-alt-ctrl-6 = 'workspace 6'
cmd-alt-ctrl-7 = 'workspace 7'
cmd-alt-ctrl-8 = 'workspace 8'
cmd-alt-ctrl-9 = 'workspace 9'
cmd-alt-ctrl-0 = 'workspace 10'

cmd-alt-ctrl-shift-1 = 'move-node-to-workspace 1'
cmd-alt-ctrl-shift-2 = 'move-node-to-workspace 2'
cmd-alt-ctrl-shift-3 = 'move-node-to-workspace 3'
cmd-alt-ctrl-shift-4 = 'move-node-to-workspace 4'
cmd-alt-ctrl-shift-5 = 'move-node-to-workspace 5'
cmd-alt-ctrl-shift-6 = 'move-node-to-workspace 6'
cmd-alt-ctrl-shift-7 = 'move-node-to-workspace 7'
cmd-alt-ctrl-shift-8 = 'move-node-to-workspace 8'
cmd-alt-ctrl-shift-9 = 'move-node-to-workspace 9'
cmd-alt-ctrl-shift-0 = 'move-node-to-workspace 10'

cmd-alt-ctrl-v = 'layout floating tiling'
cmd-alt-ctrl-esc = 'enable off'
```

该语法有以下已验证语义：

1. modifier 顺序在 parser 中不重要；parser 以 `-` 拆分、把最后一段作为 key，并把前面的
   modifier 合并为 `NSEvent.ModifierFlags`。本文统一以 `cmd-alt-ctrl-*` 表示 Hyper，仅在
   “移动窗口到 workspace” 时额外加入 `shift`。
   [HotkeyBinding parser](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/Sources/AppBundle/config/HotkeyBinding.swift)
2. 所有 bindings 都留在 `main` mode，不引入 W 前缀、裸数字捕获或额外 mode 状态。
   `cmd-alt-ctrl-shift-N` 直接执行一次 `move-node-to-workspace N`；这里不需要 command array。
3. AeroSpace 确实支持 command string array，且上游 parser 会把 array 转成顺序 shell `seq`，
   但本方案不依赖该能力。保留这一事实只用于解释上游默认 service mode，并非试验接口。
   [配置 parser](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/Sources/AppBundle/config/parseConfig.swift#L184-L202)
   [顺序执行实现](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/Sources/AppBundle/shell/Shell.swift#L93-L145)
4. `move-node-to-workspace` 默认只移动窗口，不把焦点跟随到目标 workspace，符合
   “先整理、继续留在当前 workspace” 的行为；若真人验收要求跟随，必须另行明确选择
   `--focus-follows-window`。[命令定义](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/aerospace-move-node-to-workspace.adoc)
5. `layout floating tiling` 按当前状态在 floating/tiling 间切换；上游默认 service mode 使用同一
   command。[layout command](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/aerospace-layout.adoc)

在 Nix 中，上述含连字符的 binding key 必须作为带引号的 attribute name 表达；Home Manager
的 TOML formatter 再生成上面的原生 TOML。实现阶段应审阅实际生成结果，而不是只审阅 Nix
source。

### 2.2 `Hyper+Esc` 暂停与恢复

`enable off` 是可用的即时暂停入口：上游保证禁用时把当前不可见 workspace 的窗口移回可见
区域，并停止截获键盘事件。[enable command](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/aerospace-enable.adoc)

这个逃生操作是刻意非对称的。v0.21.3-Beta 的实现会在 disable 时把 active mode 设为 `nil`，
从而停用全部 hotkey；重新 enable 时恢复 `main` mode。因此按下 `Hyper+Esc` 后，不能再用任何
AeroSpace binding 执行 `enable on`。恢复路径必须预先告知维护者：

- 从 macOS 原生菜单栏的 AeroSpace 图标选择 **Enable**；或
- 在终端运行短命令 `aerospace enable on`。

[EnableCommand.swift](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/Sources/AppBundle/command/impl/EnableCommand.swift)
[菜单栏 Enable/Disable 实现](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/Sources/AppBundle/ui/MenuBar.swift#L52-L59)

退出 AeroSpace 是第二层逃生。上游说明正常退出或检测到即将 crash 时会把全部窗口恢复到
可见区域；若严重 crash，macOS 不允许窗口完全移出屏幕，仍可能留下约 1 像素供手工拖回。
[Workspace emulation](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#emulation-of-virtual-workspaces)

## 3. Workspace 与多显示器边界

AeroSpace Workspaces 不是原生 macOS Spaces。不可见 workspace 的窗口被移动到屏幕底部角落；
官方预期用户保留一个原生 Space，或在启用 “Displays have separate Spaces” 时每个显示器一个，
然后不再操作原生 Spaces。此模型提供快速切换，但意味着 Mission Control 预览、原生 fullscreen
和 Space 切换不能被假定与 Hyprland workspace 等价。
[Workspace emulation](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#emulation-of-virtual-workspaces)

多显示器下：

- 全部显示器共享一个 workspace 池；
- 每台显示器显示自己的 visible workspace，同一 workspace 不能同时显示在两台显示器；
- 每个 workspace 都有 assigned monitor，默认是 macOS 指定的 main display；
- 切换到 workspace 会先在其 assigned monitor 显示，再聚焦它；
- 可配置 `workspace-to-monitor-force-assignment`，但这会使 `move-workspace-to-monitor` 对该
  workspace 无效。

[Multiple monitors](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#multiple-monitors)

上游观察到关闭 “Displays have separate Spaces” 通常更稳定，但该设置影响原生 fullscreen、
菜单栏位置与跨屏行为，而且需要 logout 才生效。Issue #171 不应修改它，也不应擅自调整显示器
排列；首轮只记录当前事实和异常。AeroSpace 隐藏窗口要求每台显示器底部至少一个角落有空闲
区域，否则其他显示器可能露出被隐藏窗口的一部分。
[Separate Spaces caveat](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#a-note-on-displays-have-separate-spaces)
[Proper monitor arrangement](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#proper-monitor-arrangement)

因此最小试验不声明 `workspace-to-monitor-force-assignment`，不修改原生 Spaces 或显示器系统
设置；多屏 workspace 归属待真人观察后再由后续窄 issue 决定。

## 4. 权限、SIP 与应用规则

AeroSpace 通过 macOS Accessibility API 读取、移动和调整其他应用窗口。上游启动逻辑持续检查
`AXIsProcessTrustedWithOptions`，未获权限时等待用户授权；这个 TCC 授权只能在首次人工启动
关卡由维护者确认，不能由 Nix build 或 activation 声称完成。
[Accessibility 实现](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/Sources/AppBundle/util/accessibility.swift)

上游明确表示 AeroSpace 不要求关闭 SIP。它主要使用 public Accessibility API，仅用
`_AXUIElementGetWindow` 取得 Accessibility object 对应的 window ID；不得为本试验关闭或削弱
SIP。[上游 Project values](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/README.md#project-values)

应用例外应使用有实机证据的 bundle ID。`on-window-detected` 是有序 callback 列表；匹配成功后
默认停止，只有 `check-further-callbacks = true` 才继续。v0.21.3-Beta 推荐
`if = 'test %{app-bundle-id} = …'`，旧 `if.app-id` 语法已 soft-deprecated。Bundle ID 应通过
`aerospace list-apps` 或 `mdls` 读取，不能猜；窗口标题可能晚于 window detection 初始化，故
title 规则不应作为首选。AeroSpace 自带 dialog heuristics，会默认浮动识别到的 dialog，首轮
不应预先把 Finder、Raycast 或其他整个应用强制浮动。
[on-window-detected](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#on-window-detected-callback)
[Dialog heuristics](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#dialog-heuristics)
[Deprecated callback syntax](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#legacy-on-window-detected-syntax)

## 5. Raycast 与快捷键冲突

AeroSpace 官方明确指出 Raycast、Karabiner-Elements 或其他全局 hotkey listener 可能抢占按键。
[Keyboard pitfall](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#common-pitfall-keyboard-keys-handling)

本方案让 Raycast 继续拥有 Caps Lock → `cmd-alt-ctrl` Hyper 的转换，AeroSpace 只注册 Hyper
后的组合。该设置已由维护者在 Raycast UI 完成，是外部可变前置事实；仓库既不生成也不修改
Raycast settings。维护者正在仓库外重组 live 快捷键，当前仓库盘点不作为本试验的键位占用事实；
activation 前必须确认 Raycast 已释放 Hyper+V。真人验收仍需检查：Hyper+四方向、Hyper+数字、
Hyper+Shift+数字、Hyper+V、
Hyper+Esc 是否与 Raycast 其他全局 command 冲突。

## 6. 构建、人工验收与回滚关卡

### 声明级验证

实现阶段应运行仓库规定的 formatter、flake check 与 macbook system build，但这些检查不启动
AeroSpace、不授予 Accessibility 权限，也不证明 Hyper 运行态无冲突。还应从 build result 审阅：

- 生成配置只存在于一个官方搜索路径；
- `start-at-login = false`；
- 未生成 `org.nix-community.home.aerospace` launchd agent；
- TOML 中 Hyper 直接 bindings 与本文一致，且不存在额外 move-workspace mode；
- `pkgs.aerospace.version` 为 `0.21.3-Beta`，未更新 `flake.lock`。

若 AeroSpace 已由维护者人工启动，可在不应用配置的情况下使用
`aerospace reload-config --dry-run --no-gui --warnings-as-errors` 检查 TOML；真正 reload、首次启动、
Accessibility 授权和运行态 callback 都属于另行批准的人工关卡。
[reload-config](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/aerospace-reload-config.adoc)

### 真人 smoke test

获得 exact commit 的 activation 与启动授权后，最小顺序是：

1. 确认 Raycast launcher、既有 Script Commands 和原生菜单栏仍工作；
2. 授予 AeroSpace Accessibility 权限，并确认 SIP 未改变；
3. 逐项验证 Hyper+方向、Hyper+1/0、Hyper+Shift+1/0 与 Hyper+V；
4. 验证移动窗口后仍留在当前 workspace，且普通裸数字与 Esc 没有被 AeroSpace 捕获；
5. 单屏与现有多屏状态分别观察焦点、隐藏边缘、Mission Control 与原生 fullscreen；
6. 最后验证 `Hyper+Esc`：全部窗口恢复可见、快捷键停止，再从菜单栏 **Enable** 恢复到 main；
7. 退出 AeroSpace并确认窗口仍全部可见，且 logout/login 后不会自动启动。

### 回滚

1. 运行态立即用 `Hyper+Esc` 或菜单栏 **Disable** 暂停；暂停后从菜单栏或 CLI 恢复，不能依赖
   AeroSpace hotkey。
2. 退出 AeroSpace；上游会恢复不可见 workspace 的窗口。
3. 若 configuration generation 已 activation，由维护者切回 activation 前的 nix-darwin
   generation；不以删除窗口、修改 Spaces、logout 或撤销 SIP 作为代码回滚手段。
4. Accessibility 授权是 macOS 外部可变状态；如决定终止试验，由维护者在 System Settings 中
   手工撤销。Agent 不自动运行 `tccutil`。
5. 不删除或迁移 Raycast settings/database，不引入 SketchyBar，不更新 `flake.lock`。

## 7. 尚待维护者确认的事实

- Raycast 当前是否已占用任一拟议 Hyper 组合；
- Caps Lock → Hyper 在长按、释放和 Secure Input 场景下的实际事件行为；
- workspace 10 是否应显示为 `10` 并由 Hyper+0 访问；
- 移动窗口后是否保持当前 workspace，还是后续改用 `--focus-follows-window`；
- 现有显示器排列、“Displays have separate Spaces”、原生 Spaces 数量与 fullscreen 使用方式；
- 哪些具体 app/window 确有必要增加浮动例外；首轮不猜测。
