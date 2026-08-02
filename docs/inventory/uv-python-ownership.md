# uv、Python 与兼容 PATH 所有权

本文记录 Issue #34 的 uv 终态边界，以及 Issue #67 批准的 macbook agent Python
基线、验收关卡与回滚方式。Nix 提供可复现的 uv 入口和一个裸 Python 解释器；
项目 Python 选择、虚拟环境和依赖仍由 uv 管理。

## 1. 回归原因

提交 `0e5e028` 曾通过 `home.sessionPath` 声明 `~/.local/bin`。Phase 4 shell 模块拆分提交 `6d58506` 只保留了 Home Manager profile 路径，遗漏兼容路径，导致仍位于 `~/.local/bin/uv` 的旧 uv 无法被 Shell 发现。

本次修复同时把 Nix profile 放在 `~/.local/bin` 之前。这样 Nix 提供的 uv 会成为默认入口，而其他尚未迁移的用户工具仍可继续使用。

## 2. 终态所有权

| 对象 | 唯一所有者 | 约束 |
| --- | --- | --- |
| uv 可执行文件 | Nix/Home Manager | 由锁定 nixpkgs 提供，优先于兼容 PATH 中的同名工具 |
| agent 基线 Python | Nix/Home Manager | 仅由 macbook 的 AI 辅助运维能力提供 `python314`，同时暴露 `python`、`python3` 与 `python3.14` |
| 项目 Python 选择 | uv | 根据项目 `.python-version` 与 `requires-python` 解析，可以选择满足约束的系统或 uv-managed interpreter |
| `.venv`、Python 依赖、`uv.lock` | uv 与项目 | 属于项目声明和可变开发状态 |
| 全局第三方 Python packages | 无 | 不使用 `python.withPackages` 或用户级 pip 污染 agent 基线；临时与项目依赖使用 uv |
| Node、Bun、pnpm | mise | 保持既有唯一所有权，不接管 Python 或 uv |
| `~/.local/bin/**` | 用户可变状态 | 仅作为低优先级兼容路径；Nix 不扫描、同步、覆盖或清理 |

Home Manager 求值包含两类硬约束：共享 mise 工具表不得出现 Python 或 uv；
`home.packages` 最多包含一个 Python interpreter。macbook check 进一步要求这个唯一
基线必须是锁定 nixpkgs 的 `python314`。Node/Bun 的既有冲突检查保持不变。

### 2.1 agent 基线不是项目版本管理器

Codex 等 agent 可能从 GUI 或非交互式进程启动，不能假设已经进入 direnv、项目
dev shell 或 mise activation。`python314` 因此由 AI 辅助运维能力的内部 primitive
直接加入 Home Manager profile；该路径已经是 macbook 的稳定用户命令入口。

这个解释器只保证标准库和通用 `python` 命令可用，不替代 uv。进入声明了
`.python-version` 或 `requires-python` 的项目后，uv 仍负责选择兼容版本、创建
`.venv` 和同步依赖。当前锁定版本为 Python 3.14.6；升级 minor 必须通过后续窄范围
维护，而不是使用可变的 `latest`。

## 3. 未激活验证

实现阶段只执行格式化、求值和构建，不改变真实机器：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system
nix build .#checks.aarch64-darwin.macbook-agent-python
nix eval --raw .#darwinConfigurations.macbook.pkgs.python314.version
nix eval --json .#darwinConfigurations.macbook.config.home-manager.users.sayori.home.sessionPath
```

`home.sessionPath` 可以包含平台专用路径，但 Home Manager profile 必须位于
`/Users/sayori/.local/bin` 之前。本次 macbook 求值结果为 PostgreSQL、Home Manager
profile、`~/.local/bin`，相对优先级符合约束。

## 4. 激活后验收关卡

只有维护者审阅精确 commit 并另行批准后，才可激活 macbook。打开全新 Fish 后执行：

```fish
command -s uv
uv --version
command -s python
command -s python3
python --version
python3 --version
uv python find
cd /Users/sayori/Desktop/work/yanhuang-agent-platform
make check
```

通过条件：

- `uv` 来自 Nix/Home Manager profile，而不是 `~/.local/bin/uv`；
- `python` 与 `python3` 都来自 Nix/Home Manager profile，版本为已审阅的 3.14 patch；
- uv 在项目上下文解析满足声明的 Python 3.12；
- 项目检查通过，且项目的 `.python-version`、`pyproject.toml`、`uv.lock` 与 `.venv` 未被本仓库修改；
- `~/.local/bin` 仍在 PATH，其中其他用户工具仍可发现；
- 旧 `~/.local/bin/uv` 保留，未被覆盖或删除。

## 5. 回滚与清理边界

激活异常时切回前一个 nix-darwin generation；这会同时撤回 agent Python 基线，
但不删除 uv-managed Python、项目 `.venv` 或旧 `~/.local/bin/uv`。旧 uv 被完整保留，
因此也可临时使用以下命令恢复入口：

```fish
env PATH="$HOME/.local/bin:$PATH" make dev
```

本 Issue 不删除旧 uv。只有 Nix 版本完成实机验收并获得单独的当前批准后，维护者才能决定是否清理 `~/.local/bin/uv`；该决定不得扩大为扫描或清理 `~/.local/bin` 中的其他内容。
