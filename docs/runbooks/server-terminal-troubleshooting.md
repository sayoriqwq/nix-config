# Server 终端排障

通过已有 Mac SSH 别名进入 server：

```fish
ssh sayori
```

🔐 使用维护者的独立密钥登录远端 `sayori`；别名和密钥由本机 SSH 配置持有。

server 的两把管理公钥都映射到 `sayori`，分别用于 Mac 维护和 nixbox 部署，能够独立撤销但不形成 Unix 权限隔离；不在机器间复制私钥。root SSH 和密码认证关闭，单条管理命令使用 sudo，连续管理才使用 `sudo -i`，完成后退出。root 环境不继承用户的全部交互工具。

以下命令在目标机执行。改变服务、系统或网络前沿用 [AGENTS.md](../../AGENTS.md) 的目标、动作和恢复要求；SSH 全部失效时转到 [Server 恢复](server-recovery.md)。

## 身份与整体状态

```fish
whoami
hostname
uptime
systemctl --failed --no-pager
```

🧭 确认目标用户、主机、运行时间与失败服务；需要实时查看资源占用时使用下列工具。

```fish
btop
```

📊 查看 CPU、内存、磁盘 I/O 和进程，按 `q` 退出。

## 服务或端口故障

```fish
set unit sshd.service
systemctl status $unit --no-pager
journalctl -u $unit -b -n 100 --no-pager
sudo ss -lntup
sudo lsof -nP -iTCP:22
```

📜 将服务名和端口换成故障对象，先看退出原因和监听进程；不要用反复重启代替诊断。

SSH 问题先保留当前连接，再开第二个连接验证。依次检查服务、TCP 22、防火墙与认证日志；不为了排障开放 root SSH、密码认证或额外端口。长期修复回到[主机声明](../../hosts/server/default.nix)，不把生成的 `/etc` 文件或 systemd unit 当作配置源。

## 磁盘空间

```fish
df -hT
sudo du -xhd1 /var | sort -h
sudo du -xhd1 /nix | sort -h
sudo lsof +L1
```

💽 确认满的是哪个文件系统、哪个目录增长，以及是否有已删除但仍被进程占用的文件；`-x` 避免跨文件系统扫描。

不手删 `/nix/store`。清理 Nix 前先核对当前系统和仍需保留的恢复代际；应用数据、日志保留和数据库空间按对应服务处理。

## DNS 与网络路径

```fish
resolvectl status
dig example.com A
dig example.com AAAA
ip route get 1.1.1.1
sudo mtr --report --report-cycles 10 example.com
```

🌐 将域名和地址换成故障目标，区分解析、内核选路与逐跳问题；中间节点不回应不等于终点业务不可达。

状态和日志仍不能解释问题时，再针对明确假设抓少量数据包：

```fish
sudo tcpdump -ni any -c 50 'port 53'
```

🧪 最多观察 50 个 DNS 数据包，无流量时用 `Ctrl-C` 停止；不要公开原始地址、域名或业务内容。

仅当故障指向文件、权限或系统调用时跟踪可重复的命令：

```fish
set trace_file (mktemp /tmp/server-trace.XXXXXX)
strace -f -tt -s 256 -o "$trace_file" dig example.com
bat "$trace_file"
rm -- "$trace_file"
```

🧬 查看命令的系统调用并删除这份临时跟踪文件；输出可能含参数和私有路径，不直接公开。

## 断线后继续工作

```fish
tmux new -A -s maintenance
```

🧵 建立或恢复 `maintenance` 会话，保留终端任务；tmux 不代替服务管理或控制台恢复通道。

排障结果只需说明现象、已执行动作、关键错误、受影响服务和仍可用的访问路径。涉及系统版本的问题按 [Server 恢复](server-recovery.md#恢复已知可用代际)处理；应用数据修复、重启和恢复按实际影响范围执行。
