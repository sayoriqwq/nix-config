# Phase 3 macOS 用户层盘点

本文记录 `macbook` 首次接入 Home Manager 所需的脱敏事实、现有配置所有权和迁移边界。原始文件内容与账户标识只保留在本机；本文不保存 Git 邮箱、GitHub 账户、token、Atuin key、history 或其他私人数据。

## 1. 证据范围

- 初始采集日期：2026-07-20
- activation 与验收日期：2026-07-22
- 目标用户：Phase 1 已确认的 `sayori`，home 为 `/Users/sayori`
- 默认 shell：`/opt/homebrew/bin/fish`
- 证据来源：本机文件清单、文件权限、`chezmoi managed`、Homebrew formula 清单、当前工具版本和锁定 Home Manager 26.05 源码
- 未读取/未提交：GitHub `hosts.yml` 内容、Atuin key 与数据库内容、Fish history、shell history、缓存内容

## 2. 现有配置与所有权

| 领域 | 当前事实 | Phase 3 决定 |
| --- | --- | --- |
| Git | `~/.gitconfig` 包含 identity 与 GitHub/Gist 的 `gh auth git-credential` helper；`~/.config/git/ignore` 有一条全局 ignore | Home Manager 生成 XDG Git config 与 ignore；identity 写入本机私有 include，不进入 Git；credential helper 指向 Nix profile 中的 `gh` |
| Fish | Homebrew Fish 4.5.0 是默认 shell；配置初始化 FZF、Zoxide、Atuin、Starship、The Fuck，并保留若干本机 PATH 与应用 integration | Home Manager 管理 Fish 包、结构化 integration、现有 Zoxide `cd` 行为、Atuin Ctrl+Up 绑定、颜色和空 greeting；默认 shell 本阶段不变 |
| 编辑器 | Homebrew Helix 25.07.1；唯一已确认的静态设置是 `theme = "ayu_dark"` | 使用 `programs.helix` 声明相同主题；Code/Zed 等 GUI 编辑器函数延后到 Phase 4 |
| tmux | Homebrew tmux 3.6a 已安装，未发现 `~/.tmux.conf` 或 `~/.config/tmux` 配置 | 只启用 `programs.tmux`，不虚构快捷键或 session 配置 |
| direnv | 未发现 Homebrew formula 或用户配置 | 首次启用 `programs.direnv` 与 `nix-direnv`；不自动 allow 任何项目目录 |
| Starship | 存在静态 `~/.config/starship.toml` | 通过结构化 `programs.starship.settings` 保留当前 prompt 结构与颜色 |
| Atuin | 独立安装版本 18.13.2；配置启用 daemon，数据位于 `~/.local/share/atuin`；锁定 nixpkgs 提供 18.15.2 | Home Manager 只接管包与 Fish hook；保留现有可写 config、数据库、key、daemon state，激活前必须私有备份并人工验证兼容性 |
| GitHub CLI | Homebrew `gh` 已有 config 与私有 hosts 文件 | 只从 Nix 提供 `gh` 包和 Git credential helper；不生成、不链接、不读取认证文件 |
| 通用 CLI | 已安装 Bat、Btop、Eza、Fd、FZF、Lazygit、Ripgrep、Tree、Yazi、Zoxide 等 | 优先使用对应 `programs.*`；无结构化配置的最小工具通过 `home.packages` 安装；Yazi 与完整 Homebrew 清单本阶段不迁移 |

### 2.1 已确认的版本转换

| 工具 | 迁移前 | 锁定 Nix profile | 说明 |
| --- | --- | --- | --- |
| Fish | Homebrew 4.5.0 | 4.7.1 | macOS login shell 仍保持 Homebrew 路径；新 profile 中的 `fish` command 为 Nix 版本 |
| Git | Apple Git 2.50.1 | 2.54.0 | identity 与 credential helper 必须单独验证 |
| Atuin | 独立安装 18.13.2 | 18.15.2 | 使用既有可写数据库前先私有备份并验证 history/daemon |
| Starship | Homebrew 1.24.2 | 1.25.1 | 结构化迁移现有 prompt 设置 |
| FZF | Homebrew 0.67.0 | 0.72.0 | Fish integration 改由 Home Manager 生成 |
| Zoxide | Homebrew 0.9.8 | 0.9.9 | 保留现有 `cd` wrapper 行为 |
| GitHub CLI | Homebrew 2.95.0 | 2.96.0 | 继续读取现有私有 auth state，不由 Home Manager 生成 |

这些版本由锁定的 nixpkgs 26.05 决定，不是独立的 dependency-upgrade 工作。版本差异属于人工验证重点，不能仅用 build 成功代替行为验证。

## 3. chezmoi 交接

`chezmoi managed` 确认以下文件当前由 chezmoi 管理：

- `~/.gitconfig`
- `~/.config/fish/config.fish`
- `~/.config/fish/conf.d/zz-theme-tokens.fish`
- `~/.config/fish/functions/__sayori_cd.fish`
- `~/.config/fish/functions/fish_greeting.fish`

