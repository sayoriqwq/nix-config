# Zed Nightly 更新与回滚

Zed Nightly 的版本事实只来自根 `flake.lock`。应用自更新关闭；仓库不运行定期
sync 的 GitHub Action。维护者按需要手动更新、验证并审阅锁文件变更。

## 手动更新

在最新 `main` 的干净工作区上创建专用分支，再执行：

```fish
git status --short --branch
git switch -c codex/update-zed-nightly-YYYYMMDD
nix flake update zed
```

🔄 创建隔离的更新分支，并只更新 Zed input。

确认文件变化只有 `flake.lock`，然后审阅 Zed revision、version 和必要的传递
lock nodes：

```fish
git diff --name-only
git diff -- flake.lock
```

🔍 确认更新范围并审阅锁文件 diff。

运行适用的验证：

```fish
nix fmt -- --check .
nix flake check
nix build .#zed-nightly --no-link --print-out-paths
nix build .#darwinConfigurations.macbook.system --no-link --print-out-paths
```

✅ 验证格式、Flake outputs、Nightly package 和 macOS host build。

验证通过后，将只包含 `flake.lock` 的变更提交为普通 PR，等待维护者审阅。更新
不会自动合并、激活真实机器或上传缓存。

## 失败与暂停

- fetch、求值或 build 失败时不合并更新分支，继续使用当前 `flake.lock`；
- 如果更新超出 `flake.lock`，先停止并检查工作区，不把无关变化带入更新提交；
- 暂停更新只需暂不执行手动 sync，不需要禁用或修改 GitHub Actions。

## 回滚

如果新 Nightly 离线或真实机器验证失败：

1. 未合并时，关闭或放弃更新 PR，继续使用当前 lock；
2. 已合并但尚未 activation 时，revert 对应的锁文件提交并重新 build；或
3. 已 activation 时，先切回上一 nix-darwin generation，再 revert lock 更新。

`flake.lock` 回滚只回滚应用 package。Zed 的 live settings、扩展、登录态、
History 和 workspace/session 不随 generation 回滚，必须使用迁移前私有备份恢复。
