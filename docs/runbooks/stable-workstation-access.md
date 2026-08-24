# macbook → nixbox 稳定访问手册

本文是 Issue #148 的维护者执行与验收手册。目标是通过 Tailscale + MagicDNS 提供稳定
transport，同时继续使用 native OpenSSH key-only、sshd host key 与 tmux。命令均为 Fish；
输出只在本机审阅，提交 Issue/PR 前必须移除账户、地址、tailnet suffix、device ID、key 和
host-key 内容。

## 1. 执行边界

- build/check 不等于 activation、Homebrew 安装落地或 Tailscale enrollment。
- macbook activation、nixbox activation、System Extension/VPN approval、两端 enrollment、
  firewall runtime mutation、MagicDNS/Grants、SSH alias、reboot 与 key-expiry 各需独立的
  exact-commit/current-window 人工批准。
- 全部 soak 完成前保留 nixbox 物理 console、既有可信 LAN SSH 和实施前 SSH alias 记录。
- 不在 overlay 唯一通道中执行 reauth、远程 activation 或恢复操作。

## 2. Gate 1：只读 inventory 与 Draft PR

### 2026-08-12 脱敏基线

- macbook 未发现 `/Applications/Tailscale.app`；Homebrew 已安装 cask 中未发现 `tailscale` 或
  `tailscale-app`；launchd 与 system extension metadata 未见 Tailscale。
- Homebrew metadata 已确认目标 `tailscale-app` cask 对应官方 Tailscale / tailscale.com。
- Clash Verge 正在运行，因此真人矩阵必须分别覆盖 Clash 关闭与开启。
- `ssh -G nixbox` 显示现有 `HostName` 仍为 RFC1918 literal、`User` 为 `sayori`、
  `StrictHostKeyChecking` 为 true；真实地址不进入仓库。
- 当前无法通过该 alias 从 nixbox 读回现场状态；这项缺失保持为 Gate 3 前必须由物理 console
  或可信 LAN SSH 补齐的证据，不推断 sshd、firewall 或 host key 运行态。

在 macbook 本机只读确认没有第二个 Tailscale variant，并记录 Clash 当前状态。以下输出
不得原样贴到公开记录：

```fish
/opt/homebrew/bin/brew list --cask | string match -ri 'tailscale'
ps ax -o command= | string match -ri 'tailscale|clash'
test -f ~/.ssh/config; and ssh -G nixbox | string match -r '^(hostname|user|identityfile|stricthostkeychecking) '
```

🔎 只读核实 macOS variant、VPN 进程与现有 SSH alias 元数据。

同时把 macbook 当前 system closure 与 generation number 记录在本地私有 evidence 表；本轮
activation 前不得插入无关 generation：

```fish
readlink /run/current-system
sudo /run/current-system/sw/bin/darwin-rebuild --list-generations
```

🧾 记录 macbook 的 exact pre-change closure 与 generation，供定向回滚核对。

在 nixbox 的物理 console 或可信 LAN SSH 中只读确认恢复入口与服务基线。当前尚未 activation
时，`tailscaled.service` 不存在是预期结果；vendor state 路径证据来自 Draft PR 对锁定 package
unit/source 的审阅，不要求从尚未安装的 live unit 猜测。不要发布地址或 fingerprint：

```fish
systemctl is-active sshd
systemctl is-enabled tailscaled.service; or true
sudo iptables-save
sudo ip6tables-save
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

🧭 核实 SSH、防火墙恢复基线、host-key fingerprint 与 Tailscale 尚未落地的现场事实。

同样在 nixbox 本地私有 evidence 表记录当前运行 closure、正式 system profile 与 generation
number；不要只写“上一代”：

```fish
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

🧾 记录 nixbox 的 exact pre-change closure 与 generation，避免中间 generation 导致回错。

审阅 Draft PR 时确认 ADR-0010 为“已接受”、server 零变化，且没有敏感值或禁止功能。仓库内
允许执行的离线验证如下，不会激活机器或连接 tailnet：

