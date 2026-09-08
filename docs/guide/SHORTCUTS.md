# 快捷键与快速入口

本表按平台标注，随对应软件的配置一起维护；条目以对应软件已启用为前提。macbook 与 nixbox 将同一份静态文档投影到 `~/.local/share/nix-config/SHORTCUTS.md`，server 不选择此表。

nixbox 使用 Fish，表中的 Zsh 范围只适用于 macOS 兼容 Shell。

| 平台 | 范围 | 快捷键或入口 | 行为 | 所有者 |
| --- | --- | --- | --- | --- |
| macOS / nixbox | Fish | `↑ / ↓` | 按当前输入前缀浏览 Fish 原生历史 | fish |
| macOS | Zsh | `↑ / ↓` | 按当前输入前缀浏览原生 Shell 历史 | zsh |
| macOS / nixbox | Fish / Zsh | `Ctrl+R` | 打开 Atuin 增强历史搜索 | atuin |
| macOS / nixbox | Fish / Zsh | `Ctrl+T` | 用 fzf 选择文件并插入命令行 | fzf |
| macOS / nixbox | Fish / Zsh | `Alt+C` | 用 fzf 选择目录并进入 | fzf |
| macOS / nixbox | Fish / Zsh | `f` | 让 pay-respects 修正上一条失败命令 | pay-respects |
| macOS | Fish / Zsh | `v` | 无参数打开当前目录；有参数传给 VS Code | vscode |
| macOS / nixbox | Fish / Zsh | `z` | 无参数打开当前目录；有参数传给 Zed | zed-editor |
| macOS / nixbox | Fish / Zsh | `lg` | 启动 lazygit；正常退出后同步工作目录 | lazygit |
| macOS / nixbox | lazygit | `Shift+Q` | 退出且不把 lazygit 工作目录同步回 Shell | lazygit |
| macOS | Ghostty / WezTerm | `Cmd+D` | 向右创建 pane | terminal |
| macOS | Ghostty / WezTerm | `Shift+Cmd+D` | 向下创建 pane | terminal |
| macOS | Ghostty / WezTerm | `Shift+Cmd+Enter` | 缩放或还原当前 pane | terminal |
| macOS | Ghostty / WezTerm | `Alt+Cmd+方向键` | 切换 pane 焦点 | terminal |
| macOS | Ghostty / WezTerm | `Ctrl+Cmd+方向键` | 调整 pane 大小 | terminal |
| macOS | Ghostty / WezTerm | `Cmd+Enter` | 切换全屏 | terminal |
| macOS | Ghostty / WezTerm | `Shift+Cmd+P` | 打开命令面板 | terminal |
| macOS | Ghostty / WezTerm | `Cmd+↑ / Cmd+↓` | 在 OSC 133 语义提示区域之间滚动 | terminal |
| macOS | Ghostty | `Ctrl+Cmd+=` | 均分所有 pane | terminal |
| nixbox | Hyprland | `Super+Q` | 启动 Ghostty | hyprland |
| nixbox | Hyprland | `Super+R` | 打开 Fuzzel 应用启动器 | hyprland |
| nixbox | Hyprland | `Super+L` | 锁定当前会话 | hyprland |
| nixbox | Hyprland | `Super+Shift+M` | 正常退出 UWSM 管理的 Hyprland 会话 | hyprland |
