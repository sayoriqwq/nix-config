# ADR-0010：以 Tailscale 建立工作站间稳定访问

- **状态：** 已接受
- **日期：** 2026-08-12
- **决策范围：** `macbook` → `nixbox` 的稳定 SSH 访问
- **授权依据：** Issue #148 与 #229，以及维护者于 2026-08-12、2026-08-24 记录的实现授权

## 背景

`nixbox` 的物理网络地址由 DHCP 分配，地址漂移会使 macbook 上以该地址为目标的 SSH
alias 在 TCP 连接阶段失效。LAN 内的 DHCP reservation 或 mDNS 不能同时解决家庭、公司和
手机热点等不同网络间的稳定访问。需求也不是让一条 TCP session 永不掉线，而是保持同一
连接名称，并在真实断线后恢复远端工作现场。

2026-08-24 的 #229 现场诊断进一步证明：Tailscale 已接受 tailnet DNS 且 macOS 已注册
split resolver，但 Clash TUN 仍可把 `*.ts.net` 回答为 fake-IP；同一时刻 Tailscale direct
ping、真实 overlay IP 的 native SSH，以及 Standalone CLI 的 `tailscale nc` transport 均
稳定成功。因此修复归稳定访问能力的 OpenSSH transport seam，不修改 Clash DNS/TUN state。

这一需求触发 ADR-0001 对 mesh networking 的复审条件。维护者已在 Issue #148 接受本决策；
接受 ADR 只授权仓库内实现与离线验证，不授权任何真实机器的安装落地、激活或注册。

## 决策

采用以下分层：

```text
稳定寻址与跨网 transport：Tailscale + MagicDNS
用户与主机认证：native OpenSSH key-only + sshd host key
断线后的工作现场：tmux
```

Tailscale 只提供 overlay transport、稳定 machine name 和可直连时的 WireGuard direct path；
无法直连时允许使用其加密 relay。普通 OpenSSH 继续监听 nixbox 的 TCP 22，并继续负责用户
public-key 认证、sshd host-key 身份与 fail-closed 检查。SSH 断开后使用同一 alias 重连，
`tmux` 负责恢复已存在的远端会话。

### 能力组合与所有权

- `macbook` 通过跨层能力的 Darwin adapter，只声明 Homebrew cask `tailscale-app`，即官方
  Standalone macOS variant。不得并装 App Store variant、开源 cask 或启用 nix-darwin
  `services.tailscale`，避免出现第二个 packaging/runtime owner。
- `macbook` 的 Home Manager attachment 生成 `~/.ssh/config.d/nixbox-tailscale.conf`，只为
  `Host nixbox` 声明官方 Standalone CLI 的 `tailscale nc %h %p` ProxyCommand。`%h` 继续来自
  外部 SSH alias，但由本机 Tailscale daemon 解析，不经过可能被 Clash fake-IP 接管的系统
  DNS。该 raw TCP stream 不替换 native OpenSSH 的 user key、sshd host key 或 fail-closed
  检查，也不等于 Tailscale SSH。
- `nixbox` 通过同一能力的 NixOS adapter 使用锁定 nixpkgs 的 `services.tailscale`，保持
  `useRoutingFeatures = "none"`、`authKeyFile = null`，通过稳定的 `set` seam 把 Tailscale
  machine name 声明为 `nixbox`，但保留 OS hostname `nixos`。
- nixbox 的 NixOS firewall 声明只新增默认 UDP 41641 以提高 direct path 概率；不信任整个
  `tailscale0` interface，也不改变 TCP 22、sshd、authorized keys、root/password/
  keyboard-interactive policy。运行中的 `tailscaled` 仍按 vendor 默认维护承载 overlay 所需的
  iptables chains；这是已公开且必须在 activation/rollback 中读回的 runtime network effect，
  不能把“声明只加一个 UDP port”误写成“运行时只有一个 firewall 变化”。
- `server` 不 import 此能力，不安装或启用 Tailscale，既有 SSH、firewall 和 production
  控制链路均不改变。

锁定 NixOS package 的 systemd unit 使用 `/var/lib/tailscale` 保存其 vendor-owned mutable
state；仓库只记录此路径的 owner 与备份/恢复边界，不管理、复制、清理或提交其中内容。
macOS Standalone 的 vendor state 精确路径尚无经锁定 package 或实机 metadata-only 证据，
因此本决策不猜测路径。

### 外部控制面

Tailnet account、登录态、device identity、node key、设备批准、MagicDNS、Grants、key expiry、
macOS System Extension/VPN configuration 和实际 machine record 都是外部可变状态。Grants
由维护者在独立关卡中按 deny-by-default 模型收窄为获批 macbook source → nixbox destination
的 `tcp:22`，并检查是否存在会以 union 方式放宽结果的旧 ACL/Grant。

