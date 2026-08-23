# macOS 登录项与 launchd 盘点

- **机器：** `macbook`
- **采集日期：** 2026-08-10
- **实施 Issue：** [#124](https://github.com/sayoriqwq/nix-config/issues/124)
- **边界：** 记录稳定声明、启动行为和外部所有权；不保存应用数据、TCC 数据、账号、日志内容或设备标识

## 1. 术语与所有权

本机同时存在三类容易被统称为“启动项”的对象：

1. **登录时打开：** System Settings 中随图形用户登录打开的应用、文档或 helper；
2. **LaunchAgent / LaunchDaemon：** 由 `launchd` 按 plist 启动的用户或系统 job；
3. **应用后台项目：** 应用通过 Service Management 注册的 updater、embedded helper、
   background task 或 extension。

本仓库只声明自己拥有的 job。Setapp、MAS、Homebrew/厂商应用继续拥有自身的登录项和
后台注册；Nix 不创建第二套竞争入口。Issue #124 只增加 Mos 的单一声明式入口，因为
Mos package 已由 Home Manager 唯一拥有，而旧登录项指向已经退役的应用副本。

## 2. 清理前“登录时打开”完整清单

只读 JXA/System Events 快照共返回 19 项。`有效` 表示记录仍能解析到当前目标；不表示
仓库接管该应用的数据或偏好。

| # | 登录项 | 目标/来源 | 采集状态 | #124 disposition |
| ---: | --- | --- | --- | --- |
| 1 | CleanShot X | Setapp | 有效 | 保留，应用所有 |
| 2 | MEGAsync | `/Applications/MEGAsync.app` | 有效 | 按维护者要求删除登录项；应用保留 |
| 3 | Timing Tracker | Setapp embedded LoginItem | 有效 | 保留，应用所有 |
| 4 | Mos | 已删除的旧 Mos 副本 | 失效 | 删除旧记录；由 Nix LaunchAgent 替代 |
| 5 | Slidepad | Setapp | 有效 | 保留，应用所有 |
| 6 | One Thing | Mac App Store | 有效 | 保留，应用所有 |
| 7 | Itsycal | Trash 中的退役应用 | 失效 | 删除旧记录 |
| 8 | SideNotes | Trash 中的退役应用 | 失效 | 删除旧记录 |
| 9 | AlDente Pro | Setapp | 有效 | 按维护者要求删除登录项；应用保留 |
| 10 | Raycast | Homebrew 声明应用 | 有效 | 保留，应用所有 |
| 11 | Bartender | Setapp | 有效 | 按维护者要求删除登录项；应用保留并可通过 Raycast 按需启动 |
| 12 | Paste | Setapp | 有效 | 保留，应用所有 |
| 13 | Typeless | Trash 中的退役应用 | 失效 | 删除旧记录 |
| 14 | FigmaAgent | Figma Application Support | 有效 | 按维护者要求删除登录项；应用保留 |
| 15 | Setapp | Setapp 客户端 | 有效 | 保留，应用所有 |
| 16 | HazeOver | Mac App Store | 有效 | 保留，应用所有 |
| 17 | Vorssaint | Homebrew 声明应用 | 有效 | 保留，应用所有 |
| 18 | Lungo | 已不存在的退役 Setapp 应用 | 失效 | 删除旧记录 |
| 19 | CodexBar | 已不存在的 Trash 目标 | 失效 | 删除旧记录 |

清理 6 个失效记录后，原有有效登录项应精确保留以下 13 项，顺序不作为配置合同：

1. CleanShot X
2. MEGAsync
3. Timing Tracker
4. Slidepad
5. One Thing
6. AlDente Pro
7. Raycast
8. Bartender
9. Paste
10. FigmaAgent
11. Setapp
12. HazeOver
13. Vorssaint

维护者随后明确要求 MEGAsync、AlDente Pro、FigmaAgent 与 Bartender 不再登录启动。删除这
4 个仍有效但非必需的记录后，当前“登录时打开”完整清单为以下 9 项：

1. CleanShot X
2. Timing Tracker
3. Slidepad
4. One Thing
5. Raycast
6. Paste
7. Setapp
8. HazeOver
9. Vorssaint

Bartender 应用及其数据保持不变；维护者在家和公司主要使用外接屏幕，携带 Mac 外出时可
通过 Raycast 按需启动，因此不再为偶发场景长期占用登录启动入口。

## 3. Nix Mos 登录启动合同

`software/mos/capabilities/mouse-utility/home.nix` 同时拥有 Mos package 和唯一登录启动
声明。本次构建解析到的 Nix package 为 `mos-4.2.1`；Home Manager LaunchAgent 的合同为：

- label：`org.nix-community.home.mos`；
- domain：当前用户的图形 `gui` domain；
- 登录时运行 `/usr/bin/open -g ~/Applications/Home Manager Apps/Mos.app`；
- `RunAtLoad = true`，但 `KeepAlive = false`；
- launchd 只发起一次打开请求，不监督或反复重启 Mos GUI 进程；
- Mos 偏好、设备状态、日志和 Accessibility/Input Monitoring 等 macOS 授权保持可写、
  不进入 Nix Store。

构建不会改变当前登录项。维护者审阅并批准精确 commit 后，实机 activation 已安装和
bootstrap 新 LaunchAgent。首次验证时，Mos 同时在原生 SessionLoginItems 中生成了一个
指向 Home Manager Apps bundle 的记录；维护者随后批准删除该原生记录。即时复核确认
SessionLoginItems 中不再有 Mos，`org.nix-community.home.mos` 仍加载且最近退出码为 0，
因此当前只有 Nix 声明的启动入口；下一次真实登录后的持久性验证仍待维护者反馈。

## 4. 文件型 launchd 盘点

清理前共有：

| 目录 | plist 数量 | 当前 Nix 所有权 |
| --- | ---: | --- |
| `~/Library/LaunchAgents` | 15 | 0；其余由应用、Pinshift 或 NuPhy Key Probe 所有 |
| `/Library/LaunchAgents` | 3 | 0；均为 Logi 组件 |
| `/Library/LaunchDaemons` | 14 | nix-darwin 声明 2 个；Lix bootstrap 另有必要组件 |

清理后、activation 前，`~/Library/LaunchAgents` 为 13 个；activation 增加 Mos 后为
14 个。`/Library/LaunchAgents` 仍为 3 个，`/Library/LaunchDaemons` 为 8 个。数量只用于
证明精确变化；所有权仍以 label、plist 内容与父应用为准。

Issue #124 精确清理以下孤儿 job，不触碰其他 plist：

| label | 清理前证据 | disposition |
| --- | --- | --- |
| `com.bjango.istatmenus-setapp.agent` | 父应用/可执行文件不存在，`EX_CONFIG` | bootout；移动 plist 到 rollback 备份 |
| `com.bjango.istatmenus-setapp.status` | 父应用/可执行文件不存在，`EX_CONFIG` | bootout；移动 plist 到 rollback 备份 |
| `com.bjango.istatmenus.installer` | iStat Menus 已退役 | bootout；移动 plist/helper |
| `com.docker.socket` | Docker Desktop 不存在，OrbStack 是唯一容器运行时 | bootout；移动 plist/helper |
| `com.docker.vmnetd` | Docker Desktop 不存在但 helper 正在运行 | bootout；移动 plist/helper |
| `com.macenhance.cDock.Injector` | cDock 应用不存在 | bootout；移动 plist/helper/精确插件 |
| `moe.elaina.nyanpasu-service` | 父应用不存在，累计 2083 次运行并 exit 1 | bootout；移动 plist/可执行文件 |
| `party.mihomo.helper` | Mihomo Party 不存在，helper 仍运行；Clash 有独立 helper | bootout；移动 plist/helper |

所有 root 文件已先归档并保留原始 owner、mode、时间和 checksum，再移动到仓库外
owner-only rollback 目录；不永久删除应用数据。root archive 的 SHA-256 为
`458ce41a558d974f9f7ba812fd62c84303793b0d7eb81c38b2b722e40fa07b82`。真实机清理与
Nix activation 是两个独立人工关卡。

## 5. 明确保留或外置的启动项

- `dev.sayori.pinshift.cleanup-guardian`：由 Pinshift 项目的签名安装、更新和回滚流程
  唯一拥有；本仓库不复制 plist 或设备专属参数。
- `local.sayori.NuPhyKeyProbe`：当前手工应用与 Agent 保持外部；若未来成为稳定工作站需求，
  另建 Issue 决定 package、签名和 TCC 所有权。
- Clash Verge Agent/Daemon、OrbStack helper、Setapp、Logi、Google updater、MEGA、百度网盘、
  Steam 与 Nix/Lix 服务：父应用或系统 owner 仍有效，不在 #124 清理范围。
- ChatGPT、Ghostty、Raycast、Visual Studio Code 等 Service Management background task：
  继续由对应应用拥有，不转换为手写 launchd plist。

## 6. 验收与回滚

Agent 可完成备份、精确清理、Nix evaluation/build 和 Draft PR，但不得在 #124 的独立
activation 关卡批准前运行 `darwin-rebuild switch`。清理验收至少确认：

- 第一轮清理精确保留原有 13 个有效登录项；随后只按维护者新要求移除 MEGAsync、
  AlDente Pro、FigmaAgent 与 Bartender，当前清单为 9 项；
- 6 个失效登录项不再出现；
- 8 个孤儿 label 不再加载，Nyanpasu 不再重试，Docker/Mihomo 孤儿进程停止；
- OrbStack、Clash Verge、Pinshift、NuPhy Key Probe 与 Nix/Lix 服务仍保持原状态；
- activation 后 `org.nix-community.home.mos` 已加载，Mos 从 Home Manager Apps 路径运行；
  首次出现的 Mos 原生 SessionLoginItems 记录已获批删除，真实重新登录验证待维护者反馈；
- rollback 目录仍存在且只能由维护者访问。

root 清理回滚使用同一私有目录中的短 helper 恢复精确文件并 bootstrap 原 label。Nix
activation 若后来出现问题，优先回滚上一代 system generation；两类回滚互不替代。
四个有效应用登录项可从各应用设置或 System Settings 重新启用；六个失效记录的原始目标
已经不存在，因此只保留清理前快照，不伪造不可用的恢复入口。
