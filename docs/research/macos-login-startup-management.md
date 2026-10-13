# macOS 登录启动的统一管理与恢复

研究日期：2026-10-03。本文比较登录启动的现有机制和可恢复方案，记录当时的调研结论。2026-10-13 维护者已选择 Home Manager 集中管理普通 GUI 的受管登录启动，当前决定和实施状态见[主工作站管理](../architecture/workstation-management.md#登录启动)；下文保留方案比较与证据，不代表迁移已经执行。研究问题是怎样减少“这里管一点、那里管一点”的维护负担，同时保留可以兑现的恢复能力。

本文只把 Apple 官方文档描述为平台支持方向，把开源项目实现描述为可核查的案例。公开文档和仓库不提供市场占有率，因此不能据此宣称某种做法是统计意义上的“主流”。

## 1. 统一的对象是什么

需要分别判断三种能力：

| 目标 | 成功标准 | 不能由此直接推出的保证 |
| --- | --- | --- |
| 统一查看 | 在一个入口看见登录应用和后台任务，并知道归属 | 已经有一份可提交、可重放的完整声明 |
| 统一操作 | 不用逐个寻找应用设置，即可改变所选启动行为 | 各种应用内部开关、helper 注册和系统授权都会同步 |
| 统一恢复 | 换机后重建选定的启动行为，删除声明也能撤销对应入口 | 能复原所有应用数据、隐私授权、历史启动状态 |

本文优先比较“普通应用在登录后打开”的统一恢复方式，再判断哪些后台服务必须保留产品自己的管理机制。这个拆分来自实际运行语义，不能仅按 GUI、CLI 或安装来源决定。

## 2. Apple 当前支持的机制

### 系统界面已经统一展示，项目语义仍不同

“系统设置 → 通用 → 登录项与扩展”可以添加或移除登录时打开的应用、文稿、文件夹及服务器连接；后台活动开关则允许应用在主界面未打开时更新或同步。两者在同一页面，但“登录时打开主应用”和“允许其后台任务”不是同一个动作。[Apple 用户手册](https://support.apple.com/zh-cn/guide/mac-help/mh15189/mac)、[登录项与扩展设置](https://support.apple.com/zh-cn/guide/mac-help/mtusr003/mac)

Apple 在 WWDC22 明确说明，这个界面汇集了登录应用、agents、daemons 和旧的 SMLoginItems 等不同机制。统一展示因此有平台依据；不能反过来把界面内所有条目都当成一份普通应用路径列表。[WWDC22：What’s new in privacy，登录项部分](https://developer.apple.com/videos/play/wwdc2022/10096/?time=762)

### SMAppService 是应用管理自身资源的现代接口

macOS 13 起，Apple 提供 `SMAppService`，使应用可以登记自己的主应用、包内登录 helper、LaunchAgent 和 LaunchDaemon。包内资源由应用安装和更新流程携带，减少外部安装脚本处理 plist 的需要。[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)、[现代包结构迁移说明](https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos)

它们的启动时机并不相同：

| 对象 | 注册后的行为 | 适合表达的需求 |
| --- | --- | --- |
| 主应用 `mainApp` | 后续用户登录时启动 | 登录后打开普通应用 |
| 包内 `LoginItem` helper | 注册后立即启动，后续登录再启动；异常退出会被重新拉起 | 应用提供的会话内辅助程序 |
| `LaunchAgent` | 注册后立即加载，之后每次登录再次加载；是否立即运行取决于任务条件 | 用户会话中的任务、按需服务 |
| `LaunchDaemon` | 需要管理员批准，批准后加载，并在后续系统启动时加载 | 系统范围后台服务 |

以上时机直接来自 [`register()` 文档](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29)；“加载”不等于“不论任务条件都立即运行”。Apple 也分别定义了 LoginItems、LaunchAgents 和 LaunchDaemons 的会话与权限范围。[Service Management 概览](https://developer.apple.com/documentation/servicemanagement/)

### 外部 LaunchAgent 仍是有效方案

用户目录的 `Library/LaunchAgents` 或系统范围的 `/Library/LaunchAgents` 可以保存外部管理的任务。launchd 在用户登录时读取它们，也支持在已有会话中显式加载。LaunchDaemon 则属于系统启动流程。它们是平台机制；是否由应用安装器、Home Manager 或其他配置工具生成，是另一层选择。[Apple：Creating Launch Daemons and Agents](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)

工程判断：对“登录后打开某个应用”，外部 agent 可以重建所需行为；它不因此变成该应用原生开关的另一种写法。对于要求持久运行、按需通信或特权操作的 helper，也不能未经核实就替换成一次打开主应用。

## 3. 应用里的开关与系统设置是不是同一个状态

现代实现可以同源。Apple 提供 `SMAppService.status` 读取注册和授权状态，并说明依赖 helper 的应用应检查状态，必要时引导用户到系统设置。Apple DTS 也明确答复，`status` 反映的是系统设置界面中的当前状态。[Apple 迁移与状态响应说明](https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos)、[Apple DTS：Control status item and login item](https://developer.apple.com/forums/thread/801489)

这支持的准确表述是：**使用同一个 SMAppService、并正确回读状态的应用开关与系统界面，是同一登记/授权状态的两个入口。** 不能保证任意应用勾选框都满足此前提；应用可能保存自己的偏好、使用旧 helper、使用普通登录列表，或者没有及时响应外部修改。

旧式实现也不能一概视作完全独立。Apple 提供 `statusForLegacyPlist(at:)` 查询旧 plist 的授权状态，说明旧任务仍受系统控制；但这不证明某个应用自己的偏好值会同步变化。判定具体应用要看它采用的接口和状态回读代码。[旧实现兼容说明](https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos)

如果另外创建一个 Home Manager agent 来打开同一个应用，就增加了另一条启动路径。原生开关只能管理它对应的登记；单独关闭原生入口不会自动删除外部 agent。反过来，删除外部 agent 也不能证明应用自己的登记已经关闭。这是两个实际入口造成的重复，不是所有“应用开关 + 系统界面”组合都会重复。

## 4. 是否存在覆盖全部项目的统一自动化接口

本次核实的 Apple 公开接口中，没有找到能把任意第三方应用的所有原生注册、后台授权和普通登录项统一导出、修改并完整重放的个人工作站接口。这是本次证据范围内的结论，不能扩写成“macOS 无法自动化自启动”。

可确认的边界如下：

| 入口 | 已核实的能力 | 边界 |
| --- | --- | --- |
| 系统设置 | 集中查看和控制登录项、后台活动 | 用户界面本身不提供声明的版本管理和重放保证 |
| SMAppService | 应用注册和观察自身主程序及包内资源 | 不是传入任意第三方应用路径、代替它管理所有开关的通用接口 |
| 外部 plist 与 launchd | 声明和加载自己拥有的 agent/daemon | 不能把应用自有登记、授权和设置自动合并成同一对象 |
| `sfltool dumpbtm` | 输出当前登录项和后台项状态，用于诊断 | 官方文档没有将其输出定义为可导入的恢复清单 |

SMAppService 的范围可直接从构造接口看出：`mainApp` 指当前主应用，agent/daemon 的 plist 必须位于调用应用自己的包内目录。[mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)、[agent](https://developer.apple.com/documentation/servicemanagement/smappservice/agent%28plistname%3A%29)、[daemon](https://developer.apple.com/documentation/servicemanagement/smappservice/daemon%28plistname%3A%29)

Apple 将 `sfltool dumpbtm`、日志和后台任务报告放在部署诊断流程里。`resetbtm` 会重置登录项与后台项数据，是测试辅助动作，不是“从声明恢复我选择的启动项”。本研究不执行这些现场命令。[Apple 部署指南](https://support.apple.com/zh-cn/guide/deployment/depdca572563/web)

普通 Open at Login 列表的自动化工具，以及 Nix 是否已有直接管理模块，在后文结合社区工具和锁定源码比较。

## 5. MDM 能集中管理，但不是个人 Mac 的免费统一开关

Apple 有管理式登录项 payload，可指定登录时打开的路径；另有 `com.apple.servicemanagement` 规则，按 bundle identifier、label 或开发团队等条件管理匹配项。[管理式登录项部署说明](https://support.apple.com/zh-cn/guide/deployment/dep07b92494/web)

关键区别是，官方 `com.apple.servicemanagement` schema 将该 payload 定义为自动启用并允许匹配项，且明确要求已获用户批准的 MDM、使用设备通道，并禁止手动安装。因此，不能把“生成一个本地 mobileconfig”当成该机制在个人 Mac 上可用的等价替代；这些规则也不是按任意应用内部偏好格式执行迁移。[Apple 官方 payload schema](https://github.com/apple/device-management/blob/release/mdm/profiles/com.apple.servicemanagement.yaml)

Apple 也提供声明式后台任务管理，可以交付 launchd 配置及相关文件；其文档限定为受监督注册，未开放本地注册。这进一步说明企业集中部署有正式方案，但需要对应的管理基础设施。[ServicesBackgroundTasks](https://developer.apple.com/documentation/devicemanagement/servicesbackgroundtasks)

工程判断：如果只是管理一台个人 Mac 的几个登录应用，引入 MDM 会增加设备注册、策略维护与服务依赖。目前没有证据表明这些成本能被本任务的收益抵消；如果未来本来就有组织 MDM，再评估此路径更合理。这里没有断言个人设备技术上绝不能加入 MDM。

## 6. 当前仓库与 Nix 社区机制

调研时仓库中普通 GUI 的显式登录启动只有 Mos：Home Manager 建立用户 agent，通过 `open -g` 打开受管 Mos.app；其他普通 GUI 尚无同类仓库声明。实施后的受管名单见 [login-items.nix](../../hosts/macbook/login-items.nix)，不能据此推断未纳管应用的原生登录项状态。本文不保存完整现场名单。

锁定的 Home Manager 使用 `launchd.agents` 生成并安装任务，首次激活、任务内容改变或任务未加载时会立即加载；内容未变且任务已加载则跳过。Mos 的 `RunAtLoad=true` 使加载触发一次打开，`KeepAlive=false` 且命令不等待 GUI 退出，因此不会因退出 Mos 而持续重开。`waitForNixStore=true` 只是等待 Nix Store 就绪。[锁定 HM 实现](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/launchd/default.nix)

锁定 nix-darwin 也会在首次创建或 plist 改变时加载服务，并非一律等待重启或登录。因此，“声明启动项”与“本次激活是否立即打开应用”必须一起考虑；Nix 构建成功本身不表示已经加载。[锁定 nix-darwin 激活实现](https://github.com/nix-darwin/nix-darwin/blob/15abb8c98f336cd8bd840d71059adebabe60bf04/modules/system/launchd.nix)

在本次核实的锁定版本中，没有直接管理原生 Open at Login 应用列表的标准模块。上游仍有对应功能请求，并明确区分原生列表和 `launchd.agents` 的语义；这些 issue 是需求证据，不是已经交付的接口。[nix-darwin #1740](https://github.com/nix-darwin/nix-darwin/issues/1740)、[Home Manager #9719](https://github.com/nix-community/home-manager/issues/9719)

标准 `launchd.agents` 仍能集中表达“选定应用在登录后打开”，不需要重新发明守护脚本或清单格式。若采用它作为这项行为的统一来源，应撤销同一应用的重复登录入口；它不负责把厂商设置界面的开关改成相同值，也不应替换未经核实的必要后台 helper。

这是一份受管名单，不是整机的严格白名单：名单外的应用仍可能自行登记。删除声明时，HM 只清理上一代由自己管理且内容没有外部变更的 plist；不会扫描并删除全部原生登录项。[HM 的清理实现](https://github.com/nix-community/home-manager/blob/a7c70cc290290f373f50cd820403833d250459ac/modules/launchd/default.nix#L433)

## 7. 可选工具、统一方式与恢复保证

### 小工具没有消除底层机制差异

- `OJFord/loginitems` 封装的是 AppleScript 的 System Events 登录列表增删，并通过作者自己的 Homebrew tap 分发。它能减少手写命令，却不是全体 SMAppService 注册的统一管理器；若接到声明激活流程，仍要自己承担去重、受管项删除和未受管项保留。[项目说明与源码](https://github.com/OJFord/loginitems)
- `m-cli` 的 service 插件操作传统 plist 与 launchctl；它没有把厂商原生登录开关同步到一个恢复清单。[插件源码](https://github.com/rgcr/m-cli/blob/main/plugins/service)
- `nix-plist-manager` 的覆盖记录明确排除 Open at Login 和 App Background Activity；因此不能为了这个问题再引入它。[项目覆盖记录](https://github.com/SushyDev/nix-plist-manager/blob/main/coverage.json)

### StartupFolder 有真实的目录与界面收益

StartupFolder 提供 `~/Startup` 目录和图形管理界面，支持应用、脚本、快捷指令等，已有 Homebrew cask。本文核实发布版 1.2.1 的实现，未安装或运行该应用。[产品说明](https://lowtechguys.com/startupfolder)、[Homebrew cask](https://formulae.brew.sh/cask/startupfolder)

GUI 添加应用实际创建普通符号链接，所以“由仓库重建目录中的应用链接”不依赖不透明的 Finder alias 文件。自动批量启动发生在启动器带登录标记启动时；用户也可以在 GUI 中手动启动全部条目。普通增删链接只刷新名单，不立即打开或停止对应应用，这是相对当前 HM 激活行为的实际优势。[1.2.1 的添加实现](https://github.com/FuzzyIdeas/StartupFolder/blob/v1.2.1/StartupFolder/ContentView.swift)、[目录监视实现](https://github.com/FuzzyIdeas/StartupFolder/blob/v1.2.1/StartupFolder/StartupManager.swift)、[登录启动实现](https://github.com/FuzzyIdeas/StartupFolder/blob/v1.2.1/StartupFolder/StartupFolderApp.swift)

代价也明确：启动器本身通过 SMAppService 登记内置 agent，关闭窗口后继续运行，观察目录和进程；源码有周期性状态检查，因此不能把产品页的“零资源”当成已测量结论。隐藏与保活默认关闭，相关选择另存 UserDefaults，单靠恢复目录链接并不能恢复这些选项。它没有接管各产品原有登录登记或必要 helper。[启动器与注册实现](https://github.com/FuzzyIdeas/StartupFolder/blob/v1.2.1/StartupFolder/StartupFolderApp.swift)、[设置定义](https://github.com/FuzzyIdeas/StartupFolder/blob/v1.2.1/StartupFolder/Settings.swift)

如果由 Nix 拥有这些链接，图形界面内的增删仍需保存进声明才能在重建后保留。首次注册启动器、系统批准及完整换机体验尚未实测；这里只确认日常目录变更的源码行为，不能承诺所有首次启用动作都完全无即时启动。

### 同一个需求的三种实现

| 方案 | 统一与恢复能力 | 改名单时的行为 | 持续成本 |
| --- | --- | --- | --- |
| 原生登录项与系统设置 | 界面集中，现代应用可与系统同源；本文未找到覆盖全部原生登记的 Git 重放方案 | 主应用的现代注册针对后续登录；helper/agent 的登记可能立即运行 | 最少额外机制；恢复仍需原生操作与状态核实 |
| 集中的标准 HM `launchd.agents` | 用已有声明重建受管应用的打开行为；不会同步厂商原生开关 | 首次或变更激活可能立即打开；无变化且已加载则跳过 | 无新增启动器；维护应用入口与重复登记归属 |
| StartupFolder + 受管目录链接 | 名单有图形界面，也能用现有文件声明重建；隐藏/保活需另存 | 日常目录变更不立即启动或停止应用 | 增加一个常驻启动器及其登记、版本和偏好管理 |

这三种方案都不是自动阻止名单外自启的全机策略。原生 helpers、系统服务和应用可能重新登记的行为仍然需要按产品核实；选择新启动器并不会自动清理旧入口。

## 8. 建议与验证范围

**对当前仓库，优先用已有标准 HM 集中管理需要进仓恢复的普通 GUI 登录启动，不另加清单语言或启动守护程序。** 这是基于现有依赖和可恢复目标的工程判断，而不是 Apple 要求：把同一种“登录后打开应用”的行为放到同一处声明，同一个应用只保留一个负责打开它的入口；必要的产品后台服务仍按其真实语义保留。具体哪些应用要纳入尚未决定，本文不把“希望统一”推定为“所有软件都必须自启或入仓”。

StartupFolder 应保留为有价值的替代：如果图形界面管理名单，或者“应用配置时不要顺带打开应用”是关键要求，它比当前 HM agent 更贴近需求，新增常驻组件可能值得。不能只因多一个应用就否定它，也不能把可重建目录夸成完整原生状态同步。

纯原生方案最少增加机制，但不能同时声称已经保留这份行为的 Git 恢复；本次找到的普通登录列表 CLI、plist 管理器和 MDM 也没有为这台个人工作站提供无额外代价的万能替代。首要改进应是消除同一应用的重复启动入口，而不是先再建立一个总控框架。

真正实施前的最小验收应覆盖：新增和移除受管项、无变化再应用、手动退出应用、重新登录，以及应用升级后的入口有效性。验收必须同时回读所选管理入口和实际行为；只看到 plist 或目录链接存在不算登录恢复成功。

本轮只读取公开一手文档、上游源码和仓库声明；未读取私人后台任务数据库，未改变登录项、应用开关、服务、安装或激活状态，也未进行注销或重启测试。来源支持的是接口和代码行为，StartupFolder 的首次启用、资源消耗及恢复效果仍需后续实测。文档验收范围为来源对应关系、相对链接与格式检查。