macbook 的 `~/.ssh/config` 继续由外部拥有。本仓库不接管整份文件；维护者在独立关卡中只
增加通用 fragment Include，并继续由外部 `Host nixbox` block 持有 endpoint、user、
private-key identity 与严格 host-key 信任。受管 fragment 不含 tailnet DNS suffix、
overlay/LAN/public IP、账户、key、IdentityFile 或 known_hosts 内容；这些值均不得进入 Git、
Issue、PR 或 Nix Store。

Standalone 首次登录后必须在同一人工关卡中显式关闭 route acceptance，并读回确认没有
Tailscale SSH、advertised routes 或 exit node。该偏好属于 macOS vendor runtime state，不由
Nix 声明；这样既避免依赖 GUI variant 的平台默认值，也不把外部登录态伪装成声明式状态。

### 人工关卡

以下各项必须绑定 exact merged commit 与当前执行窗口，并分别取得维护者批准：

1. macbook activation，以及随后的 Standalone 安装落地、System Extension/VPN 批准与注册；
2. nixbox activation、防火墙运行态变化与交互式注册；
3. MagicDNS、device approval 与最小 Grants 的控制面变更；
4. 受管 SSH fragment activation、外部主配置的一次性 Include、fresh login environment，和经
   可信 console/LAN 路径核对 sshd host-key；
5. nixbox reboot、跨网/换网、Clash Verge off/on 和 tmux 真人矩阵；
6. 全矩阵通过后，仅对有物理恢复入口的 nixbox 调整 key expiry。

Flake evaluation、check 或 build 只证明声明可求值/构建，不代表任何 activation、Homebrew
安装、enrollment、网络 mutation 或上述人工关卡已获授权或完成。

## 结果

### 正面

- DHCP 地址漂移与跨网访问不再要求修改 SSH alias；
- Clash fake-IP 抢占系统 DNS 时，OpenSSH/scp/Nix SSH 仍可通过同一 alias 使用 Tailscale
  daemon 的 raw TCP transport；
- Tailscale 与 OpenSSH 各自承担单一职责，不替换既有 key-only 与 host-key 信任模型；
- macbook 与 nixbox 的平台所有权、网络影响、可变状态和人工关卡在一个能力合同中可审计；
- SSH 真实断线时可以快速失败、同名重连并恢复 tmux 工作现场。

### 代价与风险

- 新连接依赖 Tailscale SaaS 控制面、设备登录态、MagicDNS 与外部 Grants；
- direct path 不可用时 relay 可能增加延迟或降低吞吐；
- Clash Verge 或其他 VPN 仍可能影响 route 或不读取 OpenSSH config 的客户端；受管
  ProxyCommand 只覆盖 OpenSSH/scp/Nix SSH，必须以 Clash 关闭和开启两种状态实测，不修改
  Clash DNS/TUN state；
- OpenSSH 执行 ProxyCommand 依赖调用进程拥有仍存在的 login shell。若长生命周期 GUI 进程
  继承了已删除的旧 `$SHELL`，必须在人工关卡中重启该应用或重新登录，不能把旧路径固化进
  fragment；
- app、daemon、Network Extension 重启、睡眠或换网仍可能中断现有 SSH TCP；
- key expiry、device 删除或 logout 可能使 overlay 完全不可达，因此在 soak 完成前保留物理
  console 与既有 LAN SSH 恢复入口。

## 回滚与撤销

快速隔离只执行本机 `tailscale down` 或在 Standalone UI 断开，不 logout、不删除 device。
声明回滚由两台主机分别回到实施前 generation；macbook 同时从外部主配置移除该 fragment
Include；NixOS 应验证 service/interface、UDP 41641
声明增量及 tailscaled vendor iptables chains 均消失，但不得声称 macOS generation rollback
必然卸载 Homebrew vendor app。SSH alias 可恢复为预先记录的 LAN target，并继续核对原 sshd
host key。

永久删除 Grant/device、重新启用 key expiry、logout 或定向卸载 Standalone 均是新的外部
可变状态操作，必须另获批准，不属于自动 generation rollback。

## 被否决与明确排除的方案

- FRP、独立公网 relay 或让 `server` 成为必经中转：增加公网服务、端口、认证状态与额外
  生命周期，并使 workstation access 依赖 production host；
- Tailscale SSH：会改变本决策保留的 native OpenSSH 用户/host-key 信任边界；
- 公开 TCP 22、端口转发、DDNS、以 mDNS 或 DHCP reservation 作为主路径：不能满足当前
  跨网稳定访问与最小暴露目标；
- route advertisement/acceptance、subnet router、exit node、Serve、Funnel、Tailnet Lock、
  Peer Relay、自建 DERP/Headscale：超出当前 point-to-point SSH transport 需求；
- 自动 auth key、Mosh、autossh、全局 ControlMaster/ControlPersist、`tailscaled` userspace
  networking mode 或 Clash split-tunnel/DNS workaround：没有当前需求和验证依据。这里批准的
  `tailscale nc` 只是 Standalone daemon 的单连接 TCP client，不改变 daemon networking mode。
