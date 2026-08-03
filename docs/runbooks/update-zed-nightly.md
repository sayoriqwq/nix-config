# Zed Nightly 更新与回滚

Zed Nightly 的版本事实只来自根 `flake.lock`。应用自更新关闭；定时任务只创建
Draft PR，不自动批准、合并或激活机器。

## 日常更新

`.github/workflows/update-zed-nightly.yml` 每日运行一次，也可以通过
`workflow_dispatch` 手工触发。工作流：

1. 如果已有来自 `automation/zed-nightly` 的开放 PR，则跳过本次更新；
2. 只运行 `nix flake update zed`，任何超出 `flake.lock` 的文件变化都会失败；
3. 运行 formatter、Flake check 和 `x86_64-linux` Nightly package build；
4. 推送固定分支并创建 Draft PR；
5. 不执行 merge、activation 或缓存上传。

工作流使用固定 commit 的 `actions/checkout` 与 `cachix/install-nix-action`。
Nix installer 只配置 ADR-0006 接受的 Zed Cachix URL 和公钥，并明确拒绝自动
接受其他 Flake 的 `nixConfig`。

固定分支模型依赖仓库启用“合并后自动删除 head branch”，即
`delete_branch_on_merge = true`。更新 PR 合并后，GitHub 删除
`automation/zed-nightly`；下一次定时运行再从当时的 `main` 创建同名分支。
该设置作用于仓库内所有已合并 PR 的 head branch，但不会删除关闭且未合并的
PR 分支。可用以下只读命令检查设置是否漂移：

```bash
gh api repos/sayoriqwq/nix-config --jq .delete_branch_on_merge
```

## 失败与暂停

- fetch、求值或 build 失败会让 GitHub Actions 保持失败状态；当前 lock 不变；
- 已有开放更新 PR 时不会继续叠加新的 Nightly；
- 临时暂停时在 GitHub Actions 中禁用该 workflow，或删除/注释 `schedule` 后
  通过普通 Draft PR 审阅；
- 若已合并的更新 PR 仍留下 `automation/zed-nightly`，先检查
  `delete_branch_on_merge` 是否被关闭；恢复设置并确认该 PR 的锁文件变化已进入
  `main` 后，删除遗留分支，再通过 `workflow_dispatch` 创建一次新运行；
- 若更新 PR 关闭但未合并，GitHub 会保留分支。后续 non-fast-forward 失败应保持
  可见，由维护者审阅关闭原因、分支 diff 与当前 `main` 后，决定删除或重建该
  自动化分支；workflow 不允许 force-push。

## 回滚

如果新 Nightly 离线或真实机器验证失败：

1. 不合并更新 PR，继续使用当前 lock；或
2. 若已经合并但尚未 activation，revert 该更新提交并重新 build；或
3. 若已经 activation，先切回上一 nix-darwin generation，再 revert lock 更新。

`flake.lock` 回滚只回滚应用 package。Zed 的 live settings、扩展、登录态、
History 和 workspace/session 不随 generation 回滚，必须使用迁移前私有备份恢复。
