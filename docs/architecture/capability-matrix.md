# 主机角色与能力矩阵

本文记录已确认的需求归属。它描述目标组合，不表示尚未进入当前 Phase 的能力已经在真实机器激活。

## 主机角色

| 主机 | 第一角色 | 组合原则 |
| --- | --- | --- |
| `macbook` | 主工作站 | 保留完整 GUI、CLI、迁移兼容与已确认试点能力；它是能力的全量组合，不再是其他主机的继承源。 |
| `nixbox` | 次级工作站、Linux 试验站、Server 预生产验证站 | 只选择明确需要的 macbook 能力，并增加 NixOS/Linux 自身需求；不镜像 macbook。 |
| `server` | Headless NixOS production host | 只选择 CLI、生产运行与救援能力，以配置一致性简化验证；macbook maintenance identity 与 nixbox deploy identity 都登录远端 `sayori`，经 sudo 边界提权，root SSH 关闭；不继承工作站 GUI、可变开发运行时或 GitHub 凭据。 |

## 已确认目标组合

| 能力 | macbook | nixbox | server | 合同摘要 |
| --- | --- | --- | --- | --- |
| Nix 运维 | 是 | 是 | 是 | `nh` 与 Nix generation/build/check 操作界面。 |
| 可移植 Shell | 是 | 是 | 是 | Fish 主路径；登录 Shell 的系统事实由各平台 adapter 负责。 |
| `terminal-work` Intent | 是 | 是 | 是 | 显式选择 `bat`、`eza`、`fd`、`fzf`、`jq`、`ripgrep`、`starship`、`tmux`、`tree`、`zoxide` 的原子 Software Capabilities；`fzf.configure` 使用 `fd` 作为默认 source、`bat --color=always {}` 作为 preview。 |
| 终端历史 | 是 | 是 | 是 | Atuin 本地历史；数据库、key 与 daemon state 保持可写。 |
| 跨设备历史同步 | 是 | 否 | 否 | macbook 保留既有 Atuin 同步行为；nixbox 与 server 只保留各自本地历史。Atuin Desktop 只留在 macbook。 |
| Git 基础 | 是 | 是 | 是 | Git 行为与私有 identity include；不含 GitHub 登录态。 |
| GitHub 协作 | 是 | 是 | 否 | `gh`、GitHub credential helper、lazygit、gitleaks；凭据不进入 server。 |
| 交互式 Shell 辅助 | 是 | 是 | 是 | `pay-respects` 及 Fish integration。 |
| 主机概览与诊断 | 是 | 是 | 是 | `fastfetch` 与 `btop`；不替代生产监控。 |
| Server 深度诊断 | 否 | 否 | 是 | 系统级提供 `lsof`、`dig`、`mtr`、`tcpdump` 与 `strace`；不启用服务、不增加 listener 或 firewall 规则，抓包和跨进程追踪按需经 sudo。 |
| 工作站开发运行时 | 是 | 是 | 否 | mise 管 Node/Bun/pnpm，uv 管 Python，direnv 进入项目环境。 |
| macOS 开发运行时试点 | 是 | 否 | 否 | 保留 macbook 现有 Erlang/Elixir mise defaults，不随工作站能力迁移。 |
| Pinshift 开发入口 | 是 | 否 | 否 | 仅提供全局 `pinshift` 转发命令；checkout 缺失时明确失败。源码、项目依赖、构建、签名、Keychain、Controller 与设备操作保持仓库外，activation 不执行这些动作。 |
| 终端文件工作流 | 是 | 是 | 是 | Yazi；server 用于只读浏览与用户可写文件操作，不接管 production 数据。 |
| Helix | 是 | 是 | 是 | 备用终端编辑器；server 上用于临时记录和获批配置操作，不把生成的 `/etc` 状态当作配置源。 |
| Ghostty | 是 | 是 | 否 | 两台工作站的主终端，启动 Fish；共享配置引用 Maple Mono NF-CN，macbook 由 nix-darwin 提供字体，nixbox 由 Ghostty Home Manager capability 与用户 fontconfig 提供，server 不安装。 |
| Zed | 是 | 是 | 否 | 两台工作站的主编辑器，并提供 Nix 扩展所需的 `nil` 与 `nixd` language server；macOS Darwin adapter 让未来启动的 GUI 进程发现 Home Manager profile，live settings 保持可写。 |
| LocalSend | 是 | 是 | 否 | Home Manager 拥有 package；平台 adapter 公开状态路径和 NixOS TCP/UDP 53317 合同。 |
| Hyprland 工作站 | 否 | 是 | 否 | Intent 显式组合 Hyprland/GDM/Xorg/Qt Wayland、NetworkManager、PipeWire/rtkit 与桌面用户组件；Avahi 和 BlueZ 由 nixbox 直接选择。旧 graphical bundle、Firefox 与 printing 声明已退出；activation、登录、网络、音频、蓝牙和输入验收仍是人工关卡。 |
| 工作站稳定访问 | 是 | 是 | 否 | Tailscale 只承担 macbook→nixbox transport；native OpenSSH key-only/host key 继续认证，tmux 恢复断线现场。macbook 使用 Standalone cask，并生成只含 `tailscale nc %h %p` 的 SSH fragment，使 OpenSSH 不受 Clash fake-IP DNS 影响；nixbox 使用锁定 NixOS service、machine name `nixbox`，NixOS firewall 只新增 UDP 41641，tailscaled 另按 vendor 默认维护 overlay iptables chains；server 排除。主 SSH 配置、endpoint、identity、known_hosts、登录态、MagicDNS、Grants 与 key expiry 均在外部人工关卡。 |
| Obsidian | 是 | 是 | 否 | 工作站 GUI 能力；vault 内容不由 Nix 管理。 |
| Chrome、Termius | 是 | 是 | 否 | 工作站应用；平台安装方式由各能力 adapter 决定。 |
| Clash Verge Rev | 是 | 是 | 否 | macbook 保持 Homebrew cask；nixbox 由 NixOS adapter 独占 Linux package 所有权，并通过窄、精确锁定的 package source seam 提供 2.5.2。nixbox 声明 root systemd Service Mode、专用 `clash-verge` socket group（仅加入 `sayori`），保持 `tunMode = false`、`autoStart = false`，不创建 GUI capability wrapper；应用内 TUN 只在绑定 exact commit 的人工关卡中通过声明式 service 验证。该能力不声明 firewall、Tailscale、SSH、DNS、route 或 system proxy；server 排除。 |
| Raycast 工作流 | 是 | 否 | 否 | Darwin adapter 单独拥有现有 Homebrew cask；Home Manager 从固定源码 revision 按 manifest 白名单把 7 个 navigation Script Commands 部署到 `~/.local/share/raycast/script-commands`。Settings、数据库、快捷键和 extension 运行态仍归 Raycast；已删除的 DB tunnel 与 Yume command/config 不得恢复，Script Directory 切换保留人工关卡。 |
| 中文输入 | 是 | 是 | 否 | 两个工作站按各自锁定 package set 构建同一个参数化 Rime Ice 2026.06.30 静态 data package，排除 `build`/可变名称、只启用 `rime_ice`、左右 Shift 只切 Rime 内部 mode，并以 recursive leaves 保持用户根可写。macOS frontend 继续由官方 Fcitx5.app/installer 与人工偏好拥有；nixbox 由 NixOS 单一拥有 Fcitx 5.1.19、`fcitx5-rime` 5.1.13、system defaults、toolkit environment 与 XDG autostart，HM 输入法 module/daemon 保持关闭。server 排除。两个平台的 activation、deploy 与真人输入仍是独立人工关卡。 |
| macOS application presence | 是 | 否 | 否 | 每个受管 Homebrew、MAS 与 Home Manager App 都由自己的 Software Primary Capability 拥有，并由 macbook 直接选择；不存在 legacy app bundle。账号、偏好、内容、数据库、缓存与许可证保持外部，Steam 已退出声明。 |
| macOS Shell 兼容 | 是 | 否 | 否 | WezTerm + Zsh 只保留在主工作站，不是迁移阶段。 |
| VS Code 兼容 | 是 | 否 | 否 | 配置继续保留在仓库，但 nixbox 不安装。 |
| 云端/OSS 文件工作流 | 是 | 否 | 否 | rclone 与现有 macOS 工作流；不泛化到其他主机。 |
| AI 辅助运维 | 是 | 是 | 否 | macbook 保留现有 Codex、Claude、Antigravity、Oh My Pi、ax、RTK 与裸 Python 3.14 集合；nixbox 只组合锁定 Linux package 中的 Codex、ax、RTK、裸 Python 3.14 与 Linux 专属全局 `AGENTS.md`，不继承其他客户端。两台工作站的 `RTK.md` 都由 RTK init 生命周期拥有，auth、session、history、plugins、skills、hooks、cache 和数据库保持外部可写；server 不组合该能力。macbook 细节见 [macOS AI CLI 所有权](../inventory/macos-ai-cli-ownership.md)。 |
| 机密部署 | 是 | 是 | 是 | sops-nix 使用每机独立 SSH host identity 解密本机文件；运行时路径和 mode 受声明控制，不分发管理员 identity。 |
| 机密管理 | 是 | 否 | 否 | 只有 macbook 提供 SOPS、age 与 SSH-to-age；管理员 identity 与维护者自管恢复副本保持仓库外，nixbox/server 不获得编辑或恢复能力。 |

