# ADR-0007：Software / Intent / Host 显式组合

- **状态：** 已接受；取代 ADR-0002
- **日期：** 2026-07-29
- **V3 修订：** 2026-08-24，Issues #179、#196–#199、#206

## 背景

早期 `common`、`desktop` 与平台 bundle 同时承担复用和 Host interface，导致 nixbox 容易隐式继承 macbook 的 GUI、兼容层和未确认软件。随后“纵向能力模块”又把单软件 owner 与跨软件需求混在一起，难以表达 Zed task、Zsh integration 等窄 contribution。

## 决策

采用三类长期对象：

1. `software/<software>/` 是纵向 owner，公开命名 Primary Capability 与 Extension；
2. `intents/<intent>/` 是横向纯组合，只调用 Software public interface；
3. `hosts/<host>/` 是最终 caller，显式选择 Intent、独立 Software platform module 与机器事实。

`intents/lib.nix` 只维护 `darwinModules`、`nixosModules`、`homeModules` 三个显式列表。Import graph 是唯一选择事实；不增加 registry、relation、workflow、substrate、platform namespace、自动扫描或强制 bundle。

只有 package、配置、service、network effect 或人工关卡真的不同才建立 platform seam。Configuration primitive 可以留在 `modules/`，但必须有实际消费者，不能成为 Host 的全选 interface。

可变 state 继续由应用/维护者拥有。必要边界在最近的 owner 或 runbook 表达，不维护没有 production consumer 的全局 state-path metadata。

## 结果

- Software ownership 局部、可导航；跨软件关系只有 Intent 一个落点；
- Host 选择显式，三台机器互不继承；
- Extension 能表达窄贡献，不需要通用关系框架；
- 删除空 adapter、旧 wrapper 或 metadata 不改变用户行为；
- 显式 imports 较多，但审阅者可以直接看到最终 composition。

## 被否决的方案

- 扩大 `common` / `desktop` / `linux` bundle；
- `capabilities.*.enable` registry 或自动目录发现；
- 通用 workflow/relation/contribution framework；
- 为每个 Software 预建空 Darwin/NixOS adapter；
- 让 Host import owner 私有 primitive 后自行拼装。

## 复审条件

只有当三列表组合无法表达多个已证明的真实需求，或显式 import graph 成为可量化的主要维护瓶颈时，才通过新 ADR 复审；不能因目录较多提前引入框架。
