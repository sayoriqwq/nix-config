# 从使用问题出发选择工作站管理方式

研究日期：2026-09-13。本文是探索记录，不是已接受的 ADR，也不批准新一轮迁移。现有 nix-config 作为案例，不作为必须维持或扩大其规模的理由。

## 1. 先确定希望获得什么

建议讨论的核心问题是：以可接受的日常维护成本，让工作环境持续可用，并在变化或故障后恢复真正需要的部分。这是研究提出的目标表述，仍需维护者确认优先级。

“托管”容易混合以下需求，而它们需要的保证并不相同：

| 需求 | 可观察的成功标准 | 不必预先承诺的东西 |
| --- | --- | --- |
| 日常可用 | 找得到应用，入口唯一，更新不打断工作 | 所有软件由同一工具安装 |
| 换机恢复 | 装回需要的工具，恢复关键设置，继续工作 | 每个 GUI 应用与旧机器版本完全相同 |
| 开发复现 | 同一项目得到指定工具链与依赖 | 全局环境与项目环境完全一致 |
| 多机复用 | 在目标机器复用选中的工作习惯和能力 | Mac 与 Linux 安装全部相同软件 |
| 变更可控 | 更新前知道影响，失败后有可用退路 | 回滚软件等于回滚所有应用数据 |
| 数据恢复 | 能找回笔记、项目、数据库等实际内容 | 配置仓库能代替备份 |

