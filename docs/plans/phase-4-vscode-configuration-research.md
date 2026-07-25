# Phase 4：VS Code 声明式配置模型调研

## 1. 调研问题与范围

本调研比较以下两种终态，目标环境是：

- 当前的 `aarch64-darwin` macOS 工作站；
- 后续接入的 `x86_64-linux` NixOS 工作站；
- 一个 Flake 固定依赖，Home Manager 提供两台桌面工作站共享的用户层；
- macOS 与 NixOS 可以拥有不同的扩展和平台设置。

候选方案：

- **方案 A：严格声明式。** Home Manager/Nix 管理只读的 VS Code User Settings，并声明扩展集合。
- **方案 B：基线加漂移。** Nix 管理应用、设置基线和扩展基线，live settings 与扩展目录保持可写；工具检测漂移，再由人决定是否提升回 shared、Darwin 或 Linux 声明。

调研基于本仓库当前锁定的 Home Manager
`4ce190229c73d44536caa7072f6308fb2d8feeb3` 和 nixpkgs
`fd1462031fdee08f65fd0b4c6b64e22239a77870`，以及 VS Code 官方文档和相关上游
Issue/PR。本文是决策证据，不代表已经修改 Issue #24、PR #32 或真实机器状态。

## 2. 结论摘要

**真实使用场景下，建议采用经过收窄的方案 B，但不要把它描述成“自动双向同步”。**

更准确的模型是：

> Nix 管理应用版本、共享/平台基线和经过批准的扩展；VS Code 保留可写运行态；工具只负责语义化检测和生成候选变更，人负责决定 shared、Darwin、Linux 或 local 的归属。

主要理由：

