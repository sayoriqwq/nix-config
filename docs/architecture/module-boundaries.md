# 模块与目录边界

## 1. 路径职责

| 路径 | 负责 | 不负责 |
| --- | --- | --- |
| `flake.nix` | inputs、outputs、顶层 package/check/operation wiring | 软件内部配置、Host 业务 bundle |
| `hosts/<host>/` | 最终选择、platform/hardware/provider facts、目标用户 | 复用软件实现、隐式继承其他 Host |
| `software/<software>/` | 单个 Software 的声明、配置材料、实现、外部路径说明与公开行为 | Host 选择、跨软件需求编排 |
| `intents/<intent>.nix` | 通过公开行为表达一起选择的使用需求 | 写 owner 私有 option、runtime mutation |
| `modules/` | 有真实消费者的 System 或跨 owner primitive | `common`/`desktop`/平台全选 bundle |
| `checks/` | 窄、确定性的 contract validation | production configuration source |
| `operations/` | 人工可调用且边界固定的安全操作 | 隐式 target、无人值守 production mutation |
| `dotfiles/` | 稳定、可投影的静态内容 | auth、session、cache、database 或 secret |

## 2. Software public interface

供 Intent 使用的 Software owner 在 `software/<name>/default.nix` 暴露命名接口。每个接口是普通 attrset，按需包含 `darwinModules`、`nixosModules`、`homeModules` 列表：

```nix
{
  primaryBehavior.homeModules = [ ./capabilities/primary-behavior/home.nix ];

  zshIntegration.homeModules = [ ./capabilities/primary-behavior/zsh.nix ];
}
```

规则：

- 名称描述行为，不描述目录或平台；
- 公开接口表示可选择的行为，不划分 Primary Capability、Extension 或 Contribution 类型；
- 无参数接口直接暴露 attrset；需要真实参数的行为 返回同样的 attrset；
- Software 行为不能 import Intent，也不能为了方便复制另一个 Software 的实现；
- owner-local package、脚本、manifest 和固定数据留在同一 Software tree；
- 只有一个真实实现时，不创建空 Darwin/NixOS pass-through。

## 3. Intent contract

`intents/lib.nix` 只提供一个组合函数：用 `lib.concatMap` 按输入顺序分别拼接三类 module lists，缺失的字段视为空列表。结果始终包含 `darwinModules`、`nixosModules`、`homeModules`，可继续参与组合。

Intent 表达一起选择的使用需求，可以只有一个软件，也不要求存在胶水代码。依赖必须显式选择，不能依赖另一个 Intent 恰好安装所需程序。Intent 显式列出公开接口：

```nix
let
  compose = import ./lib.nix { inherit lib; };
in
compose [
  software.editor.guiEditor
  software.git.versionControl
  (software.editor.addTask { name = "Git"; command = "lazygit"; })
]
```

不得扩展为 registry、relation graph、workflow DSL、自动扫描、优先级求解器或平台 substrate。出现新的真实需求时先增加命名行为；只有 `intents/lib.nix` 的三列表模型本身无法表达时，才通过新 ADR 复审。

## 4. Import 方向

```text
flake
  └── Host
       ├── Intent
       │    └── Software public interface
       │         └── owner-local capability files
       ├── independent Software platform files
       └── proven modules/

Check / Operation ──▶ production declaration
```

硬规则：

- Software 不 import Intent 或 Host；Intent 不 import Host。
- Production Host 不 import `checks/` 或 test-only Operation modules。
- Check/Operation 可以读取 production declaration，但不得成为其运行依赖。
- Home Manager module 不 import nix-darwin/NixOS system module。
- Darwin 与 NixOS 实现不互相 import。
- 所有 imports 显式列出；不递归扫描目录。

## 5. Host 选择

Host 可以：

- 追加 Intent 结果的三类 module lists；
- 直接 import 不需要横向协调的独立 Software platform capability；
- import hardware/system primitive；
- 通过 `specialArgs`/`extraSpecialArgs` 传入非 secret 的真实参数。

Host 不可以：

- import `common`、`desktop`、`darwin`、`linux` 或 server bundle 代替需求；
- 自动选择整个 `software/` 目录；
- 为减少 imports 建 `capabilities.*.enable` 第二注册层；
- 从另一个 Host 继承后逐项排除。

## 6. Platform seam

平台不同只有在 package、配置 API、service、network effect 或人工关卡实际不同时才形成 seam。常见布局可以是同一 capability 下的 `home.nix`、`darwin.nix`、`nixos.nix`，但文件名不是架构层。

增加 platform implementation 前必须说明：

- package owner；
- managed configuration；
- mutable/external state boundary；
- service 和 network effect；
- activation/readback/rollback gate。

移除无人消费 metadata 后只剩同一个 `home.nix` 的平台 pass-through，应让 caller 直接选择真实实现并删除空层。

## 7. State、secret 与共享值

- 可变数据库、key、登录态、cache、session、browser profile、user content 不得整体链接到 Store。
- Secret 不通过普通 Nix string、args、Issue 或日志传递。出现真实 consumer 时另立机制与权限合同。
- 必要 mutable boundary 保留在最近的 Software 注释或当前 runbook；不建立无 consumer 的全局清单。
- Username、inputs 等非 secret 可以经 module args 传递；不要建立巨大无类型 `vars` attrset。
- Host 与 hardware facts 只放 `hosts/<host>/`。

## 8. 选择判断

1. 单软件声明、材料、实现和外部状态边界：进入 Software。
2. 需要被选择的行为或参数化贡献：暴露普通命名接口。
3. 一起选择的使用需求：建立 Intent，显式列出依赖。
4. Boot、disk、NIC、provider、stateVersion：进入 Host/System。
5. 项目依赖：进入项目 dev shell。
6. External state 或 secret：保持外部，并建立数据/secret 流程。
7. 只为历史追溯存在的 wrapper、metadata、matrix 或 test：由 Git history/Issue 承担，当前 tree 删除。
