# Phase 4 VS Code 应用与核心配置迁移记录

本文记录 Issue [#24](https://github.com/sayoriqwq/nix-config/issues/24)
的盘点证据、终态所有权、离线验证、人工 activation 清单、定期配置回流与
回滚步骤。本文不授权 activation、Homebrew 定向卸载、Settings Sync 云端数据
删除、扩展变更或合并 Pull Request。

模型调研与一手来源见
[VS Code 声明式配置模型调研](../plans/phase-4-vscode-configuration-research.md)。

## 1. 迁移前证据

盘点日期：2026-07-24。

- `/Applications/Visual Studio Code.app` 为唯一发现的 VS Code 应用，版本
  `1.107.1`、Apple Silicon 架构，由 Homebrew cask
  `visual-studio-code 1.107.1` 登记。
- 应用内官方 CLI 位于
  `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`。
- 锁定的 nixpkgs 提供官方 Microsoft `pkgs.vscode 1.119.0`，支持
  `aarch64-darwin`、`x86_64-linux` 等目标平台。
- 当前 user settings 为
  `~/Library/Application Support/Code/User/settings.json`，是普通可写文件，
  SHA-256 为
  `bb11db37f6151814fc49a57f04e03a90bf12e5c578d5046f1b90396c48865db6`。
- 当前 `mcp.json` 为空；没有 `keybindings.json`、`tasks.json` 或 snippet
  文件，因此本 Issue 不声明这些对象。
- `~/.vscode/argv.json` 包含 VS Code 自身维护的 crash reporter 实例标识，
  不适合作为稳定配置提交。
- Settings Sync 当前启用并保存过 Settings、Extensions、UI State 等同步状态。
- 应用内官方 CLI 记录到 54 个扩展；扩展分类与版本策略留给 Issue #25。

## 2. 维护者批准的终态

维护者在 grilling、方案 pressure test 与一手资料调研后批准：

- Home Manager desktop 用户层安装 `pkgs.vscode`；
- 只为包名 `vscode` 配置精确 unfree allowlist；
- 应用版本只随 `flake.lock` / nixpkgs 更新，VS Code `update.mode` 保持
  `none`；
- shared desktop 模块保存跨 macOS/NixOS 的应用能力和 JSONC 基线；
- macOS adapter 只处理 live settings 路径与首次初始化；
- live `settings.json` 保持普通可写文件，允许 VS Code UI 和扩展写入；
- Nix 只在目标完全不存在时复制基线；任何已存在文件或符号链接都保持原样；
- Settings Sync 逐步退出，Git/Nix 基线与定期人工回流取代云端配置同步；
- 不在 #24 实现 watcher、交互式 activation 或自动双向 reconciler；
- macOS 与 NixOS 的扩展允许按 shared、Darwin、Linux、local 分类不同。

这是一种“可复现基线 + 可写 live 状态 + 定期人工回流”模型，不承诺两次维护
之间的完整运行态与 Git 完全一致。

## 3. 机密审查

迁移前对 `settings.json` 与空的 `mcp.json` 执行只读字段名扫描，未发现
token、secret、password、API key、credential、private endpoint、账户或
URL 类字段。人工阅读确认仓库基线只包含编辑器外观、交互、Git 行为和扩展的
非机密偏好。

定期回流时必须重新执行审查，不能因为初始文件安全就信任未来扩展写入。以下
内容明确禁止进入普通 Nix 或公开 Git：

- 登录 token、Settings Sync 凭据和账户标识；
- 私有 MCP server、连接信息和环境变量；
- `argv.json` 中的 crash reporter 实例标识；
- 扩展、workspace 或项目目录中的私有路径与连接信息。

## 4. 所有权

| 对象 | 终态所有者 | 说明 |
| --- | --- | --- |
| VS Code 应用与版本 | Home Manager / Nix | 官方 Microsoft `pkgs.vscode` |
| JSONC 基线 | Git / Nix | shared desktop 源文件 |
| live `settings.json` | VS Code / 用户 | 仅缺失时从基线初始化，此后保持可写 |
| 扩展目录 | VS Code 可变状态 | #24 不改变；#25 再分类 |
| Settings Sync | 退出中 | 先停用 Settings，#25 后关闭整个 Sync |
| History、globalStorage、workspaceStorage | VS Code 可变状态 | 不读取、不链接、不回流 |
| `mcp.json` | 本机可写状态 | 当前为空，不为未来私有连接取得所有权 |
| `argv.json` | VS Code 本机状态 | 保留 locale 与 crash reporter 实例状态 |
| keybindings、tasks、snippets | 未声明 | 当前没有有效文件，不创建空声明 |

`pkgs.vscode` 属于 unfree 软件。仓库使用
`nixpkgs.config.allowUnfreePredicate`，只允许 `lib.getName pkg == "vscode"`；
不得改成全局 `allowUnfree = true`。

## 5. Settings 初始化语义

Darwin adapter 使用一个内部 seed 工具，interface 为：

```text
seed-vscode-settings TARGET BASELINE
```

行为必须满足：

1. `TARGET` 是已存在普通文件：退出 `0`，内容、权限与时间戳不变；
2. `TARGET` 是已存在符号链接，包括 dangling symlink：退出 `0`，不替换；
3. `TARGET` 不存在：在目标目录原子创建 `0644` 的基线副本；
4. 检查与创建之间发生竞争：`mv --no-clobber` 保留先出现的目标；
5. 不创建指向 Nix Store 的 live 链接；
6. 不比较、合并或自动回写已有 live 内容。

当前 Mac 已有 settings 文件，因此首次 activation 不会修改它。未来 NixOS
adapter 应复用同一基线，但使用 Linux 路径
`~/.config/Code/User/settings.json`；该 adapter 不在 #24 中提前实现。

## 6. Settings Sync 退出

真实 activation 前由维护者在当前 VS Code 中执行
`Settings Sync: Configure`，取消 `Settings` 类别，并确认 live
`settings.json` 没有因云端 merge/replace 改变。

Issue #25 完成扩展分类后再关闭整个 Settings Sync。关闭时初期不选择清除
云端数据，保留短期回退窗口；是否最终删除微软云端旧数据是另一个需要单独
批准的动作。

关闭 Sync 不等于退出 GitHub/Microsoft 登录，也不授权删除本机登录态或
SecretStorage。

## 7. 定期人工回流

配置回流不由 activation 自动执行。维护时：

1. 使用应用内官方 CLI 记录实际应用与扩展：

   ```fish
   '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code' \
     --list-extensions --show-versions
   ```

   Homebrew cask 卸载后改用用户 Nix profile 中的 `code`。

2. 比较 live settings 与仓库基线：

   ```fish
   diff -u \
     modules/home/desktop/editors/vscode/settings.jsonc \
     "$HOME/Library/Application Support/Code/User/settings.json"
   ```

3. 人工判断每个变化属于 shared、Darwin、Linux、workspace 还是 local；
4. 排除 token、私有 URL、账号、机器路径和扩展临时状态；
5. 只把批准的长期偏好手工编辑进仓库基线；
6. 运行 secret scan、formatter、flake check 和两平台相关 build；
7. 通过普通 Git diff、PR 审阅和 activation 发布，不直接复制整个 live 文件。

Issue #25 应对扩展采用相同原则：UI 扩展可以存在，但只有经过分类和供应链审阅
的集合才提升到 Nix 声明。

## 8. 离线验证

在 activation 前运行：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link --print-out-paths
```

还要检查：

1. `pkgs.vscode` 可以通过精确 unfree predicate 求值，其他 unfree 包仍被拒绝；
2. macOS system closure 包含 `vscode-1.119.0`；
3. 生成 Brewfile 不声明 `visual-studio-code`，cleanup 仍为 `none`；
4. Home Manager generation 包含 VS Code 应用，不链接 `Code/User/settings.json`
   或扩展目录；
5. 当前 live settings 的 SHA-256 在 build 前后保持不变；
6. seed 工具通过不存在目标、已有文件、已有 symlink 和 no-clobber 测试；
7. staged secret scan 无泄漏。

## 9. 人工 activation 关卡

维护者审阅 Draft PR 与最终精确 commit 后，另行批准才可执行：

1. 记录当前 nix-darwin 与 Home Manager generation；
2. 完全退出 VS Code；
3. 把 live `settings.json` 复制到权限受限的 commit 专属私有备份，不移动原文件；
4. 在 Settings Sync 配置中取消 `Settings` 类别并复核 live hash；
5. 执行维护者批准的：

   ```fish
   sudo -H /run/current-system/sw/bin/darwin-rebuild switch \
     --flake '/Users/sayori/Desktop/nix-config#macbook'
   ```

6. 从精确路径启动 Nix 应用：

   ```fish
   open "$HOME/Applications/Home Manager Apps/Visual Studio Code.app"
   ```

Agent 不在未获批准时执行上述备份、Sync 变更或 activation。

## 10. 人工验收

activation 后由维护者确认：

1. Nix VS Code 版本为 `1.119.0`，可以从 Home Manager Apps 启动；
2. 用户 profile 中的 `code` 指向 Nix package；
3. Homebrew 应用仍保留，验收期间不依赖 LaunchServices 的模糊选择；
4. live `settings.json` 仍是原普通可写文件，hash、权限与内容未被 seed 修改；
5. Settings UI 和扩展仍能写 User Settings；
6. 外观、字体、编辑器、终端和 Git 行为符合基线；
7. 既有 54 个扩展仍可加载、安装和更新，没有被批量改变；
8. History、最近项目、workspaceStorage、登录态和本机状态仍在；
9. Settings 类别不再由 Sync 写入。

验收通过后，如要卸载 Homebrew cask，必须再次列出精确命令、备份与回滚，并
由维护者单独批准；不得运行 `brew cleanup` 或 `--zap`。

## 11. 回滚

若 Nix 应用异常：

1. 执行 `sudo -H /run/current-system/sw/bin/darwin-rebuild --rollback`；
2. Homebrew cask 在定向清理前仍可作为应用回退；
3. 如果 live settings 被人工测试改变，从私有备份恢复或手工撤销；
4. 不删除扩展、History、globalStorage、workspaceStorage、登录态或
   SecretStorage。

live settings 与 UI 安装扩展不属于 generation，不能通过 generation
自动回滚。Homebrew cask 若已在后续单独批准中卸载，则应用回退需要重新安装
已记录版本或切回可用的 Nix generation。
