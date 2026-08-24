# Server 恢复与访问失效处理

本文记录当前 NixOS server 的恢复边界。它不是无人值守安装脚本，也不授权连接、修改或重装生产主机。

## 权威配置

- 主机组合：`hosts/server/default.nix`
- 磁盘与启动：`hosts/server/disko.nix`
- 网络、DNS、防火墙与 SSH：`hosts/server/networking.nix`
- 隔离恢复演练：`operations/server-recovery/`

不要从历史迁移记录还原 server 配置。当前 Git tree 和以上文件才是声明源。

## 合并前验证

在具备 KVM、至少 100 GiB 可用空间的 `x86_64-linux` 主机上，从干净 checkout 运行：

```fish
nix run .#server-recovery-test
```

该 Operation 不接受目标地址或额外参数，只会：

1. 检查恢复策略；
2. 构建生产 server closure，但不 activation；
3. 在隔离 VM 中执行 BIOS/disko 安装演练；
4. 验证隔离网络、SSH 和防火墙行为。

成功输出必须以 `PASS; no production target was accepted or contacted` 结束。它不能替代真实机器的人工作业与回读。

## SSH 失效时的升级顺序

始终从影响最小、可回读的路径开始：

1. 保留所有仍可用的 SSH 会话，不要主动退出。
2. 尝试已知的直连路径和现有管理网络；不要临时放宽 SSH 或防火墙。
3. 使用提供商 VNC/串口控制台观察启动、地址、路由和服务状态。
4. 只有在当前 Issue/PR 已记录明确批准时，才进入 Rescue。使用临时凭据，作业后撤销。
5. 重装是最后手段。它具有破坏性，必须另有明确批准、已验证备份和恢复测试。

每次真实机器操作前都要建立 action card，至少写明：

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

按 action card 逐项记录：

- VNC/控制台仍可进入；
- `sayori` 的预期 SSH 路径可用；
- `sudo` 正常；
- root SSH 登录保持禁用；
- 启动、挂载、网络、DNS 和防火墙符合当前声明；
- 未恢复已退役的旧 workload 或 Ubuntu 管理层；
- `system.stateVersion` 未被顺手升级。

任何一项与声明不符都应停止扩大变更，保留证据并回到批准的回滚路径。
