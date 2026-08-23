# Zed Nightly 手动更新与回滚

Zed Nightly 的版本事实来自 `packages/zed-nightly/default.nix` 中固定的官方 release
identity 与双平台 hash。应用自更新关闭；仓库不运行定期 sync Action，也不再有
可执行 `nix flake update zed` 的 Zed Flake input。

## 手动同步

从最新 `main` 创建专用分支，并确认 package 文件没有待处理修改：

```fish
git status --short --branch
git switch -c codex/update-zed-nightly-YYYYMMDD
nix run .#sync-zed-nightly
```

🔄 解析官方最新精确 Nightly，验证双平台产物并更新固定 hash。

`sync-zed-nightly` 会先完成以下工作，任一步失败都不会写入 package 文件：

1. 通过官方 `latest` redirect 取得包含 run number 与完整 commit SHA 的 release identity；
2. 确认 macOS aarch64 DMG 与 Linux x86_64 tarball 都存在；
3. 用 Nix 预取两个官方产物并计算对应 hash；
4. 只替换 `packages/zed-nightly/default.nix` 的 release 与两个 hash；
5. 格式化该文件并展示 diff。

需要重做某个已知官方版本时，可让 helper 使用精确 release：

```fish
nix run .#sync-zed-nightly -- --release '<exact-release>'
```

🎯 重新固定一个已知的完整官方 release identity，不使用浮动 package source。

不要手工输入 hash，不要修改为 `latest` URL，也不要在 artifact 缺失时改走 Zed
source Flake、Cargo/Rust 或 production server builder。

## 审阅与验证

先确认改动范围和 release identity：

```fish
git diff --name-only
git diff -- packages/zed-nightly/default.nix
```

🔍 确认只有 owner-local Zed package pin 发生变化。

在 macbook 运行：

```fish
nix fmt -- --check .
nix flake check
nix build --no-link .#packages.aarch64-darwin.zed-nightly
nix build --no-link .#darwinConfigurations.macbook.system
```

✅ 验证格式、Flake policy、官方 macOS package 与 host closure，不 activation。

在 nixbox 可达后原生运行：

```fish
nix build --no-link .#packages.x86_64-linux.zed-nightly
nix build --no-link .#nixosConfigurations.nixbox.config.system.build.toplevel
```

🐧 验证官方 Linux bundle 的 NixOS 适配与整机 closure，不 activation。

审阅构建日志时不得出现 Zed source checkout、Cargo、Rust、Crane 或大量 Cargo Git
dependency fetch。Linux 端允许官方 tarball 解包、`autoPatchelfHook`、wrapper 和
普通 host integration derivations。

验证通过后创建普通 Draft PR，记录双平台 release、hash、命令与结果。helper 不会
自动 commit、push、创建 PR、合并或 activation。

## 失败与暂停

- `latest` identity 不符合预期格式时立即停止，先确认官方 API 变化；
- 任一 artifact 404、hash 预取失败或解包失败时不更新，继续使用当前固定版本；
- package/host build 失败时不合并；不得回退到源码编译；
- nixbox 离线时可先完成 macOS 与 x86 derivation 求值，但 Draft 必须保留 Linux
  原生 build blocker；
- 上游删除旧 artifact 时，现有已实现 store path 仍可使用，但新机器恢复可能失败。
  是否建立自有归档必须另开 Issue。

## 回滚

1. 未合并时，关闭或放弃更新 PR，继续使用当前 package pin；
2. 已合并但尚未 activation 时，revert 对应 package pin 提交并重新 build；
3. 已 activation 时，先切回上一代 nix-darwin/NixOS generation，再 revert pin；
4. Zed live state 异常时从仓库外私有备份人工恢复。

Git 回滚只改变应用 package。Zed settings、extensions、登录态、History 与
workspace/session 不随 generation 自动回滚。
