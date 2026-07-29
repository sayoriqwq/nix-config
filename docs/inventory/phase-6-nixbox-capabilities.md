# Phase 6 nixbox 能力与状态边界

本文记录 Issue #8 的声明结果、构建与真实机器激活证据，以及仍需人工完成的应用级验证。2026-07-29，维护者明确批准跳过独立 `dry-activate` / `test` 轮次，已将不可变 commit `3393e842b78c7580c39a99d0927514ed1ac1d3c1` 对应 generation 永久切换到 `nixbox`。

## 1. 已确认主机事实

- output：`nixbox`
- 平台：`x86_64-linux`
- 用户与 home：`sayori`、`/home/sayori`
- 当前默认 shell：Fish（Phase 6 激活后由 `/run/current-system/sw/bin/fish` 提供）
- 当前稳定桌面：GNOME + GDM
- `system.stateVersion`：保持 Phase 5 接入时的 `26.05`
- Home Manager：此前未采用；本阶段第一次接入并已成功激活

上述事实来自 `docs/inventory/phase-1-hosts.md` 和 Phase 5 的真实机器验收，不以 macbook 配置推断 nixbox。

## 2. 显式能力组合

`hosts/nixbox/default.nix` 只选择 Issue #8 已批准的能力：

- 常开工作站：GDM 与登录后的 GNOME 会话都不因空闲熄屏或自动 suspend；
- 通用终端：Fish、终端工具箱、Atuin 本地历史、Git、`nh`、`pay-respects`、`fastfetch`、`btop`；
- 工作站附加：Atuin 同步、GitHub 协作、mise/uv/direnv、Yazi；
- 编辑与终端：Zed、Helix、Ghostty；
- GUI：Obsidian、Google Chrome、Clash Verge Rev、Termius、LocalSend。

没有导入 macbook host、旧 desktop/Linux bundle 或 capability registry。VS Code、WezTerm、Atuin Desktop、AI 辅助运维、rclone 和其他未批准应用均不进入 nixbox。

## 3. 跨层合同

| 能力 | package / 稳定配置所有者 | NixOS 影响 | 可变状态边界 |
| --- | --- | --- | --- |
| 常开工作站 | NixOS 管 GDM；Home Manager 管 `sayori` 的 GNOME idle/power 设置 | GDM 不自动 suspend；登录与锁屏会话不因 idle 熄屏或 suspend | 不禁用手动 suspend，不改变合盖或电源键行为 |
| 可移植 Shell | Home Manager 管 Fish 配置；NixOS 管 package 注册与用户登录 shell | `programs.fish.enable`；`sayori.shell = pkgs.fish` | Fish history 与 universal variables 只声明、不接管 |
| Zed | Home Manager 管 Nightly package 与 seed-only 配置；NixOS 适配器声明 ADR-0006 限定的官方 Cachix 与签名公钥 | 不增加 service/firewall；缓存未命中时才允许源码回退 | live settings、extensions 与 session 保持可写 |
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

1. Termius 首次启动后的实际 user-data 路径与锁定 package 证据一致；
2. Phase 5 `p5-test`、`p5-switch`、`p5-back` 遗留入口的最终删除；
3. Zed 从 macbook 到 nixbox 的 SSH remote workflow；
4. LocalSend 在真实 LAN 上的发现和双向传输。

激活后已确认：Home Manager unit 为 active、系统没有 failed unit、GNOME 用户 idle delay 为 0，AC/电池空闲动作均为 `nothing`，GDM `autoSuspend = false`；当前 firewall generation 包含 TCP/UDP `53317`。

### 6.1 空闲 suspend 实机证据

2026-07-29 唤醒后确认：GNOME 当前 `idle-delay` 为 300 秒；system journal 记录 GDM 无人登录时约 15 分钟后触发 `The system will suspend now!`，并在人工唤醒后返回。该行为同时解释了屏幕熄灭与 SSH 不可达。

本阶段因此新增 `always-on-workstation` 能力：

- `services.displayManager.gdm.autoSuspend = false` 只关闭 GDM 登录屏的空闲 suspend；
- GDM 的 `idle-delay = 0` 阻止登录屏空闲熄屏；
- `sayori` 的 Home Manager dconf 将 GNOME `idle-delay` 设为 0，并把 AC/电池空闲 suspend 都设为 `nothing`；
- 不 mask systemd sleep targets，不改变 lid switch、电源键或人工 suspend。

