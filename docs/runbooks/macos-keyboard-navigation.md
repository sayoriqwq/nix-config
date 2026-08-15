# macOS 键盘导航审计、调控与回滚

## 1. 适用范围

本文是 Issue [#173](https://github.com/sayoriqwq/nix-config/issues/173) 的维护者手册，只处理
`macbook` 上两个已经证明的副作用偏移：

- Raycast launcher / Caps Lock Hyper 与 macOS 窗口切换、Spotlight；
- AeroSpace 裸 `Ctrl` bindings 与 macOS Mission Control / Spaces。

Nix build 只安装声明、生成 AeroSpace 配置和 `macos-keyboard-navigation` 命令，不执行
`reconcile`，不启动 AeroSpace，不修改 TCC，也不写入真实 preference domain。真实 activation、
system preference reconcile、首次启动、Accessibility 和真人 smoke 是彼此独立的人工关卡。

## 2. 行为与所有权合同

| 行为 | 期望入口 | 所有者与边界 |
| --- | --- | --- |
| 打开 Raycast | `Cmd+Space` | Raycast UI 保存 launcher；工具只读审计 |
| 产生 Hyper | Caps Lock → `Ctrl+Option+Command`，不含 Shift | Raycast UI 保存；工具只读审计 |
| 聚焦下一个 macOS 窗口 | `Hyper+Space` | macOS symbolic hotkey 27；工具可在获批后逐叶调控 |
| 聚焦 AeroSpace 窗口 | `Ctrl+方向键` | AeroSpace 配置；冲突的 macOS leaves 逐叶让位 |
| 切换 AeroSpace workspace | `Ctrl+1…0` | AeroSpace 配置；冲突的 macOS leaves 逐叶让位 |
| 移动窗口 | `Ctrl+Shift+1…0` | AeroSpace 配置 |
| 切换平铺 / accordion | `Ctrl+Tab` | AeroSpace 配置；进入 accordion 后用 `Ctrl+方向键` 切换当前窗口 |
| 切换 floating / tiling | `Ctrl+V` | AeroSpace 配置 |
| 停止 AeroSpace 接管 | `Ctrl+Esc` | AeroSpace 配置；恢复只能走菜单栏或 CLI |

AeroSpace workspace 不是原生 Space。触控板 Mission Control / Spaces 手势继续作为系统 fallback，
不由本能力修改或拥有。

Raycast preference plist、数据库、账户、Keychain、extension registry 与 TCC 继续由应用和维护者
拥有。工具只读取两个已确认的 shortcut leaves：`raycastGlobalHotkey = Command-49`，以及
`raycast_hyperKey_state = { enabled = true; includeShiftKey = false; keyCode = 57; }`；它从不写
Raycast domain，也不推断不存在的私有顶层 key。

## 3. symbolic-hotkey policy

工具只认识 Issue #173 批准的 ID：

- `27` 必须是 `[32, 49, 1835008]`，即 `Ctrl+Option+Command+Space`；唯一可自动收敛的旧基线是
  当前已取证的 `[32, 49, 1966080]`；
- `32`、`33`、`64`、`65`、`79`、`81`、`118`、`119` 必须存在且禁用；
- `120`–`127` 若不存在则保持不存在，若存在则只把原 leaf 的 `enabled` 改为 `false`；
- 其他 ID 全部忽略并保留，包括未进入本 Issue 的 slow sibling。

禁用已有 leaf 时，工具保留它原有的 `value` 与类型，只在临时 typed XML 副本中把
`enabled` 改为 Boolean `false`。写入使用一次 leaf-local `defaults ... -dict-add`；不会把
OpenStep 数字/布尔值退化为字符串，也不会整表替换 `AppleSymbolicHotKeys`。

若 required leaf 缺失、结构未知、ID 27 不是已批准的 desired/legacy 之一，工具停止而不写。
这是证据边界，不是需要“自动修复”的异常。

## 4. 只读审计

`audit` 可以在没有 activation 或写入批准时运行。它只读两个 exact plist 文件，并用退出码区分：

- `0`：Raycast 人工前置事实与 managed system leaves 都符合；
- `2`：发现工具认识、但尚未收敛的偏移；
- `1`：文件/类型/leaf 不在已证明合同内，需要停止调查。

```fish
macos-keyboard-navigation policy
macos-keyboard-navigation audit
```

🔎 显示内部 policy，并只读核对 Raycast gate 与 macOS symbolic-hotkey leaves。

`audit` PASS 只说明读取时的 exact leaves 符合，不证明 AeroSpace 已 activation、已经获得
Accessibility、正在运行，或真实窗口行为已经验收。

## 5. Activation 前后边界

本 PR 没有真实 activation 授权。未来获批时，先记录 exact commit、当前 system closure 与
generation；由 Agent 针对该批准生成包含 exact commit 的短命令，不要手工输入哈希或浮动分支。

activation 只把 package、配置和命令带入 generation。完成后，在不启动 AeroSpace 的前提下核对：

```fish
command -v macos-keyboard-navigation
command -v aerospace
test -e "$HOME/.aerospace.toml"; and echo "AeroSpace config present"
launchctl print "gui/"(id -u)"/org.nix-community.home.aerospace"
```

🧩 核对命令与配置存在，并预期 AeroSpace LaunchAgent 查询失败或不存在。

如果 activation 自动启动 AeroSpace、创建 login item/LaunchAgent，或出现两份 AeroSpace 配置，
立即停止；这不符合能力合同。

## 6. 经批准的 reconcile

真实 `reconcile` 必须取得针对 exact commit、当前机器和当前操作窗口的单独批准。执行前：

1. 完全退出 Raycast 主进程；
2. 完全退出 System Settings；
3. 确认没有未处理的 active rollback receipt；
4. 先运行 `audit` 并把输出记录到仓库外 evidence；
5. 不退出、重启或 kill Dock、SystemUIServer、WindowServer，也不 logout。

获批后只执行短命令：

```fish
macos-keyboard-navigation reconcile
macos-keyboard-navigation audit
```

🎛️ 逐叶写入已批准的 system hotkeys，保存 exact rollback receipt，并立即回读。

若当次 action card 已把允许变化进一步收窄为 exact ID 集合，必须把它作为写前事务前置条件。例如只
允许 ID 27 时使用：

```fish
macos-keyboard-navigation reconcile --expect-changed 27
macos-keyboard-navigation audit
```

🔒 实际扫描出的变化集合与获批集合不完全相同时，在 receipt 与 preference 写入前停止。

工具在
`~/.local/state/nix-config/macos-keyboard-navigation/active.json` 保存本次实际改动 leaves 的
exact before/after typed XML、目标 identity 与 ID 清单。目录和文件是 owner-only；receipt 存在时再次
`reconcile` 会拒绝执行，避免新基线覆盖仍需回滚的旧基线。

`reconcile` 与 `rollback` 还通过 owner-only `operation.lock` 串行化。若进程被强制终止而留下
stale lock，工具会安全停止；不要直接删除 lock 或 receipt。先确认没有仍在运行的操作，核对
`active.json` 与 exact leaves，再通过新的当次批准决定继续 rollback 或清理证据。

写入成功不保证当前进程立即采用新快捷键。不要由脚本自动重启系统组件；先重新打开 Raycast，
再通过 UI 和真人按键 smoke 观察。若 macOS 要求 logout/restart 才生效，停止并为该动作取得新的
批准。

## 7. AeroSpace 首次启动与 smoke

首次启动和 Accessibility 必须另获批准。只从 Home Manager 应用路径手动打开：

```fish
open "$HOME/Applications/Home Manager Apps/AeroSpace.app"
```

🚀 手动启动当前 generation 的 AeroSpace，不建立登录启动入口。

由维护者在 **System Settings → Privacy & Security → Accessibility** 中只为这份
`AeroSpace.app` 授权；不得运行 `tccutil`。随后用不含敏感内容、可安全移动的窗口依次验证：

1. `Cmd+Space` 打开 Raycast，Caps Lock 产生不含 Shift 的 Hyper；
2. `Hyper+Space` 聚焦下一个 macOS 窗口；
3. `Ctrl+←/↓/↑/→` 按布局聚焦；
4. `Ctrl+1`、`Ctrl+2`、`Ctrl+0` 切换 workspace 1、2、10；
5. `Ctrl+Shift+2` 移动窗口且不跟随；
6. 连续两次 `Ctrl+V` 往返 floating / tiling；
7. 触控板 Mission Control / Spaces 手势仍可用，原生 conflicting Ctrl chords 不再抢占；
8. 单屏通过后，再记录双屏、fullscreen、窗口找回与 workspace assigned monitor 行为。

若出现窗口丢失、持续闪动或错误聚焦，立即按 `Ctrl+Esc`。AeroSpace disable 后不会再接收自己的
快捷键；恢复测试使用：

```fish
aerospace enable on
```

▶️ 通过官方 CLI 恢复 AeroSpace；不要为恢复另加全局 hotkey。

## 8. system preference rollback

rollback 与 generation rollback 相互独立。若真实 reconcile 后要撤销，先完全退出 Raycast 与
System Settings，并对当前 active receipt 取得 rollback 批准，再执行：

```fish
macos-keyboard-navigation rollback
macos-keyboard-navigation audit
test $status -eq 2
```

↩️ 通过 before/after CAS 恢复本次 exact leaves，并预期审计重新报告旧基线偏移。

rollback 在写入前检查 receipt 中每个 leaf：当前值必须等于保存的 before 或 after；任何一个 leaf
出现第三种值，整次 rollback 都停止且一项不写。成功后 active receipt 会移入 owner-only history，
保留操作证据并允许未来重新 reconcile。

若 active receipt 丢失，不得从文档手工重建旧值，也不得整表恢复 preference domain；停止并按
当时 live facts 新开窄维护 Issue。

## 9. AeroSpace 与 generation rollback

先用 `Ctrl+Esc` 或菜单栏 **Disable**，确认所有模拟 workspace 的窗口重新可见，再退出 AeroSpace。
generation rollback 必须另获批准，并使用 activation 前记录的 exact generation。它可以撤销 Nix
package/config 声明，但不能撤销 TCC、system preference reconcile、Raycast UI 设置或窗口几何。

Accessibility 撤权同样是独立人工动作：只在获批后从 System Settings 移除 exact AeroSpace
条目；不得直接修改 TCC 数据库。

## 10. 验收记录

在 Issue #173 或 Draft PR 中记录：

- exact commit、前后 generation 与 system closure；
- reconcile 前后的 `audit` 输出、active receipt 状态和人工批准；
- Raycast launcher、Hyper no-Shift 与 `Hyper+Space`；
- AeroSpace 首次启动、Accessibility、单屏/双屏/fullscreen smoke；
- `Ctrl+Esc`、CLI Enable/Disable、全部窗口可见性；
- 触控板 fallback 与未触碰的 symbolic IDs；
- 任何 logout/restart 要求、异常、未测项和各层 rollback。

构建、审计、调控、启动和真人行为必须分别报告，不能用其中一项替代其他项。
