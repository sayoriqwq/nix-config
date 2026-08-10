# Server 终端运维与故障排查手册

本文面向 server 的日常维护者，回答三个问题：如何安全取得管理权限、遇到某类故障先用什么工具、什么时候应该停止试错并回到声明式配置或人工关卡。本文不授权 activation、reboot、网络或 firewall 变更。

## 1. 登录与提权模型

目标模型只有一个远端交互用户：`sayori`。

```text
macbook maintenance key ──▶ server:sayori ──▶ sudo / sudo -i
nixbox deploy key ─────────▶ server:sayori ──▶ sudo -n（仅获批部署）
root SSH ──────────────────▶ 禁止
```

两把 key 不同，是为了让“你本人维护”和“nixbox 机器部署”可以独立保管、撤销和轮换；它们都映射到同一个 `sayori` 用户并共享 sudo policy，所以不是两套 Unix 权限。不要在两台机器之间复制 private key。

从 macbook 登录时，继续使用本地 Host alias：

```fish
ssh sayori
```

🔐 使用 macbook maintenance identity 登录远端 `sayori`。

Termius 中同一个 Host 的 Username 也应为 `sayori`，并绑定 macbook maintenance identity；不要把 Username 配成 `root`，也不要绑定 nixbox deploy identity。

登录后先确认自己在哪里：

```fish
whoami
hostname
fastfetch
```

🧭 确认远端用户、主机名与系统身份，避免在错误机器上操作。

单条特权命令直接加 `sudo`：

```fish
sudo systemctl status sshd.service --no-pager
```

🔎 只为需要权限的命令提权，并保留清晰的命令边界。

确实需要连续执行多条 root 命令时才进入登录式 root shell，完成后立即退出：

```fish
sudo -i
exit
```

🛡️ 临时进入并退出 root 环境；不使用 `su`，也不设置或依赖 root password。

完整的 Fish、history、tmux、Helix 和 Yazi 环境归 `sayori` 所有。`sudo -i` 进入的是刻意保持精简的 root 登录 Shell，不承诺继承 `sayori` 的 alias、history 或 Home Manager profile；需要这些交互能力时退出 root，回到 `sayori`，只给具体命令加 sudo。

## 2. 五分钟排查顺序

先观察，后修改。大多数问题按以下顺序就能缩小范围。

### 2.1 主机和整体健康

```fish
fastfetch
uptime
systemctl --failed --no-pager
```

🩺 判断是否连对主机、系统是否刚重启，以及是否已有 failed unit。

需要实时观察 CPU、内存、磁盘 I/O 和进程时：

```fish
btop
```

📊 找出持续占用资源的进程；按 `q` 退出。

### 2.2 磁盘和目录容量

```fish
df -hT
sudo du -xhd1 /var | sort -h
sudo du -xhd1 /nix | sort -h
```

💽 先确认哪个 filesystem 满，再定位增长最快的一级目录；`-x` 避免跨 filesystem 扫描。

不要看到 `/nix/store` 大就直接删除文件或运行 GC。Nix Store、generation 与垃圾回收都要先确认当前 closure、回滚需求和独立批准范围。

### 2.3 服务状态和日志

```fish
set unit sshd.service
systemctl status $unit --no-pager
journalctl -u $unit -b -n 100 --no-pager
```

📜 查看某个 unit 当前状态和本次启动内最近 100 条日志；把 `unit` 改成实际服务名。

持续观察新日志时：

```fish
set unit sshd.service
journalctl -u $unit -f
```

👀 实时跟随日志；按 `Ctrl-C` 停止。

### 2.4 端口和进程

```fish
sudo ss -lntup
sudo lsof -nP -iTCP -sTCP:LISTEN
```

🔌 前者从 socket 视角列出 listener，后者把 TCP listener 映射到具体进程和文件描述符。

检查某个端口时：

```fish
set port 22
sudo lsof -nP -iTCP:$port
```

🎯 定位占用指定 TCP 端口的进程；把 `port` 改成待查端口。

### 2.5 DNS 与网络路径

```fish
resolvectl status
dig example.com
dig example.com AAAA
```

🌐 区分 resolver 配置、IPv4 解析和 IPv6 解析问题。

确认路由和逐跳质量时：

```fish
ip route get 1.1.1.1
sudo mtr --report --report-cycles 10 example.com
```

