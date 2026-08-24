# Zed 平台通道更新与回滚

Zed 的 package owner 按平台分流：macbook 使用 `software/zed/package.nix` 固定的
官方 Preview aarch64-darwin DMG；nixbox 使用 Linux release nixpkgs 中的
`pkgs.zed-editor` Stable。server 不选择 Zed。

两条通道不追求版本一致。macbook 需要较新的 Preview 功能；nixbox 使用 release
package，并优先从 USTC substitution；USTC closure 不完整时由 macbook 中继官方 cache
的已签名二进制。应用自更新关闭，仓库不运行定期更新 Action。

## macbook：手动同步 Preview

从最新 `main` 创建专用分支，并确认 package 文件没有待处理修改：

```fish
git status --short --branch
git switch -c codex/update-zed-preview-YYYYMMDD
nix run .#sync-zed-preview
```

🔄 解析官方最新 Preview，预取 aarch64-darwin DMG 并更新固定版本与 hash。

`sync-zed-preview` 会先完成以下工作，任一步失败都不会写入 package 文件：

1. 通过官方 Preview `latest` redirect 取得精确语义版本；
2. 用 Nix 预取 macOS aarch64 DMG 并计算 flat hash；
3. 只替换 `software/zed/package.nix` 的 release 与 DMG hash；
4. 格式化 package 文件并展示 diff。

需要重做某个已知官方 Preview 时：

```fish
nix run .#sync-zed-preview -- --release '<major.minor.patch>'
```

🎯 重新固定已知 Preview，不把浮动 `latest` 写入 package source。

审阅和非 activation 验证：

```fish
git diff --name-only
git diff -- software/zed/package.nix
nix fmt -- --check .
nix flake check
nix build --no-link .#packages.aarch64-darwin.zed-preview
nix build --no-link .#darwinConfigurations.macbook.system
```

✅ 验证范围、Flake policy、官方 Preview package 与 macbook closure。

构建后的 `.app` 必须读取代码签名、bundle identity 与版本；日志不得出现 Zed source
checkout、Cargo、Rust 或 Crane。helper 不会 commit、push、创建 PR、merge 或 activation。

## nixbox：随 Linux release nixpkgs 更新 Stable

nixbox 没有独立 Zed updater。Stable 版本只随经过审阅的 Linux `nixpkgs` input 更新。
在任何包含 Linux input 变化的 PR 合并前，先取得目标版本和 outPath，并真实复制完整
closure。不要用 `nix path-info` 代替复制；镜像可能存在 `.narinfo` 却缺少某个 NAR：

```fish
set zed_stable (nix eval --raw .#packages.x86_64-linux.zed-stable)
nix copy --from https://mirrors.ustc.edu.cn/nix-channels/store $zed_stable
```

🧊 以完整 NAR 复制验证 USTC 正常路径，不接受仅有 narinfo 的假阳性。

USTC 缺少任一 NAR 时，macbook 从官方 cache 取得同一签名 closure，再经既有 SSH
transport relay。以下命令不编译 Zed，也不改变 nixbox 的 substituter 或代理配置：

```fish
nix copy --from https://cache.nixos.org $zed_stable
nix copy --to ssh-ng://nixbox $zed_stable
```

📦 从官方缓存获取并中继已经签名的 Stable closure。

官方 cache 也无法完成复制时立即停止该 Linux input 更新。不在 nixbox 运行 Zed source
build，不临时增加 source Flake、Cargo/Rust、Cachix、通用外网代理或 production server
builder。macbook 只中继 store closure，不承担编译或常驻代理。

复制完成后，先在 nixbox 验证精确 path，再原生构建：

```fish
set zed_stable (nix eval --raw .#packages.x86_64-linux.zed-stable)
nix-store --check-validity $zed_stable
nix build --no-link .#packages.x86_64-linux.zed-stable
nix build --no-link .#nixosConfigurations.nixbox.config.system.build.toplevel
```

🐧 验证 Stable substitution 与整机 closure，不 activation。

## Mutable state 与首次运行

Preview、Stable 和已退休的 Nightly 可能使用不同的 channel/state namespace。本仓库只
管理 package、CLI、默认编辑器声明和 seed-only 配置；settings、keymap、tasks、
extensions、登录态、History、workspace/session、数据库与 cache 仍是外部可变状态。

第一次 activation 新通道后需要维护者分别完成启动、版本、CLI、项目打开、task 与
extension smoke。不得自动迁移、合并或删除旧 channel state。

## 失败与回滚

- Preview identity、artifact、hash、解包、签名或 host build 失败时，不合并更新；
- Stable 在 USTC 与官方 cache 都无法完成 closure 复制时，不合并对应 Linux input 更新；
- 未合并时关闭或放弃 PR；已合并但未 activation 时 revert 对应 PR 并重新 build；
- 已 activation 时先切回上一代 nix-darwin/NixOS generation，再 revert 声明；
- Zed live state 异常时从仓库外私有备份人工恢复。

Git/generation 回滚只改变应用 package，不恢复任何 Zed mutable state。
