# SOPS / age 机密管理 Runbook

> 本文适用于 Phase 11 已建立的基础能力。当前仓库没有实际 secret 声明；每项新增、轮换、撤销或 activation 都必须由独立 Issue 明确批准。不得把 identity、明文、解密输出或真实凭据粘贴到 GitHub、聊天或日志。

## 1. 身份职责

- 管理员 identity：只在 macbook 编辑和灾难恢复使用，现有文件位于 `~/Library/Application Support/sops/age/keys.txt`；恢复副本由维护者在仓库外自行管理。
- 主机 identity：复用每台机器已有的 `/etc/ssh/ssh_host_ed25519_key`；sops-nix 只在本机 activation 或 boot 时读取。
- Git：只保存 `.sops.yaml` 的 public recipients，以及经过独立批准的 SOPS 密文。

管理员 identity 不下发到 nixbox 或 server。仓库不再提供 identity 初始化 helper，也不会覆盖、读取或复制现有 identity。

## 2. 只读确认管理员 identity

只检查文件 metadata，不打印内容：

```fish
rtk /usr/bin/stat -f 'type=%HT owner=%Su group=%Sg mode=%Lp path=%N' "$HOME/Library/Application Support/sops/age/keys.txt"
```

🔎 确认现有管理员 identity 是本人持有的 mode `600` 普通文件

如果文件缺失、owner 或 mode 异常，停止 secret 变更并单独处理身份恢复；不要运行会生成新 key 的命令覆盖它。

## 3. 新增真实 secret 的前置合同

实施 Issue 必须逐项记录：

- 消费者与目标 host；
- SOPS source file、key 和 runtime path；
- owner、group、mode；
- 管理员与 host recipients；
- service reload/restart 顺序；
- rotation window、失败回滚和可恢复性边界；
- build、逐机 activation 与只读验收命令。

没有这些事实时，不创建占位密文，也不把 secret 值写进 Nix 字符串、命令行参数、Issue 或日志。

## 4. 创建或编辑获批密文

在 macbook 的 clean checkout 中确认目标路径能匹配 `.sops.yaml` 对应 host rule，然后直接用 SOPS 创建或编辑文件，不先落地明文：

```fish
rtk sops secrets/HOST/NAME.yaml
```

✏️ 只在 SOPS 编辑会话中处理获批 secret

保存后只检查 diff 结构、目标 host rule 和 recipient metadata；不得用 `cat`、shell tracing 或聊天复制验证明文。Nix 消费者必须通过运行时文件读取，不把解密值插入 Store。

## 5. 新增或轮换 recipient

1. 只从目标 identity 的 public half 派生 recipient；不得移动或读取 private half。
2. 在 `.sops.yaml` 对应 host rule 中修改 recipient，不扩大其他 host rule。
3. 由仍可解密的管理员更新精确文件：

```fish
rtk sops updatekeys secrets/HOST/NAME.yaml
```

🔄 让获批密文的 recipient metadata 与已审阅规则同步

4. 验证新 recipient 的本机解密与消费者行为后，才提交撤销旧 recipient 的独立变更。
5. 若旧 identity 疑似泄露，轮换密文 data key 并审计它曾获授权的所有文件；仅移除 recipient 不能撤回已经暴露的明文。

## 6. 撤销设备或 secret

- 从精确 creation rule 删除旧 recipient，并对所有受影响文件运行 `sops updatekeys`；必要时运行 `sops rotate`。
- 在新 identity 验证通过前保留管理员恢复入口。
- SSH host identity 轮换同时改变 known-hosts 信任，必须另建 SSH/production 行动卡。
- 删除 secret 时，同时删除消费者声明与密文；真实机器的运行时文件只有在该 host 获得单独批准并激活新配置后才会消失。

## 7. 验证与 activation

提交前运行仓库级检查：

```fish
rtk nix fmt -- --check .
rtk nix flake check path:.
```

✅ 验证格式、recipient 策略、私钥标记扫描和各主机声明

每台机器单独 build、审阅和批准 activation。Build 成功不授权 switch。activation 后只对 Issue 记录的精确 runtime path 检查 type、owner、group 和 mode；内容验收只在目标机本地完成并记录 PASS/FAIL，不粘贴内容。

macOS metadata 示例：

```fish
rtk /usr/bin/stat -f 'type=%HT owner=%Su group=%Sg mode=%Lp path=%N' /run/secrets/NAME
```

🔎 在 macbook 检查获批 secret 的运行时 metadata

NixOS metadata 示例：

```fish
rtk /usr/bin/stat -Lc 'type=%F owner=%U group=%G mode=%a path=%n' /run/secrets/NAME
```

🔎 在 nixbox 或 server 检查获批 secret 的运行时 metadata