```fish
nix fmt -- --check .
nix flake check
nix build --no-link .#darwinConfigurations.macbook.system
nix build --no-link .#nixosConfigurations.nixbox.config.system.build.toplevel
```

🧪 只格式化、检查并构建两台受影响主机，不执行 activation。

## 3. Gate 2：macbook activation 与 enrollment

仅在维护者已对 exact merged commit 和当前窗口单独批准后 activation macbook。随后由维护者
确认只存在 Standalone variant，在 GUI 中人工批准 System Extension/VPN configuration 并登录
tailnet；不要使用自动 auth key。首次基线保持 Clash Verge 关闭。

macOS GUI variant 可能默认接受 tailnet routes，因此登录后先显式关闭 route acceptance，再读回
最小偏好与客户端状态。Standalone app binary 作为 CLI 使用时显式设置
`TAILSCALE_BE_CLI=1`；输出含外部身份与地址，只能记录脱敏摘要：

```fish
env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale set --accept-routes=false
env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale debug prefs \
  | jq '{RouteAll, RunSSH, AdvertiseRoutes, ExitNodeIP}'
env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale status
```

🖥️ 关闭 route acceptance，并确认 Standalone 已登录、无 Tailscale SSH/routes/exit node 或第二 owner。

## 4. Gate 3：nixbox activation 与 enrollment

仅当维护者人在 nixbox 旁、物理 console 和旧 LAN SSH 同时可用，并已对同一 exact commit 与
当前窗口单独批准后，才 activation nixbox。防火墙运行态变化属于本关卡。activation 后从
本机 console 交互注册，不提交 auth key：

```fish
sudo tailscale up --hostname=nixbox
```

🔐 在可信本地入口以批准的 overlay 名称发起人工登录；浏览器授权与 device approval 仍由维护者完成。

注册后读回已声明边界，并确认旧 LAN SSH 仍可用：

```fish
systemctl is-active tailscaled
sudo tailscale debug prefs | jq '{Hostname, RouteAll, RunSSH, AdvertiseRoutes, ExitNodeIP}'
sudo iptables-save
sudo ip6tables-save
```

🛡️ 确认 service、machine name、routing none、UDP 41641 声明增量及 vendor overlay iptables chains。

不得启用 `--ssh`、routes、route acceptance、subnet router 或 exit node；不得把
`tailscale0` 设为 trusted interface。

## 5. Gate 4：外部控制面

在 Tailscale 管理控制面人工完成并复核：

1. 两端 device 已批准，machine record 与预期角色一致；
2. MagicDNS 已启用；
3. deny-by-default Grants 的最终效果只允许获批 macbook source → nixbox destination
   `tcp:22`；
4. 没有旧 allow-all ACL 或 broad Grant 以 union 方式扩大访问；
5. 不启用 Tailscale SSH、routes、exit node、Serve 或 Funnel。

控制面变更不由 Nix 执行。记录中不得出现 account、device ID、实际 policy selector、地址、
DNS suffix 或 key。

## 6. Gate 5：host key 与 SSH alias

先从 nixbox console 或可信 LAN SSH 读取公开 host-key fingerprint，并与 macbook 现有可信记录
交叉确认。endpoint 改为 MagicDNS 不应改变 sshd host key；任何 mismatch 必须停止并保持
fail closed。

维护者继续在外部 `~/.ssh/config` 的既有 `Host nixbox` block 中持有实际完整 MagicDNS
`HostName`；保留 `User sayori`、既有 `IdentityFile` 与 `StrictHostKeyChecking yes`；增加
`IdentitiesOnly yes`、`UpdateHostKeys yes`、`ServerAliveInterval 15` 与
`ServerAliveCountMax 3`。不全局启用 ControlMaster/ControlPersist，不删除 known_hosts 后盲目
接受，也不把 `ssh-keyscan` 当作信任来源。

