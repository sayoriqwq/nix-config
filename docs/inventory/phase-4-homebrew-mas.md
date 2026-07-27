# Phase 4 Homebrew cask 与 Mac App Store 声明记录

本文记录 Issue [#46](https://github.com/sayoriqwq/nix-config/issues/46) 的所有权、
离线验证、真实机器 activation 关卡和回滚边界。本文不授权 activation、应用升级、
应用卸载、Homebrew cleanup、App Store 账号变更或 Pull Request 合并。

## 1. 声明范围

nix-darwin 只声明已由维护者批准的恢复入口：

- 1 个限定 Homebrew tap：`erictli/tap`；
- 30 个 Homebrew cask；
- 9 个 Mac App Store 应用；
- 0 个 Homebrew formula；
- `homebrew.onActivation.autoUpdate = false`；
- `homebrew.onActivation.upgrade = false`；
- `homebrew.onActivation.cleanup = "none"`。

应用账号、许可证、登录态、偏好、缓存、数据库、容器、虚拟机、项目和其他可变状态
不由 Homebrew Bundle 或 Nix 接管。

Xcode Stable、Xcode Beta、Command Line Tools 与 Homebrew XcodeGen 是 macbook 的外部
Swift 工具链。本 Issue 只记录其存在，不声明版本、不运行 `xcode-select`，也不改变
许可证、SDK、Simulator 或工程状态。

## 2. 特殊身份与恢复入口

### 2.1 ChatGPT 与 ChatGPT Classic

当前两个 OpenAI 应用是不同产品身份：

| 当前应用 | 历史身份 | Bundle ID | 所有者 |
| --- | --- | --- | --- |
| `ChatGPT.app` | 原 Codex App | `com.openai.codex` | Homebrew `chatgpt` cask |
| `ChatGPT Classic.app` | 原 ChatGPT App | `com.openai.chat` | 外部保留 |

Homebrew `chatgpt` cask 下载自 OpenAI 的 `codex-app-prod` 通道，只对应
`com.openai.codex`。它不会取得 ChatGPT Classic 的安装或数据所有权。

### 2.2 Scratch

裸名称 `scratch` 当前指向 MIT Scratch 3，不是本机使用的 Markdown 应用。本仓库必须
使用完整 token `erictli/tap/scratch`；该应用 bundle 为 `com.scratch.app`，当前版本
为 0.10.0。`erictli/tap` 是唯一为 #46 新增并显式信任的第三方 tap。

### 2.3 OBS Studio 与旧 tap migration

本机遗留的未受信任 tap `yakitrak/yakitrak` 把裸名称 `obs` 迁移到已退役的 formula
`notesmd-cli`。Homebrew Bundle fetch 不附加 `--cask`，因此裸 token 会在 activation
中错误加载该 formula 并触发 trust 拒绝。本仓库使用完整 token
`homebrew/cask/obs`，强制解析官方 OBS Studio cask；不信任、不修改也不删除旧 tap。
旧 tap 与 notesmd-cli 的定向清理留给后续清理 Issue。

## 3. 首次 Homebrew Bundle 行为

本机已有 8 个目标 cask 由 Caskroom 登记；其余目标多数已有 `/Applications` 应用，
但尚未由 Homebrew 登记。Homebrew Bundle 对未登记 cask 使用 `--adopt`：仅当目标
artifact 与既有应用匹配时接管登记，不会因为同名目标冲突而静默覆盖应用。

首次 activation 需要特别观察：

- **Docker Desktop：** `docker-desktop` 会登记 `Docker.app`，并管理若干
  `/usr/local/bin` CLI 链接。当前 `docker`、`kubectl` 和部分 credential helper
  链接由 OrbStack 占用，另一些链接已指向 Docker Desktop。真实 activation 前必须
  保存链接清单，activation 后逐项确认最终指向；不得据此删除 Docker VM、镜像、
  容器、volume、context 或 OrbStack 数据。
- **Paseo：** cask 除应用外还可暴露 CLI；activation 后需要确认 CLI 来源，但 Agent
  session 与 workspace 继续作为可变状态。

`cleanup = "none"` 保证未列入本次声明的旧 cask 和应用不会被批量移除。
维护者已决定退役 Lark，因此 `lark` 不在声明中；本次不会安装 `LarkSuite.app`，
现有 `Lark.app` 只进入后续定向清理清单。

## 4. Mac App Store 边界

9 个目标在 activation 前均存在有效 App Store receipt，`mas list` 能识别其 App ID。
由于 `upgrade = false`，首次 activation 不应升级这些既有应用。Xcode 仍能被
`mas list` 识别，但保持外部 Swift 工具链所有，不在 `masApps` 中。The Unarchiver 已
由维护者删除并明确退役；其功能与保留的 iZip 高度重叠，不在声明中。

`mas` 6.x 不再提供可用于脚本化确认账号的 `mas account`。activation 前由维护者人工
确认 Mac App Store 已登录；本仓库不保存 Apple ID、账号标识或凭据，也不清除 receipt。

macOS 核心内建应用不写入 `masApps`。Xcode 虽有 App Store 版本，但根据维护者批准的
Swift 工具链边界保持外部所有，因此也不写入 `masApps`。

## 5. 离线验证

activation 前运行：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link --print-out-paths
```

还必须检查生成 Brewfile：

1. 正好包含 1 个 tap、30 个 cask、9 个 MAS 应用和 0 个 formula；
2. Scratch 使用 `erictli/tap/scratch`，不存在裸 `scratch`；
3. OBS Studio 使用 `homebrew/cask/obs`，不存在会触发旧 migration 的裸 `obs`；
4. ChatGPT 使用 `chatgpt` cask，ChatGPT Classic 不在声明中；
5. Xcode、Xcode Beta 与 XcodeGen 不在 Homebrew/MAS 声明中；
6. activation 使用 `HOMEBREW_NO_AUTO_UPDATE=1` 与 `brew bundle --no-upgrade`；
7. 不存在 cleanup 或 zap 参数。

## 6. activation 前私有备份

维护者审阅 Draft PR 并批准精确 commit 后，由 Agent 在仓库外创建权限受限的私有
备份目录，记录而不移动：

- 当前 nix-darwin generation；
- `brew tap`、`brew list --formula`、`brew list --cask` 与 `mas list`；
- 30 个目标应用的路径、bundle ID、版本和签名摘要；
- `/usr/local/bin` 中 Docker、kubectl、credential helper 与 Paseo 相关链接；
- Docker Desktop 和 ChatGPT 两个应用的精确身份；
- 必要时的应用偏好路径清单，但不复制或输出 token、账号、数据库、容器或 VM 内容。

Agent 不执行真实 activation。备份完成后只把绑定精确 commit 的
`darwin-rebuild switch` 命令交给维护者执行。

## 7. 人工验收

activation 后逐项确认：

1. Homebrew Bundle 完成且没有升级、cleanup 或卸载输出；
2. 30 个目标 cask 与 9 个 MAS ID 均可由声明解释，既有 MAS 应用没有升级；
3. 既有应用账号、偏好和数据仍可用；
4. `ChatGPT.app` 仍是 `com.openai.codex`，`ChatGPT Classic.app` 仍是
   `com.openai.chat`；
5. Docker Desktop 可以启动，Docker/OrbStack CLI 链接没有造成日常工作流回归；
6. Scratch 仍是 `com.scratch.app` Markdown 应用；
7. Xcode Stable、Xcode Beta、Command Line Tools 与 XcodeGen 没有被改变。

## 8. 回滚与后续清理

nix-darwin generation 回滚只能撤回声明，不能保证撤销 Homebrew 已完成的 cask adoption、
新应用安装或 CLI 链接变化。发生问题时：

1. 先回滚 nix-darwin generation，停止继续声明问题目标；
2. 对照私有备份恢复受影响的 CLI 链接；
3. 只有解析出精确 cask、应用 artifact 和数据影响，并获得新的人工批准后，才运行定向
   `brew uninstall --cask`；
4. 不运行 `brew cleanup`、`brew uninstall --zap` 或批量删除 `/Applications`；
5. 不把应用卸载等同于数据删除，也不声称 generation 能回滚应用可变状态。

Docker/OrbStack CLI 所有权、旧 Nix 替代 cask、退役应用与无主 tap 均留给
后续窄 Issue 逐项处理。
