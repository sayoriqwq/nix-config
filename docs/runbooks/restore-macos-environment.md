# macOS 环境恢复与回滚手册

本文是 `macbook` 的总体软件恢复入口。它恢复声明和应用来源，不是用户数据备份手册。
执行前先阅读 [`phase-4-macos-software-ownership.md`](../inventory/phase-4-macos-software-ownership.md)。

## 1. 恢复目标与禁止事项

恢复目标是让一台兼容 macOS 工作站重新获得：

- Lix、nix-darwin 与 Home Manager 管理的系统/用户声明；
- 已声明的 Homebrew cask 与 Mac App Store 应用；
- 外部应用的清晰人工恢复入口；
- 经批准的 macOS defaults；
- 可验证但不被 Git 接管的可变数据边界。

不要把以下内容提交到仓库或误认为 generation 能恢复：Apple/Setapp/应用账号、Atuin
key/history、浏览器 profile、编辑器登录态与 workspace、数据库、OrbStack VM/容器/volume、
云盘数据、许可证、SecretStorage、TCC 授权和任何私有备份。

## 2. 推荐恢复顺序

### 2.1 盘点与数据保护

1. 按 [`host-inventory.md`](host-inventory.md) 重新采集机器事实，不复用旧主机猜测。
2. 确认重要数据库、OrbStack、浏览器、编辑器和云盘数据已有独立可恢复备份。
3. 记录现有 `/Applications`、Homebrew/MAS receipts、当前 Nix generation 和外部应用身份。
4. 不运行 `brew cleanup`、`brew autoremove`、`brew uninstall --zap` 或批量删除应用。

### 2.2 Feishu 渠道与数据边界

Issue #74 曾从 Trash 恢复并人工验收旧 `Lark.app` 与核心数据，#81 随后明确当前目标
是中国区 `feishu` cask 与 `/Applications/Feishu.app`。#93 核验当前 Feishu 的 receipt、
bundle 与签名并取得维护者明确清理批准后，定向删除旧 `Lark.app`、全球版 `lark`
receipt/`LarkSuite.app` 和两个已批准的 Trash rollback 目录。当前恢复时：

1. 只从当前声明恢复 `feishu`，不要重新安装全球版 `lark` 作为并行来源；
2. `cleanup = "none"` 意味着 activation 不会替用户判断或删除现场已有应用；若目标路径
   冲突，先停止并盘点；
3. 安装后核验 Feishu 的 Homebrew receipt、bundle、Team ID 与签名，再由维护者验证
   中国区账号、工作区、聊天、本地文件和同步；
4. live `~/Library` 数据和仓库外私有备份属于用户数据恢复范围，不由 Nix generation
   创建、覆盖或删除。

Nix build 只能证明声明可构建，不能证明 Lark/Feishu 可变数据逻辑完整。若任何目标路径
已存在，停止并先建立私有备份/比较，不覆盖。

### 2.3 安装 Nix 系统层

1. 按 [`bootstrap-macos.md`](bootstrap-macos.md) 安装 Lix，并只构建目标
   `darwinConfigurations.macbook.system`。
2. Agent 完成私有 preflight 备份和 build；维护者单独批准并执行精确 commit 的
   `darwin-rebuild switch`。
3. 若首次启用 Zed Cachix，使用编辑器 runbook 中记录的精确 URL 与公钥完成 bootstrap，
   不全局开启 `accept-flake-config`。

首次 activation 将同时恢复 Nix/Home Manager 应用、CLI、静态配置、Homebrew cask、
MAS 声明和 defaults。它不会自动恢复外部数据。

### 2.4 AI CLI 激活顺序与验收

Issue #67 的四个命令只属于 macbook 的 `ai-assisted-operations` capability：
`codex` 0.146.0、`claude` 2.1.220、`agy` 1.1.9、`omp` 17.2.4。它们由
Nix/Home Manager 提供唯一的声明式 PATH 来源；Oh My Pi 使用固定官方 `darwin-arm64`
发布物，`claude-code` 不再是 Homebrew cask。
构建通过不代表已安装或已激活，且 activation 不清理现场未知副本。

维护者在审阅精确 commit 后按以下顺序操作：

1. 先完成本节 2.3 的 Nix build，确认版本和 lock file；
2. 另行批准并执行 nix-darwin/Home Manager activation；
3. 运行一次 RTK 的官方 Codex init，恢复由 RTK CLI 拥有的 `~/.codex/RTK.md`；Nix
   管理的 `AGENTS.md` 已包含绝对路径引用，因此当前版本应只创建或更新 RTK 自己的产物：

