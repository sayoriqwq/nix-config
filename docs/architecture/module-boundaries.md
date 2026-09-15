# 模块与目录边界

## 1. 路径职责

| 路径 | 负责 |
| --- | --- |
| `flake.nix` | inputs、outputs 与顶层接线 |
| `hosts/<host>/` | 使用需求的最终选择、目标用户与机器事实 |
| `intents/<intent>.nix` | 一起选择的使用需求、包声明、依赖和简短接线 |
| `software/<software>/` | 值得独立维护的单软件配置、素材、平台实现及外部状态说明 |
| `shared/` | 多个实际消费者复用且不归单个 Software 的基础内容 |
| `dotfiles/` | 稳定、可投影的静态内容 |

## 2. Intent 是使用需求的选择入口

Intent 可以直接声明 `home.packages`、`environment.systemPackages`、Homebrew 安装项或社区模块的启用选项。只有安装声明的软件不要求独立文件或目录。简短且仅属于当前需求的接线可以一起放入 Intent，例如 OrbStack 安装与 Shell 初始化。

有实际配置、素材或平台差异的实现继续留在 Software，由 Intent 显式引用。依赖必须完整：需要 Git、Fish 或 LazyGit 的需求直接选择同一配置模块，不能依赖另一个 Intent 恰好提供。相同实现按模块路径复用，避免在多个 Intent 复制配置。

`intents/lib.nix` 只按顺序拼接 `darwinModules`、`nixosModules`、`homeModules`，缺失字段视为空列表。需要合并已有组合时使用它；只含一个模块列表的 Intent 直接返回 attrset，不增加无用函数或空列表。Host 读取该 Intent 实际提供的字段。

Intent 按实际一起启停的需求成立，不按软件类别强行分组，也不要求涉及多个软件。不得扩展成注册表、自动扫描、第二份安装清单或通用关系框架。

## 3. Software 的公开入口

实际配置文件可直接作为公开模块入口。只有组合真实平台实现或提供有意义的参数化行为时，才用 `default.nix` 提供命名行为；不为一个文件增加路径别名。Fish 的平台组合和 Zed 的任务行为保留这种入口。

Software 内部默认平铺。脚本、配置素材和实现放在一起，只有实际规模需要时才分目录。Zsh adapter 随使用需求选择，仅在 Zsh 已启用时生效，不反向开启兼容终端。

`shared/` 只存多个实际消费者复用的基础内容；直接引用具体文件，不提供全选入口。单消费者的辅助实现留在所属 Software 或 Intent。

## 4. Import 方向与 Host 选择

```text
flake
  └── Host：需求选择与机器事实
       ├── Intent
       │    ├── 包声明、社区选项、简短接线
       │    └── Software 配置或组合入口 → 按需引用 shared/
       ├── 尚未梳理的独立 Software、系统模块
       └── hardware 与公共主机声明
```

第一组命令行、终端、编辑器、开发运行时、容器和 GitHub 协作已从 Intent 选择。其余软件按后续使用需求逐组梳理，不因本次规则变更自动搬迁。

- Software 不 import Intent 或 Host；Intent 不 import Host。
- Home Manager module 不 import nix-darwin/NixOS system module。
- Darwin 与 NixOS 实现不互相 import。
- 所有 imports 显式列出，不从另一台 Host 继承后排除。
- 磁盘、启动、NIC、provider、stateVersion 等机器事实留在 Host。

## 5. Platform seam 与外部状态

平台的安装来源、配置、运行进程、网络影响或人工操作实际不同才形成 platform seam。平台差异就近保存在对应实现，不为不存在的第二个平台创建空 adapter。

实现附近说明选定的安装与配置职责，以及必要的外部状态和恢复限制。可变数据库、认证、登录态、缓存与用户内容保持外部；Secret 按实际 consumer 单独引入。构建不证明已激活，声明不证明现场。

## 6. 删除检验

若删掉一个 module 后只少了跳转，直接收拢声明；若配置知识会散落到多个调用点，则保留 module。包名出现次数不是唯一来源的判断依据：包可由多个真实需求共同选择，同一份定制配置应复用同一实现。

项目依赖由项目声明管理；主机 Intent 提供需要的运行工具。历史决策依据见 [ADR-0007](../adr/0007-capability-modules-and-host-composition.md)。