## 明确排除或延后

- nixbox 不安装 WezTerm、VS Code、Atuin Desktop 或其他未批准 GUI，也不复制 macbook 的完整 Homebrew/MAS 集合。
- nixbox 不参与 Atuin 跨设备同步；数据库、key、session 与历史都只留在本机。
- nixbox 当前明确排除 Discord、Upscayl、OBS、Telegram、QQ、WeChat、腾讯会议、Transmission、balenaEtcher、网易云音乐、Scratch、原生 Figma/Linear/ChatGPT；Steam、MEGAsync 与百度网盘延后决定。
- 桌面环境实验放在 NixOS 基线与核心迁移之后，不作为 nix-config 当前第一性目标。
- server 不保存 GitHub 协作凭据，不使用工作站可变运行时管理 production workload；运行时来自 Nix closure、容器或服务声明。
- server 只持有自己的既有 SSH host identity，并只能解密明确授予 server recipient 的文件；管理员恢复 identity 和其他主机 identity 都不进入 server。
- 工作站稳定访问不启用 FRP、Tailscale SSH、routes/exit node、Serve/Funnel、公开 22、DDNS 或 mDNS 主路径；OpenSSH 只通过 Tailscale owner 的 `nc` transport 绕过系统 DNS，不修改 Clash Verge，仍须分别完成 Clash off/on 真人验证。Termius/Zed 等不读取 OpenSSH config 的客户端不在该修复合同内。
- Clash Verge Rev 2.5.2 与 Service Mode 当前只是 Issue #157 的待激活声明；构建不表示真实 daemon、GUI TUN、DNS/route/system proxy 或与 Tailscale/SSH/tmux 的共存矩阵已经验证。真实动作必须绑定 Draft PR 的 exact commit 并另获批准。

