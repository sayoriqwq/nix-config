# 日常 Nix 维护

适用：本机 nh 4.4.2、`darwinConfigurations.macbook` 和集成式 Home Manager。在准备应用的 nix-config checkout 根目录执行。原则见[主工作站管理](../architecture/workstation-management.md)。

## 修改后的验证

先格式化并求值受影响的 Host；需要构建候选时，在 macbook 的 checkout 中执行：

```fish
nix fmt -- --check .
nix eval --raw .#darwinConfigurations.macbook.system.drvPath
nh darwin build . -H macbook --diff always
```

🔎 检查格式、求值并构建 Mac 候选，不激活；Linux 候选应在具备对应构建条件的机器上构建。

仓库不维护独立 checks。nh 构建和包差异不能证明交互行为：激活后按本次范围确认主力终端进入 Fish、兼容终端进入 Zsh、编辑器快捷命令与任务能找到程序，服务端仍能使用所需 Shell／CLI。

## 修改配置后应用

本次明确想保留的现场配置修改先保存到声明，再审阅并提交，保留无关工作。未保存的受管字段修改可以被覆盖，常规应用不强制逐字段比对或制作备份。Zed 的可写合并会在每次激活重新应用声明，具体行为见 [Zed 手册](update-zed-preview.md)；额外未声明设置不构成偏移。修改设置无需更新输入：

```fish
nh darwin switch . -H macbook --ask --show-activation-logs
```

🔧 构建候选、展示包差异，确认后激活整份 Mac 配置；按提示输入系统密码。

确认前核对目标、变更范围和已知可用 generation；包差异不包含所有偏好、可写文件或外部应用变化。真实机器操作仍遵循 [AGENTS.md](../../AGENTS.md) 的授权条件。应用后按本次变更检查实际效果；终端启动问题需区分重新加载配置与完整重启进程。

## 准备包集更新候选

日常定向更新使用仓库入口；它会修改 lock，不是只读查询。先完成或隔离已有配置改动，文档差异和已暂存的其他工作会保留：

```fish
./bin/workstation update nix
```

🧰 仅更新 `nixpkgs-darwin`，构建并展示候选；确认后应用刚才的产物，实际功能验收通过后自动本地提交本次 `flake.lock`，不推送。

更新一个包集可能影响多个软件与依赖。入口不会更新其他独立输入；固定 tag 的来源需要显式改变版本选择。构建可能下载或本地编译；构建失败、取消应用或尚未验收时会保留 lock 差异，不生成成功提交。源码或 lock 在审阅期间改变时停止，必须重新准备候选。

若希望仅准备候选而不进入应用流程，可继续使用底层工具：

```fish
nh darwin build . -H macbook --update-input nixpkgs-darwin --diff always
```

🔎 更新所选输入并构建，不激活、不提交；后续由维护者自行处理候选与验收。

入口开始时遇到已有 lock 变化会停止，以免混入另一轮工作。不要把手工准备后的 lock 直接当作新一轮自动更新；应先明确归属。放弃候选时仅撤销本次差异，保留其他工作。

## 定向更新原生应用

```fish
./bin/workstation update qq
```

⬆️ 核实已声明且已安装的 QQ，尝试刷新官方 API 目录、预览定向升级并检查安装记录；结束前确认应用能正常启动和使用。

也接受其他已声明官方 cask 的全名或唯一短名。未声明、未安装、来源无法确认、第三方 tap、非 API 安装模式、预览涉及其他软件或依赖时停止；不会强制重装或清理。入口不调用全局 `brew update`，因为它可能迁移其他软件；目录维护需单独安排。API 网络失败时 Homebrew 可能沿用缓存，应留意原始提示。Homebrew 更新通常不改变仓库声明，因此不制造空提交；应用内更新仍按各软件原有机制使用。

## 恢复已知可用配置

```fish
sudo darwin-rebuild --list-generations
```

🕘 查看保留的代际，识别更新前已验收的恢复点。

```fish
sudo darwin-rebuild --rollback
```

↩️ 仅在上一代就是所需恢复点时使用；该命令会激活上一代配置，需要相应授权。

连续多次变更时应从列出的代际选择已知可用版本，再使用 `--switch-generation`，不能盲目反复退一代。恢复后验证实际功能，并修复或撤销 Git 中的失败声明。原生应用、defaults 和应用数据不保证随代际对称恢复；保留恢复点直到新配置验收完成。
