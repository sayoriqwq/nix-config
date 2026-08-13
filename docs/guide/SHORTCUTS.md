# 快捷键与快速入口

> 本表由各能力模块声明的行为元数据生成，并在 Nix 求值时检查漂移。配置事实仍归对应模块所有。

| 范围 | 快捷键或入口 | 行为 | 所有者 |
| --- | --- | --- | --- |
| Fish / Zsh | `↑ / ↓` | 按当前输入前缀浏览原生 Shell 历史 | portable-shell |
| Fish / Zsh | `Ctrl+R` | 打开 Atuin 增强历史搜索 | atuin |
| Fish / Zsh | `Ctrl+T` | 用 fzf 选择文件并插入命令行 | fzf |
| Fish / Zsh | `Alt+C` | 用 fzf 选择目录并进入 | fzf |
| Fish / Zsh | `f` | 让 pay-respects 修正上一条失败命令 | pay-respects |
| Fish / Zsh | `v` | 无参数打开当前目录；有参数传给 VS Code | macos-vscode-compatibility |
| Fish / Zsh | `z` | 无参数打开当前目录；有参数传给 Zed | zed-editor |
| Fish / Zsh | `lg` | 启动 lazygit；正常退出后同步工作目录 | lazygit |
| lazygit | `Shift+Q` | 退出且不把 lazygit 工作目录同步回 Shell | lazygit |
| Ghostty / WezTerm | `Cmd+D` | 向右创建 pane | terminal |
| Ghostty / WezTerm | `Shift+Cmd+D` | 向下创建 pane | terminal |
| Ghostty / WezTerm | `Shift+Cmd+Enter` | 缩放或还原当前 pane | terminal |
| Ghostty / WezTerm | `Alt+Cmd+方向键` | 切换 pane 焦点 | terminal |
| Ghostty / WezTerm | `Ctrl+Cmd+方向键` | 调整 pane 大小 | terminal |
| Ghostty / WezTerm | `Cmd+Enter` | 切换全屏 | terminal |
| Ghostty / WezTerm | `Shift+Cmd+P` | 打开命令面板 | terminal |
| Ghostty / WezTerm | `Cmd+↑ / Cmd+↓` | 在 OSC 133 语义提示区域之间滚动 | terminal |
| Ghostty | `Ctrl+Cmd+=` | 均分所有 pane | terminal |
| AeroSpace（Caps Lock → Hyper） | `Hyper+方向键` | 按方向聚焦窗口 | aerospace-window-management |
| AeroSpace（Caps Lock → Hyper） | `Hyper+1…0` | 切换到工作区 1…10 | aerospace-window-management |
| AeroSpace（Caps Lock → Hyper） | `Hyper+Shift+1…0` | 移动当前窗口到工作区 1…10 | aerospace-window-management |
| AeroSpace（Caps Lock → Hyper） | `Hyper+V` | 切换当前窗口的浮动/平铺布局 | aerospace-window-management |
| AeroSpace（Caps Lock → Hyper） | `Hyper+Esc` | 关闭 AeroSpace 接管并恢复隐藏工作区窗口可见 | aerospace-window-management |

`Cmd+Backquote` 未被 nix-config 绑定；Ghostty Quick Terminal 不在当前支持范围内。