macbook activation 后，先确认 Home Manager 已生成非 secret fragment；再在外部主配置开头
一次性增加通用 Include。不要复制 fragment 内容，不要让 Nix 接管整份主配置：

```fish
test -L ~/.ssh/config.d/nixbox-tailscale.conf
string match -rq '^Include ~/.ssh/config.d/\*\.conf$' < ~/.ssh/config
```

🧩 确认受管 fragment 已落地，并读回外部主配置是否已经接入该目录。

若第二条未通过，先停在当前窗口取得对单行 `Include ~/.ssh/config.d/*.conf` 的精确批准，再用
文本编辑器把它放在第一个 `Host`/`Match` block 之前；不得让 activation script 修改外部文件。

新 MagicDNS hostname 是新的 known_hosts 索引；旧 DHCP IP 下的信任不会自动迁移，
`UpdateHostKeys` 也不能完成首次 trust bootstrap。编辑后先从解析后的 SSH 配置取得实际新名称，
只读检查它是否已有可信记录：

```fish
set magicdns_name (/usr/bin/ssh -G nixbox 2>/dev/null | string match -r '^hostname ' | string replace 'hostname ' '')
test -n "$magicdns_name"; and ssh-keygen -F "$magicdns_name"
```

🔐 检查新 MagicDNS 名是否已有受信 host-key 记录；命令输出只在本地与 console fingerprint 比对。

若没有记录，当前 #148 明确禁止修改 known_hosts，必须暂停 Gate 5，并先取得对“把可信 console/
LAN 通道读回且 fingerprint 已匹配的公钥，定向绑定到该 MagicDNS hostname”的独立 scope
扩展与当前窗口批准。不得用 `ssh-keyscan`、`accept-new`、临时关闭严格检查或盲目确认绕过；
在可信记录存在之前，下面的 SSH smoke 不得运行。

编辑后只输出脱敏字段，确认 endpoint 不再是实施前 DHCP 地址、受管 ProxyCommand 已生效且
认证边界未漂移：

```fish
ssh -G nixbox | string match -r '^(hostname|user|identityfile|identitiesonly|stricthostkeychecking|updatehostkeys|serveraliveinterval|serveralivecountmax|proxycommand) '
```

🔍 脱敏复核 endpoint/identity 仍由外部 block 持有，只有 ProxyCommand 来自受管 fragment。

如果 `ssh` 报告某个已经删除的旧 shell 路径，先比较当前进程环境与 macOS account 记录：

```fish
printf 'process SHELL=%s\n' "$SHELL"
dscl . -read /Users/sayori UserShell
test -x "$SHELL"
```

🐚 若 account UserShell 正确而当前 `$SHELL` 已不存在，重启发起 SSH 的 Terminal/Codex 等应用
或重新登录 macOS，再重试；不要把旧 Homebrew/Nix store shell 路径写进 SSH fragment。

随后执行普通 OpenSSH 与文件传输 smoke；测试文件使用临时目录，不接触 production 数据：

```fish
ssh nixbox 'printf "ssh-ok\\n"'
set access_smoke_dir (mktemp -d)
set remote_smoke (ssh nixbox 'mktemp /tmp/stable-access-smoke.XXXXXX')
printf 'sftp-smoke\n' > $access_smoke_dir/payload
scp $access_smoke_dir/payload "nixbox:$remote_smoke"
ssh nixbox "grep -Fxq sftp-smoke $remote_smoke; and rm -f $remote_smoke"
rm $access_smoke_dir/payload
rmdir $access_smoke_dir
```

🧪 验证 native OpenSSH 与 scp 路径；临时测试文件在成功后定向删除。

如需 Nix SSH transport smoke，只执行只读远端 store 查询：

```fish
nix store ping --store ssh-ng://nixbox
```

📦 只读确认既有 Nix SSH transport 能通过同一 alias 到达 nixbox。

## 7. Gate 6：真人连接矩阵

