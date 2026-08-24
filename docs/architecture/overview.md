# 整体架构

## 1. 目标

仓库用一个显式、可审计的 import graph 管理三台不同角色的机器。架构优化目标是：

- 一个软件只有一个 package/config/service owner；
- 跨软件需求集中在 Intent，不扩散到 Host；
- Host 仍能直接看出自己选择了什么；
- Check、Operation 与 production graph 单向依赖；
- 外部 state 和危险动作不会被封装隐藏。

## 2. 当前目录

```text
flake.nix / flake.lock      inputs、outputs 与顶层 wiring
hosts/<host>/               最终选择、hardware 与 provider facts
software/<software>/        Software owner 与 owner-local package/assets
intents/<intent>/           跨 Software 的纯组合
modules/                    少量已证明复用的系统/Home primitive
checks/                     窄 contract checks
operations/                 明确、人工触发的安全操作
dotfiles/                   Nix 投影的稳定静态文件
docs/                       当前架构、ADR、runbook 与 Agent 规范
```

`software/` 与 `intents/` 是 V3 的主要业务结构。`modules/` 不再提供 `common`、`desktop`、`linux` 或 application bundle；留下的文件必须有实际跨 owner consumer 或属于 System 层。

## 3. 组合模型

### 3.1 Software 纵轴

每个 `software/<name>/` 是该软件的局部 owner。Primary Capability 表达主要行为；Extension 表达 owner-local 的窄贡献。可供 Intent 使用的 owner 通过 `default.nix` 暴露公开接口，内部 capability 文件仍保持路径局部。

Software 不知道 Host，也不 import Intent。Package expression、固定数据、脚本与平台实现尽量与 owner 共置；没有行为差异时不建立 pass-through adapter。

### 3.2 Intent 横轴

Intent 处理必须同时选择多个 Software 的需求，例如 terminal work、code development、Chinese input 或 stable workstation access 的组合。Intent 使用 `intents/lib.nix` 从空 state 开始，依次应用公开 capability/extension，最后只返回三个 module lists。

Intent 不写软件私有 primitive，不建立 relation graph，也不根据目录内容自动发现 owner。

### 3.3 Host caller

Host 是选择事实的最终 owner：

- 组合需要横向协调的 Intent；
- 直接选择无需 Intent 的独立 Software platform module；
- 声明 username、platform、boot、disk、network 等机器事实；
- 把 Home Manager modules 放入目标用户。

三台 Host 互不继承。macbook 的完整桌面不是 nixbox/server 的基类，Linux 或 Darwin 名称也不自动携带软件集合。

## 4. Flake outputs

生产 outputs：

- `darwinConfigurations.macbook`
- `nixosConfigurations.nixbox`
- `nixosConfigurations.server`

显式 package/app outputs 只为真实操作或独立验证提供稳定入口，例如 Zed binary package、Clash Verge Rev package、Zed 手动同步和 server recovery test。Output 不是已经 activation 的声明。

Darwin 使用 rolling nixpkgs/nix-darwin/Home Manager inputs；Linux 使用 26.05 release inputs。两条 cadence 共享同一 lock file，但不强求 package 版本一致。

## 5. Check 与 Operation

Check 验证窄接口和最终 host output，例如 FZF/Zed contribution、Pinshift host selection、Tailscale SSH fragment、server recovery policy 与网络黑盒。不要为“某路径不存在”长期建立架构测试。

Operation 只在确实存在需要维护者运行的流程时建立。当前 `server-recovery-test`：

- 只允许 `x86_64-linux` + KVM；
- 要求 clean checkout 和足够磁盘空间；
- 构建 production server closure；
- 在隔离 VM 验证 BIOS/disko install、双栈网络、SSH 与 firewall；
- 不接受 target，因此不能联系 production。

## 6. 配置与数据边界

Git/Nix 可以拥有：package 选择、稳定设置、systemd/launchd 声明、静态文件、明确 firewall rule 与可构建 Operation。

Git/Nix 不自动拥有：数据库、history、userdb、cache、browser profile、应用账号、token、private key、workspace、容器 volume、云端数据与备份。

需要防止误管理的事实应保留在最近的 owner 或当前 runbook；不为没有 production consumer 的 metadata 建全局 option、matrix 或报告。

## 7. 主机角色

| Host | 组合重点 | 明确排除 |
| --- | --- | --- |
| macbook | Darwin system、完整工作站 Software、开发/AI/终端 Intents、维护控制面 | 不承担 Linux closure 原生构建，不自动修改外部 app state |
| nixbox | NixOS/Hyprland 工作站、核心开发/AI/终端 Intents、server 预生产验证 | 不镜像 macbook GUI，不持有 maintenance private key |
| server | 最小 headless System、终端与 Git 基础、诊断和 recovery contract | 无 GUI、GitHub credential、工作站 runtime、Tailscale mesh 或旧 Ubuntu workload |

完整选择以 `hosts/<host>/default.nix` 为准，不另维护手写 capability matrix。

## 8. 变更路径

1. Issue 先确定需求 owner、平台、side effects、验证与人工关卡。
2. 单软件行为进入 Software；跨软件选择进入 Intent；硬件/provider facts 进入 Host。
3. 先运行窄 check，再运行 formatter、Flake check 与受影响 host build。
4. Draft PR 记录未执行的 activation、外部 state 与目标架构 blocker。
5. 真实机器动作绑定 merged exact commit，单独批准、读回并准备 rollback。
