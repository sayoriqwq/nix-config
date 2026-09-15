# ADR-0007：Software / Intent / Host 显式组合

- **状态：** 已接受；取代 ADR-0002
- **日期：** 2026-07-29
- **V3 修订：** 2026-08-24，Issues #179、#196–#199、#206
- **组合简化：** 2026-09-08，移除没有 state 读取需求的函数管线
- **模型修订：** 2026-09-14，按可选择行为组织接口，撤销强制 Primary / Extension 分类

- **使用需求修订：** 2026-09-16，围绕三台 Host 的命令行、终端入口、代码工作与诊断组合；移除独立 checks 层
- **目录简化：** 2026-09-16，Software 内部平铺，公共基础内容统一归入 shared

## 背景

早期 `common`、`desktop` 与平台 bundle 同时承担复用和 Host interface，导致 nixbox 容易隐式继承 macbook 的 GUI、兼容层和未确认软件。随后“纵向能力模块”又把单软件 owner 与跨软件需求混在一起，难以表达 Zed task、Zsh integration 等窄 contribution。

后续检查确认所有公开能力只追加模块，不读取或修改已有组合状态。为这些声明维护 `empty`、`addModules`、`realize` 与 `lib.pipe` 管线增加了接口和调用负担，普通 attrset 与列表拼接已能表达现有行为。

## 决策

采用三类长期对象：

1. `software/<software>/` 聚合同一软件的声明、素材、实现及外部边界，公开可选择的行为；
2. `intents/<intent>.nix` 表达维护者希望整体选择的使用需求，只调用 Software public interface；不要求多个软件或必须存在接线逻辑；
3. `hosts/<host>/` 是最终 caller，显式选择 Intent、独立 Software platform module 与机器事实。

Software public interface 直接暴露包含模块列表的 attrset；有真实参数的行为接口返回同型 attrset。`intents/lib.nix` 只用 `lib.concatMap` 按顺序拼接 `darwinModules`、`nixosModules`、`homeModules`，把缺失字段视为空列表，并返回三个显式列表。Import graph 表达声明选择，不增加第二份选择清单。

每个行为的依赖必须明确：由 Nix 提供的程序通过模块选择、包依赖或确定路径表达，原生安装提供的程序则就近说明外部前提。依赖另一个 Intent 恰好提供程序，说明组合边界仍需修正。公开接口无需分为 Primary、Extension 或 Contribution 三种类型，是否独立选择由实际行为决定。Software 内部默认平铺，移除 `capabilities/<行为>/` 固定层级；需要组合或参数化的公开行为由 `default.nix` 表达；简单 Software 的单文件平台声明也可由 Intent 或 Host 直接选择，不增加空转发入口。只有实际文件规模需要时才分组，文件名使用连字符，配置机制或平台在文件名中表达。

只有 package、配置、service、network effect 或人工关卡真的不同才建立 platform seam。共享主题、外观与公共账号声明统一放在 `shared/`，替代原 `modules/`。准入条件是多个实际消费者且不归单个 Software；消费者直接引用具体文件，不提供全选 interface。只有一个 Software 使用的辅助实现归回该 Software。

Software 就近说明实际受管配置、外部可写内容、数据和必要路径。社区可写合并可以持续管理选定字段；init 只初始化缺失目标。二者按具体需求选择，不由 Software 名称推导整份文件的所有权，也不维护全局 state-path metadata。

### 按真实工作需求组合

三台 Host 共享 `shell-work` 的 Fish 和 CLI／TUI；两台工作站选择 `primary-terminal`，macbook 额外选择 WezTerm + Zsh 的 `terminal-compatibility`。编辑器、开发运行时、GitHub 协作与容器开发独立于兼容入口；`code-development` 以 `withVscode` 表达 macbook 与 nixbox 的真实差异。server 只选择命令行工作和诊断需求，不继承工作站后排除 GUI。

工具的 Zsh adapter 随其所属需求选择，仅在已启用 Zsh 时生效；选择工具不能额外开启兼容入口。保留普通三列表组合，不为每项软件预建安装／配置开关或新的关系框架。普通 App 是否继续托管另行确认。

维护者选择删除独立 checks 与 flake checks 输出，验证采用格式化、相关 Host 求值、必要的 nh 构建和本次功能现场验收。nh 不提供行为回归检查，原自动化保护随删除一同退出，不建立替代检查目录。

## 结果

- Software ownership 局部、可导航；跨软件关系只有 Intent 一个落点；
- Host 选择显式，三台机器互不继承；
- 普通参数化接口能表达窄配置贡献，不需要通用关系框架或强制主次分类；
- Software 声明不依赖 Intent helper，组合不再维护额外的 state 协议；
- 删除空 adapter、旧 wrapper 或 metadata 不改变用户行为；
- 显式 imports 较多，但审阅者可以直接看到最终 composition。

## 被否决的方案

- 扩大 `common` / `desktop` / `linux` bundle；
- `capabilities.*.enable` registry 或自动目录发现；
- 通用 workflow/relation/contribution framework；
- 为每个 Software 预建空 Darwin/NixOS adapter；
- 让 Host import owner 私有 primitive 后自行拼装。

## 复审条件

实际修改负担、隐含依赖或新的使用需求足以触发复审。历史模型提供取舍依据，不限制维护者重新设计；新增抽象仍须说明相对普通模块组合的实际收益。
