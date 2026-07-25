# Phase 4 编辑器状态与扩展审计

- **采集日期：** 2026-07-26
- **机器：** `macbook`
- **范围：** 非秘密应用身份、配置文件位置/hash、扩展 ID 与版本
- **边界：** 不记录登录信息、token、History、workspace/session、缓存或扩展工作目录内容

## 应用与配置事实

| 项目 | 当前事实 |
| --- | --- |
| Zed Preview | `1.13.0`，bundle ID `dev.zed.Zed-Preview`，位于 `/Applications/Zed Preview.app` |
| 目标 Zed Nightly | 官方 Flake revision `a3ac036eb6b73e0a50af4a44c96a43f1abf1b989`，version `1.14.0-nightly+a3ac036` |
| Zed CLI 契约 | 官方 package main program 为 `zed`；目标 `EDITOR` / `VISUAL` 为 `zed --wait` |
| Zed settings | `~/.config/zed/settings.json`，普通可写文件，SHA-256 `494e48f67be389a8966930463aed9c1d09621f5b5c87f9c44a73aa8fb7da1f9a` |
| Zed keymap | `~/.config/zed/keymap.json`，普通可写文件，SHA-256 `28fbca1a467473e1b697f82e777db32bef5713340127e71b66ef6025d9cc4867` |
| Zed tasks | `~/.config/zed/tasks.json`，普通可写文件，SHA-256 `faef4ea8541195b7c6a8cd6a6b828e1b37c21e1cbf4b19862b3a4cfeb46d8657` |
| 默认编辑器声明 | 采集时没有模块声明 `EDITOR` 或 `VISUAL` |
| 机密扫描 | Zed config directory 的 Gitleaks 扫描无发现；settings/keymap/tasks 无敏感关键词命中 |

Zed baseline 以当前设置为证据，但删除了已经弃用的 Copilot prediction provider
和不适合作为跨机器安全默认值的 `session.trust_all_worktrees`，并加入
`"auto_update": false`。由于采用 seed-only 模型，现有 live settings 不会被
activation 自动修正；第一次启动 Nightly 前必须由维护者确认 live 文件中已经
关闭应用自更新。

## Zed 扩展快照

Zed 扩展继续属于可变状态。维护者于 2026-07-26 确认：当前 9 个扩展全部保留，
归类为 shared，但不由 Nix 自动安装、升级或删除；Elixir 是实际使用的语言，
`.log` 与 Git 配置文件的语法高亮也需要保留。

| ID | 版本 | 适用范围 | 终态所有权 | 决定与理由 |
| --- | --- | --- | --- | --- |
| `ayu-darker` | `1.1.2` | shared | Zed 可变状态 | 保留；Zed baseline 使用的深色主题 |
| `elixir` | `0.6.2` | shared | Zed 可变状态 | 保留；维护者实际使用 Elixir，扩展提供 Elixir/EEx/HEEx、LSP 与调试支持 |
| `git-firefly` | `0.1.8` | shared | Zed 可变状态 | 保留；提供 Git config/rebase/ignore/attributes 语法高亮 |
| `html` | `0.3.1` | shared | Zed 可变状态 | 保留；通用 HTML 语言支持 |
| `log` | `0.0.7` | shared | Zed 可变状态 | 保留；提供 `.log` 文件语法高亮 |
| `material-icon-theme` | `1.3.1` | shared | Zed 可变状态 | 保留；Zed baseline 使用的图标主题 |
| `nix` | `0.1.4` | shared | Zed 可变状态 | 保留；本仓库及未来两台工作站需要 Nix 语言支持 |
| `toml` | `1.0.3` | shared | Zed 可变状态 | 保留；通用 TOML 语言支持 |
| `vue` | `0.4.0` | shared | Zed 可变状态 | 保留；通用 Vue 语言支持 |

## VS Code 扩展快照

清单由 Nix VS Code 1.119.0 的官方 CLI `--list-extensions --show-versions` 采集。
Copilot 与 Copilot Chat 已不在 live 注册表中，不作为待保留候选。

