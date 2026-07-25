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

## 失败与暂停

- fetch、求值或 build 失败会让 GitHub Actions 保持失败状态；当前 lock 不变；
- 已有开放更新 PR 时不会继续叠加新的 Nightly；
- 临时暂停时在 GitHub Actions 中禁用该 workflow，或删除/注释 `schedule` 后
  通过普通 Draft PR 审阅；
- 若 `automation/zed-nightly` 分支因为未合并关闭的 PR 而无法快进，保留失败，
  由维护者审阅后删除或重建该自动化分支，不允许 workflow force-push。

## 回滚

如果新 Nightly 离线或真实机器验证失败：

1. 不合并更新 PR，继续使用当前 lock；或
2. 若已经合并但尚未 activation，revert 该更新提交并重新 build；或
3. 若已经 activation，先切回上一 nix-darwin generation，再 revert lock 更新。

`flake.lock` 回滚只回滚应用 package。Zed 的 live settings、扩展、登录态、
History 和 workspace/session 不随 generation 回滚，必须使用迁移前私有备份恢复。
