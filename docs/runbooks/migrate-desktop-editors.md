# VS Code 与 Zed Nightly 迁移手册

本手册只描述人工关卡。Agent 的离线 build、ADR 接受或 Draft PR 都不等同于真实
机器 activation、默认编辑器切换或旧应用卸载授权。

## 迁移前状态

- VS Code 由 Home Manager 安装，live settings 与扩展目录保持可写；
- Homebrew VS Code 暂时保留为回退应用；
- Zed Preview 暂时位于 `/Applications/Zed Preview.app`；
- Zed settings、keymap、tasks 与扩展保持可写，不由 Nix Store 链接；
- Zed Nightly 将成为唯一的 `EDITOR` / `VISUAL` 所有者；VS Code 与 Helix 保留为
  显式备用编辑器。

## 私有备份

第一次 activation 前，在仓库外建立权限为 `0700` 的私有目录，并复制：

- `~/.config/zed/settings.json`、`keymap.json`、`tasks.json`、`debug.json`（存在时）；
- `~/Library/Application Support/Zed/extensions/` 的扩展清单或所需状态；
- VS Code 的 live settings 与扩展清单；
- 需要人工恢复的编辑器专属本地配置。

不要把登录凭证、token、数据库、History、workspace/session 或完整扩展工作目录
提交到 Git。

## activation 前人工检查

1. 关闭 Zed Preview、Zed Nightly 与 VS Code；
2. 在 Zed live `settings.json` 中确认 `"auto_update": false`。seed-only 模型不会
   为已有文件强制写入该键；
3. 记录 settings/keymap/tasks 的 SHA-256 与扩展 ID/版本；
4. 确认当前 generation 和上一代回滚入口；
5. 只对 PR 中已构建并审阅的精确 commit 执行 activation。

## 首次 Cachix 引导

当前 nix-daemon 在首次 activation 前还没有读取 Zed Cachix 配置。直接构建可能
退回本地编译大量依赖；这不是应当等待完成的正常路径。维护者批准 activation 后，
第一次切换使用与 ADR-0006 完全相同的 URL 和公钥：

```fish
sudo darwin-rebuild switch \
  --flake 'github:sayoriqwq/nix-config/<approved-revision>#macbook' \
  --option extra-substituters 'https://zed.cachix.org' \
  --option extra-trusted-public-keys 'zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU='
```

`<approved-revision>` 必须替换为已审阅并批准的完整提交 SHA。临时参数不增加新
信任边界，只为首次构建提前提供仓库已经声明的缓存配置。切换成功后 daemon 会从
正式配置读取这两项，后续普通 activation 不再需要临时参数。

## 双安装验收

activation 后保留 Zed Preview 与旧 Homebrew VS Code。明确从
`~/Applications/Home Manager Apps/` 启动 Nix 生成的 Zed Nightly，验证：

- 显示名、bundle ID、版本和 CLI 都属于 Nightly，不是 Preview 或 Stable；
- `zed --wait` 可作为 `EDITOR` / `VISUAL`；
- settings、keymap、tasks 仍是普通可写文件，内容与 activation 前 hash 一致；
- 登录态、项目、远程开发、扩展和 workspace/session 行为符合预期；
- VS Code 备用路径仍能打开需要的项目。

## 回滚与清理关卡

应用或系统声明异常时，先使用上一代 nix-darwin generation 回滚。live 编辑器状态
异常时，从私有备份人工恢复；不要声称 generation 能回滚可变状态。

只有 Nightly 验收通过并获得新的单独批准后，才可以依次处理：

- 卸载 Zed Preview；
- 卸载旧 Homebrew VS Code 并修正旧 `code` CLI；
- 移除已明确排除的扩展；
- 关闭或清理 Settings Sync 云端遗留状态。

每个删除动作都应先再次解析精确目标，并保留可恢复路径。
