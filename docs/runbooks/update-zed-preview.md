# Zed 更新与配置应用

当前决定见 [ADR-0006](../adr/0006-zed-nightly-upstream-flake-and-cache.md)。macOS 使用原生 Preview 自更新；Linux 使用锁定的 release Stable。Mac 固定包与 `sync-zed-preview` 已删除，旧操作只保留在 Git 历史。

## 配置写入范围

Home Manager 持续合并 settings、keymap 与 tasks，文件仍可由 Zed 修改。声明字段优先，settings 递归合并，keymap 按 context、tasks 按 label 合并；其他字段与任务保留。当前稳定材料在 `software/zed/`，任务通过 `zed.addTask` 提供。

跨主机复用重点是所选设置和编辑习惯，允许 Preview/Stable 版本差异。`secondary-shift-g` 在 Mac 表示 Cmd，在 Linux 表示 Ctrl；现场已有 `cmd-shift-g` 不应当作不同使用意图。上游合并按字面键名处理，因而可能保留两个等价别名。

删除声明不会删除现场遗留字段、快捷键或任务；需要删除时另行明确目标。数组通常被声明数组替换，不能假定逐项保留。合并会丢失注释与原有格式。当前上游 JSON5 解析失败会退回空对象/数组，存在覆盖风险；它不是备份机制。

## 配置应用

1. 只有本次明确希望保留的现场修改才保存到仓库并审阅；不顺带导入账号、令牌、私有路径或整份现场配置。
2. 本次修改 Zed 配置时，退出 Zed 后按[日常维护](daily-nix-maintenance.md)应用；nh 展示候选变化并在整机激活前确认。

正常 Mac 激活也会重新执行合并。维护者接受未保存配置被覆盖，日常不再强制逐字段比对、现场解析检查或三份文件快照。已知配置错误按实际问题修复，不以另建保全流程作为普通维护的前提。

## 读回与恢复

本次改变 Zed 配置后，启动 Zed 确认所改设置、键位或任务生效；仅 Nix 求值通过不能代替实际使用验证。没有相关变化时不重复全套验收。

配置失败时修复或用 Git 撤销本次声明，再重新应用；若撤销的是新增字段或任务，还需按需删除对应的现场遗留项。只有涉及系统版本的问题才考虑 generation 回滚。Git 不恢复未入仓的现场修改，generation 也不恢复原生应用版本，不为这些内容另建恢复系统。

## 应用更新

Mac 使用 Preview 自身的更新入口；确认 CLI `zed` 和图形入口指向同一原生应用。应用安装与版本恢复使用原生流程，Nix 不提供 Mac Zed 恢复包。

Linux 随 Linux nixpkgs input 更新。求值精确目标：

```fish
nix eval --raw .#packages.x86_64-linux.zed-stable.outPath
```

🔎 只读取锁定的目标路径，不证明缓存完整，也不编译 Zed。

更新前必须真实复制完整签名闭包：先用 USTC，缺失时 Mac 从官方 cache 获取并经已有 SSH transport 中继到 nixbox。由当前任务准备使用求值结果的短命令，不能手抄 Store path。nixbox 确认该路径有效后才构建 toplevel；两处缓存均不完整则保留原 lock，禁止源码构建回退。此修改若不更新 Linux input，不需要重复下载现有 Zed 闭包。