🛣️ 先看内核选路，再用有限次数报告观察丢包与延迟；中间节点不回 ICMP 不一定代表业务中断。

### 2.6 抓包与系统调用

只有前面的状态、日志、端口、DNS 和路由仍不能解释问题时，才进入这一层。

```fish
sudo tcpdump -ni any -c 50 'port 53'
```

🧪 最多抓 50 个 DNS 数据包并自动停止；数据包可能含地址、域名或业务内容，不要原样公开粘贴。

追踪一个可重复失败的命令：

```fish
strace -f -tt -s 256 -o /tmp/dig.strace dig example.com
bat /tmp/dig.strace
rm -f /tmp/dig.strace
```

🧬 记录并查看该命令的系统调用，然后删除这个精确的临时 trace；trace 可能包含路径、参数或敏感内容。

跨进程 attach、读取其他用户文件或抓取所有流量通常需要 sudo，也更容易暴露敏感信息。若不能明确说明要验证的假设，就先不要运行。

## 3. 工具怎么选

| 工具 | 它回答的问题 | 典型用途 | 不是用来做什么 |
| --- | --- | --- | --- |
| `fastfetch` | “我在哪台机器、什么系统和架构？” | 登录后的身份确认 | 不判断服务是否健康 |
| `btop` | “CPU、内存、磁盘 I/O 被谁占用？” | 实时资源和进程观察 | 不代替长期监控和告警 |
| `systemctl` | “某个 systemd unit 现在是什么状态？” | 查看 active/failed、依赖和启动结果 | 不应在未知原因时反复 restart |
| `journalctl` | “服务和内核刚才记录了什么？” | 按 unit、boot、时间查看日志 | 不应把未脱敏完整日志公开上传 |
| `ss` | “哪些 socket 正在监听或连接？” | 端口、协议、进程概览 | 不解释进程打开的普通文件 |
| `lsof` | “哪个进程打开了这个文件或端口？” | 端口占用、被占用 mount、已删除但仍打开的文件 | 不分析网络路径质量 |
| `dig` | “DNS 向我返回了什么？” | A/AAAA、指定 resolver、TTL 与响应码 | 不证明应用本身可用 |
| `mtr` | “到目标的逐跳延迟和丢包如何？” | 路由、间歇性延迟、疑似上游问题 | 单个中间节点不回应不等于终点丢包 |
| `tcpdump` | “线上实际收发了哪些包？” | DNS、握手、重传和接口方向确认 | 不适合作为第一步，也不要无限抓包 |
| `strace` | “进程最后卡在哪个系统调用？” | 文件缺失、权限、连接、阻塞和退出原因 | 不适合作为已知配置错误的替代方案 |
| `rg` | “哪些文件包含这段文本？” | 快速搜日志、配置和源码 | 不按文件名寻找 |
| `fd` | “名称匹配的文件在哪里？” | 比 `find` 更简洁地找文件 | 不搜索文件内容 |
| `fzf` | “我想从很多结果中交互筛选哪一个？” | 与 history、`fd`、进程列表组合 | 不产生原始数据 |
| `jq` | “JSON 的目标字段是什么？” | 过滤、格式化和验证 JSON | 不处理任意日志格式 |
| `bat` | “如何带高亮和行号安全查看文本？” | 配置、日志片段、trace 阅读 | 不替代结构化查询 |
| `eza` / `tree` | “目录里有什么、层级如何？” | 文件列表和浅层目录树 | 不扫描内容和容量 |
| `zoxide` | “如何快速回到常用目录？” | 按历史频率跳目录 | 不同步或备份目录 |
| `tmux` | “SSH 断开后如何保留终端任务？” | 长时间观察、构建和分窗 | 不让危险命令变安全 |
| `hx` | “如何在纯终端编辑文本？” | 临时记录、用户可写文件和经批准的配置修改 | 不应直接把生成的 `/etc` 文件当配置源 |
| `yazi` | “如何交互浏览和整理文件？” | 目录浏览、预览、选择文件 | 不应用 root 权限批量整理 production 数据 |
| `nh` | “如何更清楚地查看 Nix build 与 generation？” | 已知 Flake source 的 build/diff 界面 | 未批准时不得执行 production switch |
| `atuin` | “以前执行过什么命令？” | 本机历史搜索 | server 不参与跨设备同步 |
| `pay-respects` | “刚失败的常见命令可能怎样修正？” | 给出候选修正供人工复核 | 不应盲目执行建议，尤其是 sudo 命令 |

