# macOS 环境恢复与回滚

本手册恢复 `macbook` 的声明式系统和软件来源，不恢复应用数据库、账号或用户内容。

## 1. 前置与禁止项

恢复前确认：

- 目标仍是兼容的 Apple Silicon macOS；
- 管理员、FileVault/recovery 与重要数据备份可用；
- 仓库和 `flake.lock` 来自已审阅 commit；
- 浏览器、编辑器、OrbStack、云盘、AI CLI、Atuin、Rime userdb 与应用账号有各自恢复策略。

不要运行批量 Homebrew cleanup/zap，不覆盖未知 `/Applications` 或 `~/Library` 内容，不把 private key、token、Keychain、TCC、database、profile 或容器 volume 放进 Git/Nix Store。

## 2. 恢复顺序

### 2.1 盘点与数据保护

按 [host-inventory.md](host-inventory.md) 重新收集当前机器事实。记录现有 Nix generation、Homebrew/MAS receipts 和应用冲突；先备份用户数据，再恢复声明。

### 2.2 Lix 与非激活构建

macbook 使用 Lix 作为 Nix implementation；bootstrap 和完整卸载遵循 Lix 官方 installer/receipt，日常版本由 `nix.package = pkgs.lix` 与 lock file 管理。

```fish
nix build .#darwinConfigurations.macbook.system
```

🔍 求值并构建目标 generation，不 activation。

若 `/nix`、daemon、mount 或 installer receipt 与预期不一致，停止并单独诊断；不要把重装 Nix 当作 generation rollback。

### 2.3 Activation

审阅 exact commit、build output、现有 generation 和 rollback 后，维护者另行批准并执行 activation。Activation 可以落地 nix-darwin、Home Manager、Homebrew/MAS 声明与 macOS defaults，但不会恢复外部应用数据，也不会自动删除现场多余应用。

Pages、Keynote、Numbers、GarageBand 已按维护者选择移出安装声明，交由系统或 App Store 处理，缺失不形成仓库补录任务；当前 Homebrew `cleanup = "none"`，移除声明不会自动卸载已安装的应用。

### 2.4 外部 owner

按单一 owner 恢复外部状态：

