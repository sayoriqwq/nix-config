# Server 恢复与访问失效处理

本文记录当前 NixOS server 的恢复边界。它不是无人值守安装脚本，也不授权连接、修改或重装生产主机。

## 权威配置

- 主机组合：`hosts/server/default.nix`
- 磁盘与启动：`hosts/server/disko.nix`
- 网络、DNS、防火墙与 SSH：`hosts/server/networking.nix`

不要从历史迁移记录还原 server 配置。当前 Git tree 和以上文件才是声明源。

## 声明验证

日常变更只构建 production server closure：

```fish
nix build .#nixosConfigurations.server.config.system.build.toplevel
```

🧪 验证 production server 声明可构建，不 activation。

## SSH 失效时的升级顺序

始终从影响最小、可回读的路径开始：

1. 保留所有仍可用的 SSH 会话，不要主动退出。
2. 尝试已知的直连路径和现有管理网络；不要临时放宽 SSH 或防火墙。
3. 使用提供商 VNC/串口控制台观察启动、地址、路由和服务状态。
4. 只有当前明确授权已覆盖本次目标与 Rescue 动作时，才进入 Rescue。使用临时凭据，作业后撤销。
5. 重装是最后手段。它具有破坏性，必须另有明确批准、已验证备份和恢复测试。

涉及 Rescue、重装或会改变远端访问的操作前，在当前任务中至少明确：

- 精确目标与识别方式；
- 预期磁盘、启动模式和网络模型；
- 要执行的短命令；
- 每一步回读；
- 停止条件和回滚路径；
- SSH 恢复路径与控制台可用性。

不得要求维护者手输 store path、hash、公钥或长参数列表。需要复杂动作时，应传输并校验窄范围临时 helper，提供短入口，并在完成后删除 helper。

## 重装前置条件

以下事实缺一不可：

- 备份位置与恢复测试已记录；如果当前数据确实可丢弃，则必须记录维护者针对本次动作的
  明确 data-loss waiver，不能沿用历史豁免；
- Rescue/VNC/串口控制台可用；
- 目标磁盘、启动模式、接口和网络参数来自目标机证据；
- 当前 `system.stateVersion`、硬件配置和 SSH 身份保持不变；
- 明确批准了本次磁盘、启动、网络、DNS、防火墙和 SSH 变更。

提供商凭据、私钥、令牌、公网地址和其他敏感事实不得写入 Git。

## 恢复后验收

按本次操作范围逐项记录：

- VNC/控制台仍可进入；
- `sayori` 的预期 SSH 路径可用；
- `sudo` 正常；
- root SSH 登录保持禁用；
- 启动、挂载、网络、DNS 和防火墙符合当前声明；
- 未恢复已退役的旧 workload 或 Ubuntu 管理层；
- `system.stateVersion` 未被顺手升级。

任何一项与声明不符都应停止扩大变更，保留证据并回到批准的回滚路径。
