# Raycast 声明式配置研究

- **日期：** 2026-08-03
- **目标机器：** `macbook`
- **范围：** Raycast 应用、稳定偏好、Script Commands、Store Extensions、本地扩展、
  Snippets、Quicklinks、快捷键与可变状态边界
- **性质：** 研究与未来参考；当前配置已被维护者确认为稳定基线，暂不创建实现或维护
  Issue。本文不授权修改配置、导入数据、安装/卸载应用、activation、TCC 变更或清理
  Raycast 状态

## 1. 结论

维护者在 2026-08-03 确认：

- Raycast Settings 的 **Show only customized** 视图可以直接作为其中“所有已修改内容”的权威
  边界，包括其中显示的 command、alias 和 hotkey；不需要用完整 `.rayconfig` 再确认范围；
- `Toggle DB Tunnel` 及其 `autossh` 依赖已经废弃，不迁移、不补依赖、不进入 capability；
- 当前 Raycast 配置相对稳定，以下架构与 Issue 拆分只保留为未来触发条件，不立即实施。

Raycast 可以成为本仓库的一项纵向 capability，但不能把整个 Raycast 运行目录当作普通
dotfiles 接管。推荐目标是：

1. 由 Nix 声明应用所有权、Script Commands、扩展源码版本、可复现构建、稳定快捷键参考和
   可审阅的 Snippets/Quicklinks 基线；
2. 通过 Raycast 官方入口完成人工导入或首次注册，不直接修改加密数据库；
3. 让账号、Keychain、第三方 token、Cloud Sync、AI/Clipboard/Notes、扩展运行数据和使用
   历史继续由 Raycast 管理；
4. 使用加密 `.rayconfig` 作为仓库外恢复材料，而不是把它或解密后的全量内容提交到 Git。

