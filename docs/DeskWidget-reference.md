# DeskWidget 参考分析与 DeskIsle 设计依据

分析日期：2026-10-24。目标是理解用户喜欢的桌面交互能力，为独立实现的 DeskIsle 制定范围。本报告只使用已安装应用的发布产物、中文本地化资源和 REA 导出的静态证据，没有读取用户便签、文件分区内容、偏好设置或账号数据，也没有修改或启动参考应用。

## 证据范围

| 项目 | 观测值 |
| --- | --- |
| 应用路径 | `/Applications/DeskWidget.app` |
| 标识 | `com.byteapp.widget` |
| 版本 | `5.2.2`，build `50041` |
| 系统声明 | 最低 macOS `12.4`，`LSUIElement = true` |
| 可执行文件 | `Contents/MacOS/DeskWidget`，Mach-O universal，本次 REA 选择 arm64 |
| 可执行文件 SHA-256 | `99793ae71e4090f9e5ff31ef31fc3be065b44b31e2067601212ba696c9213fb0` |

原始结构化证据保存在同目录的 `rea-evidence.json`。以下编号用于复核：

- **E1** — `inspect_plist`：`ev_577f57e334244fce936a6ec5fecb28e069f639e7eb78da1502cdf72f5d1feaaf`，来源 `Contents/Info.plist`。
- **E2** — `inspect_plist`：`ev_9c0b05fcab3be00d90fdb725c8bb649ce3ab380d14f7cf900f9f50ee46ce27c5`，来源 `Contents/Resources/zh-Hans.lproj/Localizable.strings`。
- **E3** — `inspect_macho`：`ev_cc13ae735aa9e611f90ccb472259671c2404bdf406bb8f06fd33c986189d87c7`。

`observed strings` 表示确实存在于发布资源中的文本，不等于已确认当前版本会显示该界面。`inference` 是由文本或依赖推导的解释。`unknown` 表示当前证据不能回答的问题。

## 四类功能线索

### 1. 文件分区

**Observed strings（E2）**

- `widget.file.title` → “文件区”。
- `file.path.title` → “设置桌面文件存储区”。
- `file.path.descrip` 说明放入分区的文件会移动到专属目录，推荐文稿目录。
- `file.delete.descrip` 说明删除分区后文件仍保存在源文件路径。
- `file.same.content` 描述同名文件冲突。
- `file.migration.prompt.title`、`file.migration.success.title` 与一组 `file.migration.*` 资源描述存储机制升级、文件安全区及手动迁移。
- `widget.pop.showInFinder`、`widget.pop.copyFolderPath` 对应访达定位及复制目录路径。

**Inference**

参考产品至少曾设计过由应用管理真实存储目录的文件分区，包含权限、命名冲突及升级迁移流程。文件分区不仅是视觉分组，可能涉及实际文件移动。

**Unknown**

当前用户是否已迁移、当前版本使用哪条实现路径、拖拽究竟移动还是复制，以及遇到磁盘断开或权限撤销时的运行行为均未验证。资源中仍存在“升级中，当前不可用”之类旧流程文案，不能据此断言功能当前不可用。

### 2. 应用分区 / 快捷启动

**Observed strings（E2）**

- `widget.quick.app` → “应用”。
- `widget.quick.selectApp` → “选择应用”。
- `widget.quick.search` → “搜索...”。
- `widget.quick.customBackground` → “自定义背景”。
- 引导文案 `guide.type1.descrip` 明确列出“App快捷启动”。

**Inference**

该组件提供应用选择、搜索及快捷入口，并可定制背景。用户所说的“应用分区”可以落为多个应用入口组成的桌面卡片。

**Unknown**

没有验证参考应用的扫描目录、排序策略、拖拽交互、启动方式及是否支持网页快捷方式；不将这些作为已知事实。

### 3. 倒数日

**Observed strings（E2）**

- `countdown.titile.palcehold` → “倒数日”。
- `widget.countdown.name` → “标题”。
- `widget.countdown.date` → “日期”。
- `countdown.target.day` → “日期：”。
- 另有 `widget.timer.countDown`、`widget.timer.countUp`、`widget.timer.start`、`widget.timer.stop` 等计时器资源。

