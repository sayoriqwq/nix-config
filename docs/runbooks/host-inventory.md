# 主机盘点手册

## 1. 原则

- 只收集复现配置或设计 rollback 所需的事实；
- 先只读，任何需要 `sudo`、远程控制面或外部账号的检查都单独获批；
- 不读取 secret value、private key、数据库内容、浏览器资料或完整业务配置；
- Public IP、账号 ID、serial、fingerprint、credential 和 private hostname 默认脱敏；
- 不能从另一台机器、旧报告或默认值推断当前事实。

## 2. 通用事实

对每台 Host 至少确认：

- OS、architecture、kernel/Nix implementation；
- 逻辑 output 与实际 hostname 的区别；
- 用户、home、shell、`system.stateVersion` / `home.stateVersion`；
- filesystem、mount 与可用空间；
- network interface、route、DNS 与 remote-access model；
- 当前 generation、failed units 与关键 service；
- package/config owner 与 mutable/external state boundary；
- build、activation、rollback 与物理/带外恢复入口。

## 3. macbook

确认 Apple Silicon/Darwin 版本、Lix daemon、当前 nix-darwin generation、Home Manager profile、FileVault/恢复入口、Homebrew/MAS owner、Tailscale/Clash 的外部运行边界，以及可能影响 activation 的 unmanaged `/etc` 或应用路径。

不要读取 Keychain、TCC database、应用账号、browser profile 或 vendor container 内容。

## 4. nixbox

确认 `x86_64-linux`、boot mode、stable disk identity、hardware configuration、network/SSH、display/session、KVM、可用空间和当前 NixOS generation。涉及 bootloader、disk、firewall、Tailscale enrollment 或 reboot 的事实采集必须与 mutation 分离。

作为 server recovery 验证节点时，还要确认用户可访问 `/dev/kvm`、checkout clean，且仓库所在 filesystem 至少有 100 GiB 可用空间。

## 5. server

确认 provider/virtualization、BIOS/boot、stable disk alias、network model、SSH/sudo policy、firewall、当前 generation、failed units、VNC/Rescue/Reinstall 是否真实可用，以及 macbook 与 nixbox 两条独立认证路径。

Host-specific disk/network facts 以 `hosts/server/` 为声明来源。Provider credential、VNC/Rescue password 和 SSH private material 不得进入 Git、Issue 或命令输出。

任何 disk、network、SSH、firewall、reboot、Rescue 或 Reinstall 动作必须转入 [server-recovery.md](server-recovery.md) 的独立行动卡，盘点本身不授权执行。

## 6. Issue 摘要模板

```md
## 主机事实
- output / platform：
- current generation：
- boot / disk：
- network / access：
- services / failed units：
- mutable data / secret boundary：

## 未知事实
- ...

## 允许动作
- ...

## 禁止动作与人工关卡
- ...

## 验证与 rollback
- ...
```

盘点完成不等于变更获批；未知事实必须显式保留。
