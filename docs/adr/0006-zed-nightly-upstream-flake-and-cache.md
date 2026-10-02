# ADR-0006：Zed 按平台安装，共享可写配置声明

状态：已接受；2026-09-14 修订，2026-10-03 简化日常配置应用并补入 Homebrew 安装声明。范围为 Zed 安装、配置写入与二进制更新。

## 背景

历史 source Flake 在缓存缺失时触发大量 Rust 构建；官方 Nightly 二进制又不能满足 nixbox 的缓存路径。2026-08-24 因此选择 Mac Preview 与 Linux release Stable。2026-09-13 Mac 改用原生可写应用；本次删除不再使用的固定 Preview package 与更新器，旧实现留在 Git 历史。

跨主机需要复用编辑习惯，不要求相同通道或版本。仅初始化不能把后来保存的设置重新应用，因此本次明确采用社区 Home Manager 的可写合并。

## 决定

- macbook 由 Homebrew cask `zed@preview` 保存原生 Preview 的安装需求，应用自行更新，Home Manager 的 `package = null`。直接使用 cask 提供的 `zed-preview` 命令，`z` 快捷与默认编辑器跟随该名称，并验证 CLI 与 Finder/Raycast 指向同一应用。Nix 不固定或恢复 Mac 应用版本。
- nixbox 使用锁定的 Linux release `pkgs.zed-editor`，关闭应用自更新，保留 `packages.x86_64-linux.zed-stable` 验证入口。server 不选择 Zed。
- 配置采用 `programs.zed-editor` 的 `mutableUserSettings`、`mutableUserKeymaps`、`mutableUserTasks`。每次激活按上游机制合并声明；settings 声明字段优先，keymap 按 context、tasks 按 label 合并。用户额外字段继续保留。
- settings、keymap 和 Intent 提供的任务是所选稳定声明；应用账号、扩展安装、会话、数据库、缓存与用户内容保持外部。明确希望保留的现场配置修改先保存到声明，未保存修改可以被覆盖，不增加常规比对或备份流程。
- 不实现本地合并引擎，不保留 Mac 固定包、恢复包或专用 updater。默认编辑器、快捷命令与任务集成保留。

## Linux 二进制边界

Linux input 更新时先取得 `zed-stable` 精确 outPath，以真实 `nix copy` 验证完整闭包；`nix path-info` 和 `.narinfo` 不足以证明所有 NAR 可下载。优先 USTC；缺失时 Mac 可从官方 cache 获取已签名闭包，并经既有 SSH transport 中继同一路径到 nixbox。

只有 nixbox 上确认精确路径有效后才构建其 toplevel。两处 cache 均不完整则停止更新并保留原 lock，不在 nixbox 回退源码构建，不引入 Cargo/Crane、Zed source Flake、额外缓存、通用代理或 server builder。Mac 只中继二进制，不编译或成为常驻代理。

## 代价与验证

可写合并不是双向同步或完整恢复：声明删除不会清除现场旧值；注释和格式会被重写；当前上游在现场解析失败时可能退回空配置并覆盖文件。维护者接受未保存配置丢失，日常应用不再以现场解析检查或三份文件快照为前置关卡；已发现的配置错误按实际问题修复。Git 负责已入仓声明的回退，generation 不负责恢复可写文件。具体步骤见 [Zed 手册](../runbooks/update-zed-preview.md)。

Preview/Stable 的 schema 与功能可能不同，需要验证实际使用的设置和任务。修改模块时验证平台包选择、任务组合和上游生成合并动作；更新 Linux 包时额外执行完整缓存验证。真实应用、退出程序、升级和恢复仍需当前任务授权；本 ADR 不声称已经激活。

源码构建、双平台 Nightly 和强制统一版本均不满足当前需求；本次不改变 Linux 网络、服务器或数据管理设计。上游合并语义、包供应链或平台配置兼容性发生实际问题时复审。