```fish
rtk init -g --codex
```

4. 完全退出并重新打开 Fish，在不继承 Codex 进程 PATH 的干净会话中执行：

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
rtk --version
rtk init -g --codex --show
```

四个 `command -s` 必须命中 Home Manager profile，版本分别符合上述锁定值。#93 已
删除旧 Homebrew Claude、手工 `agy` 和停用 mise Node 25 树；恢复流程不应重新创建这些
兼容副本。`ChatGPT.app` 及其 embedded Codex helper 继续保留为应用私有组成。

RTK 本体必须同样命中 Home Manager profile；`--show` 必须把 global `RTK.md` 与
`AGENTS.md` reference 都报告为 `[ok]`。不要把 `RTK.md` 复制进仓库或链接到 Nix Store；
后续 RTK package 升级后仍由维护者重新运行 `rtk init -g --codex` 刷新上游模板。

凭据、登录态、token、session、history、skills/hooks、cache、数据库以及 `~/.omp` 和
项目 Oh My Pi 状态继续保持可写且不进入 Nix Store；路径边界详见
[`macOS AI CLI 所有权`](../inventory/macos-ai-cli-ownership.md)。
本节只适用于 macbook；nixbox/server 不安装这些客户端，也不改变其迁移与恢复流程。

### 2.5 恢复 macOS 中文输入能力

该能力声明 Home Manager 可安全拥有的 65 个 rime-ice 上游静态叶子和 1 个本地
`default.custom.yaml` overlay；overlay 只把 schema 列表收窄到 `rime_ice`。恢复 Fcitx5 应用时，
从 [Fcitx5 macOS 官方 installer](https://github.com/fcitx-contrib/fcitx5-macos-installer)
人工安装 `/Library/Input Methods/Fcitx5.app` 及其 Rime plugin；应用 bundle、plugin payload
和 macOS 输入源不由 Nix 安装或修改。installer 的精确语义版本若仍无法由 bundle metadata
证明，应如实记录未知，不用猜测值填补。不要安装、启用、清理或迁移遗留 Squirrel。

`~/.config/fcitx5` 和其中配置文件始终是 Fcitx-owned、可写的外部状态。能力不得 raw patch
INI、用 Store symlink 接管整文件或覆盖未知字段；行为 adapter 只通过 bundle 自带的
`fcitx5-curl` 官方本地配置 API 收敛 `ShareInputState=All`、空 `AppDefaultIM` 和
`StatusBar=Hidden`。其中隐藏状态栏表示只保留 macOS“小企鹅”输入源图标；左右 Shift
继续保留在 Fcitx `AltTriggerKeys`，Rime `InputState=All` 等 Keep 字段只读验证；MacVim
与其他未批准字段不得修改。

2026-08-11 已确认 Terminal `AppDefaultIM → keyboard-us` 与 `ShareInputState=All` 的组合会把
English 状态传播到其他应用。维护者批准窗口内已用官方 API 清空 live `AppDefaultIM`，
运行时探针由 `2 → 1 → 1` 变为 `2 → 2 → 2`；未 raw patch、restart、deploy 或 activation。
这只是已验证的 live mitigation，仓库中的长期声明在 activation 前仍未应用。对应 owner-only
应急副本只用于回退这次 live 操作，不是 Nix generation rollback。

当前 `macbook` 的首次静态所有权交接已经完成。Issue #127 记录的终态证据为：配置提交
`87d801c85bc3f6f1b5334a00aefccfbe3ecefe73` 已 activation，system generation 从 42 切换到
43；65/65 个静态叶子均为有效 Store symlink；9/9 个可变状态边界保持可写且不在 Store；
Fcitx5 仍为 selected input source；Rime 重新部署与真实输入验收均为 PASS。接管前 65 项
checksum 与 `RELEASED` 清单已验证，owner-only rollback evidence 继续保留在仓库外且不由
仓库读取、移动、重新打包或管理。Squirrel、userdb、sync 与 Fcitx5 外部状态未被该次
activation 接管或清理。

#131 已退役仅服务该次 regular-file 交接的写入型 helper。长期保留锁定到 rime-ice
2025.04.06 commit `a5f5404e369100fcfc5562f86f1205827453e31c` 的 source、65-leaf
declaration、完整 policy assertions 与公开只读 preflight：

```fish
nix run path:.#macbook-rime-preflight
```

🔍 核对 65 个 live 上游静态叶子、1 个本地 overlay 目标、锁定 source、Fcitx 行为语义与可变状态边界，不激活或重新部署输入法。

本地 overlay 经过 Home Manager 时可以解析到内容相同但 Store identity 不同的
`hm_default.custom.yaml`；preflight 必须按批准 hash/内容验证这个 regular Store leaf，而不是
要求它与原始 Flake source 是同一个 Store path。source 缺失、hash drift、内容 drift、
非 Store、broken link、路径逃逸或未知目标冲突仍必须失败关闭。它不得遍历、hash、打印或
复制 `luna_pinyin.userdb`、`rime_ice.userdb` 与 `sync` 的词条正文。

未来新机器若再次出现尚未托管的 65 个 regular leaves，不得寻找或复用历史 helper，也不得
直接覆盖。必须另开 Issue，根据当时 live facts 重新提供窄交接方案；维护者确认以下仓库外
数据保护后，才能针对 Draft PR 的 exact commit 单独批准交接和 activation：

- 既有 owner-only static rollback 包含校验和，并能恢复首次交接前的 65 个 regular files；
- `luna_pinyin.userdb`、`rime_ice.userdb`、`installation.yaml`、`user.yaml` 与
  `~/.config/fcitx5` 按 required 边界保护；
- `sync` 与 `~/Library/fcitx5` 按 separate-policy 另行处理；
- Rime `build` 与 `~/Library/Caches/org.fcitx.inputmethod.Fcitx5` 为 excluded 的可重建
  缓存，不作为恢复承诺；
- `~/Library/Rime` 与 Squirrel bundle、receipt、preferences、cache 及
  `squirrel.custom.yaml` 保持不变；allowlist 内的上游 `squirrel.yaml` 只用于保持锁定
  release 的 65-leaf 完整集合，不启用 Squirrel。

新 Issue 必须记录目标机器、exact commit、执行窗口、static-only preflight、上述数据保护证据
与 owner-only rollback 位置，再由维护者分别批准交接与 activation。任何新交接工具都只能
服务该次事实，并应在成功验收后退役；它不得被 activation 或 check 自动调用。

获批的 activation 应用 Nix/Home Manager declaration：链接 65 个上游 leaf 和 1 个本地
overlay，并通过官方本地配置 API 收敛三个批准字段。adapter 已满足目标时严格 no-op；
API/socket 缺失、响应歧义、Keep 字段漂移或回读验证失败时失败关闭。它不修改 macOS 输入源，
不 raw patch Fcitx 文件，不停止或重启 Fcitx5，也不触发 Rime deploy。发生真实外部字段修改时，
owner-only semantic journal 记录修改前语义，供官方 API 定向恢复。
journal 位于
`~/.local/state/nix-config/macos-chinese-input/fcitx5-behavior/last-change.json`；目录 mode 0700、
文件 mode 0600。它只记录 adapter 拥有字段的 before/after 语义，不包含用户输入内容。
加入 `StatusBar` ownership 后使用 v3 journal；它同时记录 transaction、逐项 applied 标记和
`prepared` / `committed` / `rolled-back` / `rollback-incomplete` 状态；未完成回滚可由固定 helper
在完整 CAS 预检通过后继续，不能手工猜值或覆盖 journal。
adapter 同时兼容既有 v2 journal：终态记录可以保留或在下一次 drift 时归档；v2 的 frontend
entry 只恢复当时拥有的 `AppDefaultIM`，并通过官方 partial API 保留当前 `StatusBar`；若 journal
还记录了已应用的 global entry，则同一事务也会恢复 `ShareInputState`。v2 `prepared` 不允许由
新版本猜测续跑，必须在任何 POST 前失败关闭，并进入绑定原实施 revision 的受监督恢复窗口。
若以后再次出现 drift，adapter 只会把先前的 `committed` / `rolled-back` 终态记录原子归档为
`last-change.<transaction>.<status>.json`，再建立新事务；未完成状态绝不会被覆盖。

仅在首次引入、恢复或实际变更 local overlay 时，维护者才在可观察、可回滚的窗口人工重新部署
Rime；Issue #134 的 StatusBar/preflight 增量不执行新的 deploy。需要 deploy 时，当前 bundle
已确认存在官方 `fcitx5-curl`，使用官方 Rime deploy 端点：

```fish
/Library/Input\ Methods/Fcitx5.app/Contents/bin/fcitx5-curl /config/addon/rime/deploy -X POST -d '{}'
```

⌨️ 通过 Fcitx5 官方本地 API 重新部署 Rime，使第 66 个本地 overlay 生效；执行前仍需当前窗口人工批准。

完成适用的 activation，以及仅在需要时完成 deploy 后，至少完成以下实机验收：

1. macOS selected input source 仍为 Fcitx5 简体输入模式，Fcitx profile 默认输入法仍为
   Rime，可选 schema 只有 `rime_ice`；
2. 在飞书日报、Terminal、一个 macOS 原生应用和一个浏览器输入框验证中文输入；切入
   Terminal 再返回时保持 Rime，不再出现 `2 → 1 → 1`；
3. 左右 Shift 都按现有 Fcitx `AltTriggerKeys` 切换，状态栏仍隐藏且菜单栏只显示“小企鹅”；
4. 新输入仍能更新 userdb，既有 userdb、sync、installation/user state 均保留；
5. Fcitx5 bundle/plugin、Squirrel、nixbox/server、launchd/service、network 与 firewall
   均未被该能力改变。

在维护者把当前 Issue 要求的 activation 与输入结果记录到 Issue/PR 前，文档只能称本次增量的
“声明目标已建立”；只有首次引入、恢复或变更 local overlay 的 Issue 才额外要求 deploy 记录。

### 2.6 验证声明式层

在全新登录 shell 中检查：

```fish
command -s fish
command -s git
command -s uv
command -s code
command -s zed
echo $EDITOR
echo $VISUAL
```

然后验证 Ghostty/WezTerm、VS Code/Zed、Nix GUI、Dock/Finder、键盘、Trackpad、右下角
Quick Note、菜单栏时钟和电池。应用设置与 Shell PATH 必须在真实终端会话验证，不能用
Codex 进程继承的 PATH 代替。

### 2.7 恢复外部软件

按所有权逐层恢复，避免同一路径出现两个写入者：

1. **Mac App Store：** 人工登录，确认 9 个 receipt；Xcode Stable 不恢复。
2. **Setapp：** 安装官方客户端、人工登录，恢复 inventory 中的 14 个应用。
3. **Swift 工具链：** 按项目需要安装 Xcode Beta、Command Line Tools、SDK/Simulator，
   再验证外部 XcodeGen；仓库不替你接受许可证。
4. **厂商/手工应用：** 只从 inventory 中的官方入口恢复，并核对 bundle ID/Team ID。
5. **外部 formula：** 只按当前需求恢复 XcodeGen 等明确 owner；不要恢复已由 Issue #60
   退役的全局 PostgreSQL 16。项目 Python 由 uv 按项目声明重建，不恢复 Homebrew Python
   兼容层。
6. **数据：** 最后按各应用自己的恢复流程恢复数据库、容器、vault、profile、账号和历史。

## 3. 所有权验收

恢复完成后至少确认：

- Nix 应用只来自 Home Manager Apps，不存在旧 VS Code、Zed Preview 或 #61 所列七个
  `/Applications` rollback bundle；
- Homebrew Bundle 恰好声明 1 个 tap、28 个 cask、9 个 MAS app、0 个 formula；不再声明
  `claude-code`，正常环境也不存在旧 `/opt/homebrew` Claude；
- 干净 Fish 中 `codex`、`claude`、`agy`、`omp` 的首个 PATH 来源均为 Home Manager
  profile，版本分别为 0.146.0、2.1.220、1.1.9、17.2.4；
- 通信应用声明为中国区 `feishu`，不再声明全球版 `lark`；
- 不存在旧 `Lark.app`、`LarkSuite.app`、`lark` receipt 或 #57/#61 的 Trash rollback
  目录；live 应用数据仍按外部数据验收；
- `homebrew.onActivation.cleanup = "none"`；
- `ChatGPT.app` 是 `com.openai.codex`，`ChatGPT Classic.app` 是 `com.openai.chat`；
- OrbStack 是唯一容器运行时，`docker ps` 在启动 OrbStack 后正常；
- Atuin 配置和 `.hushlogin` 来自 Nix Store，但 key/history 保持本机可写状态；
- macOS 中文输入管理锁定 rime-ice 2025.04.06 的 65 个上游静态叶子与 1 个本地 overlay；
  Fcitx5.app、plugin、输入源与可写配置文件仍由各自 owner 管理，行为字段仅经官方 API
  收敛，且已分别记录 live mitigation、人工 activation/redeploy 与输入验收；
- `~/.local/share/chezmoi` 不再 apply，旧 dotfiles 不再参与配置生成；
- OrbStack、编辑器、浏览器、Setapp 数据以及 AI CLI 的状态/凭据没有被 activation
  覆盖；数据库由各消费方自己的恢复流程处理。

## 4. 回滚顺序

### 4.1 Nix 与 defaults

优先使用上一代 system generation：

```fish
sudo darwin-rebuild --rollback switch
```

该命令恢复 Nix 声明，不撤销 Homebrew 已完成的 adoption/MAS 安装，也不回滚数据或 AI
CLI 的状态。macOS defaults 的逐键试用前值和定向回滚命令见
[`phase-4-macos-defaults.md`](../inventory/phase-4-macos-defaults.md)。

### 4.2 macOS 中文输入

中文输入异常时，Nix-owned 静态文件、Fcitx 外部字段与用户数据是三个不同边界，按以下顺序
停止并回滚：

1. 选择 activation 前记录的 nix-darwin generation；
2. 上一代恢复 Nix-owned 的 65 个上游 leaf，并撤回或恢复对应 generation 的本地 overlay；
3. generation rollback 不会逆转 Fcitx 外部字段。若本次 activation 的 semantic journal 记录了
   真实修改，先验证当前值未并发漂移，再通过官方 API 定向恢复；2026-08-11 的 owner-only
   live 应急副本只可回退对应事故缓解，不可作为通用回滚来源；

   在 Issue/PR 对 exact commit 与当前回滚窗口单独批准后，运行固定目标 helper：

   ```fish
   nix run .#macbook-fcitx5-behavior-rollback -- --confirm-approved-behavior-rollback
   ```

   ↩️ 校验 committed semantic journal 与当前字段后，经官方 API 逆序恢复该事务中 `applied=true` 的 owned change；遇到第三方并发漂移时失败关闭。

4. 保留 `luna_pinyin.userdb`、`rime_ice.userdb`、`sync`、`installation.yaml`、
   `user.yaml` 与 Fcitx 可变状态；只有出现数据损坏证据时才按对应备份策略恢复，禁止为
   回滚清空 Rime 用户目录或无条件覆盖当前 userdb；
5. 仅当该回滚实际改变静态 overlay 或 compiled Rime 配置时，由维护者人工重新部署 Rime；
   Issue #134 的行为/preflight 回滚不 deploy。只有另有证据和当前批准时才重启 Fcitx5；随后重新完成
   飞书、Terminal、原生应用与浏览器的输入、左右 Shift、候选、userdb 可写性和既有状态验收，
   并在 Issue/PR 记录结果。

首次静态交接与静态回滚的写入型 helper 已退役，因此第 2 步没有仓库内写入型短入口。若上一代
已移除 Home Manager 静态链接，必须依据 owner-only evidence 的 checksum/`RELEASED` 清单或
锁定 source，使用独立 Issue 审阅并批准的窄流程恢复恰好 65 个 regular leaves；随后重新运行
只读 preflight。该流程不得恢复 userdb、sync，也不自动重新部署 Rime。

切回 generation 只能恢复 Nix declaration 和 Nix-owned 静态 leaf，不能恢复用户学习数据、
sync、installation/user state、Fcitx 配置/plugin 状态或 Squirrel 遗留状态。Fcitx 外部字段
只能根据 semantic journal 经官方 API 定向恢复。任何回滚、重启或重新部署仍需当前 Issue/PR
中针对 exact commit 与执行窗口的人工批准。

### 4.3 Homebrew 与 MAS

1. 先从声明中撤回问题项并构建验证；
2. 只有获得新的精确批准后，才定向卸载单个 cask/formula；
3. 默认设置 `HOMEBREW_NO_AUTOREMOVE=1`，防止 Homebrew 隐式回收范围外依赖；
4. 不使用 cleanup/zap；MAS 应用由 App Store receipt 与人工安装恢复。

### 4.4 Setapp、厂商应用与数据

Setapp/厂商应用通过其官方渠道重新安装。若 package 回滚后仍异常，分别恢复应用数据，
不要删除整个 `Application Support`、容器或数据库目录来“验证干净安装”。OrbStack 与
各消费方数据库需要各自的数据 runbook；没有恢复验证时不得执行破坏性迁移。

## 5. 后续变更流程

任何新增、删除或换源都先更新软件所有权 inventory，再建立窄 Issue/PR。Agent 可以完成
只读盘点、私有备份、构建和回滚清单；真实 activation 只由维护者执行。只有真实机器
验证与合并证据完成后，才更新本文的终态。
