# macbook → nixbox 稳定访问

Mac 使用 Tailscale Standalone 应用，nixbox 使用 NixOS 的 `tailscaled`。受管 `ProxyCommand` 通过应用的 `nc` 提供原始 TCP 流，用户和主机认证仍由 OpenSSH 完成。声明见 [Mac 安装](../../software/tailscale/darwin.nix)、[SSH 片段](../../software/tailscale/darwin-home-manager.nix)和 [nixbox 服务](../../software/tailscale/nixos.nix)；声明不证明远端已应用。

改变网络、登录状态或系统配置前，按 [AGENTS.md](../../AGENTS.md) 明确目标、动作和恢复办法；保留 nixbox 本地控制台或已验证的 LAN SSH，不依赖唯一的 Tailscale 通道自救。状态输出中的地址、账户、设备标识和密钥指纹只在本地核对。

## 日常连接与排障

在 Mac 检查客户端和 SSH 实际采用的配置：

```fish
env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale status
ssh -G nixbox | string match -r '^(hostname|user|identityfile|identitiesonly|stricthostkeychecking|proxycommand) '
```

🔎 确认客户端在线，目标和身份来自外部 SSH 配置，`ProxyCommand` 使用同一份 Tailscale 应用。

已有可信主机密钥后，检查连接和远端服务：

```fish
ssh nixbox 'systemctl is-active sshd tailscaled NetworkManager'
nix store ping --store ssh-ng://nixbox
```

🧪 分别检查普通 SSH 与 Nix SSH 传输；失败时先定位客户端、服务、认证或控制面，不放宽 SSH 和防火墙。

需要保留远端工作现场时：

```fish
ssh -t nixbox 'tmux new -A -s work'
```

🧵 连接已有或新建的 `work` 会话；断线后用同一命令恢复，换网和休眠仍可能中断 SSH 连接。

连接异常时按症状处理：

- Tailscale 不在线：核对两端登录、设备批准、密钥到期与服务状态；从 nixbox 控制台检查，不能在唯一远程通道中强制重新认证。
- Tailscale 在线但 SSH 失败：核对 MagicDNS 名、Grants、`sshd` 和主机密钥。主机密钥不匹配时停止，从控制台或既有可信 LAN 通道交叉核实；不删除 `known_hosts`、使用 `accept-new` 或关闭严格检查绕过。
- Clash 开启后失败：分别比较关闭和开启时的连接，确认 SSH 仍使用受管 `ProxyCommand`。Termius、Zed 可能不读取 OpenSSH 配置，须单独核实；不因此直接改全局 DNS、路由或 Clash 规则。

若报错指向已删除的 Shell 路径，在 Mac 检查进程环境：

```fish
printf 'process SHELL=%s\n' "$SHELL"
dscl . -read /Users/sayori UserShell
test -x "$SHELL"
```

🐚 账号 Shell 正确而进程仍继承旧路径时，完整重启发起 SSH 的终端应用或重新登录；不把旧 Store 路径写进 SSH 片段。

## 换机或首次接入

只有目标尚未完成接入时才需要本节。先应用对应主机声明，Mac 只保留 Standalone 版本，不另启 Nix 的 Tailscale daemon。系统扩展、VPN 批准和账号登录由维护者在应用中完成，不把自动登录密钥写入仓库。

Mac 登录后关闭接收其他设备路由，并读回偏好：

```fish
env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale set --accept-routes=false
env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale debug prefs \
    | jq '{RouteAll, RunSSH, AdvertiseRoutes, ExitNodeIP}'
```

🖥️ 设置本机不接收 tailnet 路由，核对没有启用 Tailscale SSH、通告路由或出口节点。

nixbox 未登录时，在其本地控制台交互接入：

```fish
sudo tailscale up --hostname=nixbox
sudo tailscale debug prefs | jq '{Hostname, RouteAll, RunSSH, AdvertiseRoutes, ExitNodeIP}'
```

🔐 发起浏览器登录并核对实际偏好；声明只提供服务和名称，不代表账号或设备批准已经完成。

nixbox 声明开放 UDP 41641，禁用路由用途；daemon 仍会维护运行时防火墙规则，不能把 `useRoutingFeatures = "none"` 理解为没有网络副作用。接入或相关配置变化后，在控制台检查实际规则和原有 SSH 通道：

```fish
sudo iptables-save
sudo ip6tables-save
```

🛡️ 核对 Tailscale 规则与原有防火墙能共同工作，不把 `tailscale0` 设为可信接口。

控制面保留最小访问范围：启用 MagicDNS，只允许获批 Mac 到 nixbox 的 TCP 22，并核对其他 ACL／Grant 没有叠加出更宽权限。不启用 Tailscale SSH、路由接收、子网路由、出口节点、Serve 或 Funnel。确需关闭密钥到期时仅针对 nixbox，Mac 保持正常到期策略；账号、设备批准、Grants 和到期设置均在 Nix 之外维护。

Mac 的主 SSH 配置仍由维护者拥有：`Host nixbox` 保存实际完整 MagicDNS 名、`User sayori` 和自己的 `IdentityFile`，使用 `StrictHostKeyChecking yes`、`IdentitiesOnly yes`。在首个 `Host`／`Match` 前接入 `Include ~/.ssh/config.d/*.conf`，不要复制受管片段或让 Nix 接管整份文件。

```fish
test -L ~/.ssh/config.d/nixbox-tailscale.conf
ssh -G nixbox | string match -r '^(hostname|user|identityfile|stricthostkeychecking|proxycommand) '
```

🧩 核对片段已经落地且主配置确实采用它；仅有文件并不证明 Include 生效。

新 MagicDNS 名是新的主机密钥索引。通过控制台或可信 LAN 通道取得并核对主机公钥后，才建立对应的 `known_hosts` 信任；`ssh-keyscan` 和 `UpdateHostKeys` 都不能代替首次身份核实。接入后验证常用网络、Clash 开关两种状态及断线重连，按实际需要检查文件传输和应用远程连接。

## 隔离与恢复

需要临时隔离时，在 nixbox 本地控制台执行：

```fish
sudo tailscale down
```

⛔ 断开该机 Tailscale 连接，保留登录态和设备记录；不要从唯一的远程通道执行。

Mac 可从应用断开。配置故障按 [Mac 日常维护](daily-nix-maintenance.md#恢复已知可用配置)或 [nixbox 恢复](nixbox-desktop-recovery.md#恢复系统配置)切回已核实的可用代际，再检查服务、SSH 和防火墙。外部 SSH 主配置按需要恢复到仍可达的 LAN 目标，并继续核对主机密钥。

代际回滚不会自动撤销设备登录、Grants、密钥到期设置或卸载 Mac 应用；删除设备、退出账号和重新认证是另外的操作。Mac 应用状态与 nixbox 的 `/var/lib/tailscale` 由产品维护，不要为了恢复访问清空这些数据。