这不是“少声明”，而是区分可构建的稳定声明与应用拥有的可变状态。Raycast 官方把本地数据
放在加密数据库中，Home Manager 上游截至本次调研仍没有 `programs.raycast` 模块；社区的
对应功能请求也因缺少公开配置 API/CLI 和稳定存储格式而关闭。
[Home Manager #5288](https://github.com/nix-community/home-manager/issues/5288)

## 2. 当前机器与仓库事实

### 2.1 应用版本与安装所有权

本次只读探针得到：

| 事实 | 当前值 | 含义 |
| --- | --- | --- |
| `/Applications/Raycast.app` | `1.104.24` | 实际 bundle 比 Homebrew receipt 新 |
| Homebrew receipt | `1.104.23` | 当前声明所有者仍是 Homebrew cask |
| 当前 flake 中 `pkgs.raycast.version` | `1.104.17` | 若立即迁移到当前 Nix package，会发生版本回退 |
| Bundle ID | `com.raycast.macos` | 当前稳定版身份 |

Homebrew cask 明确标记 `auto_updates true`，当前上游 cask 已是 `1.104.24`；结合 receipt
差异，当前状态符合 Raycast 自身 updater 在 Homebrew 安装后推进 bundle 的行为。
[Homebrew Raycast cask](https://github.com/Homebrew/homebrew-cask/blob/ad71d2be2690b04dc743821ecd31afcd1acbef1e/Casks/r/raycast.rb)

Nixpkgs 已提供 `raycast` 和 `raycast-beta`，但稳定包当前是 `1.104.17`、只支持
`aarch64-darwin`、属于 unfree 二进制包；它把签名 app bundle 复制进 Nix Store。
[Nixpkgs `raycast`](https://github.com/NixOS/nixpkgs/blob/50ff86c99b133f56731800c3f2596a14dda72094/pkgs/by-name/ra/raycast/package.nix)
[Nixpkgs `raycast-beta`](https://github.com/NixOS/nixpkgs/blob/50ff86c99b133f56731800c3f2596a14dda72094/pkgs/by-name/ra/raycast-beta/package.nix)

Raycast 官方要求应用自动保持更新；Nix Store 则要求 bundle 不被应用原地修改。因此迁移到
Nix 意味着把版本推进责任从 Raycast updater 移交给 `flake.lock`/Nixpkgs 更新流程，而不是
单纯替换安装命令。
[Raycast security and update model](https://developers.raycast.com/information/security)

### 2.2 当前配置

只读取键名和少数非敏感稳定值后确认：

- 全局启动键是 `⌘Space`；
- 主窗口使用 compact 模式并跟随系统外观；
- 当前仓库没有声明 Raycast 启动键，也没有声明与之对应的 Spotlight 快捷键让位；
- `~/Library/Preferences/com.raycast.macos.plist` 同时包含稳定偏好、版本迁移标记、窗口状态、
  permission 选择、活动时间、内部 ID 和二进制 data 值，不能整体声明；
- `~/.config/raycast/config.json` 存在 token 类字段。本次没有读取值，该文件不得进入 Git
  或 Nix Store；
- 主要数据位于 `~/Library/Application Support/com.raycast.macos/` 的加密 SQLite 数据库，
  另有 extension cache、Node runtime、活动与历史数据。

### 2.3 `/Users/sayori/Desktop/raycast`

该目录是独立、公开且当前 clean 的 Git 仓库：
[sayoriqwq/raycast](https://github.com/sayoriqwq/raycast)

当前可声明资产为：

- 9 个已登记的 Raycast Script Commands：8 个 Chrome tab switch 命令，以及 1 个维护者已
  标记废弃的 database tunnel toggle；未来声明范围只考虑前 8 个；
- 2 个本地 Extension：
  - `terminal-finder`：4 个 Finder / WezTerm / Ghostty 命令；
  - `open-in-editor`：3 个 VS Code / Zed Nightly / Codex 命令；
- 两个 extension 都固定 `@raycast/api = 1.104.23`，具有 pnpm lock 和已提交的构建产物。

当前 Raycast 运行目录有 9 个 extension bundle。这里已经观察到声明漂移：

- 运行态 `open-in-editor` 仍有 7 个命令，源码当前只有 3 个；
- 运行态还有 `counter`，但上述源码仓库里没有对应 source；
- `terminal-finder` 源码硬编码 `/Applications/Ghostty.app`，真实 Nix 安装路径是
  `~/Applications/Home Manager Apps/Ghostty.app`；bundle ID 路径与 fallback 仍可能工作，
  但硬编码路径本身不再是可靠合同；
- `toggle-db-tunnel.sh` 依赖 `autossh`，当前 Fish PATH 和 nix-config 都没有声明该依赖；
- 同一脚本在公开仓库中硬编码了 production 数据库端点。本文不复述该值。维护者已经将
  脚本与依赖标记为废弃，因此后续不得为它补包、迁移 secret 或恢复网络行为；现有文件只
  能在独立、明确批准的清理范围内删除。

## 3. 上游能力边界

### 3.1 Nix / Home Manager / nix-darwin

- Nixpkgs 可以安装 Raycast stable/beta，但不会管理 Raycast 的应用内配置。
- Home Manager 当前选项索引和源码没有 `programs.raycast`；上游讨论确认主要障碍是加密
  database、UUID extension registry 和缺少公开配置 CLI。
  [Home Manager options](https://nix-community.github.io/home-manager/options.html)
  [Home Manager #5288](https://github.com/nix-community/home-manager/issues/5288)
- nix-darwin 没有 Raycast 专用 module，但可以通过 `homebrew.casks` 声明 app，并通过
  `system.defaults.CustomUserPreferences` 写入可表达的 plist 值。后者只是通用 macOS
  defaults 能力，不表示 Raycast 承诺这些私有 key 稳定。
  [nix-darwin options](https://nix-darwin.github.io/nix-darwin/manual/)
- Home Manager 的 `programs.vicinae` 能从 Raycast extension source 构建 Vicinae extension；
  其输出路径和注册目标是 Linux 上的 Vicinae，不是 macOS Raycast，不能把它当作 Raycast
  module 使用。
  [Vicinae module](https://github.com/nix-community/home-manager/blob/bf9ce9fec78f95f374e8dd3b503863a3ec128ebe/modules/programs/vicinae/default.nix)

社区 dotfiles 主要出现三种自定义方案：生成 Script Commands、定向写少量
`com.raycast.macos` defaults、逆向 `.rayconfig` 加密/内部 schema。前两种可在严格边界内
参考；第三种没有 Raycast 官方格式承诺，不适合作为本仓库的长期核心。
[community Script Commands module](https://github.com/loganlinn/dotfiles/blob/eab9868a34777b1cac5e4ff1161fe9371d506db0/nix/home/raycast.nix)
[community Focus defaults module](https://github.com/indexable-inc/index/blob/931b7fe0d3f2d6bf80b0cee6436c686d63b29e53/modules/home/raycast.nix)
[community `.rayconfig` module](https://github.com/frostplexx/nixkit/blob/7da5788c1e7c843533e94577ef724f2e956571d6/modules/home/raycast/default.nix)

### 3.2 Raycast 官方支持面

Raycast 官方提供以下稳定入口：

- Script Command directory：Raycast 会索引目录内带 metadata 的脚本，源文件适合 Git/Nix
  管理；首次仍需在 Settings 中 Add Script Directory。
  [Script Commands](https://manual.raycast.com/script-commands)
- Extension CLI：`ray build`、`ray develop`、`ray lint`、`ray migrate`、`ray publish`。
  `ray develop` 会把未导入的本地 extension 加入 Raycast，但它是开发会话，不是通用的
  声明式 install/sync CLI。
  [Raycast CLI](https://developers.raycast.com/information/developer-tools/cli)
- Store extension：Store 安装的 extension 会自动更新；本地 Import Extension 不会从 Store
  自动更新。
  [Extensions](https://manual.raycast.com/extensions)
- Snippets 和 Quicklinks：可以分别导入/导出 JSON；适合作为可审阅 seed。
  [Snippets](https://manual.raycast.com/snippets/how-to-import-snippets)
  [Quicklinks](https://manual.raycast.com/quicklinks/how-to-import-quicklinks)
- 全量 `.rayconfig`：当前导出包含 11 类数据，包括 AI chats、Clipboard、Notes、MCP、Store
  extension 列表、设置/alias/hotkey 和 window layouts。文件必须使用 passphrase 加密；导入
  是选择性、additive merge，重复项会跳过，现有内容不会被完整 reconcile。
  [Import & Export](https://manual.raycast.com/import-export)

因此，官方入口适合“构建 + seed + 恢复”，不提供与 VS Code settings/extensions 相同的
持续强制声明语义。

## 4. 声明能力矩阵

| 配置面 | 可声明程度 | 推荐所有者 | 备注 |
| --- | --- | --- | --- |
| Raycast app | 完整 | Homebrew 或 Nix 二选一 | 当前保持现状；未来若迁移，另开 Issue 决定版本所有权 |
| 全局 hotkey / compact / appearance | 部分 | nix-darwin adapter | 私有 plist key；只声明实机逐项验证过的稳定子集 |
| Spotlight 让位 | 完整但有系统副作用 | Raycast Darwin adapter | 必须记录旧值、冲突与回滚 |
| Script Commands | 高 | Home Manager | Nix 管理目录和 runtime wrapper；首次目录注册人工完成 |
| 自研 extension source/build | 高 | 独立 raycast repo + Nix build/check | 用 flake input 固定 commit，不复制源码 |
| 自研 extension 首次安装/更新 | 部分 | Raycast 官方 dev/import 流程 | 不直接伪造 UUID registry 或修改数据库 |
| Store extension 清单 | 盘点/恢复 | Raycast Store / `.rayconfig` | 无官方批量 install CLI，Store 自己更新 |
| Snippets / Quicklinks | seed | Git + Raycast importer | JSON 可审阅；import 是 additive，不负责删除/覆盖 |
| alias / command hotkey | 参考 + 恢复 | `sayori.shortcuts` + `.rayconfig` | 详细运行态仍由 Raycast database 持有 |
| extension preferences | 部分 | reviewed baseline + Raycast | password/token 只进 Keychain，不进 Nix Store |
| account / OAuth / API keys | 不声明 | Raycast / Keychain | secret |
| AI chats / Clipboard / Notes / usage | 不声明 | Raycast mutable state | 只通过加密 export/Cloud Sync 备份 |
| TCC / Accessibility / Automation | 不自动声明 | macOS + 人工关卡 | 首次使用时按 app 身份授权并人工验证 |

## 5. 推荐 capability 结构

Raycast 同时涉及 Homebrew app、macOS shortcut/defaults、用户脚本、扩展构建和可变状态，
已经证明存在跨层 seam，适合建立：

```text
modules/capabilities/raycast/
├── darwin.nix       # app owner、经批准的 macOS/Raycast defaults、HM attachment
└── home.nix         # Script Commands、构建/导入 helper、statePaths、shortcuts
```

Host 只 import `modules/capabilities/raycast/darwin.nix` 一次，不再从
`macos-legacy-applications` 单独选择 `raycast`。

建议的能力合同：

- **package ownership：** v1 先保留 Homebrew cask；`autoUpdate = false` / `upgrade = false` /
  `cleanup = "none"` 的仓库全局 activation 策略保持不变，但承认 Raycast app 自身 updater
  会推进 bundle；
- **managed configuration：** 经审阅的 Script Commands、少量稳定 plist key、快捷键参考、
  Snippets/Quicklinks import files、固定 revision 的 extension source/build；
- **mutable state：** 声明但不接管 `~/.config/raycast`、Application Support、preferences plist
  和相关 extension state；Keychain 不作为文件路径声明；
- **network effects：** 普通 navigation 命令只操作本机应用；已废弃的 database tunnel
  command 明确排除在目标 capability 外，不安装 `autossh`，也不在 activation 中执行；
- **human gates：** Raycast 完全退出后才写私有 defaults；Script Directory、local extension、
  JSON/`.rayconfig` import、TCC 和 app package migration 均需人工确认；
- **rollback：** Nix generation 只撤销声明。Raycast import 是 additive，不能假设 generation
  rollback 会删除已导入项目；应用迁移还需单独恢复原安装渠道。

## 6. 未来实施顺序（当前暂停）

维护者当前不要求实施或维护 Raycast capability。只有出现新机器恢复、当前配置明显漂移、
Raycast 上游提供稳定配置接口，或维护者重新提出声明需求时，才从以下窄 Issue 中选择一项
启动；不得把它们自动转为当前 backlog。

### Issue A — Raycast capability contract 与安全基线

- 从 `macos-legacy-applications` 拆出 Raycast cask；
- 建立跨层 capability 和 `sayori.statePaths`；
- 声明已验证的 `⌘Space` / compact / system appearance 子集，并处理 Spotlight shortcut
  ownership；
- 记录 TCC、登录项、Raycast v1/v2 和回滚边界；
- 不导入数据、不修改 extension、不迁移到 Nix package。

### Issue B — Script Commands 与 runtime dependency

- 以 `github:sayoriqwq/raycast` 的固定 revision 作为非 flake input；
- 把 8 个 navigation command 及其 helper/config 生成到稳定用户目录；
- 给脚本使用绝对系统工具路径或 Nix wrapper，避免依赖 GUI app 的不确定 PATH；
- 永久排除已废弃的 database tunnel 和 `autossh`，不为其设计 secret/网络合同；
- Raycast 中 Add Script Directory 保持一次性人工动作。

### Issue C — 两个自研 extension 的可复现构建与导入

- 用 pnpm lock 在 Nix build/check 中验证 command entry JS 和 assets；
- 修复 Ghostty 的 `/Applications` 假设；
- 对比 source manifest 与当前 installed bundle，明确删除 4 个旧 `open-in-editor` commands；
- 盘点 `counter` 的 source/去留；
- 只提供短的 maintainer-run build/import helper，不让 Home Manager activation 直接修改
  Raycast database；
- 评估公开 Store 或组织 private Store 是否比永久 local development 安装更合适。

### Issue D — 可审阅数据基线与 backflow

- 先从 Raycast 官方命令分别导出 Snippets 和 Quicklinks JSON；
- 人工删除 private URL、token、个人内容和 host-specific 路径后再决定哪些进入 Git；
- 生成 import artifact 和手工验收步骤，不重复自动 import；
- 将稳定 alias/hotkey 转写到 `sayori.shortcuts`，全量 `.rayconfig` 只保存在仓库外；
- 建立“export → diff/redact → review → update declaration”的人工配置回流流程。

### 独立决策 — Homebrew 还是 Nix package

在 Raycast v2 稳定、Nixpkgs freshness 和本机 extension compatibility 有证据后，再选择：

1. **继续 Homebrew：** 保留官方 auto-updater 与 `/Applications` 路径，接受版本不由
   `flake.lock` 固定；
2. **迁移到 `pkgs.raycast`：** 版本完全由 Nix 更新，增加 unfree allowlist，并验证登录项、
   LaunchServices、TCC、浏览器扩展、本地 extension 和 updater 行为；
3. **本仓库维护 overlay：** 能追平官方版本，但把频繁版本/hash 维护责任永久带入仓库，
   除非 Nixpkgs 延迟已实际影响使用，否则不优先。

当前推荐选项是 1；现有 app/API/receipt 版本证据不支持立即迁移到当前较旧的 Nix package。

## 7. 验证与人工关卡

若未来重新启动实现，每个 Issue 至少需要：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link
```

extension Issue 还需对每个 manifest 验证：

- `commands[].name` 均有对应构建后的 `<name>.js`；
- source manifest 与安装 bundle 不存在未解释的旧 command；
- Ghostty、WezTerm、Zed Nightly、VS Code、Codex 均按 bundle ID/实际 Nix app path 解析；
- Raycast 启动进程的非 login PATH 下，所有 script runtime dependency 均可解析；
- 不读取或输出 token、OAuth、Keychain、数据库内容和 export passphrase。

所有真实 `darwin-rebuild switch`、Raycast import、TCC 授权、Store publish、extension prune
和 Homebrew/Nix package 移交都必须作为独立人工关卡记录。已废弃的 production tunnel 不在
验证范围内，不得为了验证而恢复。构建成功不构成执行授权。

## 8. 已记录的维护者决策

1. 当前配置是稳定基线，暂不实施 Issue A–D，也不创建 Raycast 维护 backlog；
2. Show only customized 是自定义内容的权威盘点视图；
3. `Toggle DB Tunnel` 与 `autossh` 已废弃，未来声明、构建和恢复流程均排除；
4. `counter`、本地 extension 分发方式、Snippets/Quicklinks 回流和 app package owner 等问题
   暂不决策；只有出现实际需求时才重新打开对应窄 Issue；
5. 现有运行态不因本研究自动清理、重建或迁移。
