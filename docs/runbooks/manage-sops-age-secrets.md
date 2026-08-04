# SOPS / age 机密管理 Runbook

> 本文适用于 Phase 11 建立的非生产基础。命令只在对应行动卡获得维护者当前批准后执行；不得把 identity、明文、解密输出或真实凭据粘贴到 GitHub、聊天或日志。

## 1. 身份职责

- 管理员 identity：只在 macbook 编辑/恢复使用，保存在 `~/Library/Application Support/sops/age/keys.txt`，另有一份加密离线备份。
- 主机 identity：复用每台机器已有的 `/etc/ssh/ssh_host_ed25519_key`；sops-nix 只在本机 activation/boot 时读取。
- Git：只保存 `.sops.yaml` 的 public recipients 与 `secrets/` 中的 SOPS 密文。

管理员 identity 不下发到 nixbox 或 server；server 不安装 GitHub 协作凭据，也不需要 checkout 仓库即可运行已推送 closure。

## 2. 初始化管理员 identity

在 macbook 的 Phase 11 clean checkout 运行：

```fish
rtk nix run .#phase11-init-admin-key
```

🔑 创建 mode `0600` 的管理员 identity 并只输出 public recipient

helper 拒绝参数、`sudo`、symlink 和已有目标，绝不覆盖旧 identity。只记录 `public-recipient=age1...`；不要复制 identity 文件内容。

## 3. 离线备份与恢复验证

首选一块与 macbook 分离、静置时加密的外部介质。维护者在本地把 identity 复制为单独文件，保持只对本人可读；介质标签不得包含 private key 或 secret 内容。备份完成后，在不打印文件内容的前提下分别执行 `age-keygen -y`，两个 public recipient 必须完全一致。

若没有已挂载且确认加密的离线介质，停止在这里，不 activation。云同步目录、Git 仓库、普通 U 盘、Issue 附件和聊天都不是合格备份位置。

恢复演练只在临时隔离目录进行：从离线介质复制恢复副本，确认 mode、owner 与 public recipient，随后删除临时副本并确认原工作副本未被覆盖。不得通过 `cat`、剪贴板或 shell trace 检查 identity。

## 4. 编辑非生产示例

维护者工作站 activation 后，进入 clean checkout 并直接让 SOPS 打开对应密文；不要先创建明文文件：

```fish
rtk sops secrets/macbook/phase11-demo.yaml
```

✏️ 在内存和编辑器临时缓冲中编辑 macbook 的 SOPS 密文

所有 host 文件都只在 macbook 编辑；nixbox 与 server 不承担编辑职责。保存后先检查 Git diff 只出现 `ENC[...]` 与 SOPS metadata，再运行 Phase 11 checks。

## 5. 新增或轮换 recipient

1. 只从目标 identity 的 public half 派生 recipient；不得移动或读取 private half。
2. 在 `.sops.yaml` 对应 host rule 中增加新 recipient，不扩大其他 host rule。
3. 由仍可解密的管理员运行：

```fish
rtk sops updatekeys secrets/<host>/phase11-demo.yaml
```

🔄 让目标密文的 recipient metadata 与已审阅规则同步

4. 验证新 recipient 可解密后，再提交撤销旧 recipient 的独立变更。
5. 若旧 identity 疑似泄露，先按 compromise 处理：停止使用、轮换密文中的 data key，并审计该 identity 曾获授权的全部文件；仅移除 recipient 不会撤回已经看过的明文。

## 6. 撤销设备

- 从该 host 的 creation rule 删除旧 recipient；
- 对所有受影响文件运行 `sops updatekeys`，必要时使用 `sops rotate` 轮换 data key；
- 在新 identity 验证通过前保留管理员恢复入口；
- 维护者确认不再需要回滚后，才在目标机侧销毁旧 identity；
- SSH host identity 轮换还会影响 known-hosts 信任，必须另建 SSH/production 行动卡，不能作为普通 secret 变更顺带执行。

## 7. 首次 activation 与权限检查

每台机器单独 build、单独审阅、单独批准 activation。build 成功不授权 switch。activation 后只检查 metadata，避免命令输出明文：

```fish
rtk stat -f '%Su:%Sg %Lp %N' /run/secrets/phase11-demo
```

🔎 在 macbook 检查运行时 symlink 目标的 owner、group 与 mode

```fish
rtk stat -Lc '%U:%G %a %n' /run/secrets/phase11-demo
```

🔎 在 nixbox 或 server 检查运行时 secret 的 owner、group 与 mode

预期 owner 为 `sayori`、mode 为 `400`；Darwin group 为 `staff`，NixOS group 以声明求值结果为准。内容验收由维护者在目标机本地完成，只记录 PASS/FAIL，不粘贴内容。

## 8. Phase 12 production-secret 关卡

每一项真实 secret 必须在 Phase 12 或独立 Issue 逐项记录：消费者、host、source file、key、runtime path、owner、group、mode、recipient、reload/restart 行为、轮换窗口、失败回滚与备份边界。没有这些事实，不增加占位 production secret，也不复用 `phase11-demo` 作为业务入口。
