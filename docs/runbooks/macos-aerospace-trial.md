# macbook AeroSpace 首次试验与回滚

## 1. 适用范围

本文是 Issue [#171](https://github.com/sayoriqwq/nix-config/issues/171) 的维护者操作手册，只适用于
`macbook` 上由 Home Manager 声明的 AeroSpace `0.21.3-Beta` 候选。仓库内构建通过不等于已经
activation、启动应用、授予 Accessibility，或通过真实窗口验收。

当前候选有意保持手动启动：`programs.aerospace.launchd.enable = false`、
`start-at-login = false`、`after-login-command = []`。首次 activation 不会也不得自动启动
AeroSpace；本文不要求 logout 或 restart，也不把自动登录启动作为验证项。

以下动作必须分别在 Issue 或 Draft PR 中针对 exact commit、`macbook` 和当前操作窗口获得明确批准：

1. activation 新 generation；
2. 首次手动启动 AeroSpace；
3. 在 System Settings 中授予 Accessibility；
4. 执行真实窗口与双显示器冒烟验证；
5. generation rollback 或撤销 Accessibility。

本试验不修改 Raycast Settings、SIP、原生菜单栏、Mission Control、原生 Spaces、触控板手势、
“Displays have separate Spaces”或显示器排列。不要运行 `tccutil`，也不要为了试验注销或重启。

## 2. 交互合同

Raycast 继续唯一拥有 Caps Lock → Hyper 的转换。维护者已在 Raycast UI 中把 Hyper 设置为
`Command + Option + Control`，不含 Shift；AeroSpace 只消费最终产生的标准修饰键组合。

| 输入 | 预期行为 |
| --- | --- |
| `Hyper + ←/↓/↑/→` | 按方向聚焦窗口 |
| `Hyper + 1…9` | 切换到 AeroSpace workspace 1…9 |
| `Hyper + 0` | 切换到 AeroSpace workspace 10 |
| `Hyper + Shift + 1…9` | 移动当前窗口到 workspace 1…9，不跟随过去 |
| `Hyper + Shift + 0` | 移动当前窗口到 workspace 10，不跟随过去 |
| `Hyper + V` | 在 floating / tiling 间切换当前窗口 |
| `Hyper + Esc` | 执行 `enable off`，恢复隐藏 workspace 的窗口并停止 AeroSpace 快捷键 |

`Hyper + Esc` 是非对称逃生键：AeroSpace disable 后不再接收自己的快捷键，不能靠另一个
AeroSpace hotkey 恢复。恢复只能使用原生菜单栏的 **Enable**，或终端 CLI。

AeroSpace workspaces 是模拟工作区，不是原生 macOS Spaces。非活动 workspace 的窗口会被移动到
屏幕底部角落；正常 disable 或退出会将这些窗口恢复到可见区域，但不保证恢复试验前的精确几何。

## 3. Activation 前记录

在获得 activation 批准后，先确认待执行的是 Draft PR 中已审核的 exact commit，并把 commit、当前
system closure 和 generation number 记录到仓库外的本地 evidence。确认这期间没有插入无关
generation；若有，停止并重新制定定向回滚方案。

```fish
git rev-parse HEAD
readlink /run/current-system
sudo /run/current-system/sw/bin/darwin-rebuild --list-generations
```

🧾 记录 exact commit、当前 system closure 与 activation 前 generation。

在 Finder 或 Activity Monitor 中确认 AeroSpace 当前未运行。不要预先启动应用或修改
Accessibility。还应从 System Settings 只读确认当前原生 Spaces 数量、Mission Control 行为、
“Displays have separate Spaces”和显示器排列；只记录事实，不改变任何值。

Raycast live 快捷键正在由维护者仓库外重组，当前仓库盘点不作为占用事实。activation 前必须由
维护者确认 Raycast 已释放 `Hyper + V`；Ghostty、VS Code、Finder、Zed 等应用入口如何分配不由
本试验声明，待维护者之后同步新盘点。

## 4. 经批准的 Activation

维护者应使用已审核的 exact commit，而不是浮动分支名。下面的 `<exact-commit>` 必须由批准记录中
的完整 commit 替换；命令应由 Agent 预先生成供维护者复制，不要求手工录入哈希。

```fish
sudo darwin-rebuild switch --flake "github:sayoriqwq/nix-config/<exact-commit>#macbook"
```

🧩 激活已审核的 macbook generation，但不启动 AeroSpace。

activation 后先确认命令与应用已经进入当前声明，且没有 AeroSpace user LaunchAgent。以下只做
读取，不启动应用：

```fish
command -v aerospace
aerospace --version
test -e "$HOME/.aerospace.toml"; and echo "AeroSpace config present"
launchctl print "gui/"(id -u)"/org.nix-community.home.aerospace"
readlink /run/current-system
sudo /run/current-system/sw/bin/darwin-rebuild --list-generations
```

🔍 核对 CLI、版本、配置路径与 activation 后 generation，并预期 LaunchAgent 查询失败或不存在。

若 activation 自行启动了 AeroSpace、出现对应 LaunchAgent，或配置同时存在于
`~/.aerospace.toml` 与 `~/.config/aerospace/aerospace.toml`，立即停止首次试验并进入回滚；这与候选
合同不符。

## 5. 首次手动启动与 Accessibility

首次启动必须取得新的明确批准。通过 Finder 打开个人主目录下的
**`~/Applications/Home Manager Apps/AeroSpace.app`**；不要创建 Login Item、LaunchAgent 或其他
自动启动入口。若 LaunchServices 已识别该
应用，也可按 Home Manager 管理的准确应用路径执行：

```fish
open "$HOME/Applications/Home Manager Apps/AeroSpace.app"
```

🚀 仅在获批窗口中首次手动启动 AeroSpace。

AeroSpace 需要 macOS Accessibility 才能读取、聚焦和移动其他应用窗口。出现系统提示后，由
维护者手工进入 **System Settings → Privacy & Security → Accessibility**，只为此次 Nix 提供的
`AeroSpace.app` 打开权限。不得关闭或削弱 SIP，不得运行 `tccutil`，也不得为其他应用顺带改权。

授权后确认原生菜单栏出现 AeroSpace 图标；菜单栏中的 workspace 名称是本试验唯一新增的状态
反馈，不安装 SketchyBar。若系统要求退出/重新打开 AeroSpace 才能读取新权限，只允许在当前
首次启动批准中退出并手动重开该应用；不得 logout 或 restart。

## 6. 单显示器冒烟验证

使用不含敏感内容、可以安全移动的普通窗口验证。先保留一个原生 Space，不调整 Spaces 或显示器
设置。每一步都记录“通过 / 异常 / 未测”，遇到窗口丢失、持续闪动、错误聚焦或快捷键冲突时，
立即执行第 8 节的运行态逃生，不继续扩大测试。

1. 验证 Raycast 与 macOS 基线：
   - `Command + Space` 仍打开 Raycast；
   - Caps Lock 仍产生不含 Shift 的 Hyper；
   - Raycast 现有 Script Commands 和窗口命令仍能调用；
   - 原生菜单栏、时钟、电池与 Bartender 布局未改变。
2. 打开至少三个普通窗口，确认新窗口默认自动平铺；打开一个真实对话框，观察内建 dialog
   heuristics，而不添加应用例外。
3. 依次按 `Hyper + ←/↓/↑/→`，确认焦点按布局方向移动，且裸方向键未被截获。
4. 依次验证 `Hyper + 1`、`Hyper + 2` 与 `Hyper + 0`；确认 workspace 10 显示和切换语义明确，
   普通数字键仍正常输入。
5. 在 workspace 1 聚焦一个窗口，按 `Hyper + Shift + 2`；确认窗口移动到 workspace 2，而当前
   视图仍停留在 workspace 1。切到 workspace 2 找回该窗口，再用相同方式移回。
6. 对普通窗口按两次 `Hyper + V`，确认第一次切到 floating、第二次回到 tiling；记录窗口几何是否
   可接受，但不要把几何差异误判为 generation 失败。
7. 打开 Mission Control，确认原生总览仍可调用并记录模拟 workspace 窗口的实际呈现。再验证一个
   原生 fullscreen 窗口和既有原生 Space 切换入口；只观察交互，不改变系统设置。

## 7. 双显示器冒烟验证

连接并保持维护者当前的双显示器排列与“Displays have separate Spaces”设置，不拔插、重排或修改
主显示器。首轮配置没有 `workspace-to-monitor-force-assignment`：全部 AeroSpace workspaces 共享
池，并默认分配给 macOS 当前 main display，因此只记录实际行为，不现场设计绑定规则。

1. 两台显示器各放置至少一个可安全移动的窗口，确认平铺和方向聚焦不会让窗口永久不可见。
2. 在两台显示器分别切换 workspace，记录 workspace 的 assigned monitor、焦点落点以及同一
   workspace 不能同时显示在两台屏幕上的表现。
3. 移动窗口到另一 workspace 后，从对应显示器找回；确认被隐藏窗口没有在另一显示器底部或边角
   大面积露出。约 1 像素边缘属于上游模拟模型的已知限制，也应记录。
4. 分别在两台显示器调用 Mission Control、原生 Space 切换和一个原生 fullscreen 窗口，确认原生
   菜单栏仍存在，且没有改变当前系统设置。
5. 若必须新增 workspace-to-monitor 分配或应用例外，停止本轮：先收集真实 monitor/window/bundle
   ID 证据，再通过新的窄范围 commit 和人工审核处理，不在现场修改配置。

## 8. 运行态暂停、恢复与退出

完成其他 smoke 后再验证逃生键。按 `Hyper + Esc` 后应立即发生：AeroSpace 停止接管快捷键；所有
模拟隐藏的 workspace 窗口回到可见区域；原生 macOS 与 Raycast 快捷键继续工作。窗口位置可能与
试验前不同，这是运行态限制，不要为此修改 Spaces 设置。

需要继续测试时，从 macOS 原生菜单栏的 AeroSpace 图标选择 **Enable**。若菜单不可用而 CLI 仍
可执行，使用：

```fish
aerospace enable on
```

▶️ 从终端恢复 AeroSpace main mode；disable 后不能使用 AeroSpace hotkey 恢复。

若逃生键失效但 CLI 可用，先执行：

```fish
aerospace enable off
```

🛑 通过官方 CLI 停止窗口接管并恢复隐藏 workspace 的窗口。

随后从原生菜单栏选择 **Quit AeroSpace**。退出后确认全部窗口可见、Raycast 和原生窗口操作正常。
本轮不通过 logout/login 验证自动启动；`launchd.enable = false` 与 `start-at-login = false` 已由声明
级检查覆盖，真实 logout/restart 需要另行授权且不属于 Issue #171。

## 9. 完整回滚

回滚分三层，不能互相替代。

### 9.1 运行态回滚

先执行 `Hyper + Esc` 或菜单栏 **Disable**，再从菜单栏退出 AeroSpace。确认 workspace 1…10 的
窗口都回到可见区域后，才处理 generation。正常退出会恢复可见性，但不会恢复原始窗口几何。

如果应用无响应，可先用第 8 节的 CLI disable；不要直接强制结束后便假设所有窗口已经恢复。

### 9.2 声明与 generation 回滚

generation rollback 需要新的当前批准。重新核对第 3 节记录的 activation 前 generation，并确认
没有插入其他 generation。只有目标确实是紧邻上一代时才执行：

```fish
sudo darwin-rebuild --rollback switch
```

↩️ 切回紧邻上一代 nix-darwin/Home Manager 声明。

若已有中间 generation，不要使用模糊的 `--rollback`；停止并针对已记录的目标 generation 制定
定向恢复。切回上一代会移除 AeroSpace 的 Nix package/config 声明，但不能撤销 TCC、恢复窗口
几何、修改 Raycast Settings，或改变原生 Spaces/显示器状态。不得运行 GC；保留候选与已知良好
generation，直到 Issue 验收完成。

### 9.3 Accessibility 回滚

Accessibility 是 macOS TCC 外部可变状态，不由 Nix generation 拥有。决定终止试验且取得撤权
批准后，由维护者手工进入 **System Settings → Privacy & Security → Accessibility**，关闭或移除
`AeroSpace.app` 对应项。只操作精确 AeroSpace 条目，不运行 `tccutil`，不修改 Raycast 或其他应用
权限。

若旧的 Nix store app 条目在 generation 回滚后仍显示，这是 TCC/系统设置残留，不表示 AeroSpace
仍自动运行。记录条目身份和 UI 结果即可；不要删除 TCC 数据库或手工清理 Nix store。

## 10. 验收记录

在 Issue #171 或 Draft PR 中记录：

- activation 的 exact commit、前后 generation 与 system closure；
- 首次启动和 Accessibility 的人工批准与结果；
- Raycast `Command + Space`、Caps Lock Hyper、Script Commands 和既有窗口命令是否回退；
- 单屏与双屏的方向聚焦、workspace 1/2/10、Shift 移窗、floating/tiling 结果；
- 原生菜单栏、Mission Control、fullscreen、Spaces 和多显示器行为；
- `Hyper + Esc`、菜单栏 Enable/Disable、CLI fallback 与 Quit 是否恢复全部窗口可见；
- 未修改 SIP、Raycast Settings、原生 Spaces/显示器设置，未创建 launchd/login startup；
- 异常、未测项、回滚动作和仍保留的 TCC 外部状态。

只有维护者完成上述真人验证、审阅最终 diff，并分别批准 Ready、merge 后，才能把本试验视为完成。
