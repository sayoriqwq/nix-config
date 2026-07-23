# Phase 4 终端与 Shell 最终目标基线

本文固化 Issue [#23](https://github.com/sayoriqwq/nix-config/issues/23) 后续实施必须遵守的已批准共识。它取代 `0c6a81a` 交付快照中的软件来源、模块边界与集成决策，但不抹除迁移前证据、备份记录或构建记录。

本文只描述声明式配置的最终目标，不授权 activation、Homebrew cleanup、删除可变数据或合并 Pull Request。

## 1. 支持矩阵

- 主环境是 Ghostty + Fish。
- 备用/兼容环境是 WezTerm + Zsh。
- Ghostty + Zsh 与 WezTerm + Fish 不属于承诺维护和验收的组合。
- Ghostty 默认键位是终端快捷键基准；WezTerm 对齐双方共有的高频操作。
- Zsh 核心配置属于跨平台共享用户层，必须可用于 macOS、Linux 与 NixOS；Darwin 专属 PATH、应用集成和启动钩子单独声明。

## 2. 软件、配置与数据所有权

每个软件的迁移必须明确以下七项：软件来源、稳定配置、Shell/平台集成、字体/插件/外部依赖、生成目标、可变数据边界、可复用模块边界。

- 软件优先由 Nix 安装，稳定配置由 nix-config 通过 Home Manager、nix-darwin 或 NixOS module 管理。
- 优先使用上游 `programs.*` 和结构化选项；静态配置链接次之；activation script 是最后选择。
- 已迁入 Nix 的 CLI 不再由 Homebrew 持续管理。
- 可变数据、数据库、历史、密钥、缓存、登录态和应用状态不进入 Nix Store。
- WezTerm 由 Nixpkgs 与 `programs.wezterm` 安装和配置；允许升级到 `flake.lock` 固定的版本。
- WezTerm 使用 Nix 提供的 Zsh；macOS 登录 Shell 暂不改变。
- Maple Mono NF-CN 由 nix-darwin 统一安装，供 Ghostty 与 WezTerm 共用；两个终端都通过实机验收后才能清理手工重复字体。
- VS Code 与 Zed 的安装、设置和扩展不属于本次迁移。

## 3. 模块组织

- 每个软件使用独立模块；配置复杂的软件使用目录与 `default.nix` 作为入口。
- 不采用同名 `.nix` 文件与同名目录并存的结构。
- 模块通过显式 `imports` 组合，不通过目录自动扫描决定配置。
- `common` 只包含跨平台且适用于 headless host 的用户配置。
- 平台专属路径、GUI 应用与系统服务进入对应的平台模块。
- 最终目录结构仍需在实施前单独批准；本节只约束组织原则。

## 4. 共享 Shell 行为

- `v` 与 `z` 是 Fish/Zsh 共用行为：无参数时打开当前目录，有参数时原样转发。
- 编辑器可执行程序的安装和具体配置由后续编辑器 issue 接管。
- Starship 在 Fish 与 Zsh 使用同一套提示符配置。
- Atuin 由 `programs.atuin` 管理包和稳定配置，数据库与密钥保留为可变数据；`Ctrl+R` 是唯一增强历史入口，删除自定义 `Ctrl+Up`。
- Fish 与 Zsh 的上下方向键保留原生前缀历史行为。
- FZF 使用 `Ctrl+T` 选择文件、`Alt+C` 选择目录，不占用 `Ctrl+R`。
- zoxide 的增强 `cd` 行为在 Fish 与 Zsh 等价提供，其数据保持可写。
- eza 使用 `ls`、`ll`、`la`、`lla`、`lt` 与图标自动模式。
- lazygit 使用 `lg`；正常退出同步工作目录，`Shift+Q` 退出时不做目录同步。
- direnv 与 nix-direnv 由 Nix 管理，Fish/Zsh 都启用 hook；项目通过 `.envrc` 和显式 `direnv allow` 启用。
- pay-respects 由 Nix 管理，保留上游默认别名 `f`，不创建 `fuck` 兼容别名，不添加自定义规则。
- 上游默认快捷键、别名或集成与当前配置冲突时，必须先展示冲突并获得维护者决定，不得静默覆盖。

## 5. 终端快捷键

WezTerm 保留并对齐以下 Ghostty 行为：

| 快捷键 | 行为 |
| --- | --- |
| `Cmd+D` | 向右分屏 |
| `Shift+Cmd+D` | 向下分屏 |
| `Shift+Cmd+Enter` | 缩放/还原当前 pane |
| `Alt+Cmd+方向键` | 切换 pane 焦点 |
| `Ctrl+Cmd+方向键` | 调整 pane 大小 |
| `Cmd+Enter` | 切换全屏 |
| `Shift+Cmd+P` | 打开命令面板 |
| `Cmd+Up` / `Cmd+Down` | 在 OSC 133 语义提示区域之间滚动 |
| `Ctrl+Cmd+=` | 均分 pane |

终端内部模式或无法自然对应的专属快捷键不强制统一。最终快捷键总表维护在独立中文 reference 文档中。

## 6. mise 退出边界

- nix-config 不声明 `programs.mise`，mise 不再管理全局 Node、Bun 或其他运行时。
- mise 的安装、Shell hook 与稳定配置必须从最终环境移除。
- Oh My Pi 需要的 Bun/Node 不得继续依赖 mise。
- 不得直接写入或覆盖 Home Manager 管理的 `~/.config/fish/config.fish`。

## 7. 工作线分叉

Issue #23 继续负责终端与 Shell 的完整最终迁移。当前 Fish 配置丢失、mise/Bun 与 Oh My Pi 可用性属于阻塞日常开发的紧急修复，必须使用独立 issue、分支和 Pull Request：

- 紧急修复只恢复 Home Manager 对 Fish 配置的唯一所有权，移除 mise 依赖，并让 Oh My Pi 使用非 mise 的声明式运行时；
- 紧急修复不得顺带实施 Issue #23 尚未完成的全量模块重构；
- Issue #23 后续以本基线重新修订验收标准和实现，不沿用旧交付快照中的 Homebrew WezTerm、`/bin/zsh` 或保留 mise 决策。

## 8. 验收约束

- 先执行格式化、Flake check 与受影响 output build，不把 build 当作 activation 授权。
- 实机 activation 必须针对明确 commit 获得当次批准。
- activation 后分别验收 Ghostty + Fish 与 WezTerm + Zsh，并核对共享行为、快捷键、PATH 和可变数据边界。
- 清理 Homebrew 软件、mise、手工字体或旧配置必须在替代项实机验收通过后单独执行。