## 4. 常见场景

### 服务启动失败

1. 用 `systemctl status` 看退出码和最近日志。
2. 用 `journalctl -u` 看本次 boot 的完整上下文。
3. 用 `ss` / `lsof` 排除端口冲突。
4. 只有日志指向文件或 syscall 问题时才用 `strace`。
5. 不要把“重启后暂时恢复”当作根因已解决。

### 磁盘空间告急

1. `df -hT` 确认满的是哪个 filesystem。
2. `du -xhd1` 从该 mount 的一级目录向下定位。
3. `lsof +L1` 检查已删除但仍被进程占用的文件。
4. 不手删 `/nix/store`；Nix GC 和 generation 清理另走批准边界。

```fish
sudo lsof +L1
```

🕳️ 找出链接数为零、但仍被进程占用空间的打开文件。

### 域名解析异常

1. `resolvectl status` 看当前 link DNS。
2. `dig` 看响应码、记录类型和耗时。
3. `mtr` 看前往 resolver 或目标的路径质量。
4. 仍不清楚时，用有限 `tcpdump port 53` 判断请求是否发出、响应是否返回。

### SSH 或端口不可达

若当前会话仍在，保持它不要退出；另开 tmux pane 或第二个客户端做观察。依次确认 `sshd.service`、TCP 22 listener、firewall 现状和 auth log。不要为了“试一下”修改 SSH、network、DNS 或 firewall；这些都需要独立 Issue、行动卡和恢复路径。

## 5. 长任务与文件工作流

创建一个可在 SSH 重连后恢复的会话：

```fish
tmux new -s rescue
tmux ls
tmux attach -t rescue
```

🧵 创建、列出并重新进入名为 `rescue` 的持久终端会话。

tmux 内常用键：`Ctrl-b d` 脱离、`Ctrl-b c` 新窗口、`Ctrl-b %` 左右分屏、`Ctrl-b "` 上下分屏。

用 Helix 写临时事件记录、用 Yazi 浏览日志目录：

```fish
hx /tmp/incident-notes.md
yazi /var/log
```

🗂️ 在用户终端中记录排查过程并交互浏览日志；不要用 Yazi 批量改动 production 数据。

## 6. Nix 与 production 边界

server 的声明来自本仓库，主要由 nixbox 构建和验证 closure，再在独立批准下推送并 activation。Server 上看到的 `/etc`、systemd unit 和 profile 多数是生成结果，不应现场修改后当作长期修复。

以下动作必须停下来走独立 Issue 或当次行动卡：

- `nixos-rebuild switch`、`nh os switch` 或 profile rollback；
- reboot、shutdown、Rescue、Reinstall；
- SSH、network、DNS、firewall、端口或 provider 控制面修改；
- Nix GC、generation 删除、production 数据删除或迁移；
- 对真实服务执行 restart、数据修复或 restore，而当前问题尚未确认影响面。

一次有用的交接记录只需要：现象与时间、执行过的只读命令、关键错误摘要、受影响 unit/port/filesystem、是否仍保留可用 SSH/VNC 路径。Public IP、完整 auth log、packet capture、private path、key、token 和业务内容应脱敏或不进入 Issue。

## 7. Issue #99 activation 后的人工验收

本手册随声明先合并，不表示 production 已切换。未来取得当次批准并 activation 后，必须由维护者现场确认：

- macbook maintenance identity 能登录 `server:sayori`；
- Termius 的 Host Username 为 `sayori` 且绑定 maintenance identity；
- `sudo -n true` 与按需 `sudo -i` 正常；
- nixbox deploy identity 能登录同一个 `sayori` 并通过已批准的 `sudo -n` 检查；
- 两把 key 登录 `root` 都失败，password 与 keyboard-interactive 仍失败；
- SSH 仍只暴露 TCP 22，VNC 恢复路径可用，failed unit 为零；
- Helix、Yazi、`lsof`、`dig`、`mtr`、`tcpdump` 与 `strace` 可用，且没有新增 service、listener 或 firewall rule。

任何一项失败都停止后续动作，保留现有会话并按行动卡回滚；不要临时重新开放 root SSH。
