# ADR-0003：使用 sops-nix 与 age 管理部署机密

- **状态：** 已接受
- **日期：** 2026-07-17
- **决策范围：** 机密声明与部署

## 背景

三台机器未来会需要 API token、服务密码、私有环境变量等机密。普通 Nix 字符串可能进入 Nix Store，Git 历史也无法安全保存明文。完全依赖手工复制则难以复现权限、路径和服务依赖。

## 决策

采用 sops-nix + age：

- 仓库只提交 SOPS 加密后的文件和公开 age recipient；
- 管理员 age 私钥与恢复副本保存在仓库外，其介质、位置和保护方式由维护者自行管理；
- 每台目标机器使用独立、可轮换的解密身份；
- Nix 声明 secret 的目标路径、owner、group、mode 与服务依赖；
- 服务优先通过运行时文件读取 secret，不把明文插值为普通 Nix 字符串；
- Server 最小 NixOS 稳定后，先用非生产示例验证解密、权限与轮换，再接入真实服务；
- PR、Issue、构建日志和 inventory 中不得粘贴明文 secret。

## 结果

### 正面

- 加密配置可以和系统声明一起版本化；
- recipient、文件权限和服务依赖可审计；
- 可以按机器或角色控制解密能力；
- secret 轮换不需要把明文传播到 Git；
- 与 NixOS 和 nix-darwin 都能集成。

### 代价

- 必须安全备份并轮换 age 私钥；
- 首次安装存在“机器身份尚未建立”的 bootstrap 设计；
- 错误地把 secret 值插值进 Nix 仍可能泄漏到 Store；
- 丢失所有可解密私钥会导致加密文件不可恢复。

## Bootstrap 策略

- Mac 上建立管理员 age identity，并由维护者自行管理仓库外恢复副本；
- 本地 NixOS 工作站可使用独立 recipient；
- 服务器最小安装阶段不依赖业务 secret；
- 服务器成功启动并确认 SSH host identity 后，再把服务器 recipient 加入 `.sops.yaml`，重新加密并部署业务 secret；
- bootstrap 私钥、恢复密钥和明文迁移文件不得提交。

## Phase 11 身份与文件模型

- 管理员使用独立 X25519 age identity，只负责编辑、recipient 变更与灾难恢复；本机文件位于 SOPS 的 macOS 默认目录，恢复副本的介质、位置和保护方式由维护者在仓库外自行决定，Phase 11 不把 Agent 验证备份设为 activation 前置条件；
- `macbook`、`nixbox` 与 `server` 各自复用已经存在的 Ed25519 SSH host identity，仓库只记录由 public host key 派生的 age recipient；
- 每个 host 拥有独立的加密文件，creation rule 只包含管理员 recipient 与该 host recipient；主机不能横向解密其他主机文件；
- sops-nix 系统 adapter 只读取 `/etc/ssh/ssh_host_ed25519_key`，不生成第二份机器私钥，也不把管理员 identity 下发给主机；
- SOPS、age 与 SSH-to-age 编辑工具只组合到 macbook；nixbox 与 server 只运行 sops-nix 的本机解密路径，不获得 secret 编辑工具，server 也不获得 GitHub 协作凭据；
- Phase 11 的非生产示例固定为 `/run/secrets/phase11-demo`、owner 为 `sayori`、mode 为 `0400`。未来真实服务必须在 Phase 12 或独立 Issue 重新确认 owner、path、mode、recipient 与服务 reload/restart 合同。

## 被否决的替代方案

### 明文 `.env` 提交到私有仓库

Git 历史和权限边界不足以替代机密管理，不采用；仓库当前还是 public，更不可接受。

### 把 secret 直接写在 Nix 表达式中

会进入 Git 和潜在的 Nix Store，不采用。

### 完全手工 scp

可以作为紧急恢复手段，但缺少声明式权限和审计，不作为常规方案。

### 一开始引入完整外部 secret service

对当前三台机器复杂度过高。未来有动态凭证、多人权限或集中审计需求时再评估 Vault 等系统。

## 复审条件

- 增加多用户或组织级访问控制；
- 需要短期动态凭证；
- 需要集中审计、自动轮换或硬件密钥；
- age key 的运维成本不可接受。
