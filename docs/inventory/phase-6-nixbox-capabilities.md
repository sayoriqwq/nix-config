# Phase 6 nixbox 能力与状态边界

本文记录 Issue #8 的声明结果、构建、真实机器运行态与持久 generation 验证。2026-07-29，维护者明确批准跳过独立 `dry-activate` / `test` 轮次，不可变 commit `3393e842b78c7580c39a99d0927514ed1ac1d3c1` 对应 closure 已进入 `nixbox` 的当前运行态。2026-07-30 的复核发现该 closure 没有注册到正式 system profile，因此此前的“永久切换”结论不成立；Issue #8 随即重新打开。修正后的 commit `2b1b0c3e8b62b3197efb98d9adc6f818b472f4fe` 已在真实 nixbox 原生构建，并在逐项人工批准下注册为 generation 6、设为 boot default、完成重启与三路径一致性验证。

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
- 工作站附加：GitHub 协作、mise/uv/direnv、Yazi；
- 编辑与终端：Zed（提供 `z` 快速入口）、Helix、Ghostty；
- GUI：Obsidian、Google Chrome、Clash Verge Rev、Termius、LocalSend。

没有导入 macbook host、旧 desktop/Linux bundle 或 capability registry。VS Code、WezTerm、Atuin Desktop、AI 辅助运维、rclone 和其他未批准应用均不进入 nixbox。

