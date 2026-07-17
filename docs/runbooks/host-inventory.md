# 主机盘点手册

本文用于在编写任何主机专属 Nix 配置前，收集可验证、可脱敏的机器事实。它只包含只读盘点步骤，不授权激活配置、修改系统或执行破坏性操作。

## 1. 盘点原则

- 原始命令输出默认保留在本机，不直接提交 Git。
- 只把复现配置所需的非秘密事实整理到当前 Phase Issue；确有长期价值时，再提交脱敏后的 inventory 文档。
- 必须隐去公网 IP、MAC 地址、序列号、账号 ID、token、私钥、私有域名、完整 SSH key、磁盘中的业务路径和其他敏感信息。
- 不猜测未知值。无法确认时填写 `UNKNOWN`，并注明需要在哪台机器上补充什么证据。
- `system.stateVersion` 和 `home.stateVersion` 必须从现有配置读取，不能按当前 NixOS/Home Manager 版本推断。
- 任何命令如果可能暴露秘密，先人工检查输出，再贴到 Issue 或交给 Agent。

## 2. 每台主机都要确认的事实

| 类别 | 需要确认 |
| --- | --- |
| 身份 | 逻辑角色、拟定 output 名称、真实主机名是否可以公开 |
| 平台 | 操作系统版本、CPU 架构、Nix 版本和安装方式 |
| 用户 | 主用户、home 路径、默认 shell、管理员权限模型 |
| Nix 状态 | Flakes 是否启用、现有配置位置、已有 channel/profile |
| 状态版本 | 现有 `system.stateVersion` / `home.stateVersion` 及来源文件 |
| 软件 | 需要保留的软件、包管理器来源、关键 dotfiles |
| 服务 | 已启用服务、监听端口、容器与依赖关系（脱敏） |
| 恢复 | 当前配置备份、回滚路径、控制台或救援入口 |

## 3. 通用只读命令

```bash
id
uname -a
uname -m
hostname
printf 'SHELL=%s\nHOME=%s\n' "$SHELL" "$HOME"
command -v nix >/dev/null && nix --version
command -v git >/dev/null && git --version
```

盘点配置文件时只列路径，不要直接发布完整内容：

```bash
find "$HOME/.config" -maxdepth 2 -type f 2>/dev/null | sort
find "$HOME" -maxdepth 1 -type f \
  \( -name '.*rc' -o -name '.*profile' -o -name '.gitconfig' \) \
  2>/dev/null | sort
```

## 4. macOS 工作站

```bash
sw_vers
uname -m
scutil --get ComputerName
scutil --get LocalHostName
command -v nix >/dev/null && nix --version
command -v brew >/dev/null && brew --prefix
command -v brew >/dev/null && brew leaves
command -v brew >/dev/null && brew list --cask
command -v mas >/dev/null && mas list
```

还要人工确认：

- Nix 是官方、Determinate、Lix 还是其他安装方式；
- Mac 是 Apple Silicon 还是 Intel；
- 当前 shell、终端、编辑器和必须保留的 GUI 应用；
- Homebrew formula/cask 中哪些应迁移到 Nix，哪些必须继续使用 Homebrew；
- 现有 macOS defaults 中哪些确实需要声明；
- 第一次 `darwin-rebuild` 前的配置备份与回滚方式。

不要把 Apple ID、MAS 账号信息、设备序列号或私有主机名提交到仓库。

## 5. NixOS 工作站

```bash
nixos-version
uname -m
readlink -f /run/current-system
sudo lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
findmnt
if test -d /sys/firmware/efi; then echo UEFI; else echo BIOS; fi
lspci -nn 2>/dev/null || true
systemctl list-unit-files --state=enabled
```

从现有配置中定位状态版本和 imports：

```bash
sudo grep -R "system.stateVersion\|home.stateVersion\|hardware-configuration" \
  /etc/nixos 2>/dev/null
```

必须保存并原样接入的证据：

- `/etc/nixos/hardware-configuration.nix`；
- 当前 bootloader、文件系统、swap 和 GPU 配置；
- 当前 `system.stateVersion`；
- 桌面环境、显示管理器、音频、蓝牙、网络和显卡的工作状态；
- 可启动的上一代 generation 与回滚方法。

硬件配置原件可以进入私有工作分支，但在公开仓库提交前要检查序列号、UUID、主机名和其他敏感信息。

## 6. Ubuntu Server 过渡与迁移盘点

### 系统和启动

```bash
cat /etc/os-release
uname -m
sudo lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
findmnt
if test -d /sys/firmware/efi; then echo UEFI; else echo BIOS; fi
```

### 网络和服务

以下输出可能包含公网地址、私有地址、域名、用户名或业务路径，发布前必须脱敏：

```bash
ip -brief address
ip route
sudo ss -lntup
systemctl list-unit-files --state=enabled
systemctl --failed
```

### 容器和业务

```bash
command -v docker >/dev/null && docker version
command -v docker >/dev/null && docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
command -v docker >/dev/null && docker compose ls
command -v podman >/dev/null && podman ps
```

还要建立人工清单：

- 每个服务的来源、启动方式、端口和依赖；
- Compose 文件、镜像 tag、bind mount、volume 和 `.env` 的位置；
- 数据库类型、版本、原生 dump 命令与恢复验证；
- TLS 证书、DNS、反向代理和外部依赖；
- provider 的 Rescue、VNC/Console、snapshot 和重装能力；
- 目标磁盘、boot mode、网络模式和 SSH 恢复路径；
- 至少一个异机备份及最近一次恢复测试结果。

不得把 `.env`、数据库 dump、TLS 私钥、SSH 私钥或 provider 凭据提交到此仓库。

## 7. 脱敏后的 Issue 摘要模板

```md
## 主机事实

- 逻辑角色：
- 拟定 output：
- OS / 版本：
- 架构：
- Nix 版本与安装方式：
- 主用户与 home：
- 现有配置位置：
- system.stateVersion：
- home.stateVersion：
- boot mode：
- 磁盘模型：仅描述类型与容量，不记录序列号
- 网络模型：DHCP / 静态 / provider 注入；地址已脱敏
- 必须保留的软件与服务：
- 已确认的回滚路径：
- 未确认事实：
- 证据采集日期：YYYY-MM-DD
- 证据采集人/会话：
```

## 8. 完成判定

只有当当前阶段需要的每项主机事实都具备来源，且未知项不会被 Agent 用猜测替代时，inventory 才算完成。盘点完成不代表可以执行 `switch`、修改网络、重启、格式化磁盘或运行 `nixos-anywhere`；这些仍需对应 Issue 的当次人工批准。