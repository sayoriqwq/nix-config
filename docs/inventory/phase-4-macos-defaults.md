# Phase 4 macOS defaults 声明与回滚

- **机器：** `macbook`
- **采集日期：** 2026-07-27
- **来源：** Issue #37 的逐组维护者决策与逐键现场读取
- **边界：** 只记录有意管理的行为；不保存完整 defaults 数据库

## 所有权

`modules/darwin/defaults.nix` 是 macOS 系统行为的唯一声明入口。Home Manager
不管理这些键。Raycast、Bartender 和 CleanShot X 继续分别拥有窗口操作、菜单栏
布局和截图工作流；本模块只提供不会与这些应用争夺操作入口的系统基础行为。

锁定 nix-darwin 会以 `system.primaryUser` 身份写入用户 defaults，并在存在 Dock
键时重启 Dock。Control Center 选项使用主用户的 ByHost plist writer。macOS 27
显示原生电池菜单栏项所需的 `Battery = 2` 尚无上游 option，因此本地模块只补充
这个 option 的类型定义，实际写入仍由 nix-darwin 完成；仓库没有第二套 defaults
activation script。

## Dock 与 Finder

| domain / key | 采集值 | 目标值 | 可观察行为 |
| --- | ---: | ---: | --- |
| `com.apple.dock.autohide` | `1` | `true` | Dock 自动隐藏 |
| `com.apple.dock.show-recents` | `0` | `false` | 不显示最近使用的应用 |
| `com.apple.dock.tilesize` | `64` | `64` | Dock 图标大小保持 64 |
| `com.apple.dock.mru-spaces` | `0` | `false` | Spaces 不按最近使用重排 |
| `com.apple.dock.minimize-to-application` | 未设置 | `true` | 最小化窗口收进应用图标 |
| `NSGlobalDomain.AppleShowAllExtensions` | `1` | `true` | 显示所有扩展名 |
| `com.apple.finder.ShowPathbar` | `1` | `true` | 显示路径栏 |
| `com.apple.finder.FXPreferredViewStyle` | `clmv` | `clmv` | 新 Finder 窗口使用分栏视图 |
| `com.apple.finder.ShowStatusBar` | 未设置 | `true` | 显示项目数量和可用空间 |

Dock 在 activation 中由 nix-darwin 自动重启。Finder 设置对新窗口生效；若现有
Finder 窗口未刷新，人工退出并重新打开 Finder，不在无人值守 activation 中 kill。

## 键盘与文本输入

| domain / key | 采集值 | 目标值 | 可观察行为 |
| --- | ---: | ---: | --- |
| `NSGlobalDomain.InitialKeyRepeat` | `15` | `15` | 较短的首次重复延迟 |
| `NSGlobalDomain.KeyRepeat` | `2` | `2` | 较快的按键重复 |
| `NSGlobalDomain.com.apple.keyboard.fnState` | `1` | `true` | F1–F12 是标准功能键 |
| `NSGlobalDomain.ApplePressAndHoldEnabled` | 未设置 | `false` | 长按字母重复而非弹出重音菜单 |
| `NSGlobalDomain.NSAutomaticCapitalizationEnabled` | `1` | `false` | 不自动大写技术文本 |
| `NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled` | `1` | `false` | 双空格不自动插入句号 |
| `NSGlobalDomain.NSAutomaticDashSubstitutionEnabled` | 未设置 | `false` | 不自动替换破折号 |
| `NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled` | 未设置 | `false` | 不自动替换弯引号 |

已运行应用可能缓存全局文本设置；退出并重新打开应用后验证。按键与系统级文本
行为若仍未刷新，以重新登录为可靠边界。

## Trackpad、滚动与 Mission Control

| domain / key | 采集值 | 目标值 |
| --- | ---: | ---: |
| `NSGlobalDomain.AppleShowScrollBars` | 未设置 | `Always` |
| `NSGlobalDomain.com.apple.trackpad.scaling` | `2` | `2.0` |
| `NSGlobalDomain.com.apple.trackpad.forceClick` | `1` | `true` |
| `NSGlobalDomain.com.apple.swipescrolldirection` | `1` | `true` |
| `com.apple.AppleMultitouchTrackpad.Clicking` | `1` | `true` |
| `...Dragging` | `0` | `false` |
| `...DragLock` | `0` | `false` |
| `...TrackpadRightClick` | `1` | `true` |
| `...TrackpadCornerSecondaryClick` | `0` | `0` |
| `...TrackpadThreeFingerDrag` | `1` | `true` |
| `...TrackpadThreeFingerTapGesture` | `0` | `0` |
| `...TrackpadThreeFingerHorizSwipeGesture` | `0` | `0` |
| `...TrackpadThreeFingerVertSwipeGesture` | `0` | `0` |
| `...TrackpadFourFingerHorizSwipeGesture` | `2` | `2` |
| `...TrackpadFourFingerPinchGesture` | `2` | `2` |
| `...TrackpadFourFingerVertSwipeGesture` | `2` | `2` |
| `...TrackpadMomentumScroll` | `1` | `true` |
| `...TrackpadPinch` | `1` | `true` |
| `...TrackpadRotate` | `1` | `true` |
| `...TrackpadTwoFingerDoubleTapGesture` | `1` | `true` |
| `...TrackpadTwoFingerFromRightEdgeSwipeGesture` | `3` | `3` |
| `...FirstClickThreshold` | `1` | `1` |
| `...SecondClickThreshold` | `1` | `1` |
| `...ForceSuppressed` | `0` | `false` |
| `...ActuateDetents` | `1` | `true` |
| `com.apple.dock.showDesktopGestureEnabled` | 未设置 | `true` |
| `com.apple.dock.showLaunchpadGestureEnabled` | 未设置 | `false` |
| `com.apple.dock.showMissionControlGestureEnabled` | 未设置 | `true` |
| `com.apple.dock.showAppExposeGestureEnabled` | 未设置 | `false` |