| ID | 版本 | 当前管理 | 分类决定 |
| --- | --- | --- | --- |
| `aaron-bond.better-comments` | `3.0.2` | VS Code 可变状态 | 待确认 |
| `adpyke.codesnap` | `1.3.4` | VS Code 可变状态 | 待确认 |
| `alefragnani.bookmarks` | `14.1.1` | VS Code 可变状态 | 待确认 |
| `andrejunges.handlebars` | `0.4.1` | VS Code 可变状态 | 待确认 |
| `antfu.iconify` | `1.0.0` | VS Code 可变状态 | 待确认 |
| `anthropic.claude-code` | `2.1.220` | VS Code 可变状态 | 待确认 |
| `astral-sh.ty` | `2026.64.0` | VS Code 可变状态 | 待确认 |
| `bradlc.vscode-tailwindcss` | `0.16.0` | VS Code 可变状态 | 待确认 |
| `chakrounanas.turbo-console-log` | `3.27.0` | VS Code 可变状态 | 待确认 |
| `ckolkman.vscode-postgres` | `1.4.3` | VS Code 可变状态 | 待确认 |
| `davidanson.vscode-markdownlint` | `0.61.2` | VS Code 可变状态 | 待确认 |
| `dbaeumer.vscode-eslint` | `3.0.34` | VS Code 可变状态 | 待确认 |
| `ddiu8081.moegi-theme` | `0.7.1` | VS Code 可变状态 | 待确认 |
| `eamodio.gitlens` | `18.3.0` | VS Code 可变状态 | 待确认 |
| `effectful-tech.effect-vscode` | `0.9.0` | VS Code 可变状态 | 待确认 |
| `esbenp.prettier-vscode` | `12.4.0` | VS Code 可变状态 | 待确认 |
| `github.remotehub` | `0.64.0` | VS Code 可变状态 | 待确认 |
| `github.vscode-github-actions` | `0.32.3` | VS Code 可变状态 | 待确认 |
| `intellsmi.comment-translate` | `3.1.0` | VS Code 可变状态 | 待确认 |
| `justusadam.language-haskell` | `3.6.0` | VS Code 可变状态 | 待确认 |
| `kisstkondoros.vscode-gutter-preview` | `0.32.2` | VS Code 可变状态 | 待确认 |
| `letrieu.expand-region` | `0.1.4` | VS Code 可变状态 | 待确认 |
| `mermaidchart.vscode-mermaid-chart` | `2.7.4` | VS Code 可变状态 | 待确认 |
| `mhutchie.git-graph` | `1.30.0` | VS Code 可变状态 | 待确认 |
| `ms-azuretools.vscode-containers` | `2.4.5` | VS Code 可变状态 | 待确认 |
| `ms-ceintl.vscode-language-pack-zh-hans` | `1.118.2026052020` | VS Code 可变状态 | 待确认 |
| `ms-playwright.playwright` | `1.1.19` | VS Code 可变状态 | 待确认 |
| `ms-python.python` | `2026.4.0` | VS Code 可变状态 | 待确认 |
| `ms-python.vscode-pylance` | `2026.3.1` | VS Code 可变状态 | 待确认 |
| `ms-vscode-remote.remote-containers` | `0.466.0` | VS Code 可变状态 | 待确认 |
| `ms-vscode-remote.remote-ssh` | `0.124.0` | VS Code 可变状态 | 待确认 |
| `ms-vscode-remote.remote-ssh-edit` | `0.87.0` | VS Code 可变状态 | 待确认 |
| `ms-vscode-remote.remote-wsl` | `0.104.3` | VS Code 可变状态 | 待确认 |
| `ms-vscode-remote.vscode-remote-extensionpack` | `0.26.0` | VS Code 可变状态 | 待确认 |
| `ms-vscode.azure-repos` | `0.40.0` | VS Code 可变状态 | 待确认 |
| `ms-vscode.remote-explorer` | `0.5.0` | VS Code 可变状态 | 待确认 |
| `ms-vscode.remote-repositories` | `0.42.0` | VS Code 可变状态 | 待确认 |
| `ms-vscode.remote-server` | `1.5.3` | VS Code 可变状态 | 待确认 |
| `naumovs.color-highlight` | `2.8.0` | VS Code 可变状态 | 待确认 |
| `openai.chatgpt` | `26.721.41059` | VS Code 可变状态 | 待确认 |
| `pkief.material-icon-theme` | `5.37.0` | VS Code 可变状态 | 待确认 |
| `pomdtr.excalidraw-editor` | `3.9.3` | VS Code 可变状态 | 待确认 |
| `ritwickdey.liveserver` | `5.7.10` | VS Code 可变状态 | 待确认 |
| `shd101wyy.markdown-preview-enhanced` | `0.8.30` | VS Code 可变状态 | 待确认 |
| `streetsidesoftware.code-spell-checker` | `4.5.6` | VS Code 可变状态 | 待确认 |
| `teabyii.ayu` | `1.1.12` | VS Code 可变状态 | 待确认 |
| `vue.volar` | `3.3.8` | VS Code 可变状态 | 待确认 |
| `w88975.code-translate` | `1.0.20` | VS Code 可变状态 | 待确认 |
| `wakatime.vscode-wakatime` | `30.2.1` | VS Code 可变状态 | 待确认 |
| `wallabyjs.console-ninja` | `1.0.537` | VS Code 可变状态 | 待确认 |
| `yoavbls.pretty-ts-errors` | `0.8.7` | VS Code 可变状态 | 待确认 |
| `yzhang.markdown-all-in-one` | `3.6.3` | VS Code 可变状态 | 待确认 |

## 审计规则

每项扩展必须同时回答两个问题：

1. **适用范围：** shared、Darwin、Linux 或 local；
2. **终态所有权：** Nix/基线声明、继续由编辑器保持可变，或明确排除并在单独
   删除关卡中清理。

Zed 与 VS Code 按用户能力而不是 Marketplace ID 机械配对。主题、图标和语言
支持可以在两个编辑器中分别选择；登录型、AI、远程和遥测扩展还要单独审查账号
状态、平台需要与机密边界。
