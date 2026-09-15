# code-development 整体架构图

[打开架构图](code-development.html) · [编辑图规格](code-development.json)

边界内呈现 `intents/code-development` 的八个选择；绿色箭头呈现实际接线，底部按平台汇总后交给两个主机。成员关系由包围边界表达，不为每个成员重复添加汇总线。`nil` 与 `nixd` 仅安装，未臆造与 Zed 的语言服务器连接。

## 维护

在仓库根目录使用 Archify 2.17 校验并生成：

```fish
node /Users/sayori/.skills-manager/skills/archify/bin/archify.mjs validate architecture docs/architecture/code-development.json --repo-root . --quality showcase --json
```
🔎 核实源码引用与图形结构；源码变化时应更新规格中的固定提交。

```fish
node /Users/sayori/.skills-manager/skills/archify/bin/archify.mjs deliver architecture docs/architecture/code-development.json docs/architecture/code-development.html --repo-root . --quality showcase --json > docs/architecture/code-development.receipt.json
```
📦 校验成功后原子写入 HTML，记录规格和产物的字节校验值。

```fish
node /Users/sayori/.skills-manager/skills/archify/bin/archify.mjs visual-check docs/architecture/code-development.html --json
```
🖼️ 检查桌面尺寸并生成截图；需另外看图确认视觉质量。

## 本次验收

- 类型：`architecture`；静态默认视图。
- 结构：[交付回执](code-development.receipt.json)，showcase 9/9，0 错误、0 警告。
- 浏览器：[自动证据](code-development.visual-check.json)，`passed`；1440×900、1600×1000、1920×1080、2048×1320 均无横纵溢出。
- 视觉：`passed`；图像审阅覆盖 1440×900、2048×1320 的浅色与深色截图，确认节点、标签、箭头及底部说明完整、清晰，最大尺寸无明显空白下带。
- 视觉修正：1 轮，压紧纵向间距；未改字号或隐藏内容。
- 视觉审阅范围为默认 READ 静态画面；未逐项人工测试搜索、聚焦及导出交互。
- 规格 SHA-256：`61fc9bba60cd060f04865b60d9b728ffd5145e4c70785e7c63dbc4d9efd47ac2`（5348 字节）。
- HTML SHA-256：`148eae148e446835d7fa820f768ca4276621c033d812c1def2d13d8b0b9f4e0e`（807472 字节）。

[查看截图对照](code-development.visual-check.html)。
