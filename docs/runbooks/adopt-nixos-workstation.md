# 接入现有 NixOS 工作站

本文是 Phase 5 / Issue #7 的构建、首次测试、验收与回滚手册。它不授权 Agent 对真实 NixOS 主机执行 `test`、`boot`、`switch` 或重启；每个真实机器动作均由维护者在明确关卡执行。

## 1. 本次接入会改变什么

- 将现有 NixOS 工作站作为 Flake output `nixbox` 纳入仓库。
- 原样保留已验证的 UEFI/systemd-boot、根与 EFI 文件系统、无 swap、Intel 硬件、NetworkManager、GNOME/GDM、PipeWire、Bluetooth、CUPS、Firefox、locale、用户与基础命令。
- 持久启用 `nix-command` 与 `flakes`。
- 永久启用最小 OpenSSH：只声明维护者公钥，禁用密码、keyboard-interactive 与 root SSH 登录。
- 保持 `system.stateVersion = "26.05"`。

本次不接入 Home Manager 或 LocalSend，不修改默认 Bash、磁盘布局、swap、GPU、Wi-Fi、桌面选型、用户密码或可变数据。

## 2. 模块所有权

| 路径 | 所有权 |
| --- | --- |
| `hosts/nixbox/hardware-configuration.nix` | 目标机硬件、根与 EFI 挂载、无 swap、平台与 Intel microcode |
| `hosts/nixbox/default.nix` | bootloader、当前 hostname、timezone、locale、`system.stateVersion` |
| `modules/nixos/administrator-user.nix` | 普通用户与 wheel system declaration |
| `software/{nix,nixpkgs,openssh,fish}/capabilities/` | Flakes、unfree package policy、key-only SSH 与登录 Shell |
| `software/{vim,wget,curl,pciutils,usbutils}/capabilities/` | Phase 5 现机 adoption 保留的基础命令与硬件盘点工具 |
| #203 的 workstation system owners | NetworkManager、桌面、XKB、打印、PipeWire、rtkit 与 Bluetooth |

首次实现先以单一 host 模块复刻现机，再机械拆分。拆分前后求值得到相同的 system derivation，证明模块边界没有改变最终闭包。

## 3. 构建验证

在仓库根目录运行：

```bash
nix fmt -- --check .
nix flake check
nix build .#nixosConfigurations.nixbox.config.system.build.toplevel
```

Apple Silicon Mac 可以完整求值该 `x86_64-linux` 输出，但锁定 NixOS 桌面闭包包含禁止替代的 Linux derivation；普通 Mac 用户无权强制 daemon 使用替代物，也不能本地编译它们。因此 Mac 侧必须如实记录跨架构 build 阻塞，完整 build 由目标机或同架构 CI 补做，不能把求值成功写成 build 成功。

## 4. 首次目标机预检

1. 保持 Mac 到目标机的现有 SSH 会话可用，并确认可以在目标机本地登录。
2. 确认 Mac 私有备份目录仍包含接入前的 `configuration.nix` 与 `hardware-configuration.nix`；不要把该目录提交 Git。
3. 记录当前永久 generation 和当前运行 system：

   ```bash
   sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
   readlink -f /run/current-system
   ```

4. 使用 Draft PR 的精确 commit，而不是浮动分支名。首次命令需临时开启 Flakes，因为旧 generation 尚未持久启用它。

## 5. 构建与 dry-activate

先在目标机只构建，不激活：

```bash
sudo nixos-rebuild build \
  --flake 'github:sayoriqwq/nix-config/<COMMIT>#nixbox' \
  --option experimental-features 'nix-command flakes'
```

成功后查看若执行 `test` 将改变哪些 unit 和文件：

```bash
sudo nixos-rebuild dry-activate \
  --flake 'github:sayoriqwq/nix-config/<COMMIT>#nixbox' \
  --option experimental-features 'nix-command flakes'
```

`build` 只生成 system closure；`dry-activate` 只报告差异。两者都不授权或代替真实 `test`。

## 6. 临时 test 关卡

只有维护者针对精确 commit 明确批准后，才由维护者在目标机运行：

```bash
sudo nixos-rebuild test \
  --flake 'github:sayoriqwq/nix-config/<COMMIT>#nixbox' \
  --option experimental-features 'nix-command flakes'
```

`test` 会切换当前运行态，但不会把新 generation 设为默认启动项。出现无法接受的问题时，重启应回到此前永久 generation。

## 7. 人工验收清单

- 本机用户可在 GDM 登录，GNOME 桌面正常。
- Wi-Fi、DNS 与普通网页访问正常。
- Mac 仍可通过公钥 SSH 登录；密码登录和 root 登录不应成为回退方式。
- 声音输入/输出、PipeWire 与音量控制正常。
- Bluetooth 可开启，并能连接现有设备。
- 打印服务没有异常；若有实际打印机，执行一次测试页。
- Intel 图形、屏幕亮度、外接显示器正常。
- 睡眠与唤醒正常。
- 键盘、触控板、USB 与 Thunderbolt 外设正常。
- `nix flake metadata` 可直接运行，证明新 generation 已持久声明 Flakes。
- `systemctl --failed` 无新增失败项。

把实际结果记录到 Issue #7。某项没有设备可测时应明确写“未测试”，不能写成通过。

## 8. 回滚与持久化

### test 阶段失败

优先在本地控制台正常重启；因为 `test` 没有改默认启动项，系统应回到此前永久 generation。SSH 不可用时不要继续远程试错。

### test 通过

先记录结果，再由维护者单独决定：

- `boot`：只把新 generation 设为下次启动项，不改变当前运行态；适合通过一次真实重启验证。
- `switch`：立即切换并设为默认启动项；变化更直接。

两者都需要新的明确批准。持久化后发生问题，在 systemd-boot 菜单选择已知好的 generation，再在可登录系统中恢复。

## 9. Phase 6 边界

Home Manager、共享 shell/dotfiles、桌面用户应用与 LocalSend 均在 Phase 6 单独接入。Phase 5 成功只证明系统层被 Flake 接管，不代表用户层迁移完成。
