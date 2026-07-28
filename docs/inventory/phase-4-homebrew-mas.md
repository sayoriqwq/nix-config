# Phase 4 Homebrew cask 与 Mac App Store 声明记录

本文记录 Issue [#46](https://github.com/sayoriqwq/nix-config/issues/46) 的所有权、
离线验证、真实机器 activation 关卡和回滚边界。本文不授权 activation、应用升级、
应用卸载、Homebrew cleanup、App Store 账号变更或 Pull Request 合并。

## 1. 声明范围

nix-darwin 只声明已由维护者批准的恢复入口：

- 1 个限定 Homebrew tap：`erictli/tap`；
- 28 个 Homebrew cask；
- 9 个 Mac App Store 应用；
- 0 个 Homebrew formula；
- `homebrew.onActivation.autoUpdate = false`；
- `homebrew.onActivation.upgrade = false`；
- `homebrew.onActivation.cleanup = "none"`。

应用账号、许可证、登录态、偏好、缓存、数据库、容器、虚拟机、项目和其他可变状态
不由 Homebrew Bundle 或 Nix 接管。

Xcode Beta、Command Line Tools 与 Homebrew XcodeGen 是 macbook 的外部 Swift 工具链；
Xcode Stable 已明确退役，Beta 是唯一保留的完整 Xcode 渠道。本 Issue 只记录目标边界，
不声明版本、不运行 `xcode-select`，也不改变许可证、SDK、Simulator 或工程状态。

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

- **OrbStack：** 首次 activation 曾因 `docker-desktop` 与 OrbStack 争用
  `/usr/local/bin/docker-credential-osxkeychain` 而失败并安全回滚。维护者随后明确选择
  OrbStack 作为唯一容器运行时，并从声明中移除 `docker-desktop`。精确 commit
  `98a94c76ef58679bbc108067e7bf622a892d30fa` 已完成重新 activation；`docker`、
  `kubectl` 与 `docker-credential-osxkeychain` 均由 OrbStack 提供。维护者随后在 #51
  明确批准并删除 Docker Desktop 遗留的 `docker-credential-desktop` 与 `hub-tool`
  两个悬空链接；删除后 OrbStack 的三个 CLI 入口与版本检查仍正常。维护者启动
  OrbStack 后再次执行 `docker ps`，确认 daemon 与现有容器工作流正常。
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

1. 正好包含 1 个 tap、28 个 cask、9 个 MAS 应用和 0 个 formula；
2. Scratch 使用 `erictli/tap/scratch`，不存在裸 `scratch`；
3. OBS Studio 使用 `homebrew/cask/obs`，不存在会触发旧 migration 的裸 `obs`；
4. ChatGPT 使用 `chatgpt` cask，ChatGPT Classic 不在声明中；
5. Xcode Beta 与 XcodeGen 不在 Homebrew/MAS 声明中，Xcode Stable 已退役；
6. activation 使用 `HOMEBREW_NO_AUTO_UPDATE=1` 与 `brew bundle --no-upgrade`；
7. 不存在 cleanup 或 zap 参数。

## 6. activation 前私有备份

维护者审阅 Draft PR 并批准精确 commit 后，由 Agent 在仓库外创建权限受限的私有
备份目录，记录而不移动：

- 当前 nix-darwin generation；
- `brew tap`、`brew list --formula`、`brew list --cask` 与 `mas list`；
- 28 个目标应用的路径、bundle ID、版本和签名摘要；
- `/usr/local/bin` 中 Docker、kubectl、credential helper 与 Paseo 相关链接；
- OrbStack 与 ChatGPT 两个应用的精确身份；
- 必要时的应用偏好路径清单，但不复制或输出 token、账号、数据库、容器或 VM 内容。

Agent 不执行真实 activation。备份完成后只把绑定精确 commit 的
`darwin-rebuild switch` 命令交给维护者执行。

## 7. 人工验收

activation 后逐项确认：

1. Homebrew Bundle 完成且没有升级、cleanup 或卸载输出；
2. 28 个目标 cask 与 9 个 MAS ID 均可由声明解释，既有 MAS 应用没有升级；
3. 既有应用账号、偏好和数据仍可用；
4. `ChatGPT.app` 仍是 `com.openai.codex`，`ChatGPT Classic.app` 仍是
   `com.openai.chat`；
5. OrbStack 可以启动，`docker`、`kubectl` 与 `docker-credential-osxkeychain` 均解析到
   OrbStack；`Docker.app` 与 Docker Desktop Caskroom 均不存在；
6. Scratch 仍是 `com.scratch.app` Markdown 应用；
7. Xcode Beta、Command Line Tools 与 XcodeGen 没有被改变，Xcode Stable 保持退役。

## 8. 回滚与后续清理

nix-darwin generation 回滚只能撤回声明，不能保证撤销 Homebrew 已完成的 cask adoption、
新应用安装或 CLI 链接变化。发生问题时：

1. 先回滚 nix-darwin generation，停止继续声明问题目标；
2. 对照私有备份恢复受影响的 CLI 链接；
3. 只有解析出精确 cask、应用 artifact 和数据影响，并获得新的人工批准后，才运行定向
   `brew uninstall --cask`；
4. 不运行 `brew cleanup`、`brew uninstall --zap` 或批量删除 `/Applications`；
5. 不把应用卸载等同于数据删除，也不声称 generation 能回滚应用可变状态。

Docker Desktop 的两个悬空 helper 链接由 #51 单独跟踪；旧 Nix 替代 cask、退役应用
与无主 tap 均留给后续窄 Issue 逐项处理。

## 9. 实机验收结果

维护者已对精确 commit `98a94c76ef58679bbc108067e7bf622a892d30fa` 执行
`darwin-rebuild switch`。Homebrew Bundle 报告 39 个 Brewfile dependency 已安装，
Home Manager activation 完成且没有失败项。

只读收口审计确认：

- 声明的 28 个 cask 全部存在；
- 声明的 9 个 MAS receipt 全部存在；Xcode Beta 是声明外的 Swift 工具链渠道；
- 使用锁定的 `mas` 执行 `brew bundle check --no-upgrade` 通过；
- `ChatGPT.app` 为 `com.openai.codex`，`ChatGPT Classic.app` 为 `com.openai.chat`；
- `Docker.app` 与 Docker Desktop Caskroom 均不存在，OrbStack 是唯一声明的容器运行时；
- Docker Desktop 遗留的两个悬空 CLI helper 链接已按 #51 的精确批准删除；
- 维护者启动 OrbStack 后执行 `docker ps`，确认 daemon 与现有容器工作流正常；
- `cleanup = "none"` 继续保留，未执行批量应用卸载、zap 或数据清理。

维护者随后对精确 commit `289dd6077b2ccf096e64d4cc35c8aeb614a7c83e`
执行 activation。Homebrew Bundle 报告 38 个 dependency，输出不再包含 Typeless，
Home Manager activation 完成且没有失败项。在新的精确批准后，使用绝对路径执行
`brew uninstall --cask typeless`；Homebrew 登记、Caskroom 与应用路径均已消失，
私有备份继续保留。该定向卸载没有启用 cleanup 或 zap，也没有处理其他 cask。
