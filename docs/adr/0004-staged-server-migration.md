# ADR-0004：Server 分阶段迁移（历史）

- **状态：** 已被 ADR-0008 取代
- **日期：** 2026-07-17
- **取代日期：** 2026-07-29

本 ADR 建立的风险原则继续成立：系统安装、网络恢复、Secret、业务恢复和数据验证必须拥有独立故障边界；任何 disk、network、SSH、firewall、reinstall、reboot 或 production data 动作都需要当次人工批准。

原方案中的 Ubuntu standalone Home Manager 过渡层已经取消。当前迁移顺序和控制链路以 [ADR-0008](0008-direct-nixos-server-replacement.md) 与 `docs/plans/migration-roadmap.md` 为准：只读盘点 → 最小 NixOS/disko → nixbox 隔离 VM 验证 → 经批准直接替换 → Secret → 业务恢复。
