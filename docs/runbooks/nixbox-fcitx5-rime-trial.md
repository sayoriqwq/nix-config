# nixbox Fcitx 5 / Rime Ice 首次试用、验收与恢复

## 1. 用途与安全边界

本文只供维护者在 `nixbox` 上试用 Issue
[#169](https://github.com/sayoriqwq/nix-config/issues/169) 的 Fcitx 5 / Rime Ice 候选。仓库内
check、build 或 closure diff 通过不等于真实 activation 获批。执行 `nixos-rebuild test`、结束当前
图形会话、重新登录、重启或以后执行 `switch` 前，都必须在 Issue 或 PR 中记录针对**准确提交、准确
动作与当前执行窗口**的人工批准。

当前 Issue 只授权声明、测试、文档和构建；本文中的 activation、logout、relogin、reboot、Rime
deploy、输入框架切换和用户状态清理都**没有获得当前授权**，本文编写期间也没有执行它们。首次试用
不得手工启动或重启 Fcitx/IBus，不得编辑 `~/.config/fcitx5`，不得删除、移动、遍历、读取或迁移
Fcitx、Rime、IBus、dconf 的用户数据，也不得运行 GC 或删除旧 generation。

本候选的所有权边界是：NixOS 模块唯一提供 Fcitx framework、`fcitx5-rime` addon、system defaults、
会话/toolkit 环境和 XDG autostart；Home Manager 只连接共享的静态 Rime data view，并声明可变状态
边界。`~/.config/fcitx5`、Rime userdb、`build`、`sync`、`installation.yaml`、`user.yaml` 和遗留
IBus/dconf 状态仍由应用或用户拥有，不进入 Git/Nix Store。

恢复模型分为两种：

- `nixos-rebuild test` 临时切换当前运行系统，但不移动 system profile，也不改变 boot default。
  候选失败时，在 reboot 已单独获批且旧 boot entry 已核实的前提下，重启返回试用前的 boot-default
  generation。
- 只有未来另行批准 `nixos-rebuild switch`，候选才成为 system profile generation 和 boot
  default；此后才能按已核实的 generation 身份使用上一代 boot entry 或
  `nixos-rebuild switch --rollback`。

无论哪种恢复都只切换声明式 generation，不会撤销试用期间写入的 userdb、Fcitx 配置、Rime deploy
产物或遗留 IBus/dconf 状态。

## 2. Inventory / PR gate（只读）

在申请首次 activation 前，由维护者在真实 `nixbox` 上收集以下脱敏事实。只检查已知路径本身的
metadata，不递归列举目录，不读取配置或词典正文；输出若包含地址、账号或其他敏感值，只在本地留存。

先核对仓库、准确提交和工作树：

```fish
git rev-parse HEAD
git status --short
```

🔎 记录候选提交，并确认它与待批准提交一致且没有未审阅改动。

记录运行 closure、profile、generation 与 boot entry：

```fish
set -l running_system (readlink -f /run/current-system)
set -l profiled_system (readlink -f /nix/var/nix/profiles/system)
printf 'running:  %s\nprofiled: %s\n' $running_system $profiled_system
nixos-rebuild list-generations
bootctl list --no-pager
```

🛟 识别试用前已验收 generation，并确认其 Store closure、profile 与 boot entry 仍可用于恢复。

只读盘点当前输入框架的 executable、process、用户 unit 与会话环境；“未找到”也是必须记录的事实：

```fish
type -a ibus ibus-daemon fcitx5 fcitx5-remote
pgrep -a ibus-daemon; or true
pgrep -a fcitx5; or true
systemctl --user list-units --all --no-legend | string match -ri '.*(fcitx|ibus).*'; or true
systemctl --user show-environment | string match -r '^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS|SDL_IM_MODULE)='; or true
```

⌨️ 记录 activation 前 IBus/Fcitx 的 package、daemon、autostart unit 与 session integration 基线。

只检查精确可变根的类型、owner、mode 和时间戳；不得用 `find`、`tree`、递归 `ls`、`rg`、`cat`、
hash 或复制命令查看其内容：

```fish
for path in \
        ~/.config/fcitx5 \
        ~/.local/share/fcitx5/rime \
        ~/.local/share/fcitx5/rime/build \
        ~/.local/share/fcitx5/rime/luna_pinyin.userdb \
        ~/.local/share/fcitx5/rime/rime_ice.userdb \
        ~/.local/share/fcitx5/rime/sync \
        ~/.local/share/fcitx5/rime/installation.yaml \
        ~/.local/share/fcitx5/rime/user.yaml \
        ~/.config/dconf/user
    if test -e $path -o -L $path
        stat --format='%n | %F | mode=%a | owner=%U:%G | mtime=%y' $path
    else
        printf '%s | absent\n' $path
    end
end
```

🧾 只记录已知状态边界的 metadata，不读取用户词典、偏好或数据库正文。

从另一台已授权机器验证既有恢复通道；不要把地址、key 或完整 Tailscale 输出贴入公开 Issue：

```fish
ssh nixbox 'systemctl is-active sshd tailscaled NetworkManager'
```

🔐 确认 SSH/Tailscale 与 NetworkManager 恢复入口在试用前可用。

PR gate 还必须审阅候选 closure，确认只有一个 NixOS Fcitx package/session/autostart owner，精确包含
共享 Rime data package 的 `fcitx5-rime` addon，没有 Home Manager Fcitx daemon、IBus residue、额外
addon、输入重映射、网络/SSH/Tailscale/GDM/Hyprland/server 增量。任一事实不清楚即停止，不在真实
机器上用临时环境变量或手工配置补洞。

## 3. 非激活构建

从仓库根目录构建准确的 `nixbox` output；该命令不会切换运行系统：

```fish
nix build .#nixosConfigurations.nixbox.config.system.build.toplevel --no-link
```

🏗️ 构建候选 closure，但不激活、不重启输入法，也不改变 boot default。

构建失败即停止。构建成功后，把 `git rev-parse HEAD` 的结果、验证结果与拟执行的 `test`、logout /
relogin 以及必要时 reboot 动作写入 Issue/PR，等待针对该准确提交和当前窗口的新批准。

## 4. 首次 activation gate（未来维护者执行）

只有以下条件全部满足，维护者才可以执行首次 `test`：

1. Issue/PR 已对当前 `HEAD` 的 `nixos-rebuild test`、结束现有图形会话、重新登录、首次启动
   Fcitx/Rime 及其可能写入的 deploy cache，以及必要时的 reboot 分别给出当前批准；不能从旧
   Issue 的泛化同意推导授权。
2. 第 2 节记录的提交仍等于获批提交，工作树无未审阅改动。
3. 已记录试用前已验收 generation，且其 profile/GC root/boot entry 仍存在；试用完成前不运行 GC。
4. 本地键盘、显示器、TTY 可用，另一台机器已实测 SSH/Tailscale 恢复通道。
5. 重要用户状态已有独立备份，或维护者明确接受 generation rollback 不恢复这些状态。

从已验证的 SSH 控制面或本地 TTY，而不是即将结束的图形 terminal，最后核对 exact commit：

```fish
set -l candidate_commit (git rev-parse HEAD)
printf 'candidate commit: %s\n' $candidate_commit
git status --short
```

🧭 将屏幕上的完整 commit 与 Issue/PR 当前批准逐字核对；不一致或工作树非空立即停止。

未来获批的临时 activation 命令是：

```fish
sudo nixos-rebuild test --flake .#nixbox
```

🧪 临时切换当前运行 closure；当前没有执行该命令的授权。

命令返回后仍留在 SSH/TTY 控制面，先检查系统访问与 display manager，没有确认健康前不要 logout：

```fish
systemctl --no-pager --full status sshd tailscaled NetworkManager display-manager
```

🩺 确认输入能力变更没有造成访问、网络或登录管理器回退。

Fcitx 的 XDG autostart 属于新 UWSM graphical session。不要为“立即看到进程”手工运行 `fcitx5`、
`systemctl --user start/restart` 或修改环境变量；按当前批准正常结束旧 session，在 GDM 精确选择
`Hyprland (uwsm-managed)` 重新登录。若批准不覆盖 logout/relogin，就停在这里等待批准。

## 5. UWSM / Fcitx / Rime 基线 smoke

所有步骤都记录 PASS/FAIL；不记录密码、候选历史、用户词典正文、账号、地址或浏览器隐私数据。任一
核心项失败都不允许提升为 `switch`。

登录后确认 UWSM graphical session、唯一 Fcitx daemon、Rime engine 和无 IBus process：

```fish
systemctl --user is-active graphical-session.target
set -l fcitx_pids (pgrep -x fcitx5)
printf 'fcitx5 process count: %s\n' (count $fcitx_pids)
test (count $fcitx_pids) -eq 1; and echo 'PASS: one fcitx5 daemon'; or echo 'FAIL: fcitx5 daemon owner count is not one'
fcitx5-remote -n
pgrep -a ibus-daemon; and echo 'FAIL: IBus residue is running'; or echo 'PASS: no IBus daemon'
systemctl --user list-units --all --no-legend | string match -ri '.*(fcitx|ibus).*'; or true
busctl --user list | string match '*org.fcitx.Fcitx5*'; or true
```

🐧 确认 UWSM 中只有一个由 XDG autostart 生命周期拥有的 Fcitx daemon，active engine 为 `rime`。

记录登录 session 获得的 toolkit 环境，并与 PR 中审阅过的 NixOS module 输出一致：

```fish
systemctl --user show-environment | string match -r '^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS|SDL_IM_MODULE)='; or true
```

🧩 核对 Wayland、XWayland、GTK 与 Qt integration；缺失或意外值不得靠现场 `set -x` 修复。

打开 Fcitx 菜单，确认 Default group 只有 Rime（显示名可为“中州韵”），没有可切换的
`keyboard-us` fallback；`fcitx5-remote -n` 始终返回 `rime`。不要在 GUI 中保存或改写配置。

## 6. 真人输入矩阵

为每个应用记录：实际显示协议（Wayland 或 XWayland）、中文候选是否出现、候选窗位置、候选选择与
上屏、中文/英文标点、左右 Shift、切应用状态。测试内容必须是无敏感意义的短语，不使用真实密码、
账号或私人文本。

| 路径 | 启动/确认方式 | 必测结果 |
| --- | --- | --- |
| Ghostty / native Wayland | `Super+Q`；用 `hyprctl clients` 确认 `xwayland: 0` | GTK text input、候选窗、上屏、标点、左右 Shift |
| Firefox / native Wayland | 从 Fuzzel 启动；用 `hyprctl clients` 确认 `xwayland: 0` | 网页普通文本框和地址栏均可输入，候选位置正确 |
| Chrome / native Wayland | 从 Fuzzel 启动；用 `hyprctl clients` 确认 `xwayland: 0` | 网页普通文本框和地址栏均可输入，候选位置正确 |
| Qt | 运行候选 closure 已提供的 `fcitx5-config-qt`，只在搜索框输入后取消 | Qt frontend 可输入，不保存任何设置 |
| XWayland | 以 `GDK_BACKEND=x11` 启动一个新的 Ghostty 窗口，并用 `hyprctl clients` 确认 `xwayland: 1` | XIM 路径的候选、上屏、标点与 Shift 均正常 |

Qt 工具或 XWayland 测试窗口若未由候选提供或无法启动，记录 FAIL 并回到 Issue 修正声明；不要在 live
session 临时安装 package。XWayland Ghostty 的未来 smoke 命令是：

```fish
uwsm app -- env GDK_BACKEND=x11 ghostty
hyprctl clients
```

🪟 启动一个明确的 XWayland 测试窗口，并人工确认该窗口条目的 `xwayland: 1`。

### 6.1 左右 Shift 与跨应用状态

在每个矩阵应用的普通文本框中分别完成：

1. 保持 Rime engine active，输入拼音、看到中文候选、选择候选并上屏，验证中英文标点。
2. 单按左 Shift 进入 Rime 内部 ASCII mode，输入无敏感意义的 ASCII；再次按左 Shift 回到中文。
3. 对右 Shift 重复同样步骤。
4. 每次 Shift 前后执行 `fcitx5-remote -n`，都应仍为 `rime`；如果变成 `keyboard-us` 或 Fcitx
   inactive，记为 FAIL。
5. 在中文 mode 与 ASCII mode 下分别切换 Ghostty、Firefox、Chrome、Qt 和 XWayland 窗口，确认
   目标应用保持候选设计的共享输入状态，且不会因应用默认规则切走 Rime。

Shift 只切换 Rime 内部中文/ASCII，不能触发 Fcitx framework toggle，也不能产生第二个 input-method
owner。普通快捷键、`Super` 绑定、复制粘贴和窗口切换也应做最小回归。

### 6.2 密码与锁屏安全

在浏览器的可信密码输入框中只输入一个专用、非机密 smoke 字符串，确认候选窗不会暴露输入内容，
清空后不提交。随后按 `Super+L` 进入 Hyprlock：

- 确认锁屏界面没有中文候选窗或输入法菜单；
- 只在真实 Hyprlock prompt 中输入实际解锁密码，不在 terminal、Issue、录屏或截图中复现；
- 确认含 Shift 的密码按键语义仍是键盘修饰键，不被 Rime 的 mode switch 截获；
- 成功解锁后确认 `fcitx5-remote -n` 仍为 `rime`，普通应用输入恢复正常。

GDM 登录发生在用户 Fcitx daemon 启动前，也必须确认密码可正常输入且没有 Fcitx 候选 UI。任何密码
输入、锁屏绕过、重复解锁 prompt 或 candidate overlay 异常都是立即回滚条件。

## 7. 学习数据与 session 持久性

选择一个无敏感意义、不会透露用户信息的临时拼音序列，在普通文本框中重复选择同一候选，使 Rime
产生正常学习行为。只观察候选排序与已知 userdb 根的 metadata，不打开、列举、hash 或复制 userdb：

```fish
set -l userdb ~/.local/share/fcitx5/rime/rime_ice.userdb
if test -e $userdb -o -L $userdb
    stat --format='%n | %F | mode=%a | owner=%U:%G | mtime=%y' $userdb
else
    echo 'FAIL: expected Rime Ice userdb root is absent after learning smoke'
end
```

🧠 只验证 Rime Ice userdb 根仍可写并发生预期 metadata 变化，不读取学习内容。

在 logout/relogin 已获当前批准时，用 `Super+Shift+M` 正常结束 UWSM session，回到 GDM 后再次选择
`Hyprland (uwsm-managed)`。重新登录后重复第 5 节 daemon/engine 检查，并输入相同测试序列，确认学习
排序、Rime active/default、Shift 语义和跨应用状态仍保留。确认没有旧 IBus daemon，也没有出现第二
个 Fcitx daemon。

Reboot 是独立动作，不能从 logout/relogin 批准推导。若 reboot 另行获批，重启后重复上述检查；
`test` 模式重启会回到 boot-default 旧 generation，因此要分别记录“候选 relogin 持久性”与“重启
恢复旧 generation”，不能把二者混为一项。

## 8. 桌面能力回归与失败证据

在候选 session 只读核对既有访问与桌面能力，不改变网络或服务配置：

```fish
nmcli general status
tailscale status
wpctl status
systemctl --user --no-pager --full status xdg-desktop-portal.service xdg-desktop-portal-hyprland.service pipewire.service wireplumber.service
```

🌐 确认 SSH/Tailscale、NetworkManager、portal 与音频没有因输入框架替换回退。

再人工验证 LocalSend 可启动，Ghostty/Firefox/Chrome/Qt 应用切换稳定，Hyprland 绑定与锁屏正常。
若失败，从已验证 SSH 或本地 TTY 收集当前 boot 的窄日志；先在本地审阅并脱敏：

```fish
journalctl --user -b --no-pager | string match -ri '.*(fcitx|rime|uwsm|xdg.*autostart).*'
journalctl -b --no-pager -u display-manager.service -u NetworkManager.service -u tailscaled.service
```

📋 收集输入法、UWSM autostart、display manager 与恢复链路证据，不粘贴用户输入或敏感标识。

同时记录准确 Git commit、运行 closure、GDM session entry、失败应用、Wayland/XWayland 路径、
`fcitx5-remote -n` 结果、daemon 数量、是否仍可 SSH，以及失败发生在 login、候选、Shift、锁屏还是
relogin 阶段。不要为排障读取 userdb/config 正文或现场修改用户配置。

## 9. `test` 失败恢复

恢复优先级如下：

1. SSH 可用：保持该控制面，收集第 8 节证据；若 reboot 已获当前批准，重启回 boot-default 旧
   generation。
2. SSH 不可用但本地 TTY 可用：从 TTY 收集日志，再执行已批准的 reboot。
3. Hyprland 仍响应：可用 `Super+Shift+M` 正常结束 UWSM；这不等于系统 generation 已回滚。
4. 图形与 TTY 都失败：硬件重启只作为最后手段，并在 boot menu 选择第 2 节确认仍存在的已验收
   generation。

未来只有 reboot 已准确获批时才可执行：

```fish
sudo systemctl reboot
```

🧯 让 `test` 候选回到未被移动的 boot-default 旧 generation；当前阶段禁止执行。

远程恢复也必须由同一次准确批准覆盖：

```fish
ssh -t nixbox 'sudo systemctl reboot'
```

🚑 从已实测的既有访问路径执行已批准的恢复重启。

`test` 候选没有自己的 system profile generation，所以不要用
`nixos-rebuild switch --rollback` 假装“撤销 test”。恢复后确认 `/run/current-system` 等于第 2 节
记录的 boot-default closure，并回归登录、网络、SSH/Tailscale、输入法 owner 与核心应用。

不得通过 kill Fcitx、手工启动 IBus、删除 `~/.config/fcitx5`、清除 Rime build/userdb 或改 dconf
来制造表面恢复；这些动作既不属于 generation rollback，也没有本 Issue 授权。

## 10. 未来 `switch` 晋升与 rollback

只有真人矩阵全部 PASS、结果已记录、diff 已审阅，并且维护者对**准确提交的 `switch` 动作**另行
批准后，才可执行：

```fish
sudo nixos-rebuild switch --flake .#nixbox
```

🚦 将候选提升为 system profile generation 与 boot default；当前阶段禁止执行。

晋升前必须再次确认已验收旧 generation 仍在 `nixos-rebuild list-generations` 和
`bootctl list` 中，且没有 GC。若新 generation 仍可通过 SSH/TTY 控制，上一代身份也已核实为第 2 节
记录的已验收 generation，未来另行批准的回滚命令是：

```fish
sudo nixos-rebuild switch --rollback
```

↩️ 切回已经核实身份的上一代 system generation；当前阶段禁止执行。

若新 generation 无法启动，在 systemd-boot 中人工选择保留的已验收 entry。恢复成功后再单独决定
是否把它设为默认；不要先删除失败候选、旧 entry、Store closure 或 GC root。

## 11. Generation 回滚不覆盖的可变状态

以下内容不由 system/Home Manager generation 做文件系统快照；试用、relogin 或 rollback 都不得
擅自清理：

- `~/.config/fcitx5`：Fcitx5 可写配置、偏好和 frontend runtime state；NixOS system defaults 不
  代表接管此目录正文。
- `~/.local/share/fcitx5/rime/build`：Rime 可重建 deploy cache；可以排除备份，但不能在本 Issue
  的恢复现场删除。
- `~/.local/share/fcitx5/rime/luna_pinyin.userdb`、`rime_ice.userdb` 及可能存在的其他
  `*.userdb`：用户学习数据；应按用户数据策略备份，禁止读取正文或进入 Git/Store。
- `~/.local/share/fcitx5/rime/sync`：Rime sync/export 状态；仓库不启用或管理同步，也不把它当静态
  schema 数据。
- `~/.local/share/fcitx5/rime/installation.yaml` 与 `user.yaml`：Rime 安装 identity、deploy 与最近
  schema 状态；保持可写、外部所有。
- `~/.config/dconf/user` 与 inventory 未来确认的其他遗留 IBus 输入偏好：移除 IBus
  声明/daemon owner 不等于删除历史状态。当前不知道独立 IBus 用户路径，不猜测、不遍历；任何
  路径固化、退休或迁移另开 Issue。
- `$XDG_RUNTIME_DIR` 下的 Fcitx socket、D-Bus owner、Wayland/XWayland connection 与 UWSM user
  session：易失运行态，由正常 logout/relogin 重建，不备份。
- Ghostty、Firefox、Chrome、Qt 应用、LocalSend、portal permission store 与 keyring 的 profile、
  cache、session、credential 和用户内容：继续由各应用/用户拥有，generation rollback 不恢复。

如果 smoke 写入了 userdb 或其他状态，只记录发生过写入及对应 metadata，不把数据提交到 Issue/PR。
需要备份、恢复、清理、迁移或重新 deploy 时建立新的窄范围 Issue 和人工关卡。

## 12. 验收记录模板

维护者在 Issue/PR 中使用以下脱敏摘要；每项只能按真实结果填写，未执行写 `NOT RUN`：

```text
exact commit:
activation action: NOT RUN / test / switch
pre-trial generation and closure recorded: PASS / FAIL
SSH + TTY + boot recovery verified: PASS / FAIL
UWSM XDG autostart; exactly one fcitx5: PASS / FAIL
active/default engine remains rime; no IBus daemon: PASS / FAIL
Ghostty Wayland: PASS / FAIL
Firefox Wayland: PASS / FAIL
Chrome Wayland: PASS / FAIL
Qt frontend: PASS / FAIL
XWayland/XIM: PASS / FAIL
left/right Shift only switch Rime internal mode: PASS / FAIL
cross-application state: PASS / FAIL
GDM/Hyprlock/password safety: PASS / FAIL
userdb learning survives logout/relogin: PASS / FAIL
reboot: NOT RUN / PASS / FAIL (separate approval recorded)
SSH/Tailscale/LocalSend/core desktop regression: PASS / FAIL
rollback exercised: NOT RUN / PASS / FAIL
mutable state inspected only as path metadata: PASS / FAIL
```

📝 记录 exact-commit 真人结果与人工关卡，不把 build 结果误报为运行态验收。
