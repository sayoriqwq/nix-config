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
维护者于 2026-07-26 在应用内自行完成精简；重新采集后剩余 24 个扩展，并确认
它们全部保留。该集合只描述 `macbook` 当前需要，不要求 Darwin 与 NixOS 保持
完全一致，因此适用范围统一记为 local。扩展继续由 VS Code 管理，Nix 不负责
自动安装、升级或删除。Copilot、Copilot Chat、Claude Code 与 OpenAI ChatGPT
均已不在 live 注册表中。

| ID | 版本 | 适用范围 | 终态所有权 | 决定 |
| --- | --- | --- | --- | --- |
| `antfu.iconify` | `1.0.0` | local | VS Code 可变状态 | 保留 |
| `astral-sh.ty` | `2026.64.0` | local | VS Code 可变状态 | 保留 |
| `bradlc.vscode-tailwindcss` | `0.16.0` | local | VS Code 可变状态 | 保留 |
| `dbaeumer.vscode-eslint` | `3.0.34` | local | VS Code 可变状态 | 保留 |
| `ddiu8081.moegi-theme` | `0.7.1` | local | VS Code 可变状态 | 保留 |
| `eamodio.gitlens` | `18.3.0` | local | VS Code 可变状态 | 保留 |
| `effectful-tech.effect-vscode` | `0.9.0` | local | VS Code 可变状态 | 保留 |
| `esbenp.prettier-vscode` | `12.4.0` | local | VS Code 可变状态 | 保留 |
| `justusadam.language-haskell` | `3.6.0` | local | VS Code 可变状态 | 保留 |
| `kisstkondoros.vscode-gutter-preview` | `0.32.2` | local | VS Code 可变状态 | 保留 |
| `mhutchie.git-graph` | `1.30.0` | local | VS Code 可变状态 | 保留 |
| `ms-ceintl.vscode-language-pack-zh-hans` | `1.118.2026052020` | local | VS Code 可变状态 | 保留 |
| `ms-python.python` | `2026.4.0` | local | VS Code 可变状态 | 保留 |
| `ms-python.vscode-pylance` | `2026.3.1` | local | VS Code 可变状态 | 保留 |
| `naumovs.color-highlight` | `2.8.0` | local | VS Code 可变状态 | 保留 |
| `pkief.material-icon-theme` | `5.37.0` | local | VS Code 可变状态 | 保留 |
| `ritwickdey.liveserver` | `5.7.10` | local | VS Code 可变状态 | 保留 |
| `shd101wyy.markdown-preview-enhanced` | `0.8.30` | local | VS Code 可变状态 | 保留 |
| `streetsidesoftware.code-spell-checker` | `4.5.6` | local | VS Code 可变状态 | 保留 |
| `teabyii.ayu` | `1.1.12` | local | VS Code 可变状态 | 保留 |
| `vue.volar` | `3.3.8` | local | VS Code 可变状态 | 保留 |
| `w88975.code-translate` | `1.0.20` | local | VS Code 可变状态 | 保留 |
| `wakatime.vscode-wakatime` | `30.2.1` | local | VS Code 可变状态 | 保留 |
| `yoavbls.pretty-ts-errors` | `0.8.7` | local | VS Code 可变状态 | 保留 |

## 审计规则

每项扩展必须同时回答两个问题：

1. **适用范围：** shared、Darwin、Linux 或 local；
2. **终态所有权：** Nix/基线声明、继续由编辑器保持可变，或明确排除并在单独
   删除关卡中清理。

Zed 与 VS Code 按用户能力而不是 Marketplace ID 机械配对。主题、图标和语言
支持可以在两个编辑器中分别选择；登录型、AI、远程和遥测扩展还要单独审查账号
状态、平台需要与机密边界。