Home Manager activation 不得自动覆盖这些 regular file。维护者必须先按迁移手册完成私有备份和 identity 分离，再显式移开会冲突的目标文件。验证成功前不得对这些路径运行 `chezmoi apply`；验证成功后再在 chezmoi source repository 中移除重复所有权并单独审阅该变更。

此外，以下现有文件会与本阶段生成的 Home Manager 文件冲突，但当前不由 chezmoi 管理：

- `~/.config/git/ignore`
- `~/.config/fish/conf.d/atuin.env.fish`
- `~/.config/helix/config.toml`
- `~/.config/starship.toml`

## 4. 明确不管理的状态

以下内容不会成为 Home Manager file link，也不会复制进 Nix Store：

- `~/.config/fish/fish_variables`
- Fish/其他 shell history
- `~/.config/atuin/config.toml`
- `~/.local/share/atuin/**`，包括 databases、WAL、key、daemon pid 和 cache
- `~/.config/gh/hosts.yml` 与其他认证状态
- Zoxide database
- OrbStack、OpenClaw、pnpm、GHCup、Cabal、Rustup 的安装与可变数据
- cache、session、浏览器 profile、编辑器 runtime data

Darwin 用户模块显式加入 `/etc/profiles/per-user/sayori/bin`，因为当前 Homebrew Fish 不读取 nix-darwin 的 POSIX environment script；未迁移工具的路径只作为后备追加。模块仅在相关文件存在时加载应用 shell integration，不取得这些工具的安装或数据所有权。

## 5. 本阶段延后项

- Fish 的 `zen` 彩蛋与 `opencli` completion；
- Yazi 及其较大的媒体预览依赖闭包；
- Code/Zed GUI 启动函数；
- Homebrew formula/cask 的完整迁移与 cleanup；
- Git Delta 等尚未在现有 Git config 中启用的行为；
- Atuin config、daemon service 和数据迁移；
- 项目专用 language toolchain 与依赖。

Nixpkgs 26.05 已移除上游停止维护且不兼容 Python 3.12+ 的 The Fuck，因此本阶段不把它加入共享 Nix profile；Darwin 模块暂时保留现有 Homebrew binary 的条件式 Fish integration，不把替代工具当作未经批准的行为变更。

## 6. `home.stateVersion` 依据

这是该用户第一次采用 Home Manager，没有既有 `home.stateVersion`。锁定 input 为 Home Manager release 26.05、revision `4ce190229c73d44536caa7072f6308fb2d8feeb3`。该 revision 的 nix-darwin installation manual 明确使用 `home.stateVersion = "26.05"`，并要求初始值在安装后保持不变；option 文档说明提高该值可能要求数据转换或移动文件。

因此 `macbook` 首次值固定为 `26.05`。未来升级 Home Manager 不自动改变此值。

参考：

- [锁定 revision 的 nix-darwin installation manual](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/docs/manual/installation/nix-darwin.md)
- [锁定 revision 的 `home.stateVersion` option](https://github.com/nix-community/home-manager/blob/4ce190229c73d44536caa7072f6308fb2d8feeb3/modules/misc/version.nix)

## 7. 首次 activation 与验收记录

维护者在升级至 macOS 27.0 Public Beta（build `26A5378n`、Darwin `27.0.0`）后，重新执行格式检查、Flake 检查和 `darwinConfigurations.macbook.system` build，结果均为 `0`。系统升级没有要求修改 `system.stateVersion = 7`、`home.stateVersion = "26.05"` 或 `nixpkgs.hostPlatform = "aarch64-darwin"`。

在 commit `0e5e028` 的当次批准记录完成后，维护者手动执行 Phase 3 activation，命令退出状态为 `0`。当前 nix-darwin system profile 为 generation 3，generation 2 是直接回滚点。9 个旧文件在 activation 前已逐项移动到权限受限的本机私有备份目录；Home Manager 没有强制覆盖 regular file。

自动检查确认：

- Git、Fish、Atuin hook、Helix 与 Starship 等目标均链接到当前 Home Manager generation；
- Nix-managed CLI 在 PATH 中优先于同名 Homebrew 或 Apple CLI；
- Git identity include 与 GitHub credential helper 可用，身份值未进入仓库或验证记录；
- Atuin config/data、Fish universal variables、GitHub auth 和其他可变状态仍为本机可写数据；
- 私有备份 archive 在 activation 后仍可读取。

维护者随后在全新终端中确认 Fish/Starship 启动、Up/Down 与 Ctrl+Up Atuin、Zoxide-backed `cd`、既有 Atuin history、Helix `ayu_dark`、GitHub CLI auth 和 tmux 全部正常。激活前保留的旧终端/tmux 状态不会自动获得新 key bindings；全新终端加载新 generation 后行为正常。

chezmoi source repository 中的重复所有权尚待独立移除和审阅。在完成该交接前，不得对已由 Home Manager 接管的目标运行 `chezmoi apply`。真实备份路径、批准记录、完整命令结果和回滚细节保留在 Draft PR #20，不写入本 inventory。