### 6.2 Phase 5 遗留与 Home Manager 冲突审计

2026-07-29 的只读审计确认：

| 路径 | 类型与目标 | 当前判断 |
| --- | --- | --- |
| `/home/sayori/p5-test` | symlink，指向当前已启动 closure 的 `switch-to-configuration` | 与当前 system 相同，已无独立 test 回滚价值 |
| `/home/sayori/p5-back` | symlink，经 `/run/booted-system` 指向同一当前 closure | 与 `p5-test` 重合，已无独立回滚价值 |
| `/home/sayori/p5-switch` | mode 0700 的脚本，固定 Phase 5 commit `6c541608d44bfbe000284a73f07b7918319044c4` | 只保留旧 switch 快捷入口，不是 generation 本身 |

三者都没有删除。删除前仍须向维护者展示三个精确绝对路径与命令，并获得当次批准，不使用通配符。

已批准能力对应的 `~/.config/fish`、Atuin、Git、Lazygit、Helix、Ghostty、Zed 与 mise 路径当前均不存在，因此没有发现首次 Home Manager activation 的同名文件冲突。只存在 Phase 5 已记录的空 `~/.nix-profile` symlink；Nix 不会据此推断或删除任何用户 package。

目标机不可达时，上述项保持为显式 blocker。不得因此猜路径、扩大端口、引入 OrbStack builder 或删除疑似遗留文件。

### 6.3 原生 build 与 Zed 缓存 bootstrap

2026-07-29 在真实 `x86_64-linux` nixbox 上完成原生整机 build；不可变 commit 对应的最终 output path 记录在 PR #69 的验证结果中，避免把会随仓库内容变化的临时 dirty-tree store path 固化为配置事实。

首次 build 暴露出 Zed 能力的跨层缺口：macOS 已声明 ADR-0006 批准的 Zed Cachix，但 nixbox 只导入 Home Manager 配置，没有同时声明 NixOS daemon 的 substituter 与签名公钥，因此 Nix 按上游 Flake 的合法 fallback 开始源码编译 LiveKit/WebRTC。精确 store path 随后确认在 `https://zed.cachix.org` 命中、在 `cache.nixos.org` 不命中。

修正后，`zed-editor/nixos.nix` 一次 import 同时选择 Home Manager Zed 配置及限定的官方缓存信任。首次 switch 前的 bootstrap 通过维护者运行的短入口临时 helper 完成签名成品导入；最终配置的整机 build 只剩 18 个 Home Manager/NixOS 集成 derivation，没有继续源码编译 Zed 或 LiveKit。当前 generation 已激活该 daemon 设置，`nix show-config` 可见 `https://zed.cachix.org`。

## 7. 激活结果与回滚

维护者明确批准直接永久 `switch`，不再单独执行 `dry-activate` / `test`。切换后 `/run/current-system` 指向本阶段 output `/nix/store/xpr6pi8shz5n7dyyjbf1f2yfkwdansf1-nixos-system-nixos-26.05.20260719.fd14620`；`/run/booted-system` 在重启前仍指向 Phase 5 generation，这是 NixOS 的预期行为。

首次 switch 的系统部分已经生效，但 Home Manager unit 因远端一个未注册且内容不完整的 Flake source store path 失败。诊断通过同一路径在 macbook 校验成功、在 nixbox 报 `is not valid` 的确定性检查锁定原因；随后仅通过 Nix store 协议补齐该 source path 并重启 Home Manager，没有重复整套 switch。第二次激活返回 `status=0/SUCCESS`，系统 failed unit 为 0。两端临时 helper 均已删除。

仍需人工完成的应用级验证包括：Atuin 同步、Ghostty/Zed/Helix/Yazi、全部批准 GUI 应用、Zed remote workflow，以及 LocalSend 真实 LAN 发现与双向互传。这些不阻塞声明与系统激活结果，但应在 Issue #8 完成总结中逐项记录。

若后续发现系统级回归，从 systemd-boot 选择 Phase 5 已知良好的 generation；也可在当前可用 console/SSH 通道中切回上一 generation。回滚不删除任何应用可变数据。
