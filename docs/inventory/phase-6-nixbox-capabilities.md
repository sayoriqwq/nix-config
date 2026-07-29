# Phase 6 nixbox 能力与状态边界

本文记录 Issue #8 的声明结果、证据和仍需真实机器确认的关卡。它不表示配置已经在 `nixbox` 激活。

## 1. 已确认主机事实

- output：`nixbox`
- 平台：`x86_64-linux`
- 用户与 home：`sayori`、`/home/sayori`
- 当前默认 shell：Bash；Phase 6 声明的目标为 Fish
- 当前稳定桌面：GNOME + GDM
- `system.stateVersion`：保持 Phase 5 接入时的 `26.05`
- Home Manager：此前未采用；本阶段为第一次接入

上述事实来自 `docs/inventory/phase-1-hosts.md` 和 Phase 5 的真实机器验收，不以 macbook 配置推断 nixbox。

## 2. 显式能力组合

`hosts/nixbox/default.nix` 只选择 Issue #8 已批准的能力：

- 通用终端：Fish、终端工具箱、Atuin 本地历史、Git、`nh`、`pay-respects`、`fastfetch`、`btop`；
- 工作站附加：Atuin 同步、GitHub 协作、mise/uv/direnv、Yazi；
- 编辑与终端：Zed、Helix、Ghostty；
- GUI：Obsidian、Google Chrome、Clash Verge Rev、Termius、LocalSend。

没有导入 macbook host、旧 desktop/Linux bundle 或 capability registry。VS Code、WezTerm、Atuin Desktop、AI 辅助运维、rclone 和其他未批准应用均不进入 nixbox。

## 3. 跨层合同

| 能力 | package / 稳定配置所有者 | NixOS 影响 | 可变状态边界 |
| --- | --- | --- | --- |
| 可移植 Shell | Home Manager 管 Fish 配置；NixOS 管 package 注册与用户登录 shell | `programs.fish.enable`；`sayori.shell = pkgs.fish` | Fish history 与 universal variables 只声明、不接管 |
| LocalSend | Home Manager 是 package 唯一所有者 | 仅增加 TCP/UDP `53317` | Linux preferences/application support 与接收文件都保持可写 |
| Google Chrome | Home Manager 管 Linux package | 无 service/firewall | profile 与 cache 不进入 Nix Store |
| Clash Verge Rev | Home Manager 管 Linux package | 不启用 service、TUN、system proxy 或额外端口 | profiles、配置与日志保持可写 |
| Termius | Home Manager 管 Linux package | 无 service/firewall | 登录、连接、key 与 Electron user data 保持可写，secret 不进入 Git |

LocalSend 合并后的 NixOS firewall 预期值为 TCP `[ 22 53317 ]`、UDP `[ 5353 53317 ]`。`22` 和 `5353` 是既有 SSH/Avahi 基线；本阶段唯一新增值是两个协议的 `53317`。

## 4. 状态路径与证据

| 应用 | 声明路径 | 证据与边界 |
| --- | --- | --- |
| LocalSend | `~/.local/share/org.localsend.localsend_app` | 锁定 LocalSend 源码的 Linux application ID 为 `org.localsend.localsend_app`；锁定 `shared_preferences_linux` 通过 `path_provider_linux` 写入 XDG data home/application ID。 |
| Google Chrome | `~/.config/google-chrome`、`~/.cache/google-chrome` | Chromium 官方 Linux user-data/cache 路径规则；浏览器可通过环境或参数覆盖，当前声明记录默认值。 |
| Clash Verge Rev | `~/.local/share/io.github.clash-verge-rev.clash-verge-rev` | 锁定源码定义同名 `APP_ID`，并使用 Tauri Linux data directory；Nix 不管理目录内容。 |
| Termius | `~/.config/Termius` | 解包锁定的 9.36.2 Snap 后，根 `package.json` 的应用名为 `Termius`；主进程读取 Electron 默认 `userData`，且没有 `setPath("userData", ...)` 覆盖。结合 Electron Linux 默认规则得到该路径；首次启动仍核对实际落盘结果。 |
| Obsidian | `~/.config/obsidian` | 现有 Linux capability 声明；vault 位置由用户选择，完全位于 Nix 配置之外。 |
| Zed | `~/.config/zed` | Nix 只 seed 缺失的基线文件，live settings、extensions 与 session 保持可写。 |
| Atuin | `~/.local/share/atuin` | 数据库、key 与 daemon state 属于每台机器的可变状态；同步不把 key 或数据库提交到 Git。 |

其余 Fish、GitHub CLI、Git identity、mise 与 uv 状态由对应 capability 的 `sayori.statePaths` 一并公开。该 option 只形成可审计清单，不创建、链接、备份或删除任何路径。

## 5. `home.stateVersion` 依据

真实 nixbox 没有既有 Home Manager 配置，因此没有可保留的历史值。仓库锁定 Home Manager release 26.05，本阶段第一次采用 `home.stateVersion = "26.05"`，并要求首次激活后保持不变。它不是根据当前 NixOS 版本自动升级出的值。

## 6. 仍需真实机器确认

以下事项在 build 前后都不由 Agent 推断：

1. GNOME/GDM 仍与 Phase 5 基线一致，且当前没有异常 failed unit；
2. Termius 首次启动后的实际 user-data 路径与锁定 package 证据一致；
3. Phase 5 `p5-test`、`p5-switch`、`p5-back` 遗留目标的精确绝对路径、类型、所有者和内容；
4. Zed 从 macbook 到 nixbox 的 SSH remote workflow；
5. LocalSend 在真实 LAN 上的发现和双向传输。

目标机不可达时，上述项保持为显式 blocker。不得因此猜路径、扩大端口、引入 OrbStack builder 或删除疑似遗留文件。

## 7. 激活与回滚关卡

构建成功不授权 activation。首次 `dry-activate`、`test`、登录 shell 切换以及遗留文件删除前，必须基于已推送的不可变 commit 向维护者展示精确命令与目标，并获得当次批准。

人工验证至少包括：现有 console/SSH 回滚通道、Fish 登录与 PATH、Atuin 本地历史及同步、Git/GitHub 工具、Ghostty/Zed/Helix/Yazi、全部批准 GUI 应用，以及 LocalSend firewall 与互传。

若 test 失败，重启回到当前永久 generation；若后续持久化失败，从 systemd-boot 选择 Phase 5 已知良好的 generation，再移除对应 capability adapter。回滚不删除任何应用可变数据。
