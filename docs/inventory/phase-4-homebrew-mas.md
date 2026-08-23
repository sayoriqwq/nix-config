# Phase 4 Homebrew cask 与 Mac App Store 声明记录

本文记录 Issue [#46](https://github.com/sayoriqwq/nix-config/issues/46) 的所有权、
离线验证、真实机器 activation 关卡和回滚边界，并在第 10–13 节保留后续维护事实。
本文不授权新的 activation、应用升级、Homebrew cleanup、App Store 账号变更或 Pull
Request 合并。

## 1. 声明范围

nix-darwin 只声明已由维护者批准的恢复入口：

- 1 个限定 Homebrew tap：`erictli/tap`；
- 28 个 Homebrew cask；
- 9 个 Mac App Store 应用；
- 0 个 Homebrew formula；
- `homebrew.onActivation.autoUpdate = false`；
- `homebrew.onActivation.upgrade = false`；
- `homebrew.onActivation.cleanup = "none"`。

以上 28 个 cask 是 Issue #46 的原始实施与验收基线。Issue #74 在 2026-07-31 曾恢复
全球版 `lark` 声明，Issue #81 随后把当前渠道更正为中国区 `feishu`；Issue #67 又把
`claude-code` 从 Homebrew 迁移到 Nix/Home Manager；Issue #199 再按已批准语义仅删除
Steam declaration，因此当前目标为 27 个 cask。
原始 build/activation 记录继续按当时 28 个条目解释，后续修订见第 10–12 节。

应用账号、许可证、登录态、偏好、缓存、数据库、容器、虚拟机、项目和其他可变状态
不由 Homebrew Bundle 或 Nix 接管。

Xcode Beta、Command Line Tools 与 Homebrew XcodeGen 是 macbook 的外部 Swift 工具链；
Xcode Stable 已明确退役，Beta 是唯一保留的完整 Xcode 渠道。本 Issue 只记录目标边界，
不声明版本、不运行 `xcode-select`，也不改变许可证、SDK、Simulator 或工程状态。
当前实机已恢复 Xcode Beta 27.0（Build `27A5228h`）；使用临时 `DEVELOPER_DIR` 的
版本探针通过，系统 `xcode-select` 继续指向 Command Line Tools。

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
使用完整 token `erictli/tap/scratch`；该应用 bundle 为 `com.scratch.app`。Issue
[#64](https://github.com/sayoriqwq/nix-config/issues/64) 已把实际 bundle 与 Homebrew
receipt 从漂移状态定向对齐到 1.0.0。`erictli/tap` 是唯一为 #46 新增并显式信任的
第三方 tap。

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
Issue #46 当时依据维护者决定未声明 `lark`，随后 #57 将旧 `Lark.app` 与专属数据移入
可恢复 Trash。该历史决定先由 #74 修正为声明全球版 `lark`，再由 #81 更正为声明中国区
`feishu`；原始 #46 activation 仍只包含 28 个 cask。

## 4. Mac App Store 边界

9 个目标在 activation 前均存在有效 App Store receipt，`mas list` 能识别其 App ID。
由于 `upgrade = false`，首次 activation 不应升级这些既有应用。Xcode 仍能被
`mas list` 识别，但保持外部 Swift 工具链所有，不在 `masApps` 中。The Unarchiver 已
由维护者删除并明确退役；其功能与保留的 iZip 高度重叠，不在声明中。

`mas` 6.x 不再提供可用于脚本化确认账号的 `mas account`。activation 前由维护者人工
确认 Mac App Store 已登录；本仓库不保存 Apple ID、账号标识或凭据，也不清除 receipt。

macOS 核心内建应用不写入 `masApps`。Xcode 虽有 App Store 版本，但根据维护者批准的
Swift 工具链边界保持外部所有，因此也不写入 `masApps`。

## 5. Issue #46 原始离线验证

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
6. Scratch 仍是 `com.scratch.app` Markdown 应用；涉及版本检查时必须使用完整 token
   `erictli/tap/scratch`，避免解析到同名的 MIT Scratch；
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

Issue #64 升级前确认 Homebrew receipt 为 0.4.0、实际 app bundle 为 0.10.0。维护者在
Issue 中批准当次定向升级后，先正常退出 Scratch，把签名有效的 0.10.0 bundle 保存到
仓库外权限受限的 `~/.local/state/nix-config-backups/scratch-issue-64-pre-1.0/`，再执行
Homebrew 元数据更新和 `brew upgrade --cask erictli/tap/scratch`。升级输出只包含 Scratch
`0.4.0 -> 1.0.0`，没有升级同时报告为 outdated 的其他 8 个 formula 与 5 个 cask，也没有
执行 cleanup、zap、卸载或 autoremove。

升级后实际 bundle 与 Homebrew receipt 均为 1.0.0；完整 token 的 outdated JSON 中 cask
集合为空。`CFBundleIdentifier` 仍为 `com.scratch.app`，Team Identifier 仍为
`38H4DN8A25`，深度签名验证和启动探针均通过。裸 `brew outdated scratch` 会误解析到
MIT Scratch 3.32.0，因此后续安装、升级和 outdated 验证都必须使用完整 token。

## 10. Issue #74：恢复 Lark 声明与数据边界（历史）

2026-07-31 的只读检查确认：

- live `/Applications/Lark.app` 与 `~/Library/Application Support/LarkShell` 均不存在；
- `~/.Trash/nix-config-phase4-retired-apps.sTa1Cr` 仍存在，总计约 8.3 GB；
- 其中旧 `Lark.app` 约 1.3 GB，`Application Support/LarkShell` 约 4.7 GB；
- bundle-specific preferences、HTTPStorage、cache 与字体 workaround 仍在隔离目录；
- 未打开聊天、账号、数据库或其他用户内容。

Issue #74 实施时选择的官方 Homebrew token 为 `lark`。对 Homebrew API 所列 DMG 做
SHA-256 校验和只读挂载后，确认 artifact 为 `LarkSuite.app`，bundle ID 为
`com.larksuite.larkApp`，
Team ID 为 `JBRN9C6V7T`。Trash 中旧 `Lark.app` 的 bundle ID 为
`com.electron.lark`，Team ID 为 `XY6NLV7YTS`。两者的
`CFBundleShortVersionString` 均为 `131.0.6778.268`，二进制均引用 `LarkShell` 和旧新
bundle identity，但 Keychain access group 随 Team/bundle 改变；因此文件数据具有迁移
路径，登录凭据不能假定可直接继承。

Homebrew 还提供 `feishu` cask，它面向 `feishu.cn` 并安装 `Feishu.app`。Issue #74 当时
选择全球版 `lark`；该产品渠道判断已由维护者在 Issue #81 明确推翻。以下步骤保留为
#74 的历史恢复证据，不再描述当前目标声明。

人工恢复必须遵循：

1. 验收前不要清空上述 Trash；先在仓库外建立可恢复的私有副本；
2. 在目标 live 路径不存在时，恢复旧 `Lark.app`、`LarkShell`、字体 workaround、
   preferences 与 HTTPStorage；cache 可选，过期的 `com.ebus.lark.nf_ipc.sock` 不恢复；
3. 由维护者启动旧 `Lark.app`，先验证账号、登录态、聊天和本地文件，并完成必要同步或
   导出；随后完全退出旧应用；
4. 再对合并后的精确 commit 单独批准并执行 nix-darwin activation，由 Homebrew 安装
   可并存的 `LarkSuite.app`；
5. 维护者首次启动新应用并完成可能需要的重新登录，确认数据迁移后再另行决定旧
   `Lark.app` 的处置；两份应用不得同时运行，验收前继续保留私有回滚副本。

Agent 在 #74 中只修改声明、文档并 build，不执行恢复、activation、安装或应用启动。

## 11. Issue #81：更正为中国区 Feishu（历史）

维护者已明确当前产品要求是中国区 Feishu。Homebrew 官方 `feishu` cask 的 homepage 为
`https://www.feishu.cn/`，当前元数据版本为 `7.72.8,715e64ed`，并把 DMG 内的
`Lark.app` 安装为 `/Applications/Feishu.app`。当前声明只包含 `feishu`，不再包含
`lark`；Homebrew 继续只拥有应用 presence，不拥有账号、聊天、数据库或其他可变状态。

Issue #81 开始时，真实机器已同时保留恢复后的 `/Applications/Lark.app` 和已由
Homebrew 安装的 `/Applications/LarkSuite.app`。由于 `cleanup = "none"`，后续 Feishu
activation 不会卸载既有 `lark` receipt 或删除 `LarkSuite.app`。三份应用的并存是迁移
回滚窗口；它们不得同时运行，任何卸载、zap、数据选择或迁移都必须另行批准。

当时的人工顺序为：

1. 保留旧 App、`LarkSuite.app`、Trash 原件与私有备份，并确认相关进程全部退出；
2. 对包含 `feishu` 的精确 merge commit 单独批准并执行 nix-darwin activation；
3. 核验 `/Applications/Feishu.app`、Homebrew receipt、bundle 与签名身份，不启动应用；
4. 再由维护者单独启动 Feishu，验证中国区账号、工作区、聊天、文件和同步，并判断是否
   需要迁移旧 `LarkShell` 数据；
5. 验收完成前不卸载或删除任何一份应用、receipt、Trash 原件或私有备份。

## 12. Issue #67：Claude Code 迁移到 Nix

Issue #67 将 `claude-code` 从 Homebrew cask 声明移除，并由 macbook 的
`ai-assisted-operations` Home Manager capability 提供锁定版本。当前 Homebrew 目标因此
从 #81 完成后的 29 个 cask 回到 28 个；`cleanup = "none"` 保持不变，所以声明变化不会
在 activation 中自动卸载真实机器已有的 Claude cask。

新的 Nix `claude` 已完成 activation、PATH 与版本验收；维护者在 #93 另行批准后定向
卸载旧 cask，未运行 cleanup 或 zap。Claude 的账号、凭据、会话和其他可变状态仍不由
Homebrew 或 Nix 接管；完整四 CLI 所有权与清理记录见
[`macOS AI CLI 所有权`](macos-ai-cli-ownership.md)。

## 13. Issue #93：迁移残留最终收口

2026-08-03，维护者批准在不执行新 activation、不运行全局 cleanup/zap 的前提下清理
已完成替代验收的旧来源。Homebrew 侧完成：

- 定向卸载全球版 `lark` cask 和旧 Claude Code cask，并删除手工旧 `Lark.app`；
- 保留中国区 `feishu` cask、`/Applications/Feishu.app` 及全部 live `~/Library` 数据；
- 在项目 venv 切换到 uv-managed CPython 并通过测试后，定向卸载 `python@3.12`；
- 删除无消费者的 `freetype`，当时保留 PostgreSQL 16、XcodeGen 及其依赖；
- 保持 `HOMEBREW_NO_AUTOREMOVE=1`，#93 当时没有触碰 PostgreSQL service/data 或其他 cask。
- 精确删除六个指向已退役 Docker、WARP 与 Zed Preview 应用的 root-owned
  `/usr/local/bin` 悬空链接；OrbStack 和 Nix Zed 的现行入口复验通过。

Issue #93 完成时声明仍为 1 tap、28 cask、9 MAS app、0 formula；真实 Homebrew formula 外部状态为
14 个。`feishu 7.72.8,715e64ed` 的 receipt 与 `/Applications/Feishu.app` 存在；实际
bundle ID 为 `com.electron.lark`、Team ID 为 `XY6NLV7YTS`，深度签名和 Gatekeeper
notarization 验证均通过。#74/#81 的 Lark 恢复步骤继续作为历史证据，不再描述当前
机器的应用集合；账号、聊天与本地数据未在本维护中读取或验收。

2026-08-06，#60 在新的独立批准下卸载 PostgreSQL 16，并接受 Homebrew 对当时无消费者
依赖的自动回收；这不改变 #93 的历史执行边界。

## 14. Issue #199：V3 application presence ownership

Issue #199 把当前 27 个 Homebrew cask 与 9 个 MAS application presence 分别迁移到
`software/<software>/capabilities/<primary-capability>/darwin.nix`。macbook 逐项显式选择这些
Primary Capabilities；仓库不再存在 `macos-legacy-applications` bundle，也没有 cask/MAS
registry、自动扫描或按应用生成的测试矩阵。Homebrew 自身的 capability 单独保留
`autoUpdate = false`、`upgrade = false` 与 `cleanup = "none"` 的非破坏策略。
完整当前 Brewfile 另包含工作站稳定访问 capability 拥有的 `tailscale-app`，因此总 cask 数为
28；该 frozen owner 不属于 Issue #199 的迁移或修改范围。

Steam 是唯一退出的现有 declaration。该删除只改变下一代候选配置，不卸载 live App，
不读取或修改 Steam account、library、game、save 或其他数据；Alice in Cradle 继续在仓库外。
其余 cask、MAS receipt 与 application external state 的历史验证和恢复边界保持不变。