Issue [#128](https://github.com/sayoriqwq/nix-config/issues/128) 的后续声明让 Ghostty capability 在 Linux 同时提供 `MapleMono-NF-CN` package，并继续使用 Home Manager 已启用的用户 fontconfig。该补齐只描述待激活的新 closure，不追溯改变本页记录的 Phase 6 实机 generation；server 不选择 Ghostty，因此不获得字体包。

## 3. 跨层合同

| 能力 | package / 稳定配置所有者 | NixOS 影响 | 可变状态边界 |
| --- | --- | --- | --- |
| 常开工作站 | NixOS 管 GDM；Home Manager 管 `sayori` 的 GNOME idle/power 设置 | GDM 不自动 suspend；登录与锁屏会话不因 idle 熄屏或 suspend | 不禁用手动 suspend，不改变合盖或电源键行为 |
| 可移植 Shell | Home Manager 管 Fish 配置；NixOS 管 package 注册与用户登录 shell | `programs.fish.enable`；`sayori.shell = pkgs.fish` | Fish history 与 universal variables 只声明、不接管 |
| Zed | Home Manager 管 Nightly package、`z` 快速入口与 seed-only 配置；NixOS 适配器声明 ADR-0006 限定的官方 Cachix 与签名公钥 | 不增加 service/firewall；缓存未命中时才允许源码回退 | live settings、extensions 与 session 保持可写 |
| Ghostty | Home Manager capability 管 Linux package、Maple Mono NF-CN 字体包与稳定配置 | 用户 fontconfig 发现字体；无 service/firewall | window、session 与登录态保持可写 |
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
| Termius | `~/.config/Termius` | 解包锁定的 9.36.2 Snap 后，根 `package.json` 的应用名为 `Termius`；主进程读取 Electron 默认 `userData`，且没有 `setPath("userData", ...)` 覆盖。结合 Electron Linux 默认规则得到该路径，实机首次启动已确认实际落盘位置一致。 |
| Obsidian | `~/.config/obsidian` | 现有 Linux capability 声明；vault 位置由用户选择，完全位于 Nix 配置之外。 |
| Zed | `~/.config/zed` | Nix 只 seed 缺失的基线文件，live settings、extensions 与 session 保持可写。 |
| Atuin | `~/.local/share/atuin` | 数据库、key 与 daemon state 属于每台机器的可变状态；nixbox 不登录 macbook 的账号、不接收其 key/session/database，也不参与跨设备同步。 |

其余 Fish、GitHub CLI、Git identity、mise 与 uv 状态由对应 capability 的 `sayori.statePaths` 一并公开。该 option 只形成可审计清单，不创建、链接、备份或删除任何路径。

## 5. `home.stateVersion` 依据

真实 nixbox 没有既有 Home Manager 配置，因此没有可保留的历史值。仓库锁定 Home Manager release 26.05，本阶段第一次采用 `home.stateVersion = "26.05"`，并要求首次激活后保持不变。它不是根据当前 NixOS 版本自动升级出的值。

## 6. 实机验证与持久关卡

2026-07-30 已由维护者在真实机器完成以下使用层验证：

1. Termius、Obsidian、Google Chrome 与 Clash Verge Rev 均可正常启动，实际状态路径与声明一致；
2. Ghostty、Zed、Helix、Yazi 与 Atuin 本地历史入口均可执行，Ghostty 呈现共享能力中的稳定配置；
3. macbook 上的 Zed Nightly 通过现有 SSH connection 打开 nixbox 目录，远端终端执行 `hostname` 返回 `nixos`；
4. LocalSend 通过双方保存的 favorite/手动地址完成多轮双向文件传输。

LocalSend 自动发现未通过，但双端本机多播正常、nixbox 发包计数增长且包未到达 Mac `en0` 抓包点；没有证据表明 NixOS firewall 或本仓库 adapter 阻断该路径。当前以 favorite/手动地址作为稳定通道，不为自动发现扩大仓库、firewall 或 macOS privacy 边界。

随后完成了全部持久关卡：

1. 在真实 nixbox 原生构建移除 Atuin 同步能力后的修正 closure；
2. 经单独批准，把该 closure 注册为 `system-6-link` 并执行 `switch-to-configuration boot`；
3. 经单独批准重启，确认 running system、booted system、system profile 与 systemd-boot 当前条目都进入 generation 6；
4. 展示三个 Phase 5 临时路径并取得当次删除批准后，精确删除 `p5-test`、`p5-switch` 与 `p5-back`，不删除 `system-5-link`。

最终运行态已确认：Home Manager unit 为 active、系统没有 failed unit、GNOME 用户 idle delay 为 0，AC/电池空闲动作均为 `nothing`，GDM `autoSuspend = false`；active firewall generation 包含 TCP/UDP `53317`。Atuin 运行态配置只有本地 key、daemon 与本地搜索模式，没有 `sync` 或 `records`。

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
| `/home/sayori/p5-test` | symlink，指向 Phase 5 closure 的 `switch-to-configuration` | generation 6 重启验证后，经当次批准删除 |
| `/home/sayori/p5-back` | symlink，经 `/run/booted-system` 指向当前 booted closure | generation 6 重启验证后，经当次批准删除 |
| `/home/sayori/p5-switch` | mode 0700 的脚本，固定 Phase 5 commit `6c541608d44bfbe000284a73f07b7918319044c4` | 存在误部署旧 commit 风险，经当次批准删除 |

删除使用三个精确绝对路径，不使用通配符或递归参数；删除后分别确认文件与 symlink 均不存在。正式 `/nix/var/nix/profiles/system-5-link` 继续指向 Phase 5 closure，系统级回滚能力没有因用户目录清理而丢失。

首次 Home Manager activation 前没有发现已批准能力的同名文件冲突。激活与首启后，各应用按预期创建了自己的可写状态；这些内容仍不由 Nix 接管。Phase 5 已记录的空 `~/.nix-profile` symlink 也不会被据此推断或删除。

### 6.3 原生 build 与 Zed 缓存 bootstrap

2026-07-29 在真实 `x86_64-linux` nixbox 上完成原生整机 build；不可变 commit 对应的最终 output path 记录在 PR #69 的验证结果中，避免把会随仓库内容变化的临时 dirty-tree store path 固化为配置事实。

首次 build 暴露出 Zed 能力的跨层缺口：macOS 已声明 ADR-0006 批准的 Zed Cachix，但 nixbox 只导入 Home Manager 配置，没有同时声明 NixOS daemon 的 substituter 与签名公钥，因此 Nix 按上游 Flake 的合法 fallback 开始源码编译 LiveKit/WebRTC。精确 store path 随后确认在 `https://zed.cachix.org` 命中、在 `cache.nixos.org` 不命中。

修正后，`zed-editor/nixos.nix` 一次 import 同时选择 Home Manager Zed 配置及限定的官方缓存信任。首次 switch 前的 bootstrap 通过维护者运行的短入口临时 helper 完成签名成品导入；最终配置的整机 build 只剩 18 个 Home Manager/NixOS 集成 derivation，没有继续源码编译 Zed 或 LiveKit。当前 generation 已激活该 daemon 设置，`nix show-config` 可见 `https://zed.cachix.org`。

2026-07-30，真实 nixbox 针对修正 commit `2b1b0c3e8b62b3197efb98d9adc6f818b472f4fe` 再次完成原生整机 build，输出 `/nix/store/lribk269i2n29vxd964n7rf2i2vdfh4l-nixos-system-nixos-26.05.20260719.fd14620`。该轮只构建 9 个 Atuin、Home Manager 与系统集成 derivation，没有重新编译 Zed。

## 7. 运行态、generation 修复与回滚

维护者于 2026-07-29 批准跳过独立 `dry-activate` / `test`，直接切换 Phase 6 closure。`/run/current-system` 随后指向 `/nix/store/xpr6pi8shz5n7dyyjbf1f2yfkwdansf1-nixos-system-nixos-26.05.20260719.fd14620`，系统与 Home Manager 行为已按前文完成验证。

首次切换时 Home Manager unit 因远端一个未注册且内容不完整的 Flake source store path 失败。诊断通过同一路径在 macbook 校验成功、在 nixbox 报 `is not valid` 的确定性检查锁定原因；随后仅通过 Nix store 协议补齐该 source path 并重启 Home Manager，没有重复整套 switch。第二次激活返回 `status=0/SUCCESS`，系统 failed unit 为 0。两端临时 helper 均已删除。

2026-07-30 的持久性审计建立了可重复的失败信号：`/run/current-system` 与 `/nix/var/nix/profiles/system` 的解析目标不相同。前者时间戳为 Phase 6 运行态切换时间，后者仍是更早的 `system-5-link`；Phase 6 closure 的有效 root 只有 `/run/current-system`，而 Phase 5 closure 同时由 `/run/booted-system` 和 `system-5-link` 保持。系统不存在备用 system profile。证据共同表明此前直接调用了 closure 的切换入口，但没有完成 `nixos-rebuild switch` 所负责的 system profile generation 注册；因此“永久 switch”结论被撤回。

诊断期间，`nix-store -q --roots` 在查询 root 时自动移除了已经失效的临时 auto-GC-root symlink 与 temproot；没有删除有效 closure、配置或用户数据。后续不再把该命令当作纯只读探针。

修复使用前述新 closure。经维护者当次批准，校验过 SHA-256 的短 helper 按 `nixos-rebuild-ng` 的原生顺序执行 `nix-env -p /nix/var/nix/profiles/system --set` 与新 closure 的 `switch-to-configuration boot`；journal 记录该 transient unit 成功退出。system profile 随后成为 `system-6-link`，临时 helper 已删除。

维护者再次单独批准重启后，`/run/current-system`、`/run/booted-system` 与 `/nix/var/nix/profiles/system` 全部解析到 `/nix/store/lribk269i2n29vxd964n7rf2i2vdfh4l-nixos-system-nixos-26.05.20260719.fd14620`，systemd-boot 当前条目为 `nixos-generation-6.conf`。系统状态为 `running`、failed unit 为 0，Home Manager 在本次 boot 成功激活。

Phase 5 的三个用户目录快捷入口已在单独批准后精确删除；正式 `system-5-link` 仍保留并指向 Phase 5 closure，作为系统级回滚路径。该修复与清理均未删除应用可变数据。
