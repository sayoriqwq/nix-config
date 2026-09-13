# 日常 Nix 维护

适用：本机 nh 4.4.2、`darwinConfigurations.macbook` 和集成式 Home Manager。在准备应用的 nix-config checkout 根目录执行。原则见[主工作站管理](../architecture/workstation-management.md)；普通本地维护不要求 PR。

## 修改配置后应用

先审阅并提交当前任务的声明变更，保留无关工作。修改设置无需更新输入：

```fish
nh darwin switch . -H macbook --ask --show-activation-logs
```

🔧 构建候选、展示包差异，确认后激活整份 Mac 配置；按提示输入系统密码。

确认前核对目标、变更范围和已知可用 generation；包差异不包含所有偏好、可写文件或外部应用变化。真实机器操作仍遵循 [AGENTS.md](../../AGENTS.md) 的授权条件。应用后按本次变更检查实际效果；终端启动问题需区分重新加载配置与完整重启进程。

## 准备包集更新候选

这会修改当前 checkout 的 lock 并构建候选，不能当作纯只读查询。先完成或隔离已有工作；此例仅更新 Mac 的包集输入，不自动更新其他独立来源：

```fish
nh darwin build . -H macbook --update-input nixpkgs-darwin --diff always
```

🔎 获取所选渠道的新输入并构建，与当前系统比较包变化，不激活机器。

更新一个包集可能影响多个软件与依赖；固定 tag 的独立输入需要显式改变版本选择。构建复用已有产物与可用缓存，但仍可能下载或本地编译。构建失败也可能已经修改 lock。

审阅源码和 lock 差异，接受时提交候选，再运行上一节不带更新参数的 switch；使用同一候选，避免确认前重新选择版本。放弃时仅撤销本次候选改动，保留其他工作。面向“只查更新”的临时候选快捷入口尚未实现，当前不使用不存在的 `nx` 命令。

## 恢复已知可用配置

```fish
sudo darwin-rebuild --list-generations
```

🕘 查看保留的代际，识别更新前已验收的恢复点。

```fish
sudo darwin-rebuild --rollback
```

↩️ 仅在上一代就是所需恢复点时使用；该命令会激活上一代配置，需要相应授权。

连续多次变更时应从列出的代际选择已知可用版本，再使用 `--switch-generation`，不能盲目反复退一代。恢复后验证实际功能，并修复或撤销 Git 中的失败声明。原生应用、defaults 和应用数据不保证随代际对称恢复；保留恢复点直到新配置验收完成。
