# ADR-0005：macOS 使用 Lix 作为 Nix 实现

- **状态：** 已接受
- **日期：** 2026-07-20
- **决策范围：** `macbook` 的 Nix bootstrap 与 nix-darwin 系统层
- **批准记录：** 维护者在 Issue #4 / Phase 2 明确选择 Lix，并手动完成安装

## 背景

`macbook` 在 Phase 2 开始时没有 Nix、Lix、`/nix`、`/etc/nix`、Nix daemon 或安装收据。nix-darwin 本身不是 Nix 实现；在构建和激活 `darwinConfigurations.macbook` 前，必须先安装上游 Nix 或兼容实现。

原迁移路线只要求建立 Nix 基础设置，没有预先规定使用上游 Nix 还是 Lix。因此，Lix 不能被当作原计划中的隐含要求，必须作为可追溯的维护者决策记录。

nix-darwin 官方说明：

- 上游 Nix 与 Lix 都是受支持的前置实现；
- 官方 Nix 安装器不提供自动卸载器，而 macOS 手动卸载较复杂，因此新安装推荐考虑 Lix Installer；
- 安装器不决定 nix-darwin 后续使用的实现；若要继续使用 Lix，必须显式设置 `nix.package = pkgs.lix`。

## 决策

`macbook` 使用 Lix Installer 完成 bootstrap，并在 nix-darwin 配置中声明：

```nix
nix.package = pkgs.lix;
```

这意味着首次安装和后续由 nix-darwin 管理的 Nix 实现保持为 Lix。Flakes、Nix language、Nix Store、nixpkgs、Home Manager 与仓库 output 模型保持不变。

安装、构建和激活仍是不同人工关卡：

1. Lix 安装由维护者手动执行；
2. 原生 Darwin build 由维护者手动执行，且不激活；
3. 第一次 `darwin-rebuild switch` 需要新的明确批准。

截至 2026-07-20，维护者已在 `macbook` 使用 Lix 2.95.2 完成 `nix flake check --all-systems` 和 `darwinConfigurations.macbook.system` 原生构建，两者退出状态均为 `0`。这证明 Flake 可以在目标 Mac 上检查和构建；nix-darwin 仍未激活。

## 选择依据

- 当前 Mac 是干净环境，不需要兼容或迁移既有 Nix 安装；
- Lix Installer 提供安装收据和自动卸载入口，符合首次接入的可回滚要求；
- nix-darwin 官方同时支持并推荐这一 bootstrap 路径；
- 显式固定 `pkgs.lix` 避免首次 nix-darwin 激活时无意切换到上游 Nix；
- 维护者在了解上游 Nix 与 Lix 的差异后明确接受此方案。

## 安装事实

维护者于 2026-07-20 在 `macbook` 手动确认安装计划并完成安装。安装器报告成功完成：

- 创建加密 APFS `Nix Store` 并挂载到 `/nix`；
- provision Lix/Nix Store；
- 创建构建用户 UID 351–382 与 GID 350 的构建组；
- 配置 Time Machine exclusions；
- 配置 Nix、zsh 非交互 shell 支持与 PATH；
- 配置 launchd daemon；
- 清理临时安装目录。

安装成功不等于 nix-darwin 已构建或激活。安装后只读验证已确认：

- Lix 版本：`2.95.2`；
- system type：`aarch64-darwin`；
- additional system type：`x86_64-darwin`；
- system configuration：`/etc/nix/nix.conf`；
- store directory：`/nix/store`；
- state directory：`/nix/var/nix`；
- experimental features：`flakes nix-command`。

## 结果

### 正面

- macOS bootstrap 有安装收据和明确卸载入口；
- Lix 选择进入 Git、Issue 和 PR 历史，不依赖聊天记忆；
- nix-darwin 激活前后使用同一个 Nix 实现；
- 不改变一个 Flake、多主机 output 和 Home Manager 分层架构。

### 代价

- `macbook` 与当前 NixOS 工作站可能使用不同的 Nix 实现和版本；
- 排障和升级时必须注明问题发生在 Lix 还是上游 Nix；
- Lix 升级必须继续通过锁定的 nixpkgs/nix-darwin 配置评估，不能把安装器的自升级当作日常升级流程；
- 完整卸载 Lix 与回滚 nix-darwin generation 是不同操作，不能混用。

## 被否决的替代方案

### 官方 Nix Installer + 上游 Nix

兼容且更接近 NixOS 工作站当前实现，但 macOS 完整卸载和首次接入回退更复杂，本阶段不采用。

### Lix Installer bootstrap + 上游 Nix runtime

nix-darwin 官方说明技术上可行，但首次激活会切换实现，增加不必要的状态转换和认知成本，本阶段不采用。

### Determinate Nix

其 daemon 所有权和 nix-darwin 的 Nix 管理边界需要单独设计；当前 Issue 没有引入另一套 daemon 管理模型的需求，本阶段不采用。

## 操作与回滚边界

- 第一次 nix-darwin 激活前，安装器卸载入口为 `/nix/lix-installer uninstall`；具体命令以当时安装收据和 runbook 为准。
- 激活 nix-darwin 后，优先回滚 nix-darwin generation；不能用完整卸载代替 generation 回滚。
- Agent 不得自行执行 Lix 安装、卸载、升级、原生 Mac build 或 nix-darwin 激活。

## 参考

- [nix-darwin Prerequisites](https://github.com/nix-darwin/nix-darwin/blob/master/README.md#prerequisites)
- [Lix 官方安装说明](https://lix.systems/install/)
- [Issue #4：macOS 最小 nix-darwin 接入](https://github.com/sayoriqwq/nix-config/issues/4)

## 复审条件

出现以下情况时通过新的 Issue 与 ADR 复审，不直接修改 `nix.package`：

- Lix 与锁定的 nixpkgs、nix-darwin 或 Home Manager 出现持续兼容问题；
- Lix 项目的维护、安全或发布状态发生重大变化；
- 多主机运维明确需要统一 Nix 实现，并有证据表明差异造成实际成本；
- 上游 Nix Installer 在 macOS 上提供同等可靠的自动卸载与升级路径；
- 维护者决定迁移回上游 Nix。