**Inference**

倒数日可由标题及目标日期描述；日期倒数与按时长运行的计时器是两类功能。用户本次重复提及倒数日，首版按一个组件类型处理。

**Unknown**

未验证到期日是否计入、过期后的文字、时区、农历或周年重复规则。DeskIsle 应明确使用本地日历的日期差，避免把未知规则当作参考产品行为。

### 4. 项目随记 / 便签

**Observed strings（E2）**

- `widget.note.addtext` → “添加文本...”。
- `widget.note.newNotebook` → “新建便签”。
- `widget.note.history.title` → “便签列表”。
- `widget.note.pop.title` → “标题”。
- `note.pop.*` 包含正文、标题、小标题、编号列表及项目符号列表。
- `widget.note.history.deleteConfirmMultiple` 描述一份便签可影响多个组件。
- `widget.note.export.toNotes` → “导出到备忘录”；E1 同时声明控制“备忘录”的 Apple Events 用途。

**Inference**

参考产品有可复用便签内容及若干文字格式能力。“项目随记”在本次独立实现中可以表现为有标题的项目笔记卡，支持编辑并持久保存。

**Unknown**

未找到足以确认“项目随记”是参考产品精确组件名的证据。项目结构、富文本模型、同步和历史版本机制均未知。首版采用普通文本编辑，不宣称已复刻参考产品富文本或备忘录导出。

## 桌面交互与技术观察

**Observed（E1 / E2 / E3）**

- E1 声明 `LSUIElement = true`、`NSPrincipalClass = NSApplication`、`NSMainStoryboardFile = Main`。
- E2 包含“始终置顶”“锁定位置”“对齐网格”“移动到当前屏幕”，以及屏幕变化后组件可能位于屏幕外的提示。
- E3 的动态依赖包含 AppKit、SwiftUI、Foundation、CoreGraphics、Combine、RealmSwift，以及其他与参考产品更广范围功能相关的系统框架。

**Inference**

发布产物符合原生 macOS 应用形态，支持可移动桌面组件。AppKit 与 SwiftUI 依赖支持采用原生实现作为合理技术方向，但不能证明具体窗口类、窗口层级或视图结构。

**Unknown**

尚未运行或反编译窗口创建路径。是否使用 WidgetKit 扩展、确切的 NSWindow collection behavior、各 Spaces 行为、数据库表结构及资源中的哪些字符串仍有效均未知。RealmSwift 依赖仅证明链接关系，不能证明所有组件内容都由 Realm 保存。

## DeskIsle 的独立设计选择

以下是本项目的工程决定，并非对参考应用内部实现的断言。

| 选择 | 原因与首版边界 |
| --- | --- |
| 文件引用 | 文件区保存用户选择的文件 URL / 书签引用，展示图标并支持打开、访达定位、移除引用。不会为了添加卡片而搬动原文件，从而避免首版引入文件迁移与重名覆盖。引用断开时应可移除或重新选择。 |
| AppKit 独立桌面窗口 | 用每张卡片对应的原生窗口承载 SwiftUI 内容，提供直接编辑、拖拽摆放及位置保存；可围绕置顶、锁定及屏幕变化继续扩展。该结构满足桌面卡片需要，不依赖参考应用代码。 |
| JSON 持久化 | 用 Codable 模型保存组件类型、标题、内容、日期、文件/应用引用和窗口几何信息，写入 DeskIsle 自己的应用支持目录。首版数据规模小，便于检查、备份与迁移，无需跟随参考应用的数据库选择。 |
| 四类首版组件 | 文件区、应用区、倒数日、项目随记。暂不把参考应用其他系统监测、照片、日历、白噪音或订阅功能加入本次范围。 |

实现完成后，应以实际可执行验证补充启动、拖动、编辑、重启恢复与文件引用行为。本文的静态参考分析本身不构成 DeskIsle 运行验证。