需要进一步确认的是恢复的深度：“装回同类工具”“恢复习惯”“恢复精确程序版本”“恢复某一时刻数据”是不同承诺。Apple 的 Time Machine 专门处理文件与环境恢复，软件声明不是它的等价替代。[Apple 备份说明](https://support.apple.com/en-us/104984)

## 2. 生态中的工具分别解决什么

| 工具或方式 | 主要能力 | 边界与代价 |
| --- | --- | --- |
| 官方安装器 / 应用更新器 | 沿产品原生流程安装和更新 | 仍需安排安装清单、关键配置与数据恢复；更新能力因产品而异 |
| Homebrew / Brewfile | 包安装、升级，以及声明需要安装哪些软件 | 安装清单不等于锁住完整依赖图或恢复所有用户配置 |
| Nix / Nixpkgs | 用明确输入构建包与依赖，版本并存、profile 代管理 | 需要维护声明、输入版本和兼容性；不接管全部可变状态 |
| Home Manager | 声明用户软件、配置文件及用户服务 | 被接管文件与应用自行修改设置之间需要明确边界 |
| nix-darwin | 在 macOS 上声明系统选项及服务，并可组织 Homebrew 等操作 | 管理的是其声明范围，不能当成对整个 macOS 与应用数据的镜像 |
| NixOS | 将 Nix 扩展到 Linux 系统配置 | 不应据此要求 Mac 桌面采用相同的控制粒度 |
| mise、项目开发环境 | 按项目选择工具链；Nix dev shell 也可用于项目 | 应按依赖复现需求选择，没必要让所有项目共享一套全局版本 |
| chezmoi 等配置工具 | 复用 dotfiles 并处理机器差异 | 不因此得到包依赖图、完整系统或数据恢复 |
| nh | 改善 Nix 相关操作的命令与输出体验 | 不替用户决定上述职责如何划分 |

上述能力依据：[Brewfile 官方文档](https://docs.brew.sh/Brew-Bundle-and-Brewfile)、[Nix 原理](https://nix.dev/manual/nix/2.34/introduction)、[Home Manager 手册](https://nix-community.github.io/home-manager/)、[nix-darwin 选项](https://nix-darwin.github.io/nix-darwin/manual/)、[mise 工具管理](https://mise.jdx.dev/dev-tools/)、[chezmoi 定位](https://www.chezmoi.io/what-does-chezmoi-do/)。表中取舍是本研究的工程判断。

Nix 可以只用于一个项目，不要求同时采用 Home Manager、nix-darwin 或 NixOS。其官方入门就包括临时环境、声明式开发环境和固定 Nixpkgs 输入。[Nix 入门](https://nix.dev/tutorials/first-steps/)、[固定输入](https://nix.dev/tutorials/first-steps/towards-reproducibility-pinning-nixpkgs)

因此，“集中记录”不等于“全部安装到 Nix Store”；“可复现”也不意味着已经有完整的备份、永久可获取的软件产物或恢复演练。

## 3. 当前探索实际暴露了什么

### 应用更新与基线重应用存在目标冲突

当前 lock 中的 Home Manager `copyApps` 把 GUI 应用复制为可写目录，激活时用包含 checksum、delete 和可写权限选项的 rsync 从声明产物同步。因此不能笼统说“Nix 安装的 GUI 一定完全不能自更新”；但副本即使已更新，再应用原声明仍会把它同步回声明版本。[当前锁定的实现](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/targets/darwin/copyapps.nix)

案例推论：若要求原生应用任意独立更新，同时要求下次基线应用原样保留该更新，就不能再让旧声明无条件拥有同一个应用目录。可选办法包括让声明承担版本更新、改变该目录的所有权，或把恢复版本与日常运行版本明确分开。迁出只是其中一种。

VS Code 的 `update.mode = none` 则是另一层问题：它禁用了原生更新渠道。是否修改它，取决于希望采用原生更新还是 Nix 更新；设置本身并不能证明应该迁移全部 GUI 软件。[VS Code 更新说明](https://code.visualstudio.com/docs/enterprise/updates)

### 命令入口有两个维护来源

Pinshift 旧包装与项目自行注册的新入口并存，根因是重复所有权。删除过时声明可以直接解决，无需调整其他应用，也无需删除项目目录。本轮已移除对应 Software、Host 引用及专属测试。

### 迁移会产生额外工作

本轮 VS Code 移动后，Raycast 搜索失效；macOS 索引正常，重启 Raycast 后相同查询恢复。这支持“启动器未及时刷新”的判断，不证明程序安装损坏。迁移成本必须包含启动器、CLI、登录启动及权限回读，而不是仅统计改了几行 Nix。

签名完整性检查失败也是诊断信号，不能单凭它推导“必须迁出 Nix”。应继续区分打包处理、复制过程、实际启动与更新影响。

## 4. nh 可以简化哪部分

本机已安装 **nh 4.4.2**；[仓库声明](../../software/nh/capabilities/nix-operations/home.nix)已启用它。它不是尚待引入的新方案。

nh 提供 NixOS、Home Manager、nix-darwin 的操作入口，改善构建进度、版本差异、确认、搜索和清理体验。若问题是命令难记、输出难读，先用好已有 nh 比迁移安装来源更直接。[nh 官方项目](https://github.com/nix-community/nh)

本机 `nh darwin switch --help` 与 `nh home switch --help` 表明它们选择配置输出，没有按软件名称选择激活的选项。当前仓库只有集成到 nix-darwin 的 Mac Home Manager，没有独立 `homeConfigurations` 输出，因此不能把 `nh home switch` 直接视为现成的单应用通道。

| 操作 | 真正的范围 |
| --- | --- |
| 更新一个 flake input | 更新该来源；若它是 nixpkgs，可能影响许多包，不等于只更新一个应用 |
| 构建一个包或主机输出 | 获得产物，可复用已构建结果或缓存；不等于从头编译一切，也不等于应用 |
| 激活配置 | 执行所选配置的激活动作；一次小修改不自动使激活范围缩成该软件 |
| 回滚 generation/profile | 切换所管软件或配置代；不是自动撤销用户数据迁移 |

依据：[flake update](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-flake-update)、[nix build](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-build)、[HM 激活](https://nix-community.github.io/home-manager/internals/activation.html)、[profile rollback](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-profile-rollback)。

Nix 本身也提供独立包 profile 和单包升级。这说明“用 Nix”不必意味着“每次整体管理工作站”。但另加 profile 会增加恢复与 PATH 管理责任，尤其不能再让 HM 同时声明同一入口。[profile upgrade](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-profile-upgrade.html)

## 5. 不预设答案的三种方案

| 方案 | 何时有价值 | 需要接受什么 |
| --- | --- | --- |
| 原生桌面 + 安装清单 + 配置与数据恢复 | 主要关心日常顺手和换机恢复，不要求每个 GUI 精确版本一致 | 安装与配置恢复分工，精确版本回退能力依产品而定 |
| 按需求使用 Nix | 某些项目或环境有实际复现价值，其他应用更需要独立更新 | 工具可能多于一种，但每个对象必须有明确负责人 |
| 以 Nix 声明为主要运行依据 | 版本与配置一致性、审阅、重建及系统服务管理的收益很高 | 更新进入声明流程，承担包兼容性与集成维护成本 |

这是比较框架，不是推荐立刻改成第二种。选择性管理也会造成复杂性；只有分工减少实际冲突时才有价值。

现有仓库已经有中间路径：[Homebrew 模块](../../software/homebrew/capabilities/non-destructive-application-management/darwin.nix)关闭激活时自动更新、升级和清理；nix-darwin 可以保存安装需求而不要求这些应用都成为 Nix 包。Brewfile 也可独立维护。两种入口不应重复拥有同一份安装清单。[nix-darwin Homebrew 行为](https://nix-darwin.github.io/nix-darwin/manual/#opt-homebrew.onActivation.upgrade)

当前 [VS Code 声明](../../software/vscode/capabilities/editor-compatibility/home.nix)只为首次设置提供基线；[seed-files 实现](../../modules/home/desktop/editors/seed-files.nix)遇到已有路径就跳过。这能保留现场调整，却不会自动把后续现场设置记录进 Git。若“恢复我后来调好的设置”很重要，仍需显式选取和保存，而不能把首次模板误当完整恢复方案。

## 6. 下一步应验证问题，而非继续搬应用

先保留可用状态，暂停按软件名单批量迁移。对一个真实场景进行小实验，并记录耗时和影响：

1. **日常更新**：选一个现存痛点，先试现有渠道；若是 Nix 命令体验，再评估 nh 是否已足够。
2. **换机恢复**：用临时环境验证能恢复哪些工具和关键设置；明确哪些仍需账号登录、数据备份或人工操作。
3. **项目复现**：挑一个有真实依赖问题的项目验证开发环境，避免先把工作站全部重构。

每个实验只回答：原问题是否消失、会影响什么、需要维护什么、失败如何返回可用状态。所花维护时间、更新阻碍频率、恢复成功程度，比 Nix 覆盖率更适合作为指标。

某个软件值得改变管理方式，应有四项说明：具体痛点、当前方式下的最小修复、换方式后的新增收益、迁移及长期维护代价。若无法说明，暂不迁移。

## 7. 仍待澄清的选择

- 哪种损失最重要：日常维护打断、换机重配、项目依赖不一致，还是服务故障恢复？
- 恢复需要做到熟悉可用，还是必须回到精确版本与配置？哪些对象例外？
- 希望现场设置自由变化，还是愿意让所选设置以声明为准？
- 能接受多大更新延迟与维护时间？是否真的需要跨平台复用该软件？

这些答案决定工具分工。当前还没有足够证据为整个工作站确定唯一最优组合。

## 8. 研究验证范围

读取现有 Flake、Host、nh、Homebrew、mise、编辑器基线声明与锁定 Home Manager 源码；只读检查本机 nh 版本及帮助，并对照上述官方来源。本文不更改任何安装、激活、服务、权限、数据或已接受架构决策。

文档验收检查相对链接与 `git diff --check`。本轮不运行系统构建或激活，不把前几轮构建结果当成本研究的验证结果。上游文档会演进；涉及本机命令的结论以已检查的 nh 4.4.2 为准。
