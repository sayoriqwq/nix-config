# 主机角色与能力矩阵

本文记录已确认的需求归属。它描述目标组合，不表示尚未进入当前 Phase 的能力已经在真实机器激活。

## 主机角色

| 主机 | 第一角色 | 组合原则 |
| --- | --- | --- |
| `macbook` | 主工作站 | 保留完整 GUI、CLI、迁移兼容与已确认试点能力；它是能力的全量组合，不再是其他主机的继承源。 |
| `nixbox` | 次级工作站、Linux 试验站、Server 预生产验证站 | 只选择明确需要的 macbook 能力，并增加 NixOS/Linux 自身需求；不镜像 macbook。 |
| `server` | Headless NixOS production host | 只选择 CLI、生产运行与救援能力，以配置一致性简化验证；不继承工作站 GUI、可变开发运行时或 GitHub 凭据。 |

## 已确认目标组合

| 能力 | macbook | nixbox | server | 合同摘要 |
| --- | --- | --- | --- | --- |
| Nix 运维 | 是 | 是 | 是 | `nh` 与 Nix generation/build/check 操作界面。 |
| 可移植 Shell | 是 | 是 | 是 | Fish 主路径；登录 Shell 的系统事实由各平台 adapter 负责。 |
| 终端工具箱 | 是 | 是 | 是 | `bat`、`eza`、`fd`、`fzf`、`jq`、`ripgrep`、`starship`、`tmux`、`tree`、`zoxide`。 |
| 终端历史 | 是 | 是 | 是 | Atuin 本地历史；数据库、key 与 daemon state 保持可写。 |
| 跨设备历史同步 | 是 | 否 | 否 | macbook 保留既有 Atuin 同步行为；nixbox 与 server 只保留各自本地历史。Atuin Desktop 只留在 macbook。 |
| Git 基础 | 是 | 是 | 是 | Git 行为与私有 identity include；不含 GitHub 登录态。 |
| GitHub 协作 | 是 | 是 | 否 | `gh`、GitHub credential helper、lazygit、gitleaks；凭据不进入 server。 |
| 交互式 Shell 辅助 | 是 | 是 | 是 | `pay-respects` 及 Fish integration。 |
| 主机概览与诊断 | 是 | 是 | 是 | `fastfetch` 与 `btop`；不替代生产监控。 |
| 工作站开发运行时 | 是 | 是 | 否 | mise 管 Node/Bun/pnpm，uv 管 Python，direnv 进入项目环境。 |
| macOS 开发运行时试点 | 是 | 否 | 否 | 保留 macbook 现有 Erlang/Elixir mise defaults，不随工作站能力迁移。 |
| 终端文件工作流 | 是 | 是 | 否 | Yazi；低使用频率不取消已确认的迁移方向。 |
| Helix | 是 | 是 | 否 | 备用终端编辑器；server 的最小编辑需求在 server Phase 再确认。 |
| Ghostty | 是 | 是 | 否 | 两台工作站的主终端，启动 Fish。 |
| Zed | 是 | 是 | 否 | 两台工作站的主编辑器；live settings 保持可写。 |
| LocalSend | 是 | 是 | 否 | Home Manager 拥有 package；平台 adapter 公开状态路径和 NixOS TCP/UDP 53317 合同。 |
| Obsidian | 是 | 是 | 否 | 工作站 GUI 能力；vault 内容不由 Nix 管理。 |
| Chrome、Clash、Termius | 是 | 是 | 否 | 工作站应用；平台安装方式由各能力 adapter 决定。 |
| Raycast 工作流 | 是 | 否 | 否 | Darwin adapter 单独拥有现有 Homebrew cask；Home Manager 从固定源码 revision 按 manifest 白名单把 7 个 navigation Script Commands 部署到 `~/.local/share/raycast/script-commands`。Settings、数据库、快捷键和 extension 运行态仍归 Raycast；已删除的 DB tunnel 与 Yume command/config 不得恢复，Script Directory 切换保留人工关卡。 |
| macOS 遗留应用集合 | 是 | 否 | 否 | 保留尚未逐项能力化的 Homebrew/MAS 现状；Raycast 已拆为独立 capability，其他应用后续按真实需求拆出，不作为其他主机的继承源。 |
| macOS Shell 兼容 | 是 | 否 | 否 | WezTerm + Zsh 只保留在主工作站，不是迁移阶段。 |
| VS Code 兼容 | 是 | 否 | 否 | 配置继续保留在仓库，但 nixbox 不安装。 |
| 云端/OSS 文件工作流 | 是 | 否 | 否 | rclone 与现有 macOS 工作流；不泛化到其他主机。 |
| AI 辅助运维 | 是 | 否 | 否 | macbook 的 `rtk`、Graphviz、Poppler、裸 Python 3.14 agent 基线，以及由 Nix/Home Manager 唯一提供 PATH 来源的 `codex` 0.146.0、`claude` 2.1.187、`agy` 1.1.9、`omp` 17.2.4；Oh My Pi 使用固定官方 `darwin-arm64` 发布物，状态与凭据外部，详见 [macOS AI CLI 所有权](../inventory/macos-ai-cli-ownership.md)。 |

## 明确排除或延后

- nixbox 不安装 WezTerm、VS Code、Atuin Desktop 或其他未批准 GUI，也不复制 macbook 的完整 Homebrew/MAS 集合。
- nixbox 不参与 Atuin 跨设备同步；数据库、key、session 与历史都只留在本机。
- nixbox 当前明确排除 Discord、Upscayl、OBS、Telegram、QQ、WeChat、腾讯会议、Transmission、balenaEtcher、网易云音乐、Scratch、原生 Figma/Linear/ChatGPT；Steam、MEGAsync 与百度网盘延后决定。
- 桌面环境实验放在 NixOS 基线与核心迁移之后，不作为 nix-config 当前第一性目标。
- server 不保存 GitHub 协作凭据，不使用工作站可变运行时管理 production workload；运行时来自 Nix closure、容器或服务声明。

## 当前 Phase 5.5 状态

- macbook 已通过显式 capability import 重组现有全量行为。
- nixbox 保持 Phase 5 系统基线，本阶段不接入任何 Home Manager 用户能力。
- server 不连接、不修改；Ubuntu 事实只在后续盘点阶段读取。
- Phase 6 只按本矩阵为 nixbox 组合已经批准的子集。
