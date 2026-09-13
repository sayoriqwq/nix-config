# Zed 更新与配置应用

当前决定见 [ADR-0006](../adr/0006-zed-nightly-upstream-flake-and-cache.md)。macOS 使用原生 Preview 自更新；Linux 使用锁定的 release Stable。Mac 固定包与 `sync-zed-preview` 已删除，旧操作只保留在 Git 历史。

## 配置写入范围

Home Manager 持续合并 settings、keymap 与 tasks，文件仍可由 Zed 修改。声明字段优先，settings 递归合并，keymap 按 context、tasks 按 label 合并；其他字段与任务保留。当前稳定材料在 `software/zed/capabilities/gui-editor/`，任务通过 `zed.addTask` 提供。

跨主机复用重点是所选设置和编辑习惯，允许 Preview/Stable 版本差异。`secondary-shift-g` 在 Mac 表示 Cmd，在 Linux 表示 Ctrl；现场已有 `cmd-shift-g` 不应当作不同使用意图。上游合并按字面键名处理，因而可能保留两个等价别名。

删除声明不会删除现场遗留字段、快捷键或任务；需要删除时另行明确目标。数组通常被声明数组替换，不能假定逐项保留。合并会丢失注释与原有格式。当前上游 JSON5 解析失败会退回空对象/数组，存在覆盖风险；它不是备份机制。

## 激活前

1. 在目标机器读回三份现场文件，核实 JSON/JSONC 解析成功且根类型正确（settings 对象、keymap/tasks 数组）；发现错误就停止并先修复。
2. 比较已声明字段，将想保留的现场修改保存到仓库，审阅 diff；不要顺带导入账号、令牌、私有路径或全部配置。
3. 退出 Zed，避免应用在合并期间再次写入；复制现存 settings.json、keymap.json、tasks.json 到私有、带时间的备份目录，确认副本一致。缺失文件记录为缺失，不造假备份。
4. 检查候选与整机影响，确认目标、revision、执行窗口、停止条件和已知可用 generation 后，再按[日常维护](daily-nix-maintenance.md)执行授权的激活。正常 Mac 激活也会重新执行这些合并。

检查、备份、退出应用和激活须针对具体操作执行，本手册本身不表示已经执行或授权。复杂动作应由当前任务准备短入口，不要求维护者手抄 Store path 或长参数。

## 读回与恢复

激活后确认三份文件可解析、仍是可写普通文件，声明字段生效，未声明的测试字段与任务保留。启动 Zed 检查主题、键位、LazyGit 任务和默认编辑器；仅 Nix 求值通过不能代替真实使用验收。

失败时停止继续应用，退出 Zed，从本次私有副本恢复可写文件并核对内容；必要时按授权回滚 generation。先修复或撤销 Git 中的失败声明，否则下一次激活会再次应用。generation 回退不能保证恢复可写配置或原生应用版本，缺失前不存在的文件也不能靠副本自动撤销。

## 应用更新

Mac 使用 Preview 自身的更新入口；确认 CLI `zed` 和图形入口指向同一原生应用。应用安装与版本恢复使用原生流程，Nix 不提供 Mac Zed 恢复包。

Linux 随 Linux nixpkgs input 更新。求值精确目标：

```fish
nix eval --raw .#packages.x86_64-linux.zed-stable.outPath
```

🔎 只读取锁定的目标路径，不证明缓存完整，也不编译 Zed。

更新前必须真实复制完整签名闭包：先用 USTC，缺失时 Mac 从官方 cache 获取并经已有 SSH transport 中继到 nixbox。由当前任务准备使用求值结果的短命令，不能手抄 Store path。nixbox 确认该路径有效后才构建 toplevel；两处缓存均不完整则保留原 lock，禁止源码构建回退。此修改若不更新 Linux input，不需要重复下载现有 Zed 闭包。
