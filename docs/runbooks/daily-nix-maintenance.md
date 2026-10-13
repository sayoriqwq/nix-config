# 日常 Nix 维护

在准备应用的 checkout 根目录执行。以下命令针对 `macbook`；职责与写入边界见[架构](../architecture.md)，机器操作遵循 [AGENTS.md](../../AGENTS.md)。

## 检查配置

```fish
nix fmt -- --check .
nix eval --raw .#darwinConfigurations.macbook.system.drvPath
nh darwin build . -H macbook --diff always
```

🔎 检查格式、求值并构建 Mac 候选，不激活。文档修改只检查链接与内容；Linux 候选在具备对应构建条件的机器上验证。

## 应用配置

先保存本次想保留的受管字段修改，审阅并本地提交，保留无关工作；修改设置无需更新输入。

```fish
nh darwin switch . -H macbook --ask --show-activation-logs
```

🔧 构建候选并显示包差异，确认后激活整份 Mac 配置；按提示输入系统密码。

确认目标、变更范围和可用恢复点。包差异不包含全部偏好、可写文件与登录任务变化；未保存的受管字段修改可能被覆盖。应用后按改动检查实际功能；终端环境变化需重新打开进程，不能只重新加载配置。

## 更新 Nix 包集

```fish
./bin/workstation update nix
```

🧰 仅更新 `nixpkgs-darwin`，构建并展示候选；确认后应用同一产物，实际功能验收通过后仅本地提交本次 `flake.lock`，不推送。

包集更新可能影响多个软件与依赖。入口要求先提交或隔离已有配置、lock 改动，允许并保留文档差异和已暂存的其他工作；其他独立输入与固定 tag 按实际需要另行更新。构建失败、取消或未验收时保留差异、不生成成功提交；审阅期间源码或 lock 改变则停止。

仅准备更新候选时使用：

```fish
nh darwin build . -H macbook --update-input nixpkgs-darwin --diff always
```

🔍 更新所选输入并构建，不激活、不提交；后续自行审阅、应用与验收，已有 lock 差异不能混入新一轮自动更新。

## 更新原生应用

```fish
./bin/workstation update qq
```

⬆️ 核实已声明且已安装的 QQ，尝试刷新官方 API 目录、预览定向升级并检查安装记录；结束前确认应用能启动和正常使用。

也接受其他已声明官方 cask 的全名或唯一短名。未安装、来源不明、第三方 tap、非 API 模式或升级涉及其他软件与依赖时停止；不强制重装或清理。入口不执行全局 `brew update`；目录维护单独处理。API 失败可能沿用缓存，应留意原始提示；无可用更新不等于已验证真实升级。

Homebrew 更新通常不改变声明，不制造空提交。应用内更新继续使用各软件自身入口；需要检查更新与配置应用能否并存时，在实际更新后重启应用，再按本次范围应用并验证，勿为了测试强制升级。

## 更新入口的测试

```fish
uv run --no-project python tests/workstation_test.py
```

🧪 用临时 Git 仓库与假工具运行 Python 标准库测试，不更新真实软件或系统；uv 在缺少解释器时可能下载 Python，无需增加全局 Python 声明。[uv 脚本说明](https://docs.astral.sh/uv/guides/scripts/)

## 恢复已知可用配置

```fish
sudo darwin-rebuild --list-generations
```

🕘 查看保留代际，识别更新前已验收的恢复点。

```fish
sudo darwin-rebuild --rollback
```

↩️ 仅在上一代就是目标恢复点时使用；这会真实激活上一代配置。

需要更早代际时按列表选择并使用 `--switch-generation`，不要连续盲退。恢复后检查实际功能，并修复或撤销失败声明；保留恢复点直到新配置验收完成。原生应用、macOS 偏好和应用数据不保证随代际恢复，详见 [Mac 恢复](restore-macos-environment.md)。