逐项执行并把结果以脱敏 PASS/FAIL 摘要记录在 Issue/PR：同一 LAN、手机热点、家庭网络、公司
网络、macbook Wi-Fi 切换、nixbox DHCP renew、获批真实 reboot、macbook relogin、direct 与
relay fallback、Clash Verge off/on、SSH 真断后的同名重连。Termius 与 Zed 只做人工连接
smoke，不接管其数据库或 session。

在每种网络场景观察连接类型，但不要公开对端地址或 tailnet 信息：

```fish
env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale ping nixbox
ssh nixbox
```

🌐 验证同一稳定名称在各网络场景可重连，并观察 direct 或 relay 结果。

建立或恢复远端工作现场：

```fish
ssh -t nixbox 'tmux new -A -s work'
```

🧵 验证 SSH 断线后可以用同一 alias 恢复既有 tmux 工作现场。

Clash 关闭和开启必须分别通过。OpenSSH 应在两种状态都读到同一个受管 ProxyCommand；Termius
与 Zed 若仍受 fake-IP 影响，只记录为不读取 OpenSSH config 的独立事实，不扩大本票去修改
Clash。任一 route 或 SSH transport 冲突都暂停，不修改 Clash、不启用 `tailscaled` userspace
networking mode，也不自行加入 split-tunnel workaround；另开 Issue 由维护者裁决。

验收口径是“地址漂移后无需改配置、跨网仍能同名连接、断线后工作可恢复”，不是“一条
TCP/SSH session 在换网、睡眠或 VPN 重启时永不掉线”。

## 8. Gate 7：key expiry

只有完整跨网矩阵通过，且确认 nixbox 保有物理恢复入口后，维护者才可在 Machines UI
单独批准并仅对 nixbox 关闭 key expiry。macbook 保持正常 expiry。记录决策、恢复入口和
撤销方式，不记录账户或 device ID。

## 9. 快速隔离与回滚

故障时优先保留 device 和登录态。在 nixbox 本机 console 快速隔离：

```fish
sudo tailscale down
```

⛔ 只断开 nixbox overlay，不 logout、不删 device，也不依赖 overlay 自救。

macbook 从 Standalone UI 断开。随后分别回滚两机到实施前 generation；NixOS 验证
tailscaled/interface、UDP 41641 声明增量及 vendor iptables chains 均消失。macOS generation
rollback 不保证卸载 Homebrew vendor app，必须按现场行为记录。把外部 `Host nixbox` 恢复为
实施前 LAN target，继续核对原 sshd host key。

回滚时使用 Gate 1 记录的 exact generation number，而不是含糊的“上一代”。先列出 generation
并确认目标仍解析到记录的 pre-change closure，再执行定向切换：

```fish
sudo /run/current-system/sw/bin/darwin-rebuild --list-generations
read --prompt-str 'macbook pre-change generation number: ' macbook_generation
if string match -rq '^[0-9]+$' -- "$macbook_generation"
    sudo /run/current-system/sw/bin/darwin-rebuild --switch-generation "$macbook_generation" switch
else
    echo 'invalid generation number; rollback not executed' >&2
end
readlink /run/current-system
```

↩️ 把 macbook 定向切回已核对的 pre-change generation，并读回 closure。

在 nixbox 物理 console 执行对应定向回滚；只允许输入 Gate 1 记录并已与 pre-change closure
核对的短 generation number：

```fish
read --prompt-str 'nixbox pre-change generation number: ' nixbox_generation
if string match -rq '^[0-9]+$' -- "$nixbox_generation"
    sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation "$nixbox_generation"
    and sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
else
    echo 'invalid generation number; rollback not executed' >&2
end
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
```

↩️ 从物理 console 把 nixbox 定向切回已核对的 generation，并验证运行态与正式 profile 一致。

永久删除 Grant/device、重新启用 key expiry、logout 或定向卸载 Standalone 都需要新的明确
批准。不得在唯一远程 overlay 通道执行 `tailscale up --force-reauth`。
