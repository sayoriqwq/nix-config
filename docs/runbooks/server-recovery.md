# Server 恢复与访问失效处理

声明来源为 [主机配置](../../hosts/server/default.nix)、[磁盘与 GRUB](../../hosts/server/disko.nix)、[网络](../../hosts/server/networking.nix)和 [SSH 防火墙](../../software/openssh/ssh-only-firewall-nixos.nix)。当前声明采用 `x86_64-linux`、BIOS／GPT、ext4、固定磁盘标识及静态双栈网络；现场是否采用这些设置必须从目标机核实。

真实操作遵循 [AGENTS.md](../../AGENTS.md)。保留维护者从 Mac 直连 server 的路径和提供商控制台；nixbox 负责同架构候选的构建、验证和传递，不是必经跳板。Server 运行已有系统不依赖 GitHub 或可变 checkout。提供商凭据、私钥和应用数据不进入仓库。

## SSH 失效时

1. 保留仍可用的 SSH 会话，用第二个连接检查；不临时放宽 SSH 或防火墙。
2. 按[终端排障](server-terminal-troubleshooting.md)检查 `sshd`、监听端口、地址、路由与日志。
3. 所有 SSH 路径都失效时，使用提供商 VNC／控制台确认主机身份、启动和网络状态。
4. 普通控制台不能修复时，再按已明确的目标与恢复方案进入 Rescue；重装是最后手段。

在目标控制台收集当前事实：

```fish
hostname
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
findmnt /
ip -br address
ip route
ip -6 route
systemctl --failed --no-pager
```

🔎 对照声明确认磁盘、挂载、网络和服务，避免把另一台机器或旧配置当作恢复依据；地址只在本地核对。

## 恢复已知可用代际

先从目标机列出运行系统和保留的代际：

```fish
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
```

🕘 区分当前运行系统与正式 profile，选择确实可用的恢复点，不盲目连续回退。

在已确认不会失去恢复通道的控制台或会话中，输入核实过的短编号：

```fish
read --prompt-str '已核实的恢复代际编号：' recovery_generation
if string match -rq '^[0-9]+$' -- "$recovery_generation"
    sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation "$recovery_generation"
    and sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
else
    echo '代际编号无效，未执行恢复。' >&2
end
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
```

↩️ 选择并激活指定 NixOS 代际，再核对实际结果。若选择成功但激活失败，profile 已改变，必须从保留的控制台继续处理，不能报告恢复完成。

无法在运行系统切换时，通过控制台启动菜单选择已核实的旧代际。代际恢复不恢复数据库或用户数据，也不自动修正 Git 中的失败声明；不要删除恢复点来腾空间。

## Rescue 或重装

这类操作由维护者在场执行。开始前核实实际磁盘标识、启动模式、网卡与地址配置、SSH 身份，以及控制台是否可用。准备必要数据备份并确认可恢复；未纳入恢复的状态须明确本次可以丢弃。

在具备 `x86_64-linux` 构建条件的 checkout 中验证恢复候选：

```fish
nix build --no-link .#nixosConfigurations.server.config.system.build.toplevel
```

🏗️ 只构建候选，不分区、重装或激活。不要为适配重装随手改变 `stateVersion`，也不要要求维护者抄写 Store 路径、哈希或长参数；具体安装步骤按核实的目标准备。

恢复后确认控制台、预期的 `sayori` SSH 登录、sudo、挂载、网络和 DNS 均可用，root SSH 与密码认证继续关闭，防火墙仍符合声明。临时 Rescue 凭据及时撤销；业务数据按自己的备份恢复流程处理。
