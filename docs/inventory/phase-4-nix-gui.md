# Phase 4 Nix GUI 应用迁移

- **Issue：** [#45](https://github.com/sayoriqwq/nix-config/issues/45)
- **目标机器：** `macbook`
- **安装层：** Home Manager desktop / Darwin 用户层
- **当前状态：** 已声明、完成真实 Mac activation 和维护者基础验收

> 本文保留 #45 首次迁移的双安装证据。旧应用随后由 #56/#61 定向清理，#93 在当前 Nix
> 应用 presence 复核后永久删除 #61 的精确 Trash rollback 目录；以下“激活前/旧副本”
> 描述均为历史记录，不是当前恢复指令。

## 1. 目标与边界

本批次最初把九个可靠的 GUI package 分别放在
`modules/home/desktop/applications.nix` 与 `modules/home/darwin/applications.nix`，交给
Home Manager 的 `home.packages` 与 `copyApps`，没有新增自定义复制或 activation 脚本。
Phase 5.5 后，当前所有权已按能力移入 `modules/home/capabilities/` 与
`modules/capabilities/`；本文件保留当时的迁移证据，不再把旧聚合路径描述为当前接口。

Nix 只拥有应用本体和版本。账号、许可证、vault、插件、历史、缓存、设备状态、
接收目录、模型、输出、workspace 与数据库继续由应用或用户拥有。仓库不创建、链接、
覆盖或备份这些可变数据。

Mole 不在本批次中。已安装的 `Mole.app` 是 tw93 的原生 macOS 应用
`com.tw93.MoleApp`；Nixpkgs 中同名 `pkgs.mole` 是 SSH tunnel CLI，且 Darwin 标记为
broken，不能作为替代品。

## 2. 版本与应用身份

| 应用 | 激活前版本 | Nix 锁定版本 | Bundle ID | Nix 应用名 |
| --- | --- | --- | --- | --- |
| Atuin Desktop | 0.2.20 | 0.2.20 | `sh.atuin.app` | `Atuin.app` |
| Discord | 0.0.390 | 0.0.390 | `com.hnc.Discord` | `Discord.app` |
| IINA | 1.4.1 | 1.4.2 | `com.colliderli.iina` | `IINA.app` |
| LocalSend | 1.17.0 | 1.17.0 | `org.localsend.localsendApp` | `LocalSend.app` |
| MonitorControl | 4.3.3 | 4.3.3 | `app.monitorcontrol.MonitorControl` | `MonitorControl.app` |
| Mos | 3.5.0 | 4.0.2 | `com.caldis.Mos` | `Mos.app` |
| Obsidian | 1.10.6 | 1.12.7 | `md.obsidian` | `Obsidian.app` |
| Upscayl | 2.15.0 | 2.15.0 | `org.upscayl.Upscayl` | `Upscayl.app` |
| xbar | 2.1.7-beta | 2.1.7-beta | `com.xbarapp.app` | `xbar.app` |

Discord、Mos、Obsidian 和既有 VS Code 是本机唯一精确允许的 unfree package；没有开启
全局 `allowUnfree`。若以后新增其他 unfree package，Nix 必须继续拒绝并要求单独审阅。

Obsidian package 同时提供上游应用附带的 `obsidian` 与 `obsidian-cli` 命令。这不恢复
此前退役的第三方独立 `obsidian-cli` 工具，也不形成第二个版本所有者；命令随同一个
`pkgs.obsidian` package 更新和回滚。

## 3. 激活前准备

真实 activation 必须绑定待合并分支的精确 commit，并由维护者亲自执行。代理负责在
申请 activation 前完成以下准备：

1. 确认九个目标应用已完全退出；
2. 记录 `/Applications` 中旧应用的路径、版本与 bundle identity；
3. 只对有必要的稳定配置和应用清单创建权限受限的私有备份；
4. 记录关键可变数据路径的存在性与摘要，不读取机密内容；
5. 重新运行 formatter、Flake check 和 macOS system build；
6. 给出精确 activation 命令、上一代 generation 与回滚命令。

本批次不卸载、移动或覆盖 `/Applications` 中的旧应用。首次 activation 后会短暂形成：

```text
/Applications/<旧应用>.app
~/Applications/Home Manager Apps/<Nix 应用>.app
```

双安装是刻意保留的回退窗口，不是清理失败。

## 4. 人工 activation 与验收

只有维护者明确批准精确 commit 后，才由维护者执行：

```fish
sudo darwin-rebuild switch \
  --flake 'github:sayoriqwq/nix-config/<exact-commit>#macbook'
```

activation 后逐项从 `~/Applications/Home Manager Apps` 打开 Nix 应用，并验证：

- About 页面版本与上表一致；
- 原有登录态、vault、插件、历史、设备状态和偏好仍可读取；
- 应用仍可写入自身运行态；
- IINA、Mos 与 Obsidian 的版本升级没有破坏主要工作流；
- LocalSend 仍可发现设备并使用原接收目录；
- MonitorControl 与 Mos 的辅助功能/输入监控权限仍正常；
- xbar 仍能读取现有 plugins；
- Atuin Desktop 仍能读取原 workspace/Hub 状态；
- Obsidian vault 与第三方插件未被 Nix 接管；
- `/Applications` 中旧应用仍存在，可作为独立回退入口。

验收期间不得用 Spotlight、Dock 或普通应用名猜测启动来源；应先用精确路径打开，再在
About、进程路径或应用 bundle 中确认运行的是 Home Manager Apps 版本。

## 5. 回滚

若 system activation 本身失败，执行：

```fish
sudo darwin-rebuild --rollback switch
```

若只有某个 Nix GUI 应用不工作：

1. 完全退出 Nix 版本；
2. 从 `/Applications` 打开原应用；
3. 保留可变数据原位；
4. 在 Issue #45 记录应用、版本、启动路径和错误；
5. 在修订配置前不要卸载任何一方。

generation 回滚只回滚声明和应用本体，不回滚应用运行期间产生的可变数据。旧应用的
定向卸载、旧 Homebrew cask 清理、Dock/Launch Services 收口必须另行列出精确目标并
取得新批准；`homebrew.onActivation.cleanup` 继续保持 `none`。

## 6. 离线验证记录

2026-07-27 在未 activation 的工作树上完成：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link --print-out-paths
```

生成的 Home Manager generation 含既有四个应用和本批次九个应用，共十三个 app。
Homebrew `Brewfile` 仍为空，`homebrew.onActivation.cleanup` 仍为 `none`。生成的
`home-files` 没有新增任何目标应用的配置或数据链接。精确 unfree predicate 对
Discord、Mos、Obsidian、VS Code 返回 true，对反例 Spotify 返回 false。

## 7. 真实机器验收记录

2026-07-28，维护者对精确提交
`8c7992a1e37e08f279a715dd5823d6b8af9321ce` 执行 `darwin-rebuild switch`，activation
完成且无报错。机器侧确认：

- `/run/current-system` 指向离线验证的精确 build；
- 九个 Nix 应用均存在于 `~/Applications/Home Manager Apps`，版本和 bundle ID 正确；
- 九个 `/Applications` 旧副本全部保留；
- Discord 与 Obsidian 主配置相对私有备份哈希未变；
- Homebrew cleanup 仍为 `none`；
- 已观察到 IINA、MonitorControl、Mos 与 Nix xbar 从 Home Manager Apps 路径运行。

维护者反馈初步使用良好，并明确接受不逐项完成全部 GUI checklist、将低概率问题延后到
真实使用时处理。该决定不扩大配置所有权：旧应用和 `0700` 私有备份继续作为回退入口，
后续发现单应用问题时按第 5 节处理。

旧 Homebrew `obsidian-cli` 在 #45 验收时仍位于 PATH 前部，未影响 Obsidian GUI；它已
由后续定向清理批次删除，当前命令不再依赖该旧入口。
