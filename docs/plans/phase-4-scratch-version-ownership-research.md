# Phase 4：Scratch 版本所有权与更新策略调研

- **日期：** 2026-07-28
- **范围：** macOS Scratch、nix-darwin Homebrew 声明、应用内更新与版本可复现性
- **关联 Issue：** [#64](https://github.com/sayoriqwq/nix-config/issues/64)
- **性质：** 研究与决策输入；本文不授权 activation、Homebrew 升级或应用替换

## 1. 结论

当前现象可以通俗地称为 **version drift（版本漂移）**，但在本仓库语境中更准确的
描述是：

> nix-darwin 只声明 Homebrew cask 的存在；Scratch app bundle 仍是 Homebrew 管理域中的
> 可变外部状态。Scratch 的应用内更新是一次 out-of-band mutation（绕过声明路径的
> 变更），并造成 Homebrew installation receipt 与实际 app bundle 之间的 metadata/version
> drift。

它不是 Nix derivation 的 impurity，也不是 Nix Store 内容被修改。Nix Store 本身用于保存
不可变文件系统数据；当前 `/Applications/Scratch.app` 不在 Nix Store 中，因此 Nix 的不可变、
按内容寻址与 generation 回滚保证并不覆盖它。[Nix Store](https://nix.dev/manual/nix/2.28/store/index.html)

还应区分以下术语：

| 术语 | 是否适用 | 本例含义 |
| --- | --- | --- |
| version drift | 适用，偏现象描述 | Homebrew 收据版本、实际 bundle 版本和上游 cask 版本不一致 |
| configuration drift | 部分适用 | 若把 Brewfile 理解为期望状态，它只约束“已安装”，没有固定 Scratch 版本 |
| state drift | 适用，范围更宽 | 激活后的真实机器状态在声明之外继续变化 |
| out-of-band mutation/update | 最准确的原因描述 | Scratch 自己替换 app bundle，绕过 Homebrew/nix-darwin 更新路径 |
| unmanaged mutable state | 适用但需限定 | bundle 内容相对 Nix 是外部可变状态；应用是否存在仍由 Brewfile 声明 |
| impurity | 不宜用于最终现象 | 没有证据表明 Nix evaluation/derivation 读取了未声明输入；漂移发生在激活后的外部包管理域 |

## 2. 升级前现场与三个不同的“版本事实”

Issue #64 定向升级前的只读检查得到：

1. 当前激活 generation 生成的 Brewfile 声明 `erictli/tap/scratch`，activation 使用
   `HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --no-upgrade`；
2. Homebrew Caskroom 收据仍是 `scratch 0.4.0`；
3. `/Applications/Scratch.app/Contents/Info.plist` 是 `0.10.0`；
4. 上游 cask 已发布 `1.0.0`，并用固定 SHA-256 指向官方 universal DMG；
5. Scratch v1.0.0 已作为 GitHub 最新 release 发布，并明确同时支持应用内更新、DMG 与
   Homebrew 安装。

上游 cask 当前定义为 `version "1.0.0"`，但没有 `auto_updates true` stanza。
[Scratch cask source](https://github.com/erictli/homebrew-tap/blob/main/Casks/scratch.rb)
[Scratch v1.0.0 release](https://github.com/erictli/scratch/releases/tag/v1.0.0)

这三个版本分别代表：

- **Homebrew 收据 `0.4.0`：** Homebrew 最后一次正式安装或升级时记录的版本；
- **实际 bundle `0.10.0`：** 当前真实运行的程序版本；
- **tap `1.0.0`：** Homebrew 在更新 tap 后能够安装的最新声明版本。

Homebrew 官方文档明确承认：应用自己的 updater 可以让 Homebrew 安装记录落后于实际
app。盲目只按旧收据替换 app 甚至可能造成降级；对正确声明 `auto_updates true` 的 cask，
Homebrew 会尽可能读取 bundle 版本后再决定是否升级。
[Homebrew FAQ: self-updating apps](https://docs.brew.sh/FAQ#how-does-brew-upgrade-handle-apps-that-update-themselves)

## 3. nix-darwin 选项的准确边界

当前策略中的三个选项都不固定 Homebrew cask 的版本：

- `homebrew.onActivation.autoUpdate = false`：activation 时设置
  `HOMEBREW_NO_AUTO_UPDATE`，不刷新 Homebrew/tap 元数据；它不控制 Scratch 自己的 updater；
- `homebrew.onActivation.upgrade = false`：activation 时传递 `--no-upgrade`，因此重复
  `darwin-rebuild switch` 不会顺带升级已安装包；
- `homebrew.onActivation.cleanup = "none"`：Brewfile 中未声明的包仍保留，不做 uninstall
  或 zap。

nix-darwin 文档把前两个默认值的理由表述为保持重复 activation 的幂等性。这里的
“幂等”只表示 activation 不主动推进 Homebrew 版本，不表示 Homebrew 管理的 app bundle
已经成为 Nix 可复现输出。
[nix-darwin Homebrew options](https://nix-darwin.github.io/nix-darwin/manual/#opt-homebrew.onActivation.autoUpdate)

`homebrew.casks.*.greedy = true` 只表示在执行 upgrade 时，即使 cask 无版本或会自更新也
始终考虑升级；它不能越过全局 `onActivation.upgrade = false` 单独触发升级。
[nix-darwin per-cask greedy option](https://nix-darwin.github.io/nix-darwin/manual/#opt-homebrew.casks)

## 4. Homebrew 与 Tauri 的更新语义

Homebrew 的 `auto_updates true` 是 cask 作者对“应用可以自行下载并安装更新”的声明；
`livecheck` 用于发现新版本；`greedy` 控制 upgrade 是否把自更新或无固定版本的 cask 纳入。
这些概念彼此不同。[Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

Scratch 当前 cask 虽然带应用内 updater，却没有 `auto_updates true`。这不会阻止 Scratch
更新，但会削弱 Homebrew 对“收据落后而实际 bundle 已更新”这一情形的识别。这适合向
`erictli/homebrew-tap` 提交一个上游修正，而不是在本仓库永久维护同名 cask 分叉。

Scratch 使用 Tauri updater，配置指向 GitHub Release 的 `latest.json` 并嵌入更新签名公钥。
[Scratch Tauri config](https://raw.githubusercontent.com/erictli/scratch/main/src-tauri/tauri.conf.json)
Tauri 的标准流程会检查版本、下载并安装带签名的 macOS app archive，然后由应用选择重启；
默认只接受比当前版本更高的更新。
[Tauri updater](https://v2.tauri.app/plugin/updater/)

## 5. 可选策略

| 策略 | 新鲜度 | 可复现性与审计 | 回滚 | 维护成本 | 评价 |
| --- | --- | --- | --- | --- | --- |
| 继续点应用内更新 | 最高，发布后立即可用 | 低；绕过 Git、Brew receipt 与 generation | 需手工恢复旧 DMG/app | 最低 | 适合把 Scratch 明确视为 self-managed app |
| `brew update` 后定向升级 Scratch cask | 高；取决于 tap 更新速度 | 中；版本与 hash 在 tap 中，但 tap revision 未被 `flake.lock` 固定 | Homebrew/备份式手工回滚 | 低 | **当前推荐的 v1.0.0 获取路径** |
| activation 全局开启 autoUpdate + upgrade | 高 | 低到中；一次 rebuild 可能推进大量 cask/formula/MAS | 回滚 Nix generation 不能撤销 Homebrew 升级 | 低，但爆炸半径大 | 不建议只为 Scratch 开启 |
| 定期 PR/人工流程更新 tap 后定向升级 | 高 | 中；决策和验证有 Git/PR 记录，但 app 仍不在 Nix Store | 需配套旧 bundle 备份 | 中 | 适合作为 Homebrew 迁移期治理方案 |
| 在仓库中维护固定版本/hash 的 Nix derivation | 取决于更新 PR 频率 | 高；版本与 DMG/source hash 进入 Git/Nix 输出 | 切换 generation | 中到高 | 适合长期严格所有权 |
| 使用官方 Flake input 并锁定 revision | 理论上高且可复现 | 高 | 更新 `flake.lock` 后切 generation | 低到中 | Scratch 当前没有官方 `flake.nix`，暂不可用 |

Flake lock file 可以把输入解析到精确 revision/content hash，从而保证相同输入图；但 Homebrew
tap 与 cask 安装不因出现在 nix-darwin 配置中就自动进入 `flake.lock`。
[Nix flake lock files](https://nix.dev/manual/nix/2.24/command-ref/new-cli/nix3-flake.html#lock-files)

## 6. 推荐决策

### 6.1 获取 Scratch v1.0.0

优先走 **更新 Homebrew 元数据后定向升级单个 cask**，而不是先点应用内更新。上游 cask
已经是 1.0.0，因此这条路径能同时得到新版本，并把 Homebrew receipt 从旧值推进到 1.0.0。
Issue #64 已记录维护者的当次明确批准，并执行以下命令；权限没有扩大为全局升级：

```bash
/opt/homebrew/bin/brew update
/opt/homebrew/bin/brew upgrade --cask erictli/tap/scratch
```

执行前已正常退出 Scratch，并把原 app bundle 保存到仓库外权限为 `0700` 的
`~/.local/state/nix-config-backups/scratch-issue-64-pre-1.0/`。执行后检查：

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  /Applications/Scratch.app/Contents/Info.plist
/opt/homebrew/bin/brew list --cask --versions scratch
/opt/homebrew/bin/brew outdated --cask --json=v2 erictli/tap/scratch
```

结果为：实际 bundle 与 Homebrew receipt 均为 `1.0.0`，完整 token 的 outdated 集合为空；
bundle ID 仍为 `com.scratch.app`，Developer ID Team Identifier 仍为 `38H4DN8A25`，深度签名
验证通过，应用可以从 `/Applications/Scratch.app` 正常启动。升级输出只包含 Scratch
`0.4.0 -> 1.0.0`，没有升级报告中同时列出的其他 8 个 formula 和 5 个 cask。

验证不能使用裸 `brew outdated scratch`：它会解析到官方 Homebrew Cask 中同名的 MIT
Scratch 3.32.0，产生错误的 outdated 结果。安装、升级和验证都必须继续使用完整 token
`erictli/tap/scratch`。

上述结果记录已执行事实，不把本文扩展为未来 Homebrew 升级或 activation 的授权。

如果维护者只想立即使用新功能，不在意 Homebrew receipt 暂时不一致，点击应用内更新也是
上游支持的有效路径；它是“选择 self-managed 更新模型”，不是获得 Nix 固定版本。

### 6.2 中期治理

1. 向上游 tap 提议为 Scratch cask 添加 `auto_updates true`；
2. 保持 `onActivation.autoUpdate = false`、`upgrade = false`，避免一次 activation 隐式升级
   全部 Homebrew 软件；
3. 对需要及时更新的少数 cask 使用定向、可审阅的维护流程，而不是全局 `greedyCasks`；
4. 在 inventory 中明确 Scratch 的版本所有者是 Homebrew 还是应用自身，不能同时声称二者
   都是唯一所有者。

### 6.3 长期严格可复现方案

若希望 Scratch 与 Zed 一样由 Git/Nix generation 推进和回滚，应创建独立 Issue：

1. 用固定 release URL、版本和 SHA-256 打包 universal DMG，或从固定 source revision 构建；
2. 将 app 置于 Nix Store，并通过 Nix 管理的 Applications 入口暴露；
3. 禁用/隐藏应用内 updater，因为只读 Nix Store 不能被应用就地更新；
4. 以定期 Draft PR 更新版本/hash，运行 build 和签名/bundle 检查；
5. 验证笔记目录、Git remote、设置等可变数据仍保留在 store 外；
6. 完成验证后再定向移交 Homebrew cask 所有权，不能让两份 `Scratch.app` 竞争 LaunchServices。

这里“使用最新版本”应定义为“最近一次通过验证并被 Git 固定的版本”，而不是每次 evaluation
从浮动 URL 下载不同内容。这样会比应用内更新略慢，但得到可审计更新、确定性构建与 generation
回滚。

## 7. Issue #64 验证结果

仓库验证命令：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link --print-out-paths
```

三条命令均返回 0。`nix flake check` 提示跳过不兼容的 Linux formatter；macOS system
build 产物为 `/nix/store/rcziypmidajf7w15izfl9kv3ya25jk01-darwin-system-26.05.c3e90c8`。
生成的 Brewfile 继续包含受信任 tap `erictli/tap` 与完整 cask token
`erictli/tap/scratch`；activation 继续使用 `HOMEBREW_NO_AUTO_UPDATE=1` 和
`brew bundle --no-upgrade`，没有 `--cleanup` 或 `--zap`。求值结果仍为：

- `homebrew.onActivation.autoUpdate = false`；
- `homebrew.onActivation.upgrade = false`；
- `homebrew.onActivation.cleanup = "none"`。

因此 Issue #64 没有把一次获批的 Scratch 定向维护扩大为普通 activation 的全局升级。

## 8. 未决事项

- 是否接受 Scratch 作为明确的 self-managed 例外，还是要求所有桌面核心应用进入 Nix Store；
- Scratch 1.0 宣布进入稳定阶段且维护节奏将放缓，自维护 Nix package 的长期收益是否足以覆盖成本；
- 上游 tap 是否接受 `auto_updates true`；
- 若迁移为 Nix package，macOS 签名、公证票据、Tauri updater UI 与 LaunchServices 的实机行为需要
  在独立 Issue 中验证。