1. VS Code 官方把 User Settings 设计为可由 Settings UI 和扩展持久化更新的
   `settings.json`。扩展 API 明确允许扩展把配置写到 Global/User、Workspace 或
   Workspace Folder 层；严格只读会阻断选择 Global/User 的正常操作
   ([VS Code Settings](https://code.visualstudio.com/docs/configure/settings#_settings-json-file)，
   [WorkspaceConfiguration.update API](https://code.visualstudio.com/api/references/vscode-api#WorkspaceConfiguration))。
2. Home Manager 的 VS Code 模块当前会把声明的 `userSettings` 作为
   `home.file` 链接到 User `settings.json`，没有 writable/baseline/merge 选项；
   “可写 settings 并自动合并”仍是开放的功能请求
   [home-manager#7617](https://github.com/nix-community/home-manager/issues/7617)。
3. 扩展方面不必在“全只读”和“全不管”之间二选一。锁定版 Home Manager 已有
   `mutableExtensionsDir`：只使用 default profile 时默认允许声明式扩展与 UI
   安装扩展共存；这正是方案 B 的上游现成部分
   ([锁定版模块源码](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/programs/vscode/mkVscodeModule.nix)，
   [引入 immutable/mutable 选择的 PR](https://github.com/nix-community/home-manager/pull/2613))。
4. 没有发现 VS Code、Home Manager、nixpkgs 或 nix-community
   提供安全的双向 reconciler。现有能力是单向声明、扩展清单查询、Profile
   导入导出或云同步；它们都不能判断一项漂移应该属于 shared、Darwin、Linux
   还是 local，更不能安全判断其中是否含机密。

因此，方案 B 的优势成立，但只在以下条件下成立：

- activation 非交互、不会自行修改 Git 工作树；
- Nix 拥有的 key 始终以声明值为准；
- live 中额外的 key 只作为候选漂移，不自动提交；
- 扩展的“声明基线”与“实际生效版本”分开报告；
- 另开窄范围 Issue 实现并测试 drift/capture 工具，不把未经验证的
  reconciler 顺带塞进 Issue #24。

## 3. VS Code 自身的配置与状态模型

### 3.1 User Settings 是一个可写配置层

VS Code 在 macOS 使用
`~/Library/Application Support/Code/User/settings.json`，在 Linux 使用
`~/.config/Code/User/settings.json`。Settings UI 和直接编辑 JSON 最终都修改这个文件；
Workspace Settings 则位于项目的 `.vscode/settings.json`，并覆盖 User Settings
([官方路径和优先级](https://code.visualstudio.com/docs/configure/settings#_settings-file-locations))。

扩展不仅能“贡献设置定义”，也能调用
`WorkspaceConfiguration.update(section, value, target)` 持久化更新配置。目标可以是
Global/User、Workspace 或 Workspace Folder；如果扩展明确选择 Global，不能由
Home Manager 在文件内部按 key 授予它单独写权限
([官方 API](https://code.visualstudio.com/api/references/vscode-api#WorkspaceConfiguration))。

这说明严格只读并非只影响用户手工打开 `settings.json`。它也可能影响：

- Settings UI 中修改 User 范围设置；
- 把交互式 UI 状态实现为 User setting 的 VS Code 命令；
- 通过配置 API 写 Global target 的扩展 onboarding 或功能开关。

Home Manager 的一手使用反馈已经记录过这类摩擦：缩放、列选择模式和 diff
显示切换等操作曾因只读 `settings.json` 不能持久化而失败；讨论中用户反复采用
activation 后复制为可写文件的自定义 workaround
([home-manager#1800](https://github.com/nix-community/home-manager/issues/1800))。
这是实际兼容性成本，而不仅是偏好差异。

### 3.2 并非所有扩展状态都应进入 settings

VS Code 为扩展另外提供：

- `globalState` / `globalStorageUri`：与当前 workspace 无关的扩展状态；
- `workspaceState` / `storageUri`：当前 workspace 的扩展状态；
- `SecretStorage`：独立的秘密存储。

官方明确建议不属于 `settings.json` 或项目配置的状态使用这些存储 API
([ExtensionContext API](https://code.visualstudio.com/api/references/vscode-api#ExtensionContext)，
[Remote Development 的持久化建议](https://code.visualstudio.com/api/advanced-topics/remote-extensions#_persisting-extension-data-or-state))。

因此，方案 B 不应把 `globalStorage`、`workspaceStorage`、SecretStorage、History
或登录态纳入 drift 工具；这些是可变应用状态。反过来，也不能假设所有扩展都正确遵守
这个边界，因为 Global Settings 写入是官方支持的 API。

### 3.3 Settings Sync 不是 Nix reconciler

Settings Sync 可以同步 Settings、Keyboard Shortcuts、Snippets、Tasks、UI State、
Extensions 和 Profiles；扩展清单还包含全局启用状态。它在冲突时提供 Accept Local、
Accept Remote 或手工 merge，但事实来源仍是本机和云端，不理解 Nix 声明
([官方 Settings Sync 文档](https://code.visualstudio.com/docs/configure/settings-sync))。

如果采用 Git/Nix 基线，继续让 Settings Sync 写相同的 Settings/Extensions 会引入第三个
写入者。关闭 Settings Sync、初期保留云端旧数据作为短期回退，符合“单一声明来源 +
本机明确漂移”的目标；Settings Sync 的本地备份只保留 30 天、远端每类只保留最近
20 个版本，也不应被当作长期配置历史
([官方备份范围](https://code.visualstudio.com/docs/configure/settings-sync#_restoring-data))。

## 4. Home Manager 与 nixpkgs 的实际能力

### 4.1 Settings：当前只有单向声明

锁定版 Home Manager 接受 Nix attrset 或自定义 JSON 文件路径作为
`profiles.<name>.userSettings`，然后通过 `home.file` 生成/链接对应 profile 的
`settings.json`。模块特意不链接整个 User 目录，并明确保留
`globalStorage/storage.json` 可写，因为其中包含主题背景、最近目录等其他状态
([锁定版 VS Code 模块源码](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/programs/vscode/mkVscodeModule.nix))。

`home.file` 的默认语义是链接到 Home Manager generation。激活前的
`checkLinkTargets`：

- 遇到内容完全相同的现有普通文件时允许继续；
- 遇到内容不同且不是 Home Manager 所有的目标时默认中止；
- 只有配置 backup 或 `force = true` 才会移动/覆盖。

相关行为直接见
[files.nix](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/files.nix)
和
[check-link-targets.sh](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/files/check-link-targets.sh)。
所以如果 VS Code 或扩展把链接替换成内容不同的普通文件，下次 activation
会暴露冲突，而不会自然完成反向同步。

Home Manager 上游目前只有 Zed 模块实现了“live 可写、activation 时以静态值覆盖同名
key”的单向 merge。VS Code 请求同等能力的
[home-manager#7617](https://github.com/nix-community/home-manager/issues/7617)
仍为开放状态。这证明该模型可以实现，但也证明它目前不是 VS Code 模块的受支持接口；
更重要的是，这种 merge 仍不会把 live 差异分类并写回 Nix。

### 4.2 Extensions：已有受支持的混合模式

锁定版 Home Manager 的 `mutableExtensionsDir` 在只有 default profile 时默认为
`true`。它把 Nix 声明的扩展逐个链接到 `~/.vscode/extensions`，而不是把整个目录链接成
只读 Store 目录；VS Code 仍可在旁边安装扩展。声明扩展集合变化时，模块删除缓存的
`extensions.json` 并调用 `code --list-extensions` 让 VS Code 重新生成注册表
([锁定版实现](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/programs/vscode/mkVscodeModule.nix))。

这个模式有两个重要边界：

1. 使用非 default 的声明式 Profiles 时，Home Manager 要求扩展目录不可变；named
   profiles 与 mutable extension directory 不能组合使用。
2. mutable 模式只保证“声明扩展存在”，不保证 Nix 声明的版本是唯一或实际生效版本。
   VS Code 默认会自动更新已启用扩展，也允许 UI/CLI 安装指定版本或更新扩展
   ([官方扩展更新行为](https://code.visualstudio.com/docs/configure/extensions/extension-marketplace#_update-an-extension-automatically)，
   [官方 CLI](https://code.visualstudio.com/docs/configure/command-line#_working-with-extensions))。

因此：

- **严格版本所有权**需要 immutable extension directory，并关闭 VS Code 的扩展更新路径；
- **混合扩展目录**可以把 `code --list-extensions --show-versions` 作为运行态 inventory，
  但不能声称实际扩展版本完全由 `flake.lock` 决定。

早期 Home Manager PR 对这一区别的表述很直接：immutable 模式用于阻止 imperative
安装/更新；非 immutable 模式保留手工安装扩展
([home-manager#2613](https://github.com/nix-community/home-manager/pull/2613))。
另有 nixpkgs Issue 记录了把整个 `--extensions-dir` 指向只读 Store 后，Marketplace
更新试图在该目录创建文件而报 `EROFS`
([nixpkgs#270423](https://github.com/NixOS/nixpkgs/issues/270423))。

### 4.3 应用与跨平台扩展

锁定版 `pkgs.vscode` 从微软官方更新端点分别取得 Darwin/Linux 对应产物，并声明支持
`aarch64-darwin`、`x86_64-darwin`、`aarch64-linux`、`x86_64-linux` 等平台；同一个
Nix 声明可以在 macOS 与 NixOS 选择各自平台产物
([锁定版 nixpkgs `vscode.nix`](https://github.com/NixOS/nixpkgs/blob/fd1462031fdee08f65fd0b4c6b64e22239a77870/pkgs/applications/editors/vscode/vscode.nix))。

扩展本身不一定跨平台。VS Code Marketplace 支持 universal 以及
`darwin-arm64`、`linux-x64` 等平台专属 VSIX；扩展 manifest 的 `extensionKind`
还会决定扩展运行在本地 UI 端还是 workspace/remote 端
([平台专属扩展](https://code.visualstudio.com/api/working-with-extensions/publishing-extension#_platformspecific-extensions)，
[Extension Host](https://code.visualstudio.com/api/advanced-topics/extension-host))。

所以 Mac 与 NixOS 使用不同扩展集合是正常需求，但不要求放弃声明式结构。Home Manager
列表可以由模块组合自然形成：

```text
shared extensions
  + Darwin extensions  -> macbook

shared extensions
  + Linux extensions   -> nixbox
```

对于 nixpkgs 未收录或更新不及时的扩展，`nix-community/nix-vscode-extensions`
每日生成 Marketplace/Open VSX 中多数扩展的 Nix 表达式，并区分 universal 与
platform-specific 版本；但项目自己说明它无法可靠判断缓存中“语义上最新”的版本，
也不会自动展开 extension packs
([项目 README](https://github.com/nix-community/nix-vscode-extensions#readme))。
引入它会增加新的 flake input 和扩展供应链边界，应在扩展 Issue 中单独决定，而不是假设
它能无损覆盖当前全部扩展。

## 5. 两种方案的真实使用比较

| 场景 | 方案 A：只读 settings + 声明式扩展 | 方案 B：可写 live + Nix 基线 |
| --- | --- | --- |
| 新机器恢复 | 已声明部分完整、确定；strict extensions 可固定实际版本 | 只恢复基线；未提升的 live 漂移不会出现 |
| 回滚 | generation 能恢复 settings 与 strict extension set | 应用和基线可回滚；live 漂移必须另行处理 |
| Settings UI | User 范围写入失败；Workspace 范围可写 | 正常使用 |
| 扩展写 Global Settings | 可能失败并破坏 onboarding/功能开关 | 正常写入，随后由 drift 检测暴露 |
| UI 安装扩展 | immutable 模式阻止；mutable 模式可形成折中 | 正常安装；是否提升由人决定 |
| macOS/Linux 差异 | shared + platform 模块可以清晰表达 | 同样可以清晰表达，额外允许各机 local 项 |
| 版本所有权 | immutable 时最强 | 基线版本可锁定，实际版本可能由 UI 更新覆盖 |
| 日常试验成本 | 高；持久变更要改仓库、build、activation | 低；先在 UI 试验，再选择是否提升 |
| 隐藏状态风险 | 较低，失败显式 | 较高，依赖定期 status/diff |
| 实现与维护成本 | Home Manager 原生能力为主 | settings reconciler 需要自建和测试 |

判断：

- 如果首要目标是实验环境、合规机器或“实际状态必须精确等于声明”，方案 A 更合适。
- 如果首要目标是个人日常 IDE，且会频繁试验设置、使用会写 Global Settings 的扩展，
  方案 B 的交互成本明显更低。
- “Mac 与 NixOS 扩展不同”不是支持方案 B 的决定性理由，因为两种方案都能用
  shared/platform 模块表达差异。真正支持方案 B 的理由是 VS Code 和扩展需要写 live
  User Settings，以及用户需要低成本试验。

## 6. 漂移工具能与不能自动化的边界

### 6.1 可以安全自动化

一个窄接口工具可以提供：

```text
vscode-config status
vscode-config diff
vscode-config capture
```

它可以：

- 根据当前平台组合 shared baseline 与 Darwin/Linux baseline；
- 解析 JSONC 后做语义比较，忽略纯格式差异；
- 区分“基线拥有的 key 被改/删”和“live 新增 key”；
- 用 `code --list-extensions --show-versions` 取得实际扩展 ID/版本；
- 报告 declared-and-present、declared-but-missing、local-only 和 version drift；
- 生成候选 JSON 或候选 patch，供人工审阅。

activation 可以做确定性的**单向约束**：保留 live 额外 key，但让 Nix 基线中的同名 key
最终回到声明值。这个语义与 Home Manager Zed 模块的 `$dynamic * $static` 类似，但 VS Code
目前需要自定义实现，且必须测试嵌套对象、数组、语言作用域 key 和非法 JSONC。

如果还要保证 UI 试验不会在下一次 activation 中静默丢失，仅比较“新基线”和
“当前 live”并不够。安全判断至少需要三方：

```text
上一代基线    当前 live    新一代基线
```

- live 等于上一代、而新基线变化：这是 Git/Nix 的正常更新，可以应用；
- 新基线等于上一代、而 live 变化：这是本机漂移，应中止并提示 capture 或 reset；
- live 和新基线都相对上一代变化且不相同：这是冲突，必须人工处理。

所以合理的 activation 是非交互 preflight：发现 owned drift 或三方冲突就失败并给出下一步，
而不是弹出问题、静默覆盖或直接改 Git。它还需要可靠取得“上一代基线”，并明确已从基线
删除的 key 应删除还是降级为 local；这些都超出了 Home Manager 当前 VS Code 模块。

### 6.2 不能安全自动化

工具不能仅凭值或 key 自动判断：

- 新 key 应进入 shared、Darwin、Linux，还是只留本机；
- key 是长期偏好、扩展临时状态，还是包含账号、私有 URL、路径或 token；
- 同一扩展在另一平台是否有等价二进制、依赖或实际用途；
- live 新版本应该提升到 flake，还是应回退到已审阅版本；
- nested object/array 的差异应该整体替换还是逐项合并。

JSONC 还带来额外问题：简单地 parse 后重新序列化会丢失注释、顺序和原始格式。若必须
保留 live 注释，需要使用语法树级 JSONC edit；否则应明确接受“仓库基线保留注释，
live 文件为规范化 JSON”的边界。

`capture` 因此最多生成候选结果，不能自动：

- 修改 shared/platform Nix 文件；
- 提交 Git；
- 删除 live key 或扩展；
- 把疑似机密写入 Nix Store 或公开仓库。

最关键的分类问题是人的领域判断，不是 merge 算法。上游开放的
[home-manager#7617](https://github.com/nix-community/home-manager/issues/7617)
只请求“声明值覆盖 live 同名值”的单向 merge，并没有 reverse promotion；VS Code
Profiles 的 export/import 也曾出现 disabled extension 未被完整表达的真实缺口
([microsoft/vscode#170916](https://github.com/microsoft/vscode/issues/170916))。
这些工具都不能替代 Git diff 和人工审阅。

## 7. 对本仓库的建议终态

建议采用以下不对称边界：

### 应用

- `pkgs.vscode` 由 Home Manager 的 desktop 用户层安装；
- 官方 Microsoft VS Code 仅通过精确 unfree allowlist 放行；
- 应用版本跟随 `flake.lock`，关闭 VS Code 应用自更新；
- macOS 与 NixOS 共用能力模块，各自取得平台产物。

### Settings

- Git/Nix 保存 shared baseline 与 Darwin/Linux baseline；
- live `settings.json` 是普通可写文件，不直接链接到 Nix Store；
- activation 使用上一代基线、live 和新基线做非交互 preflight；owned drift 或冲突时中止，
  无冲突时应用新声明值并保留额外 key；
- `status/diff` 报告漂移，`capture` 只生成候选变更；
- 人工把候选项归入 shared、Darwin、Linux 或 local；
- Settings Sync 关闭；
- workspace settings、globalStorage、workspaceStorage、History、SecretStorage
  和登录态不纳入 reconciler。

### Extensions

- 声明集合拆成 shared、Darwin、Linux；
- 迁移期使用 Home Manager 原生 `mutableExtensionsDir = true`，允许 Nix 基线与 UI
  扩展共存；
- 实际扩展 inventory 使用官方 CLI 采集，不把“声明版本”误报为“实际唯一版本”；
- 若未来要求完整复现，再对选定 extension profile 切换 immutable 模式，并接受 UI
  安装/更新受阻的代价；
- 不把 WSL、Remote、原生二进制扩展无条件放入 shared，逐项依据运行位置和平台支持分类。

### 实施关卡

该终态会改变 Issue #24 当前“Homebrew cask + Home Manager 只读 settings 文件”的合同，
也会引入自定义 activation/reconciler。实施前应：

1. 更新 Issue #24 的允许范围与验收标准，记录维护者决策；
2. 把最小 one-way merge 与 drift/capture 工具拆为明确、可测试的窄范围；
3. 先用副本测试 JSONC、nested object、array、语言作用域和扩展写 Global Settings；
4. 不在验证前 activation，不定向卸载 Homebrew cask；
5. 在 Issue #25 中逐项决定扩展的 shared/platform/local 归属和版本策略。

如果不愿在 Phase 4 承担 reconciler 的实现与长期维护成本，则应回退到方案 A，而不是采用
一个没有检测工具、只靠记忆清理的“可写配置”。没有 status/diff 的方案 B 会把配置事实
来源重新退化为 live 机器，不符合本仓库的可审计目标。
