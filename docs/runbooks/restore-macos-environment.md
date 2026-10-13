# macOS 环境恢复与回滚

恢复 `macbook` 的声明式系统、选定软件与使用习惯。职责见[架构](../architecture.md)，日常变更走[日常维护](daily-nix-maintenance.md)；账号、应用数据库与用户内容从各自外部材料恢复。

## 恢复前准备

- 确认目标为 Apple Silicon macOS，核对 [macbook](../../hosts/macbook/default.nix) 中的用户名、主目录与机器事实；不同机器先调整声明，不修改 `stateVersion`。
- 确认管理员与 FileVault 恢复方式可用，所需用户数据和应用恢复材料在旧机之外可取得。
- 确认选定的仓库提交及 `flake.lock` 能从远端或独立备份取回；仅存在于旧机的本地提交不构成异机恢复材料。
- 若目标已有环境，只处理本次涉及的文件与应用冲突，并保留想要的现场修改；不做全机补录或批量 cleanup/zap。

## 空白机器首次接入

1. 在 Terminal 中按 [Lix 官方安装说明](https://lix.systems/install/)安装 Lix，保留安装收据；已有可用 Lix 时跳过，不把重装当作回滚。
2. 按 [Homebrew 官方安装说明](https://docs.brew.sh/Installation)安装 Apple Silicon 版本至 `/opt/homebrew`，完成安装器提示的环境设置；准备可用 Git，系统提示缺少 Command Line Tools 时先完成安装。
3. 按需登录 App Store，并准备登录任务引用的外部应用，见下文“应用与外部材料”；激活会加载这些任务。

首次激活前可用 Terminal 默认 Shell 执行以下兼容命令；激活后改用 Ghostty 中的 Fish。

```fish
nix --version
/opt/homebrew/bin/brew --version
git --version
```

🔎 确认 Lix、Homebrew 与 Git 可用；Nix 版本输出应包含 Lix。

目标目录尚不存在时取得仓库；已有 checkout 直接进入并核对提交：

```fish
mkdir -p ~/workspace
git clone https://github.com/sayoriqwq/nix-config.git ~/workspace/nix-config
cd ~/workspace/nix-config
git log -1 --oneline
```

📦 确认当前 HEAD 正是选定的已审阅恢复点，再继续；不在恢复过程中顺手更新输入。

```fish
nix build --no-update-lock-file .#darwinConfigurations.macbook.system
```

🔨 按现有 lock 构建候选并生成 `result`，尚未应用。遇到已有文件或应用冲突，先确认其来源与保留方式。

目标、写入范围与恢复办法明确后，按 [AGENTS.md](../../AGENTS.md) 的授权执行首次激活，期间保持 checkout 与 lock 不变：

```fish
sudo ./result/sw/bin/darwin-rebuild switch --flake .#macbook --no-update-lock-file
```

🔧 使用候选自带的 `darwin-rebuild` 首次应用此仓库；它会再次求值同一配置并登记系统代际，无需先安装 nh。[nix-darwin 安装说明](https://github.com/nix-darwin/nix-darwin#step-2-installing-nix-darwin)

完成后重新打开 Ghostty，后续通过[日常维护](daily-nix-maintenance.md#应用配置)中的 nh 入口应用配置，不再重复安装器步骤。首次激活前没有可退回的 Nix 代际；安装器问题按 Lix 收据处理，应用与数据使用各自恢复材料。

## 应用与外部材料

Homebrew 声明安装缺失软件，当前激活不升级已有软件、不卸载额外应用。遇到同名手工安装副本先处理具体冲突，不把 `force` 固化进常规声明。

| 对象 | 恢复与写入边界 |
| --- | --- |
| Ghostty | Homebrew 安装原生应用并保留应用自更新；Home Manager 持续管理 `~/.config/ghostty/config`、主题和 CLI 接线，外部应用偏好与数据另行恢复。 |
| VS Code | 原生应用自更新；每次激活整份覆盖默认用户 `settings.json` 并保持可写，未保存修改及额外字段会丢失；扩展、账号、keybindings、其他 profiles 与数据保持外部。 |
| Zed | 原生 Preview 自更新；settings/keymap/tasks 可写合并，删除声明不删除现场遗留值，见 [Zed 维护](zed-maintenance.md)。扩展与应用状态另行恢复。 |
| Obsidian | 应用日常自动更新，Electron 安装器按需由 Homebrew 更新；恢复笔记库、插件、主题与账号，并在应用内开启官方 CLI，cask 已提供命令入口。 |
| Git | 从私有恢复材料还原 `~/.config/git/identity.inc`；身份和凭据不写入公开声明。 |
| Fcitx/Rime | Fcitx frontend 与输入源由官方安装流程恢复；Nix 只投影静态 Rime schema，不覆盖 userdb、sync、identity 或整个配置目录。 |
| Raycast、Pinshift | Raycast 设置、扩展与 Script Directory 选择保持外部；Pinshift 从自己的项目恢复，并由 `pinshift register` 注册命令。 |
| 其他外部状态 | 浏览器资料、Atuin 历史与密钥、OrbStack 容器和卷、云盘、许可、AI 工具及账号按各自产品与项目流程恢复。 |

登录启动名单集中在 [login-items.nix](../../hosts/macbook/login-items.nix)。先准备名单中的 Setapp 应用及其他外部安装；NuPhy Key Probe 的程序与数据从其项目或备份恢复，并确保声明中的日志目录存在。

同一应用只保留一个“登录时打开”入口。启用受管任务时撤销重复原生登记，但保留产品必要的更新器、设备驱动、网盘服务与网络扩展；不要把系统“允许在后台”总开关当作重复 GUI 入口关闭。

普通任务登录时打开应用，手动退出后不重新拉起；NuPhy 保留常驻策略。新增或修改任务的激活可能立即打开应用或重启服务，移除普通任务不会退出已运行应用。调整 Tailscale、Clash Verge 等网络应用时保留恢复通道，勿通过退出主进程来试探登录项归属。

## 开发运行时准备

在新 Ghostty/Fish 中执行：

```fish
cd ~
mise install node bun pnpm
```

🧰 按当前 mise 配置准备运行时。[mise install](https://mise.jdx.dev/cli/install.html) 安装工具而不改写版本选择；仓库默认使用 `latest`，不保证恢复旧机的精确版本，已有个人配置也可能覆盖默认值。

等 Fish 出现新的提示符、刷新运行时 PATH 后核对：

```fish
mise ls --current
node --version
bun --version
pnpm --version
```

🔎 确认当前选中的工具已安装，并能从新 Fish 会话直接调用。

项目需要的版本、依赖与锁文件从项目恢复。进入含 `.envrc` 的项目时先阅读其内容再按 direnv 提示授权；有 mise 配置时先审阅并按其提示信任、安装。Python 由项目和 uv 管理，不交给 mise；本仓库标准库测试入口见[日常维护](daily-nix-maintenance.md#更新入口的测试)。

## 实际使用验收

```fish
command -s fish git uv mise direnv zed-preview lazygit code obsidian
echo $EDITOR
echo $VISUAL
ghostty +validate-config
cd ~/workspace/nix-config
z .
```

✅ 确认 Ghostty 启动 Fish、主要命令可用，编辑器变量为 `zed-preview --wait`；Ghostty 配置校验通过，`z .` 打开当前仓库的原生 Zed Preview。

在 Zed 中按 `Cmd+Shift+G` 或选 `Run → Spawn Task → LazyGit`，确认任务打开当前仓库并可按 `q` 退出。再从 Finder 或应用启动器打开同一项目，检查集成终端与任务；两个入口的环境获取方式见 [Zed 维护](zed-maintenance.md)。nix-config 没有项目运行时文件，这一步不证明其他项目的版本切换。

按实际恢复范围检查原生应用启动器与 CLI 指向同一份 `/Applications` 安装，并验证笔记库、扩展、输入法、必要权限和网络功能。遇到真实应用更新时，更新并重启后再应用配置，确认新版与外部数据保留；没有更新时不把“已是最新”当作升级验收。

下一次真实登录后核对受管 GUI 应用各启动一次，普通应用退出后不会被任务重开，NuPhy 正常常驻。重新打开终端、手工 `open` 或单独加载任务不能代替登录验收；网络应用的退出测试须有恢复通道。

## 回滚

已有已验收代际时按[日常维护](daily-nix-maintenance.md#恢复已知可用配置)切换并验证实际功能。代际切换不会对称撤销 Homebrew 安装、原生应用升级、macOS 偏好、权限或应用数据变化。

声明错误从 Git 修复或撤销后重新应用；应用数据库与用户内容使用外部恢复材料。定向卸载、receipt 修复或数据删除按具体目标处理，不用清空用户目录验证“干净恢复”。