## 当前状态

- 三台 Host 已通过 realized `terminal-work` Intent 组合终端 Software Capabilities；两个工作站另通过 `code-development` 与各自的 `ai-coding` 组合选择代码/AI Software，server 直接选择 `git.version-control`，Pinshift 只由 macbook 直接选择。macbook 的 WezTerm + Zsh 兼容环境通过 `terminal-compatibility` Intent 显式组合，其他受管 App presence 由 host 直接选择各自 Software Capability；其余工作站能力仍按后续 V3 Issue 从现有显式 imports 逐批迁移。
- macbook 的共享 Rime 静态声明源自已合并的 #140/PR #142；维护者已在获批窗口完成
  `system-46-link` activation、一次 Rime deploy 与静态/可变边界回读，后续 #143/#145/#147
  又完成 Shift/fallback 所有权调整及 Squirrel 遗留退役，#147 Gate D 记录真人输入整体 PASS。
  当前 macbook 与 nixbox 通过同一个 `chinese-input` 能力的不同 adapter 复用静态语义；macOS
  frontend/偏好仍保持外部，Linux frontend 由 NixOS 声明。Issue #169 的 nixbox 候选尚未
  activation、deploy 或真人验收，不能把其 build/evaluation 结果描述为机器运行态。
- 更早的 #127 首次 65-leaf 所有权交接已在配置提交
  `87d801c85bc3f6f1b5334a00aefccfbe3ecefe73` 完成实机验收：generation 42→43、65/65
  Store symlink、9/9 可写且非 Store 的 mutable boundaries、Rime 重新部署与真实输入均为
  PASS。#131 已退役这次交接的写入型 helper；这些数字只保留为历史迁移证据，不再构成
  #140 终态的逐 leaf manifest、runtime preflight 或行为 rollback 合同。
- server 已运行最小 NixOS，只组合 headless 基线与明确需要的共享能力。
- server 当前目标采用维护者明确批准的单管理员 `sayori + sudo` 模型；macbook 与 nixbox 使用独立 key 登录同一远端用户，root SSH 关闭，nixbox 不是交互身份或必经跳板。该目标只有在独立 production action card 获批并 activation 后才成为运行态事实。
- Phase 12 已延后；新增能力继续按本矩阵和独立 Issue 审批，不从其他主机继承 bundle。