四指水平手势切换 Spaces/全屏应用；四指上推进入 Mission Control，四指展开显示
桌面。Launchpad 和 App Exposé 不占用手势，三指只用于拖动。Dock 重启后验证；
Trackpad 系统面板或现有应用未刷新时重新登录。

## 窗口与 Hot Corners

| domain / key | 采集值 | 目标值 | 行为 |
| --- | ---: | ---: | --- |
| `com.apple.WindowManager.EnableTilingByEdgeDrag` | 未设置 | `false` | 关闭拖到边缘平铺 |
| `com.apple.WindowManager.EnableTopTilingByEdgeDrag` | 未设置 | `false` | 关闭拖到顶部填充 |
| `com.apple.WindowManager.EnableTilingOptionAccelerator` | 未设置 | `false` | 关闭按住 Option 拖动平铺 |
| `com.apple.dock.wvous-tl-corner` | `1` | `1` | 左上关闭 |
| `com.apple.dock.wvous-tr-corner` | `1` | `1` | 右上关闭 |
| `com.apple.dock.wvous-bl-corner` | `1` | `1` | 左下关闭 |
| `com.apple.dock.wvous-br-corner` | `14` | `14` | 右下 Quick Note |
| 四个 `wvous-*-modifier` | `0` | `0` | Hot Corner 不要求修饰键 |

Raycast 是窗口管理主路径。macOS 绿色按钮、Window 菜单和全屏保持可用。Hot
Corners 已在决定阶段人工试用并保留；activation 只把当前状态声明化。

## 菜单栏、时钟与电池

| domain / key | Phase 4 试用前 | 当前/目标 | 行为 |
| --- | ---: | ---: | --- |
| `com.apple.menuextra.clock.Show24Hour` | 未设置 | `true` | 24 小时制 |
| `...ShowDayOfWeek` | `false` | `true` | 显示星期 |
| `...ShowDate` | `2` | `1` | 始终显示日期 |
| `...ShowSeconds` | 未设置 | `false` | 不显示秒钟 |
| ByHost `com.apple.controlcenter.Battery` | UI 关闭 | `2` | 显示原生电池项 |
| ByHost `...BatteryShowPercentage` | UI 关闭 | `true` | 显示电量百分比 |

这些目标已由维护者在真实菜单栏中试用并确认。Bartender 继续拥有布局。若
activation 后菜单栏没有刷新，先退出并重新登录；只有维护者另行批准时才重启
SystemUIServer 或 Control Center。

## 不管理的行为

- 保存/打印面板、默认本地或 iCloud、自动窗口标签、自动终止与窗口恢复；
- 原生截图保存位置、格式、阴影与缩略图；
- Dock 动画、方向、Magnification；
- 拼写纠正、行内预测、完整键盘焦点导航；
- 鼠标 tracking speed、滚动条空白区域点击行为；
- Raycast、Bartender、CleanShot X 的应用内设置；
- TCC、隐私、安全、网络和其他系统边界。

## Activation 前检查

1. 完全退出正在编辑系统设置的 System Settings 窗口。
2. 记录当前 generation 和本文中原先未设置/已改变的键。
3. 使用 PR 中经过验证的精确 commit 构建。
4. 单独取得维护者对 `darwin-rebuild switch` 的当次批准。
5. activation 后先验证 Dock/Finder、输入、手势、窗口拖拽、Hot Corner、时钟和
   电池；只有未刷新时才请求额外的进程或登录动作。

## 回滚

首先回滚 system generation：

```fish
sudo darwin-rebuild --rollback switch
```

这不会删除上一代未声明的 defaults。若目标是恢复 Phase 4 试用前状态，还需在
维护者批准后定向执行：

```fish
defaults delete com.apple.dock minimize-to-application
defaults delete com.apple.finder ShowStatusBar

defaults delete -g ApplePressAndHoldEnabled
defaults write -g NSAutomaticCapitalizationEnabled -bool true
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool true
defaults delete -g NSAutomaticDashSubstitutionEnabled
defaults delete -g NSAutomaticQuoteSubstitutionEnabled
defaults delete -g AppleShowScrollBars

defaults delete com.apple.dock showDesktopGestureEnabled
defaults delete com.apple.dock showLaunchpadGestureEnabled
defaults delete com.apple.dock showMissionControlGestureEnabled
defaults delete com.apple.dock showAppExposeGestureEnabled

defaults delete com.apple.WindowManager EnableTilingByEdgeDrag
defaults delete com.apple.WindowManager EnableTopTilingByEdgeDrag
defaults delete com.apple.WindowManager EnableTilingOptionAccelerator

defaults delete com.apple.menuextra.clock Show24Hour
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
defaults write com.apple.menuextra.clock ShowDate -int 2
defaults delete com.apple.menuextra.clock ShowSeconds
```

原生电池项和百分比的试用前状态均为关闭；由于 macOS 27 使用 ByHost 状态，回滚
优先通过 System Settings 关闭，而不是假设跨系统版本的整数表示。Hot Corners
试用前为左上/右上/左下未设置、右下 Disabled；只有维护者要求放弃已批准体验时，
才删除前三个 corner 键并将右下恢复为 `1`。

完成定向回滚后，按同样的人工关卡重启 Dock/Finder/SystemUIServer 或重新登录。
