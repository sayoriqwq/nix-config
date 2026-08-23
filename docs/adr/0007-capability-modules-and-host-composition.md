# ADR-0007：主机按能力模块显式组合

- **状态：** V3 修订后保留核心约束
- **日期：** 2026-07-29

> 2026-08-24 修订：Issue #179 批准、Issue #196 首次实现的 V3 模型把“纵向能力模块”拆为 Software Capability 纵轴与 Executable Intent 横轴。本文关于显式 imports、无 registry、无平台 bundle、真实变化才建立 adapter 的约束继续有效；`modules/home/capabilities/` 作为终态 host interface 的路径结论已由 [`module-boundaries.md`](../architecture/module-boundaries.md) 取代。

## 背景

早期架构把 `common`、`desktop` 与平台模块同时当作复用边界和主机组合接口，实际实施时导致 nixbox 一次 import 意外继承 macOS 的完整桌面应用与兼容路径。主机今后只选择纵向的能力模块；能力模块由细粒度基础配置实现，并共同封装系统与用户层的软件和稳定配置托管、状态路径声明、可变状态边界及平台 adapter。macbook 组合全量工作站能力，nixbox 与 server 按需求选择子集并增加自身能力；不再建立强制全选的 `common`/`desktop` bundle，也不因平台名称预建通用 Linux 用户层。

只有真实变化形成 seam 时才建立 adapter。基础配置属于能力模块实现，不成为 host 必须理解或逐项组合的 interface；验证以能力模块和最终 host composition 为测试面。Host 通过显式 `import` 选择一项能力，`import` 本身就是采用声明，不再叠加 `capabilities.*.enable` 一类全局注册机制。Host 对一项能力只选择一次；能力合同必须明确公开其软件与配置所有权、状态路径、系统服务或网络影响及人工关卡，不能用封装隐藏安全副作用。

## 目录与依赖方向

- `modules/home/capabilities/` 是纯用户能力的 host interface；
- `modules/home/common/`、`desktop/` 与 `darwin/` 保存可被能力复用的基础配置，不再作为 host bundle；
- 真实跨层能力放在 `modules/capabilities/<name>/`，由 `home.nix` 与已证明的平台 adapter 组成；
- 纯用户能力不为形式统一创建空 system adapter；平台名称本身不形成 seam。

## 结果

- macbook 从“大而全的继承源”变为全量能力 composition；
- nixbox 与 server 可以复用同一能力实现，又不会自动继承无关 GUI、凭据或兼容路径；
- import graph 直接成为能力矩阵的可审计实现；
- 能力内部需要维护 state path metadata 与跨层合同，但这种局部复杂度换取了 host interface 的稳定和安全可见性。

## 被否决的方案

- 继续扩大 `common` / `desktop` / `linux` bundle：需求与平台混合，无法阻止隐式全选；
- `capabilities.*.enable` registry：与显式 import 重复，制造第二个事实来源；
- 为每个能力创建 Darwin/NixOS pass-through adapter：只有一个行为时是虚构 seam，增加浅层 indirection。
