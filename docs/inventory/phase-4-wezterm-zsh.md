# Phase 4 WezTerm + Zsh 迁移记录

本文记录 Issue [#23](https://github.com/sayoriqwq/nix-config/issues/23) 的决策、迁移前证据、所有权交接、离线验证、人工 activation 清单与回滚步骤。本文不授权 activation、Homebrew cleanup 或删除可变数据。

## 1. 支持边界

维护者把终端与 shell 的四种潜在组合收敛为两套受支持环境：

- 主环境：Ghostty + Fish；
- 备用/兼容环境：WezTerm + Zsh。

WezTerm 明确保留 `/bin/zsh -l`，不迁移到 Fish。Ghostty + Zsh 与 WezTerm + Fish 不作为承诺维护和验收的组合，但不人为禁止 Home Manager 的低风险 shell integration 在其他组合中偶然可用。

`v` 与 `z` 是独立的跨 shell 用户行为：无参数时分别执行 `code .` 与 `zed .`，有参数时原样转发。它们不归属于某个终端或某个编辑器配置迁移。

## 2. 迁移前证据与备份

- 采集日期：2026-07-22。
- 当前应用：Homebrew cask `wezterm`，CLI 版本 `wezterm 20240203-110809-5046fc22`。
- live WezTerm 配置：`~/.wezterm.lua`；chezmoi source：`dot_wezterm.lua.tmpl`。
- live Zsh 配置：`~/.zshrc`、`~/.zprofile` 与 `~/.zshenv`。`dot_zshrc` 仍存在于 dotfiles 仓库，但已被 `.chezmoiignore` 排除，不再部署。
- WezTerm source 通过 chezmoi 模板读取共享 YAML 主题；live 文件是当时的渲染结果。首次迁移直接固化已确认的 live 颜色，不重构共享主题系统。
- live `.zshrc` 相比被忽略的 source 多出 Antigravity PATH；`.zprofile` 还加载 OrbStack，`.zshenv` 加载 Cargo 环境。Home Manager 目标以 live 行为为证据，并用已有 Home Manager integrations 替代可声明部分。
- 敏感字段扫描未发现 token、密码、私钥、API key 或 credential 内容。

迁移前私有备份位于 `/Users/sayori/wezterm-zsh-phase4.wCdeuL`，目录权限为 `0700`，文件权限为 `0600`。备份不包含 `~/.zhistory`、Atuin 数据库、窗口状态或其他可变数据，且本体不进入 Git。

| 文件 | SHA-256 |
| --- | --- |
| live `.wezterm.lua` | `2fa85652fb0d0dd404a1134cd7d5d848be80a55499e1d330ee4d78983f4ffdfd` |
| live `.zshrc` | `b9e3040dec4d2014c2b36e73292d195de5fd4961d9c264c16f5d00dda1a4760d` |
| live `.zprofile` | `544401191400e72be1058514e668e538dbde1d0be377ca13b7c39d48af3c8cdd` |
| live `.zshenv` | `787ab203279ada7ab10fd7c252f9b414ef4185d632ca2a9d2d38307cd8cca606` |
| chezmoi WezTerm source | `64e1cb8b1f07b034d192e03ffbe0125018d46053d48a164e8ba24866357f23c5` |
| 被忽略的 chezmoi Zsh source | `39d614207c3e3079d2f67027c81c71a9a14768085b67294c1ef42d4577c81258` |

## 3. 目标所有权与模块边界

| 目标 | 声明所有者 | 模块 |
| --- | --- | --- |
| WezTerm macOS 应用 | nix-darwin Homebrew cask | `modules/darwin/homebrew.nix` |
| `~/.wezterm.lua` | Home Manager | `modules/home/darwin/wezterm/` |
| `~/.zshrc`、`~/.zprofile`、`~/.zshenv` | Home Manager | `modules/home/darwin/shells/zsh.nix` |
| Fish 与 Zsh 的 `v`、`z` | Home Manager | `modules/home/darwin/user-behaviors/editor-launchers.nix` |
| `~/.zhistory` 与其他 mutable state | 本机可写数据 | 不进入 Nix Store |

`modules/home/darwin.nix` 只组合模块。WezTerm 的基础设置、按键与主题分别保存在 `settings.nix`、`keybindings.nix` 与 `theme.nix`，由 Nix 生成完整 Lua；没有启用会无条件安装 Nixpkgs WezTerm 的 `programs.wezterm`。Home Manager 的 Zsh 模块会把 Nix Zsh 放入用户 profile 以提供模块依赖，但 WezTerm 的 `default_prog` 仍精确执行 macOS `/bin/zsh -l`。

Zsh 继续使用可写的 `~/.zhistory`，并保留 Starship、mise、autosuggestions、syntax highlighting、fzf、zoxide、Atuin、thefuck、eza、原按键、GHCup、OpenClaw、OrbStack 与 Cargo 环境。Home Manager 对 Ghostty、eza、lazygit 和 direnv 的正常 Zsh integration 保持启用；这些是获维护者接受的低风险默认行为，不改变两套环境的验收边界。

## 4. dotfiles handoff

dotfiles handoff 使用独立分支 `codex/phase-4-wezterm-zsh-handoff`：

- 删除 `dot_wezterm.lua.tmpl`，使 chezmoi 不再拥有 `~/.wezterm.lua`；
- 删除已被忽略的 `dot_zshrc` 参考副本，避免形成过期的第二真相来源；
- 更新 README、Chezmoi 指南与终端架构文档；
- 使用 `chezmoi --source /Users/sayori/Desktop/dotfiles managed` 验证 WezTerm/Zsh 目标均不再出现；
- 未执行 `chezmoi apply`，未修改任何 live 配置。

handoff 合并并以 Git fast-forward 同步到本机 chezmoi source 前，不得对这些目标运行 `chezmoi add`、`re-add` 或 `apply`。

## 5. 离线验证结果

最终执行以下仓库约定命令，均返回 `0`：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link
```

`nix flake check` 提示跳过当前主机不兼容的 Linux formatter；macOS system build 产物为 `/nix/store/icvdzn0xqg9zhqdw1kfnxirvrkkyaa8h-darwin-system-26.05.c3e90c8`。

使用未 activation 的 Home Manager generation `/nix/store/6z3r5d6f4nc2qclzdcanwg9jgqzgq8zr-home-manager-generation` 验证：

- 当前 WezTerm live 配置与 Nix 生成配置的 `wezterm show-keys --lua` SHA-256 均为 `8636b184e09585acdb35a7be3b3ea72bf0a53a9f3cfaad86dbbca0e34a83a26e`，按键行为一致；
- WezTerm CLI 成功载入生成配置，默认程序为 `/bin/zsh -l`，字体、透明度、blur、主题与全部 11 条 pane 快捷键保留；
- `/bin/zsh -n` 通过 `.zshrc`、`.zprofile` 与 `.zshenv` 语法检查；`fish -n` 通过 `v`、`z` 两个函数检查；
- 生成 closure 中不存在 Nixpkgs WezTerm package，Brewfile 同时包含 `ghostty` 与 `wezterm` cask；
- `homebrew.onActivation.cleanup` 求值为 `none`；
- Home Manager generation 不包含 `.zhistory`。

| 生成文件 | SHA-256 |
| --- | --- |
| `.wezterm.lua` | `56ce53653bd267141877af687163b54587404099fc658318a60d2af33f4a4adf` |
| `.zshrc` | `38581719461be5e27b60b12a435ff733df651f818416ec59433b3e0299814763` |
| `.zprofile` | `7664fa83ac6e62f42d31a40b21b35d1c30907dd86dd0a93b0ac410e979ae0dfe` |
| `.zshenv` | `c9400adb359107765d9341b15b1acddb68c9641eadd371594a44d62e7b7d71cd` |
| Fish `v` | `f585fece4b6f4f6548ecfd3f266909c5e7ea5cdb937168433cbc1cf42ecb0172` |
| Fish `z` | `35af65c15e0e73c7cc803f2f0bb1c36bfc750399595654da1e8d62df8d63ddc5` |

以上 build 与 CLI 检查不构成 activation 授权。

## 6. 人工 activation 清单

1. 审阅并合并 nix-config 与 dotfiles 两个 Draft PR，记录当次 nix-config commit 和上一代 nix-darwin generation。
2. 只用 Git fast-forward 同步本机 chezmoi source；不要运行全局 `chezmoi apply`。
3. 确认 `chezmoi managed | rg 'wezterm|zshrc|zprofile|zshenv'` 无输出，并复核私有备份 hash。
4. 退出 WezTerm；把现有 `~/.wezterm.lua`、`~/.zshrc`、`~/.zprofile` 与 `~/.zshenv` 移入私有备份的 `displaced/`，避免 Home Manager 与 regular file 冲突。不要移动 `~/.zhistory`。
5. 在当前 PR/Issue 给出这一次 activation 的明确批准后，由维护者执行：

   ```fish
   sudo -H /run/current-system/sw/bin/darwin-rebuild switch \
     --flake '/Users/sayori/Desktop/nix-config#macbook'
   ```

6. 确认 `brew list --cask wezterm` 成功，四个 Home Manager 目标均为指向 Nix Store 的链接，`~/.zhistory` 仍是可写数据。
7. 打开 WezTerm，确认进入 Zsh，主题/字体/透明度与 pane 快捷键正常；运行 `echo $0` 与 `ps -p $$ -o command=`，确认实际 shell 为 `/bin/zsh -l`。
8. 在 WezTerm/Zsh 与 Ghostty/Fish 中分别验证：`v`、`z` 无参数打开当前目录；带文件或目录参数时原样转发。
9. 验证 Zsh prompt、上下历史、`Ctrl+Up` Atuin、`cd`/zoxide、`ls`/eza、`lg`、direnv、mise、GHCup、OpenClaw、OrbStack 与 Cargo 环境；确认 history、Atuin 数据库和应用状态未被重置。

## 7. 回滚

1. 在仍打开的终端中执行 `sudo -H /run/current-system/sw/bin/darwin-rebuild --rollback`，恢复上一代系统与 Home Manager generation。
2. 从 `/Users/sayori/wezterm-zsh-phase4.wCdeuL/live/` 恢复四个原始 live 文件，并复核 SHA-256。
3. 在 dotfiles 仓库 revert handoff，使用 Git fast-forward 同步本机 chezmoi source；确认唯一所有者恢复后，才可对精确目标执行 chezmoi 操作。
4. Homebrew 应用不会随 generation 自动卸载；本次无需卸载 WezTerm。禁止运行 cleanup 或 zap。
5. 不删除或覆盖 `.zhistory`、Atuin 数据、窗口状态、登录态或其他可变数据。
