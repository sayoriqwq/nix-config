# ADR-0002：Home Manager 用户层边界（历史）

- **状态：** 已被 ADR-0007 取代
- **日期：** 2026-07-17
- **取代日期：** 2026-07-29

本 ADR 曾把 `common`、`desktop`、平台与 server 横向分层同时作为复用结构和 host 组合 interface。Phase 6 实施证明该模型会让 nixbox 一次 import 意外继承 macbook 的完整桌面、Zsh/WezTerm 兼容路径与未确认应用，因此不再作为实现依据。

当前规范见 [ADR-0007](0007-capability-modules-and-host-composition.md)：Home Manager 仍只管理用户配置，但 host 按需求显式 import 纵向能力模块；细粒度基础配置只作为能力内部 implementation；跨层安全副作用通过平台 adapter 公开。

Server 的 Ubuntu standalone Home Manager 过渡方案也已取消，见 [ADR-0008](0008-direct-nixos-server-replacement.md)。