- Pinshift 的 `~/.local/bin/pinshift` 由项目自己的 `pinshift register` 注册，Home Manager 不再提供转发命令。项目移动后从新 checkout 重新注册；项目依赖、签名、设备操作和应用数据仍由 Pinshift 管理。
- Obsidian 的 Mac 安装需求由 `homebrew.casks` 声明 `obsidian`；[cask](https://formulae.brew.sh/cask/obsidian) 安装 `/Applications/Obsidian.app`，并提供指向其中 `obsidian-cli` 的官方命令。Home Manager 不再提供 `~/.local/bin/obsidian`，Linux 继续使用 Nix 包。应用日常自动更新与 Electron 安装器更新是两件事：前者由应用处理，后者通过 Homebrew 按需升级，见[官方更新说明](https://obsidian.md/help/updates)。[官方 CLI](https://obsidian.md/help/cli) 需要安装器 1.12.7 以上，并在应用设置中开启命令行界面；cask 已提供 PATH 入口时可跳过应用的重复注册。`obsidian` 不带参数进入交互式命令界面，单纯启动图形应用使用 `open -a Obsidian`。笔记库、插件、主题、偏好与账号保持外部，原生版本不会随 Nix generation 回滚。
- VS Code 的 Mac 安装需求由现有 `homebrew.casks` 声明 `visual-studio-code`；[cask](https://formulae.brew.sh/cask/visual-studio-code) 使用微软提供的应用安装到 `/Applications/Visual Studio Code.app`，日常继续由应用原生更新。恢复时由 Homebrew 安装缺失应用，当前激活配置不升级已有包。Home Manager 保留指向该应用的 `~/.local/bin/code`，快捷命令 `v` 复用此入口。每次 Mac 激活都会用仓库基线整份覆盖默认用户的 `~/Library/Application Support/Code/User/settings.json`，保持文件可写；基线使用 `update.mode = default`。日常可以直接修改，但希望保留的内容应先保存到声明，下次激活不会保留该文件的额外字段。扩展、账号、keybindings、其他 profiles 和用户数据保持外部，原生应用版本不会随 Nix generation 回滚；非 Mac 包策略不变。
- Ghostty 的 Mac 安装需求由现有 `homebrew.casks` 声明 `ghostty`；cask 使用[官方 DMG](https://ghostty.org/docs/install/binary#homebrew)安装到 `/Applications/Ghostty.app`，日常继续通过应用原生渠道独立更新。恢复时由 Homebrew 安装缺失应用，当前激活配置不升级已有包。Home Manager 继续维护 Fish、主题和终端设置，以及指向原生应用的 `~/.local/bin/ghostty`；Linux 继续使用 Nix 包。Mac 不由 Home Manager 自动校验 Ghostty 配置或提供 `bat` 的 Ghostty 配置语法高亮。原生版本不会随 Nix generation 回滚，已有应用偏好文件保持原样。
- LocalSend 的 Mac 安装需求由 `homebrew.casks` 声明 `localsend`，安装和升级使用 Homebrew，应用没有内置自动更新；当前激活只安装缺失应用，不升级已有包。Linux 继续使用 Nix 包和既有防火墙规则。
- Zed 的 Mac 安装需求由 `homebrew.casks` 声明 `zed@preview`，Preview 应用继续原生更新。直接使用 Homebrew 提供的 `zed-preview`，`z` 快捷与默认编辑器同步采用此名称；配置按现有 Home Manager 可写合并应用，详见 [Zed 手册](update-zed-preview.md)。Linux 继续使用 Stable 与 `zeditor`。
- Fcitx5.app/frontend 由官方 installer 和 macOS 输入源拥有；Nix 只投影 Rime Ice 静态 schema leaves。不得覆盖 `~/.config/fcitx5`、userdb、sync、identity 或整个 Rime 根目录；只有静态 overlay 实际改变且另获批准时才人工 deploy。
- AI 编码工具、解释器、配置与会话由当前外部工作流管理；本仓库已移除旧 AI 编码模块，待工作流稳定后重新评估迁移。
- Raycast 的 Script Commands 由 Nix 投影；Settings、database、shortcuts、extensions 和 Script Directory 选择保持外部。
- Browser profile、Obsidian vault、VS Code 扩展与其他外部配置、Zed 未声明设置与应用状态、Atuin history/key、OrbStack VM/container/volume、cloud data、licenses 和账号通过各自产品流程恢复。

VS Code、Ghostty、Obsidian 与 Zed Preview 首次接管已有手工安装时需核实应用与安装记录，处理冲突，不在常规声明中固化 `force`。公共 Homebrew 配置将其命令目录追加到系统 PATH，使登录环境可找到 cask 提供的 CLI，并保留现有工具优先级。

## 3. 验收

在新登录 Fish 中至少确认：

```fish
command -s fish git uv mise zed-preview code obsidian
echo $EDITOR
echo $VISUAL
```

✅ 核对主要 CLI 的预期来源与默认编辑器环境；原生应用的 CLI 应指向对应的 `/Applications` 安装。

随后人工验证 Ghostty/Fish、Zed、Raycast、Fcitx/Rime、Tailscale、Homebrew/MAS 应用和必要 macOS defaults。Build 不能替代这些 runtime checks。

VS Code 需确认 Homebrew 安装记录、启动器、`code` 与 `v` 对应同一份 `/Applications/Visual Studio Code.app`，扩展和集成终端正常；完成应用内真实更新与重启后，再应用基线并确认新版保留、默认用户 `settings.json` 与声明一致且仍可写、旧 Home Manager 入口未重建。该设置文件的临时修改和额外字段应被基线覆盖；扩展、账号、keybindings 和其他 profiles 不受此写入动作管理。没有可用更新时，真实更新项保持待验收。

Obsidian 需确认 Homebrew 安装记录、原有笔记库、插件与主题可用，自动更新与命令行界面开启；`obsidian version`、`obsidian help open` 正常，启动器与 CLI 使用同一原生安装。应用基线后确认原生版本和偏好保留、旧 Home Manager 应用与 CLI 入口未重建。通过 Homebrew 更新安装器不能代替应用内自动更新验收；没有可用应用更新时，后者保持待验收。

Ghostty 还需确认 Homebrew 安装记录、启动器与 `ghostty` CLI 对应同一份 `/Applications/Ghostty.app`，Fish、主题和分屏可用；用 `ghostty +validate-config` 显式校验配置。通过应用完成一次真实更新与重启，并在随后应用基线后确认新版仍在、旧 Home Manager 应用入口未重建、现场偏好未覆盖。没有可用更新时，该项保持待验收，不能把“已是最新”当作更新成功。

## 4. 回滚

优先切回 activation 前一代 nix-darwin generation；这只恢复 Nix 声明，不会撤销 Homebrew 已执行安装、vendor login、TCC、数据库或用户数据变化。

Homebrew/MAS 问题先从声明撤回并重新 build；定向 uninstall、zap、receipt 修复或数据删除必须另获批准。Fcitx/Rime 回滚要区分静态 Nix leaves、外部 frontend/preferences 与 userdb；禁止通过清空用户目录验证“干净恢复”。

如果上一代本身包含已退役的 activation side effect，切换前必须先审阅该 generation，不能假设旧 generation 只恢复静态文件。
