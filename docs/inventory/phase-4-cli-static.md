# Phase 4 通用 CLI 与静态用户配置

- **目标机器：** `macbook`
- **父阶段：** [Issue #6](https://github.com/sayoriqwq/nix-config/issues/6)
- **决策账本：** [Issue #36](https://github.com/sayoriqwq/nix-config/issues/36)
- **实施 Issue：** [Issue #41](https://github.com/sayoriqwq/nix-config/issues/41)

## 所有权

Home Manager 在共享用户层提供以下通用 CLI：

- `fastfetch`
- `delta`（命令来自 Nix package `git-delta`，本批不改变 Git pager）
- `gitleaks`
- `dot`（来自 `graphviz`）
- `pdfinfo` 等 Poppler 工具（来自 `poppler-utils`）
- `rclone`
- `rtk`
- `yazi`

这些工具适用于桌面与 headless 用户环境。项目专属版本和依赖仍应由项目
dev shell 管理；本批不把 Python、Node、Erlang、Elixir、数据库或服务加入
全局用户 profile。

这是 Phase 4 当时的历史归类。Phase 5.5 能力化后，`rtk`、Graphviz 与 Poppler 曾由
macbook-only `ai-assisted-operations` capability 选择，没有扩展到 nixbox/server。
#67 后续未能证明 Graphviz 存在实际 caller，而 Codex 已通过客户端自带 runtime 提供
PDF 处理依赖，因此当前 capability 已删除 Graphviz 与 Poppler 的全局 package 声明。
当前 Nix 还管理 macbook-only 的 ax CLI；`RTK.md` 与 Codex integration 由 RTK init 生命周期拥有，
ax 的短期 fetch cache 仍由 ax 自己拥有。当前组合与
所有权以 capability matrix 和 `macos-ai-cli-ownership.md` 为准。

## Atuin

Home Manager 管理 Atuin CLI、Fish/Zsh integration 与以下稳定设置：

- 搜索模式：`daemon-fuzzy`；
- 同步 records；
- 启用 daemon，并允许 Atuin 自动启动；
- key 路径：`~/.local/share/atuin/key`。

仓库只声明 key 的本机路径。key 内容、history、records、meta、session、数据库、
登录态和同步凭据保持本机可写，不进入 Git 或 Nix Store。

## `.hushlogin`

Home Manager 创建空的 `~/.hushlogin`，用于抑制登录 Shell 的 last-login 提示。
该文件不承载其他配置。

## 首次 activation 关卡

盘点时以下目标是已有的普通文件：

- `~/.config/atuin/config.toml`：内容与目标稳定设置一致，但未显式写出默认 key 路径；
- `~/.hushlogin`：1 字节文件。

Home Manager 不应强制覆盖它们。activation 前必须：

1. 完全退出正在写 Atuin 配置的进程；
2. 将两个文件复制到权限受限的私有备份目录，并核对 hash；
3. 移走原文件，让 Home Manager 创建声明式目标；
4. 针对精确 commit 单独批准并由维护者执行 activation。

activation 后在全新 Fish 与兼容 Zsh 会话中验证 CLI、Atuin 搜索、daemon、history
和 key 路径。任何异常优先回滚上一代 nix-darwin generation，再从私有备份恢复
原文件；不得删除 Atuin 数据目录。

## 本批明确不做

- 不改变 Git pager；
- 不迁移 mise Erlang/Elixir；
- 不卸载 Homebrew 重复副本；
- 不清理 Chezmoi、旧 dotfiles、应用或可变数据；
- 不启用 Homebrew cleanup、zap 或 autoremove。
