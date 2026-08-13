# nixbox Fcitx 5 / Rime Ice 权威来源映射

## 1. 范围与结论

本文是 Issue [#169](https://github.com/sayoriqwq/nix-config/issues/169) 的实现证据，只覆盖
共享 Rime 静态数据 seam 与 `nixbox` 的 Fcitx 5 Linux frontend。它不授权 activation、输入框架
切换、注销、重启、GC 或用户状态清理，也不启动 Phase 12。

结论：锁定来源支持由 **NixOS `i18n.inputMethod` 模块单一拥有** Fcitx framework、Rime addon、
system defaults、session/toolkit environment 与 package 自带的 XDG autostart；Home Manager Fcitx
模块必须保持关闭。macbook 与 nixbox 可以复用同一个参数化 Rime data-package implementation，
但分别从各自锁定 package set 构建，不能跨平台引用同一个 Store artifact。

## 2. 锁定版本与来源

Linux 根 nixpkgs 由 `flake.lock` 固定为
[`fd1462031fdee08f65fd0b4c6b64e22239a77870`](https://github.com/NixOS/nixpkgs/tree/fd1462031fdee08f65fd0b4c6b64e22239a77870)，
Home Manager 固定为
[`4ce190229c73d44536caa7072f6308fb2d8feeb3`](https://github.com/nix-community/home-manager/tree/4ce190229c73d44536caa7072f6308fb2d8feeb3)。
本 Issue 不更新 lock file。

| 组件 | 锁定版本 | 权威证据与本次用途 |
| --- | --- | --- |
| Fcitx 5 | 5.1.19 | [nixpkgs package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/fc/fcitx5/package.nix)；framework 与上游 XDG autostart entry |
| `fcitx5-with-addons` | 随 Fcitx 5.1.19 | [组合包](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/tools/inputmethods/fcitx5/with-addons.nix)；唯一 system package，包含 GTK、Qt5/Qt6 frontend 与批准的 addons |
| `fcitx5-rime` | 5.1.13 | [package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/fc/fcitx5-rime/package.nix)；支持 `override { rimeDataPkgs = [ ... ]; }`，把数据合入自己的 `$out/share/rime-data` |
| librime | 1.16.1 | [package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/li/librime/package.nix)；构建期语义验证与运行时 engine |
| Rime Ice | 2026.06.30 | [package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/ri/rime-ice/package.nix)；发行数据固定输出到 `$out/share/rime-data`，并把上游 `default.yaml` 重命名为 `rime_ice_suggestion.yaml` |
| Hyprland / UWSM | 0.55.4 / 0.26.4 | [Hyprland package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/hy/hyprland/package.nix)、[UWSM package](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/by-name/uw/uwsm/package.nix)；既有会话与 autostart 生命周期保持不变 |

NixOS 的锁定
[`fcitx5.nix`](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/i18n/input-method/fcitx5.nix)
是采用来源；锁定
[Home Manager `fcitx5.nix`](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/i18n/input-method/fcitx5.nix)
只是负面证据：一旦启用，它会再次声明 package、session variables、`~/.config/fcitx5` 和
`fcitx5-daemon.service`，形成双 owner，因此不得采用。

## 3. NixOS 单一 owner 合同

`nixbox` adapter 只通过 NixOS 声明 `i18n.inputMethod.enable = true`、`type = "fcitx5"`，并在
`i18n.inputMethod.fcitx5.addons` 中只加入使用共享数据 override 后的 `fcitx5-rime`。锁定模块据此：

1. 生成唯一的 `qt6Packages.fcitx5-with-addons`，并通过 `i18n.inputMethod.package` 放入系统环境；
2. 把结构化 `globalOptions`、`inputMethod` 与 addon defaults 写入 `/etc/xdg/fcitx5/`；
3. 设置 `XMODIFIERS=@im=fcitx`、`QT_PLUGIN_PATH`；本候选保持 `waylandFrontend = false`，让锁定
   模块同时设置 `GTK_IM_MODULE=fcitx` 与 `QT_IM_MODULE=fcitx`。该 option 只控制这两个 toolkit
   变量，不会从组合包中删除或停用 Fcitx Wayland frontend；
4. 保持 `ignoreUserConfig = false`。锁定 option 明确警告，启用它会完全忽略用户配置并令
   user dictionary 无法保存或载入。

System defaults 表达目标：`Default` group 只含 `rime`、`DefaultIM=rime`、`Default Layout=us`，
Fcitx `TriggerKeys` 与 `AltTriggerKeys` 为空。左右 Shift 的中文/ASCII 切换只由共享 Rime overlay
中的 `commit_code` 拥有。`/etc/xdg` 是默认层，不覆盖优先级更高的可写用户配置；若旧用户配置
改变最终行为，只能在获批 smoke gate 中通过 Fcitx GUI/API 验证和处理，不能改用
`ignoreUserConfig`、只读 `~/.config/fcitx5` 或 activation script 强制收敛。

IBus owner 必须从 Hyprland capability 退出；闭包检查应同时证明没有 IBus package、IBus 输入法
环境、`ibus-daemon` autostart、Home Manager Fcitx service 或额外 `exec-once` daemon。

## 4. UWSM XDG autostart 与 toolkit 路径

唯一启动链为：

```text
Fcitx 5 package: etc/xdg/autostart/org.fcitx.Fcitx5.desktop
  -> fcitx5-with-addons 将 Exec 重写到组合包
  -> NixOS system package / xdg.autostart 暴露 entry
  -> UWSM xdg-desktop-autostart.target
  -> systemd-xdg-autostart-generator 生成的单一 Fcitx 进程
```

上游 Fcitx 5.1.19 的
[`org.fcitx.Fcitx5.desktop`](https://github.com/fcitx/fcitx5/blob/5.1.19/data/org.fcitx.Fcitx5.desktop.in.in)
执行 `fcitx5`；其
[`data/CMakeLists.txt`](https://github.com/fcitx/fcitx5/blob/5.1.19/data/CMakeLists.txt)
在 XDG autostart 启用时安装该 entry。锁定 `fcitx5-with-addons` 会复制并改写其中的 Store 路径。
锁定 [NixOS XDG autostart module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/config/xdg/autostart.nix)
暴露 `/etc/xdg/autostart`；锁定
[UWSM module](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/nixos/modules/programs/wayland/uwsm.nix)
与 [UWSM upstream](https://github.com/Vladimir-csp/uwsm/tree/v0.26.4) 都把
`xdg-desktop-autostart.target` 纳入 graphical session 生命周期。因此不新增 systemd service、
Hyprland `exec-once` 或用户 autostart copy。

[Fcitx Wayland 指南](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland) 区分 compositor 原生
text-input 路径与 toolkit IM module，并指出非 KWin 的 Qt Wayland 应用需要
`QT_IM_MODULE=fcitx`；[Setup Fcitx 5](https://fcitx-im.org/wiki/Setup_Fcitx_5) 也给出
`XMODIFIERS`、GTK、Qt 与 XDG autostart 合同。故本候选显式保持 `waylandFrontend = false`：

| 应用路径 | 声明接口 | 验证边界 |
| --- | --- | --- |
| native Wayland GTK/Qt | `fcitx5-gtk`、Qt5/Qt6 addon，加 `GTK_IM_MODULE` / `QT_IM_MODULE` | Ghostty、Firefox/Chrome 与至少一个 Qt 应用真人验证候选窗、上屏和切换 |
| native Wayland text-input | 组合包中的 Fcitx Wayland frontend + Hyprland compositor protocol；不由 `waylandFrontend` 这个 NixOS bool 开关 | 构建只能证明 package/protocol 依赖存在，运行时连接必须实机 smoke |
| XWayland | `XMODIFIERS=@im=fcitx`，GTK/Qt IM modules | 在明确的 XWayland 应用中真人验证；不得把 XWayland 结果代替 native Wayland 结果 |

全局 GTK/Qt 选择可能暴露候选窗定位或 toolkit 特例；这是首次试用风险，不授权添加
`QT_IM_MODULES`、`SDL_IM_MODULE`、浏览器 backend flags 或其他社区环境变量 workaround。应用级
差异必须记录后另行判断 owner。

## 5. 共享 Rime data seam

共享 implementation 接收当前平台的 `pkgs`、`pkgs.rime-ice` 与同一份
`default.custom.yaml`，固定输出 `$out/share/rime-data`。data tree 只包含发行静态叶子与 overlay：

- 排除整个 `build` 子树，以及 `sync`、`*.userdb`、`installation.yaml`、`user.yaml` 等可变名称；
- overlay 通过 `__include: rime_ice_suggestion:/` 启用发行建议，只保留 `rime_ice` schema，并把
  左右 Shift 都设为 `commit_code`；
- macbook Home Manager 递归投影 `${dataPackage}/share/rime-data` 的 leaves，保持用户 Rime 根可写；
- nixbox 以 `fcitx5-rime.override { rimeDataPkgs = [ dataPackage ]; }` 把同一 artifact 接入 Linux
  addon，同时由 capability 的 Home Manager data/state implementation 递归投影它的 leaves；后者只让
  `default.custom.yaml` 和静态 schema 出现在 Rime 用户数据层，不启用 HM input-method module、package
  或 daemon，也不替换可写根目录。Rime 的用户数据层优先于 addon 的 system shared data，因此两处
  引用同一 artifact 是刻意合同：system copy 让 plugin closure 自包含，用户 recursive leaves 让
  overlay/schema 以可审计的用户层来源生效；版本必须始终一致，首次 deploy 要验证没有 collision。

Rime 官方 [Customization Guide](https://github.com/rime/home/wiki/CustomizationGuide) 推荐用
`*.custom.yaml` patch 而不是修改发行文件；[UserData](https://github.com/rime/home/wiki/UserData)
确认 fcitx5-rime 用户目录为 `~/.local/share/fcitx5/rime`，其中 userdb、installation、user 与
`build` 分别是学习数据、身份/状态和部署产物。这些来源共同证明静态 data package 与可写用户
状态必须分离。

## 6. 可变状态、人工关卡与 STOP 条件

| 路径/状态 | owner 与备份边界 |
| --- | --- |
| `~/.local/share/fcitx5/rime/build` | Rime 可重建部署 cache；可写、备份排除、不进 Store |
| `~/.local/share/fcitx5/rime/*.userdb` | Rime 学习数据；必须备份，Agent 不读取内容 |
| `~/.local/share/fcitx5/rime/sync` | Rime sync export；独立备份策略，不由 Git 同步 |
| `~/.local/share/fcitx5/rime/installation.yaml`、`user.yaml` | Rime 身份与状态；必须备份、保持可写 |
| `~/.config/fcitx5` | Fcitx preferences/runtime config；Fcitx/用户拥有，不整体链接到 Store |
| `~/.config/dconf/user` 与遗留 IBus 状态 | 用户/旧 framework 可变状态；保留原样，不删除、不迁移；未知 IBus path 在 inventory gate 前保持未知，不猜测 |

出现以下任一情况即停止实现并记录差异：

- package/module 版本不再与第 2 节一致，或锁定 NixOS module 不再生成单一
  `fcitx5-with-addons`、上述 defaults/environment；
- Fcitx XDG entry 没有进入 UWSM autostart，或出现第二个 Fcitx/IBus daemon owner；
- Home Manager Fcitx 被启用、`ignoreUserConfig = true`、用户 Rime/Fcitx 根被整体链接到 Store，
  或 data package 含可变名称/`build`；
- Linux 消费 Darwin Store artifact，server 获得任何 Fcitx/Rime/package/session/environment 增量；
- 构建结果需要 raw patch 用户配置、读取词典正文、命令式 autostart 或社区 dotfiles 才能成立；
- Wayland、XWayland、GTK 或 Qt 任一路径在获批 smoke 中失败。此时先回滚 generation 并保留全部
  用户状态，不以删除 userdb、Fcitx、IBus 或 dconf 状态排障。

构建/check 只证明声明 closure；首次 activation 必须针对 exact commit 在物理 console 或可信 SSH
恢复入口可用的窗口单独批准。注销、relogin、reboot 和真人输入矩阵仍是独立人工关卡。
