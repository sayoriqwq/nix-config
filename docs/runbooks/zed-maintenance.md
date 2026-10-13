# Zed 使用与配置维护

macOS 使用原生 Preview，Linux 使用锁定包集中的 Stable；配置与任务共用 [software/zed](../../software/zed/home-manager.nix)。整体职责见[架构](../architecture.md)。

## 安装与更新

Mac 安装需求由 Homebrew cask `zed@preview` 保存，应用位于 `/Applications/Zed Preview.app`，日常通过应用自身更新。CLI 使用 `zed-preview`，`z`、`EDITOR` 和 `VISUAL` 跟随它；Homebrew 激活只安装缺失应用，Nix 代际不恢复原生版本。

Linux 使用 `zeditor`，随 Linux nixpkgs 输入更新。需要核对所选包时执行：

```fish
nix eval --raw .#packages.x86_64-linux.zed-stable.outPath
```

🔎 读取锁定目标，不编译、不激活；实际构建与应用按 Linux 主机的条件和本次变更范围处理。

更新 Linux Zed 前先取得所选包的完整签名闭包：优先 USTC 缓存，缺失时由 Mac 从官方缓存取得，再经已有 SSH 通道中继到 nixbox。由当次操作使用求值结果准备命令，不手抄 Store 路径；nixbox 确认闭包可用后才构建系统。两处缓存均不完整时保留原 lock，不悄然退回源码构建；未改变 Linux 输入时无需重复取得现有闭包。

## 配置写入

Home Manager 每次激活都合并 settings、keymap、tasks，文件保持可写。settings 声明字段优先并递归合并，keymap 按 context、tasks 按 label 合并；额外字段与任务保留，数组通常按声明替换。

删除声明不会删除现场遗留值；需要删除时明确对应字段、键位或任务。合并会丢失注释与原有格式，现有 JSON5 解析失败可能按空对象或数组处理，遇到语法错误先修复。

想保留的现场修改先保存到 [settings](../../software/zed/settings.json)、[keymap](../../software/zed/keymap.json) 或持有任务的 Intent。应用账号、扩展、会话与用户内容通过 Zed 自身机制恢复，不随这三份配置纳管。

本次修改 Zed 配置时先退出 Zed，再按[日常维护](daily-nix-maintenance.md)应用，随后启动确认所改行为。无相关变化时无需重复全套检查。

## 编辑器任务与恢复

[code-development](../../intents/code-development.nix) 提供 LazyGit 任务及程序。打开项目后按 `Cmd+Shift+G`（Linux 为 `Ctrl+Shift+G`），或从 `Run → Spawn Task` 选择 `LazyGit`；应打开当前项目，按 `q` 正常退出。

CLI 打开项目会传入当前 Shell 环境；从 Finder、Dock 等图形入口打开时，Zed 会读取登录 Shell 与项目环境。遇到命令缺失时先区分入口、当前项目和 PATH，再核对程序归属。[Zed 环境说明](https://zed.dev/docs/environment)

项目依赖由项目材料恢复；本仓库的 LazyGit 任务只检验编辑器到受管 CLI 的接线，不代表其他项目的 mise/direnv 或 Python 环境已经可用。

配置失败时修复或撤销本次声明后重新应用；撤销新增字段或任务时，按需删除其现场遗留项。涉及系统版本时再考虑代际回滚，未入仓修改和原生应用版本另按各自恢复材料处理。
