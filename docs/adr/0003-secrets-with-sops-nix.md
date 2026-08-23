# ADR-0003：SOPS readiness 历史与机密安全边界

- **状态：** 已被 Issue #205 取代
- **日期：** 2026-07-17
- **取代日期：** 2026-08-24
- **决策范围：** 机密声明与部署

## 历史决策

Phase 11 曾采用 sops-nix + age，以非 production demo 验证三台机器各自使用 SSH host identity 解密本机 SOPS 文件的路径。管理员 identity、恢复副本与 host private identity 始终保存在仓库外；Git 只保存公开 recipient、加密文件与声明式运行时 metadata。验收完成后 demo 与 helper 已退出，仓库长期没有真实 secret 或 service consumer。

## 当前决策

Issue #205 在仓库静态 import graph、三个 Host 的 Nix evaluation 与最终 service/unit 配置均证明没有 consumer 后，退役空的 SOPS readiness：

- 删除 sops-nix Flake input 与仅由它可达的 lock node；
- 删除 `.sops.yaml`、空部署 adapter、macbook 管理工具和 SOPS-only 文档；
- 三台 Host 不再选择 secret deployment，macbook 不再安装 SOPS、age 或 SSH-to-age；
- 不引入替代框架，也不预设未来 credential path、recipient 或 service 合同；
- 不读取、列举、检查或修改任何仓库外 identity、credential、runtime secret 或密钥集合。

这项退役只改变仓库声明。它不声称真实机器上的历史 runtime 文件已消失，也不授权 activation 或 mutable-state cleanup。

## 继续有效的安全原则

- 明文 secret 不得进入 Git、Nix Store、Issue、PR、聊天或日志；
- private identity、credential 与恢复介质保持在仓库所有权之外，Agent 不读取或验证其内容；
- future consumer 必须由独立 Issue 明确目标 Host、secret source、runtime path、owner、group、mode、服务依赖、reload/restart、rotation、recovery 与 rollback；
- 服务应通过受权限控制的运行时文件读取 secret，不能把值作为普通 Nix 字符串插值；
- build 不授权 activation，删除声明也不授权删除真实运行时文件；
- 若未来重新采用 SOPS、外部 secret service 或其他机制，必须根据当时的真实 consumer 与风险重新做出决策，不能把本 ADR 的历史实现当作默认方案。

## 结果

### 正面

- 无 consumer 的依赖、Host imports、用户工具与维护文档不再制造虚假能力；
- Flake 与 lock graph 更小，不再为三台 Host 求值无效的 secret module；
- 未来设计由真实 consumer 驱动，而不是受历史 readiness 约束。

### 代价

- 未来首次出现 secret consumer 时，需要重新选择、引入并验证部署机制；
- 历史 activation 可能留下仓库外运行时状态，只有绑定 exact commit 的独立人工关卡才能检查或清理。

## 复审条件

- 出现第一个真实 service credential consumer；
- 需要短期动态凭证、集中审计、自动轮换或硬件密钥；
- 增加多用户、自动化主体或组织级访问控制。
