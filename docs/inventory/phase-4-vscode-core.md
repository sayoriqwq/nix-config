# Phase 4 VS Code 应用与核心配置迁移记录

本文记录 Issue [#24](https://github.com/sayoriqwq/nix-config/issues/24)
的盘点证据、所有权边界、离线验证计划、人工 activation 清单与回滚步骤。
本文不授权 activation、扩展变更、Homebrew cleanup、可变状态删除或合并
Pull Request。

## 1. 迁移前证据

盘点日期：2026-07-24。

- `/Applications/Visual Studio Code.app` 为唯一发现的 VS Code 应用，版本
  `1.107.1`、Apple Silicon 架构，由 Homebrew cask
  `visual-studio-code 1.107.1` 登记。
- 应用内官方 CLI 位于
  `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`。
- 当前用户设置为
  `~/Library/Application Support/Code/User/settings.json`，SHA-256 为
  `bb11db37f6151814fc49a57f04e03a90bf12e5c578d5046f1b90396c48865db6`。
- 当前 `mcp.json` 为空；没有 `keybindings.json`、`tasks.json` 或 snippet
  文件，因此本 Issue 不声明这些对象。
- `~/.vscode/argv.json` 包含 VS Code 自身维护的 crash reporter 实例标识，
  不适合作为稳定配置提交。
- Settings Sync、History、globalStorage、workspaceStorage 与扩展目录均已
  存在并包含可写状态。

## 2. 机密审查

迁移前对 `settings.json` 与空的 `mcp.json` 执行了只读字段名扫描，未发现
token、secret、password、API key、credential、private endpoint、账户或
URL 类字段。人工阅读确认拟提交的 `settings.jsonc` 只包含编辑器外观、交互、
Git 行为和扩展的非机密偏好。

以下内容明确禁止进入普通 Nix 或公开 Git：

- 登录 token、Settings Sync 凭据和账户标识；
- 私有 MCP server、连接信息和环境变量；
- `argv.json` 中的 crash reporter 实例标识；
- 扩展、workspace 或项目目录中的私有配置。

## 3. 所有权

| 对象 | 终态所有者 | 说明 |
| --- | --- | --- |
| VS Code macOS 应用 | nix-darwin Homebrew cask | 只安装一份上游签名应用 |
| `settings.json` | Home Manager | 直接链接仓库中的 JSONC，保留注释和尾随逗号 |
| 扩展目录 | VS Code 可变状态 | 本 Issue 不安装、升级或删除扩展；留给 #25 |
| Settings Sync 与登录态 | VS Code 可变状态 | 不读取、不链接、不备份到仓库 |
| History、globalStorage、workspaceStorage | VS Code 可变状态 | 保持原目录可写 |
| `mcp.json` | 本机可写状态 | 当前为空，不为未来私有连接取得所有权 |
| `argv.json` | VS Code 本机状态 | 保留 locale 与 crash reporter 实例状态 |
| keybindings、tasks、snippets | 未声明 | 当前没有有效文件，不创建空声明 |

本阶段不启用 `programs.vscode`，因此 Home Manager 不会从 Nixpkgs 安装第
二份 VS Code，也不会生成扩展链接。锁定的 Home Manager 26.05 虽声明
`userSettings` 接受路径，内部更新设置合并仍把路径当作 attrset，无法求值；
即使不设置 profile，启用该模块也会附带可能创建 `globalStorage/storage.json`
的 activation script。为保留 JSONC 原文并严格避开可变状态，本阶段只使用
精确的 `home.file` 单文件链接，不升级锁定依赖。扩展 UI 安装与自动更新能力
保持现状。只有 `settings.json` 会成为只读的声明式链接；需要修改设置时应先
改仓库、构建并经过 activation，而不是在 UI 中直接写入。

## 4. Settings Sync 边界

现有 Settings Sync 数据和凭据保持原位。迁移后 VS Code 可以继续读取同步
状态，但仓库中的 `settings.jsonc` 是设置事实来源；Settings Sync 不应覆盖
本机只读链接。扩展同步策略不在本 Issue 中决定，待 #25 根据实际扩展清单
单独审阅。

## 5. 离线验证

在 activation 前运行：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link --print-out-paths
```

还要检查：

1. 生成的 Brewfile 只新增 `visual-studio-code` cask，cleanup 仍为 `none`；
2. Home Manager generation 包含 VS Code `settings.json`，不包含应用包、
   VS Code profile activation script、`argv.json`、`mcp.json`、
   keybindings、tasks、snippets 或扩展目录；
3. 生成设置与仓库 `settings.jsonc` 字节一致；
4. activation 前 live-file 冲突扫描只报告预期的 `settings.json`。

本次验证结果：

- `nix fmt -- --check .`：退出状态 `0`；原生 `nixfmt` 继续报告目录参数弃用
  warning，此全仓 formatter 调整不属于 #24；
- `nix flake check`：退出状态 `0`；按当前平台省略不兼容的 Linux systems；
- `nix build .#darwinConfigurations.macbook.system --no-link
  --print-out-paths`：退出状态 `0`；
- closure 中没有 VS Code Nix package 或 VS Code profile activation script；
- 生成 Brewfile 只包含 `cask "visual-studio-code", trusted: true`，全局
  cleanup 仍为 `none`；
- generation 中 `Code/User` 下只有 `settings.json`，其 SHA-256 与仓库源
  文件同为
  `bb11db37f6151814fc49a57f04e03a90bf12e5c578d5046f1b90396c48865db6`；
- 全量 Home Manager live regular-file 冲突扫描只有现有
  `~/Library/Application Support/Code/User/settings.json` 一项。

## 6. 人工 activation 关卡

维护者审阅 Draft PR 与最终精确 commit 后，另行批准才可执行：

1. 完全退出 VS Code，防止退出时用内存中的旧设置覆盖迁移结果；
2. 建立权限受限、commit 专属的私有备份目录；
3. 核对现有 `settings.json` 的 SHA-256，再把它移入备份目录，为 Home
   Manager 的声明式链接让出路径；
4. 确认 `mcp.json`、`argv.json`、扩展目录和所有可变状态未列入移动清单；
5. 执行维护者批准的：

   ```fish
   sudo -H /run/current-system/sw/bin/darwin-rebuild switch \
     --flake '/Users/sayori/Desktop/nix-config#macbook'
   ```

Agent 不在未获批准时执行上述备份、移动或 activation。

## 7. 人工验收

activation 后由维护者确认：

1. `/Applications/Visual Studio Code.app` 仍只有一份且可以启动；
2. 外观、字体、编辑器、终端和 Git 设置与迁移前一致；
3. UI 中的 Settings 编辑入口不会静默覆盖声明式文件；
4. 既有扩展仍可加载、安装和更新，没有被批量改变；
5. History、最近项目、workspaceStorage、登录态与 Settings Sync 状态仍在；
6. 空的 `mcp.json` 与 `argv.json` 仍是普通可写文件。

## 8. 回滚

若应用或设置异常：

1. 执行 `sudo -H /run/current-system/sw/bin/darwin-rebuild --rollback`；
2. 若上一代未恢复普通 `settings.json`，先退出 VS Code，再从私有备份复制回
   原路径并恢复原权限；
3. Homebrew cask 不因 cleanup 被自动卸载；如应用本体异常，按 activation
   前版本记录单独恢复，不运行 `brew cleanup` 或 `--zap`；
4. 不删除或回滚扩展、History、globalStorage、workspaceStorage、登录态和
   Settings Sync 数据。
