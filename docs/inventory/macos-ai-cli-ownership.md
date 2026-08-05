# macbook AI CLI 软件所有权

本文记录 Issue [#67](https://github.com/sayoriqwq/nix-config/issues/67) 建立、Issue
[#93](https://github.com/sayoriqwq/nix-config/issues/93) 最终收口后的 macbook AI 命令行
客户端边界。#67 的声明已由维护者激活并完成实机验收；#93 随后定向删除旧入口，未
执行新的 nix-darwin activation。

## 1. 范围与决策

本次只覆盖 macbook 的四个命令，并复用现有
`ai-assisted-operations` capability。四个命令均由 Nix/Home Manager 声明，且在
干净 Fish 会话的 PATH 中只有 Home Manager profile 这一声明式来源：

| 命令 | 目标版本 | 来源与所有权 | 更新策略 |
| --- | --- | --- | --- |
| `codex` | OpenAI 官方发布 `0.146.0` | 官方 macOS 发布物；Nix package 负责固定下载、校验和 PATH | 关闭启动更新检查；可执行文件仅由 Nix 更新 |
| `claude` | 锁定 nixpkgs `claude-code` `2.1.220` | nixpkgs recipe；Home Manager profile | recipe 禁止上游 installer/updater；版本随锁定 nixpkgs 变更 |
| `agy` | Google 官方 Antigravity CLI `1.1.9` | 官方 macOS 发布物；Nix package 负责固定下载、校验和 PATH | wrapper 关闭客户端自动更新；可执行文件仅由 Nix 更新 |
| `omp` | Oh My Pi `17.2.4` | 官方 `darwin-arm64` 发布物；Nix package 固定版本、校验和 PATH | 只读配置 overlay 关闭启动更新检查；可执行文件仅由 Nix 更新 |

Codex wrapper 关闭启动更新检查，Antigravity wrapper 关闭自动更新，Oh My Pi wrapper
通过只读配置 overlay 把 `startup.checkUpdate` 固定为 `false`；Claude 的锁定 nixpkgs
recipe 禁止上游 installer/updater。任何可执行文件版本变更都必须进入仓库声明审阅。

这四个命令只在 macbook 组合；不新增 host capability，不扩展到 nixbox 或 server。
`omp`（Oh My Pi）继续由 Nix 声明，版本固定为 `17.2.4`；`~/.omp` 及其中的登录态、
配置、session、history、skills/hooks、缓存和数据库保持外部可写。macOS legacy
Homebrew cask 声明移除 `claude-code`；该声明变化不等于对真实机器执行卸载。

ChatGPT.app 仍由既有 `chatgpt` cask 声明并保留 GUI。其 embedded Codex 是应用私有
helper，不是上述 `codex` PATH 命令的安装来源，也不纳入 Nix 迁移或清理目标。

## 2. 迁移时的重复副本与清理结果

以下副本曾作为 activation 回滚入口保留。维护者在新入口完成 PATH/版本验收后，于
2026-08-03 在 #93 明确批准并完成定向清理：

| 副本 | 迁移时事实 | #93 结果 |
| --- | --- | --- |
| Homebrew Claude | `/opt/homebrew` 中 `claude` `2.1.153` | cask 已定向卸载；未运行 cleanup 或 zap |
| 手工 Antigravity | `~/.local/bin/agy` `1.0.8` | 精确入口已删除 |
| 停用 mise Node `25.8.1` 的 Codex npm global | `@openai/codex` `0.144.4` | 随已停用 Node 25 runtime 定向删除 |
| 停用 mise Node `25.8.1` 的 Oh My Codex npm global | `oh-my-codex` `0.14.2` | 在 #67 中不属于首轮目标；#93 批准清理停用 runtime 后随 Node 25 一并删除 |
| ChatGPT.app embedded Codex | app-private helper | 保留 GUI 和应用私有文件；不把它当作 PATH duplicate 或清理对象 |

历史 Bun global `@oh-my-pi/pi-coding-agent@17.0.7` 已按 Issue #30 精确删除，不是
当前存在的副本，也不是本轮清理目标。

清理前逐项核对了真实路径、版本和消费者。不得把 `~/.codex`、`~/.claude`、`~/.claude.json`、
`~/.gemini`、`~/.omp` 或 `~/.local/share/mise` 作为递归删除目标。

## 3. 全局 Agent 策略

macbook 的 `ai-assisted-operations` capability 只把稳定策略
`~/.codex/AGENTS.md` 纳入 Home Manager。其源码为
`dotfiles/codex/AGENTS.md`。2026-08-04 的 PR #92 合并后 reconcile 明确以当时正在
使用的简洁版本为 authority，并回写 Nix 声明；该策略只公开以下 interface：

- 本机由 `nix-darwin + Home Manager` 管理，命令通过 Nix-managed Fish 登录环境执行；
- 项目环境外需要 Python 时使用 `/etc/profiles/per-user/sayori/bin/python`；
- 展示给用户的命令默认使用 Fish 语法；
- 每个需要用户执行的命令或命令块后附一行、恰好一个相关 emoji 的说明。

文件首行继续引用外部 `~/.codex/RTK.md`。当前 capability 不管理该文件，也不把 RTK
规则内联进策略；RTK 后续由专门的 AI 系列工作纳入稳定基线。旧长版中关于 Nix Store、
uv/mise、全局安装和 activation 的扩展说明不再属于该全局策略正文；对应所有权和人工
关卡仍由仓库规范、能力模块、inventory 与专项检查分别维护。

Home Manager 对该精确文件设置 `force`，使激活后的入口不能被手工副本静默漂移。
源文件不包含 token、session、账号或其他机密，可以安全进入 Nix Store。回滚上一代
generation 会恢复上一版策略，不删除任何 Codex 可变状态。

## 4. 可变状态、机密与 Store 边界

Nix 只拥有 package、稳定声明、PATH 入口和上节列出的全局 Agent 策略。以下路径及其中
除 `~/.codex/AGENTS.md` 外的 auth/token、session、history、skills、hooks、cache、
数据库、项目内容均继续由客户端或用户拥有，保持可写，不读取、不迁移、不整体链接到
Nix Store：

- `~/.codex`；
- `~/.claude`；
- `~/.claude.json`（Claude Code 的用户级认证/配置元数据）；
- `~/.gemini` 中由 Antigravity 使用的状态；
- `~/.omp` 及各项目的 Oh My Pi 状态目录；
- 客户端登录态、token、会话、历史、skills/hooks、缓存和数据库。

`sayori.statePaths` 如需记录上述位置，只表示位置、所有者和备份边界，不创建、备份、
清理或接管内容。项目 Python、`.venv` 和依赖仍由 uv/项目管理；mise 不管理 Python
或 uv。

## 5. 激活顺序与干净 Fish 验收（已完成）

以下是 #67 使用的维护者执行顺序；真实机器 activation 和最终验收均由维护者完成：

1. 审阅 diff、`flake.lock` 变更及本表版本，确认只组合 macbook 的
   `ai-assisted-operations` capability。
2. 运行 `nix fmt -- --check .`、`nix flake check` 和
   `nix build .#darwinConfigurations.macbook.system`；构建成功不代表已激活。
3. 维护者批准后执行精确 commit 的 nix-darwin/Home Manager activation；activation
   不清理上节列出的任何重复副本。
4. 完全退出并重新打开 Fish（不复用 Codex 进程继承的 PATH），确认声明式 profile
   位于用户可写兼容路径之前，再执行：

```fish
type -a codex claude agy omp
command -s codex
command -s claude
command -s agy
command -s omp
codex --version
claude --version
agy --version
omp --version
```

通过条件是四个 `command -s` 均指向 Home Manager profile（如
`/etc/profiles/per-user/sayori/bin`），版本分别为 `0.146.0`、`2.1.220`、`1.1.9`、
`17.2.4`；`type -a` 可以显示历史副本，但 PATH 首个命中不得来自 Homebrew、
`~/.local/bin` 或 mise npm globals。验收同时确认 Codex/OMP 没有启动更新检查、AGY
没有自动更新，且上述状态目录和凭据未被写入 Store。

## 6. 清理记录与回滚

维护者在 #93 批准了上述旧入口和全部停用 mise runtime 的精确清理。清理后，干净
Fish 中四个命令的首个正常来源均为 Home Manager profile；ChatGPT.app 的 embedded
Codex 继续作为应用私有 helper 保留。清理没有使用全局 `brew cleanup`、
`brew uninstall --zap`，也没有删除任何 AI 客户端状态。

若声明异常，优先回滚到上一代 nix-darwin/Home Manager generation；这只恢复 Nix
声明、package 链接和 PATH，不恢复或删除客户端状态，也不自动重装已清理的旧副本。
在清理前回滚不需要重建状态；在清理后如需旧入口，维护者必须按新的批准重新安装
对应外部副本。四个命令的 upstream 版本选择仍由仓库声明负责。

## 7. 非目标与后续

- 不扩展到 nixbox 或 server，不改变 server 迁移、SSH、网络、firewall 或数据流程；
- 不接管 AI 客户端登录、token、历史、skills/hooks、cache、数据库或项目状态；
- 不改变 ChatGPT GUI、ChatGPT Classic 或其他 macOS 应用的所有权；
- #93 的维护只删除已验证可替代的旧软件入口；不执行新的 activation；
- 后续行为兼容或数据迁移仍需独立维护者批准的窄动作记录。
