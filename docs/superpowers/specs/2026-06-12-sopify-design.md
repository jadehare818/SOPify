# SOPify — Personal SOP iOS App Design Doc

- **Date**: 2026-06-12
- **Status**: Draft (pending user approval → writing-plans)
- **Owner**: 雨桐 (single-user personal app)

## 1. What this is

SOPify 是一个**只给自己用**的 iOS / iPadOS App，用来记录、组织、执行个人的 SOP（Standard Operating Procedure，标准作业流程）——覆盖生活、工作、运动、心理调节等场景。

典型用例：
- 出门前的清单（电梯卡 / 工牌 / 耳机）
- 到家后的固定流程
- 去游泳的复合流程（出发前打包 + 换衣区流程 + 泳后流程）
- 自我心理调节的认知流程
- 不同下班时间的回家分支流程

## 2. Core design principle: 减负 (reduce burden)

SOP 本身的目的是**减负**——把脑子里的东西托付给 App，让自己执行时不用想。所以整个 App 的设计准则是：

> **任何 UX 决策若让用户在执行 SOP 时多想、多操作、多等待，则该设计必须被砍掉或降级。**

具体体现：
- 反馈机制是**小图标 + 可选填**，不是必填表单
- 触发场景**不强制**——用户用不用都行
- 创建支持**粘贴解析**等快捷路径，避免逐行手敲
- 默认无打扰，统计/历史是被动记录、不弹窗

这一原则贯穿后续所有设计权衡。

## 3. Goals / Non-goals

### Goals (v1)
- 创建、编辑、组织、执行个人 SOP
- 支持 4 种结构：checklist / flow / branching；以及它们的**树形嵌套组合**
- 用户自定义"分类 (category)"组织 SOP
- **临时 SOP (one-shot)**：即建即用、不归属任何分类、完成后弹"删 / 留"提示
- 3 种触发：定时通知 / 手动打开 / 链式触发
- 完整执行历史（自动时间戳 + 可选反馈文字）
- iCloud 同步（iPhone ↔ iPad）
- JSON 全量导入导出

### Non-goals (v1，明确不做)
- 多用户、协作、分享、社交
- 注册登录系统（仅靠 iCloud Apple ID）
- 模板市场、运营内容
- 大模型 (LLM) 辅助生成（v2 候选）
- Apple Watch app（v2 候选）
- 地理围栏 / Siri Shortcuts / 日历集成（v2 候选）
- NFC 触发、HealthKit 触发、第三方云同步
- 录音 / 拍照 / 涂鸦反馈（v2 候选）

## 4. Domain model

### 4.1 SOP 是一棵树

```
SOP
├── id, name, type (.checklist | .flow | .branching)
├── category (1 个，可选 —— 临时 SOP 不归属分类)
├── isOneShot: Bool         // 临时 SOP 标记
├── triggers (0..N)
├── steps (有序)
└── createdAt, updatedAt
```

每个 **step (步骤)** 是 union 类型，二选一：

- **TextStep**：一行文字（leaf 节点）
- **NestedSOPStep**：嵌套一个完整子 SOP（递归节点，子 SOP 有自己的 type）

特殊地，对于 **branching SOP**，step 可以是 **BranchPoint**：

```
BranchPoint
├── question: String       // "今天几点下班？"
├── options: [BranchOption]
└── rejoinAfter: Bool      // 各分支结束后是否汇入主线尾巴
```

```
BranchOption
├── label: String          // "6:00" / "9:30"
└── steps: [Step]          // 走这条分支的步骤序列
```

### 4.2 关键约束

- **嵌套是嵌入式 (embedded)，不是引用式**——子 SOP 是父 SOP 的内嵌副本，编辑互不影响。复用靠用户**手动 duplicate**。
- **类型切换单向**：结构丰富度只增不减
  - checklist → flow ✅
  - flow → branching ✅
  - 反向 ❌（要降级请 duplicate 后选新类型）
- **嵌套深度**理论上不限，但 UI 侧 v1 默认折叠 3 层以上提示"内容较深"。

### 4.3 Category（分类）

```
Category
├── id, name, icon, order
└── 关联多个 SOP（一个 SOP 归一个 category）
```

- 系统预置示例：「生活」「运动」「工作」「心理」「出行」
- 用户可改名 / 新建 / 删除 / 重排
- 删除分类时其下 SOP 落入「未分类」桶

### 4.4 Trigger（触发器）

```
Trigger
├── id, kind: TriggerKind, config
└── 关联到某个 SOP

TriggerKind:
  .scheduled  // 定时：每日/每周/每月/特定日期 + 时间
  .manual     // 手动（默认所有 SOP 都有）
  .chained    // 链式：上一个 SOP 完成后立即触发
```

v1 不实现：地理围栏、Siri、日历、Watch、NFC、HealthKit。

### 4.5 ExecutionRecord（执行记录）

```
ExecutionRecord
├── id, sopId
├── startedAt, finishedAt (nullable)
├── stepCompletions: [StepCompletion]
└── rootRecord: bool  // 是否是顶层 SOP 的执行（嵌套子 SOP 也产生子记录）

StepCompletion
├── stepId, completedAt
└── feedbackText: String?  // 用户主动点反馈按钮才有
```

每次"开始执行"都产生一条 ExecutionRecord。嵌套子 SOP 的执行产生子记录，挂在父记录下。

### 4.6 One-shot SOP（临时 SOP）

**场景**：前一晚临时想好明早要准备的东西、半小时后要走的临时流程、出差期间一次性的清单。建完用一次就够，不希望污染主分类网格。

**模型**：SOP 的一个布尔字段 `isOneShot`。临时 SOP **正交于结构类型**——它仍然可以是 checklist / flow / branching，也支持嵌套子 SOP（与普通 SOP 完全相同的能力）。

**与普通 SOP 的差异**：

| 维度 | 普通 SOP | 临时 SOP |
|---|---|---|
| 分类 | 必须归一个 category | 不归任何 category |
| 主页位置 | 在分类卡片下钻进去看到 | 主页**顶部置顶区** "临时" |
| 创建入口 | 主页右上 `+` | 主页独立按钮 `+ 临时 SOP` |
| 完成后行为 | 直接返回主页（减负） | 底部弹层 "做完啦。还留着吗？" `[删了]`(默认) `[留着]` |
| 触发器 | 可配置定时/链式 | v1 不允许配触发（临时本就一次性） |
| 导出 | 包含在 JSON 全量导出 | **不导出**（临时性数据） |

**完成后弹层默认按钮**为 "删了"——一次性的语义就是用完即弃，默认清掉减负。用户主动选 "留着" 时这条 SOP 转为**保留态**继续待在临时区，不会自动归类，下次仍可执行。

**执行历史**：临时 SOP 的 ExecutionRecord 与普通 SOP 一致地写入；删除 SOP 时其历史也级联删除（cascade delete）。

## 5. Screens（核心屏幕）

### 5.1 首页 (Home)
- **顶部 "临时" 置顶区**：列出所有 `isOneShot=true` 的 SOP（横向卡片或纵向小行）；空时整块隐藏
- **置顶区右侧/下方按钮**：`+ 临时 SOP` 独立入口（点了直接进编辑页，类型默认 checklist，不要求选分类）
- 中部：分类卡片网格（用户自定义分类 + "未分类"桶）
- 中下部：最近执行的 SOP 列表（基于 ExecutionRecord，包含临时 SOP）
- 底部：搜索条
- 右上角：「+」新建（普通）SOP

### 5.2 分类详情页
- 列出该分类下所有 SOP
- 每个 SOP 显示：名称、type 图标、最近执行时间、累计执行次数
- 左滑：duplicate / 移动到其他分类 / 删除

### 5.3 SOP 详情页（编辑模式）
- 顶部：SOP 名称、type、category 选择
- 中部：步骤列表（拖拽排序）
  - 每步可点击切换为「文字」或「嵌套子 SOP」
  - 嵌套子 SOP 折叠展示，点开进入子 SOP 编辑（无限递归）
- 底部：触发器配置（v1 仅 scheduled / chained）
- 右上 Tab：「历史」——本 SOP 的所有 ExecutionRecord
- 工具栏：「粘贴解析」按钮（仅 checklist / 纯文字 flow 显示）

### 5.4 执行界面
- **Checklist 模式**（执行界面 B）：整页清单一次展示，挨个勾选，当前未完成项**视觉醒目**（高亮 + 大字）
- **Flow 模式**（执行界面 C，折叠混合）：默认整页清单视图；当前步**自动展开 + 放大显示细节**；做完自动收起、跳到下一步
- **Branching 模式**：到达 BranchPoint 时弹卡片"今天几点下班？"+ 选项按钮，选完进入对应分支
- **嵌套子 SOP**：执行到嵌套步骤时**整体下钻**进入子 SOP 执行界面（沿用对应 type 的执行模式），子 SOP 完成后弹回父级
- **右上角小图标**（✏️）：随时点开滑出半屏卡片写反馈，纯文字，可选
- **顶部进度条**：显示在嵌套层级中的位置 + 总进度

### 5.5 全局日记本 (Diary)
- 时间倒序展示所有 ExecutionRecord
- 每条记录：时间、SOP 名、完成度、反馈文字（如有）
- 点进去看完整执行明细

### 5.6 设置 (Settings)
- iCloud 同步状态
- 导入 / 导出 JSON
- 分类管理（增删改重排）
- 模板库（v1 内置示例 + 个人模板）
- 关于

## 6. Triggers（触发器实现细节）

### 6.1 定时通知 `.scheduled`
- 基于 iOS `UNUserNotificationCenter` (本地通知 API)
- 配置：每日/每周（指定星期）/每月（指定日期）/一次性
- 通知 action：tap 通知直接进 SOP 执行界面
- 用户可批量在设置里"暂停所有通知"

### 6.2 手动触发 `.manual`
- 首页 / 分类页 / 搜索 / 收藏夹 / Spotlight (系统搜索) 调起
- 默认所有 SOP 都能手动触发，无需配置

### 6.3 链式触发 `.chained`
- 配置：选定一个"前置 SOP"
- 前置 SOP 完成后**立即**推一条本地通知"准备开始 [当前 SOP] 吗？"
- tap 通知进入执行界面；忽略不影响数据
- 不做条件判断（不接 v1 范围的"如果完成度 > X 才触发"等）

## 7. Execution + History（执行与历史）

### 7.1 执行流
1. 用户从触发或手动入口进入 SOP
2. 系统创建 `ExecutionRecord`，`startedAt = now`
3. 用户逐步勾选/确认；每勾一步写一条 `StepCompletion`
4. 嵌套子 SOP 进入时创建子 ExecutionRecord（`parentId` 关联）
5. 全部完成 → `finishedAt = now`
6. **不弹"完成总结"页**——直接返回首页（减负）
7. **若 SOP 是临时 SOP** (`isOneShot=true`)：在返回首页前弹一个底部 sheet：
   > 做完啦。这条临时 SOP 还留着吗？
   > `[删了]`（默认聚焦） `[留着]`
   - `[删了]`：级联删除 SOP 及其 ExecutionRecord，弹回首页
   - `[留着]`：什么都不做，弹回首页，SOP 保留在临时区

### 7.2 反馈输入
- 反馈按钮在执行界面右上角，小图标 ✏️
- 点击滑出半屏文字编辑卡片
- 当前关注步骤自动作为反馈的"附着点" (anchor / 锚)
- 用户写完点保存，反馈文本写到对应 `StepCompletion.feedbackText`
- 不写也行，不阻塞流程

### 7.3 历史查看入口
- **SOP 详情页摘要**：顶部显示"最近执行：3 天前 / 累计 12 次 / 平均完成度 87%"
- **每个 SOP 的「历史」Tab**：列出本 SOP 所有 ExecutionRecord
- **全局日记本**：时间线方式跨 SOP 浏览

## 8. Data persistence & sync

### 8.1 本地存储：SwiftData
- 所有 model 用 `@Model` 注解
- 嵌套关系用 SwiftData 关系字段（含递归——子 SOP 是 SOP 类型的关系，要小心循环引用）
- 注意：SwiftData 在递归 `@Model` 上有些限制，可能需要把"嵌套子 SOP"用 `Step.nestedSOPID + 单独存一个 SOP 实体"扁平化处理"，由代码层负责树的组装。具体在实现阶段验证。

### 8.2 云同步：CloudKit (`.private` database)
- SwiftData + CloudKit 集成模式
- 同 Apple ID 设备自动同步
- 离线可用，重连自动 merge
- 冲突策略：last-write-wins（个人 App，无并发协作场景，足够）

### 8.3 隐私
- 数据全部在用户私有 iCloud 容器
- 无任何数据上传第三方
- 通知权限 / iCloud 权限是仅有的两个系统权限请求

## 9. Import / Export

### 9.1 导出
- 设置页「导出全部」按钮 → 生成单一 JSON 文件
- JSON 结构包含所有 SOPs / Categories / Triggers（**不包含 ExecutionRecord**——历史不导出，避免文件膨胀）
- 通过系统 share sheet 出去（AirDrop / 邮件 / 第三方网盘 / 任何 app）

### 9.2 导入
- 设置页「导入」按钮 → 选择 JSON 文件
- 解析后展示 diff（新增 / 已存在同名 SOP）
- 用户确认 → 写入数据库
- 同名 SOP 默认导入为副本（名称加 " (imported)" 后缀），不覆盖

### 9.3 单 SOP 分享（轻量）
- SOP 详情页右上「⋯ → 分享」 → 导出单个 SOP 的 JSON 片段
- 接收方导入时合并到自己的库

## 10. Architecture & tech stack

| 层 | 选型 | 备注 |
|---|---|---|
| **UI** | SwiftUI | iOS 17+，声明式 UI |
| **状态管理** | SwiftUI 原生 `@Observable` + `@Environment` | 不引入外部 state 库 |
| **数据层** | SwiftData (`@Model`) | iOS 17 引入的 ORM |
| **同步** | CloudKit `.private` database | 经由 SwiftData 集成 |
| **通知** | `UNUserNotificationCenter` | 本地通知，无远程推送 |
| **导入导出** | Codable + FileExporter / FileImporter | iOS 16+ 系统 API |
| **粘贴解析** | 自写正则 + 行拆分 | 简单：按换行 / 编号识别 |
| **触感反馈** | `SensoryFeedback` API | 勾选完成时轻触感 |
| **目标平台** | iOS 17 + iPadOS 17（同一 universal binary） | Watch v2 |
| **测试** | XCTest + SwiftUI 预览 | 单元 + UI 预览快照 |

## 11. v1 scope vs v2 backlog

### v1（MVP）必交付
- ✅ 4 种 SOP 结构 + 树形嵌套
- ✅ 用户分类（增删改重排）
- ✅ **临时 SOP**（即建即用、置顶区、完成后弹删除/保留）
- ✅ 3 种触发：定时 / 手动 / 链式
- ✅ 折叠混合执行界面（flow）+ 整页清单（checklist）+ 分支问答（branching）
- ✅ 反馈按钮（纯文字）
- ✅ 完整执行历史 + 三处入口
- ✅ iCloud 同步
- ✅ JSON 全量导入导出
- ✅ 内置模板示例
- ✅ iPhone + iPad

### v2（明确推迟，但保留接口扩展位）
- 🕐 大模型辅助生成 SOP
- 🕐 Apple Watch app（独立 watchOS target）
- 🕐 Siri Shortcuts / AppIntents 触发
- 🕐 日历事件触发
- 🕐 地理围栏触发
- 🕐 反馈支持图片 / 录音
- 🕐 全局日记本的高级筛选

### 永不（暂不考虑）
- ❌ NFC tag 触发
- ❌ HealthKit 触发
- ❌ 第三方云同步
- ❌ 多用户 / 社交 / 协作

## 12. Open questions（实现阶段验证）

1. **SwiftData 递归 model 限制**：`SOP` 自身嵌套是否需要扁平化处理。需要在搭建数据层时实测。
2. **CloudKit schema 演进**：未来加新字段时的迁移策略，v1 阶段先用最简 schema。
3. **branching 在 SwiftData 里怎么建模最干净**：BranchPoint / BranchOption 是 step 子类还是独立实体。倾向独立实体。
4. **嵌套执行的导航返回**：在 iOS NavigationStack 里嵌套层级深时的导航体验需要原型验证。
5. **粘贴解析的智能度**：仅按换行拆 vs 识别"1.""2.""-" 等编号——v1 起步先做识别编号 + 按行兜底。

## 13. Out of scope (this doc)

- 视觉设计稿（颜色 / 字号 / icon 选型）——交给后续 frontend-design 阶段或实施时迭代
- App icon / 启动图
- App Store 上架（这是个人 App，不计划上架）
- 隐私协议 / 用户协议文案

---

## Appendix A: 关键术语对照

| 中文 | 英文 | 含义 |
|---|---|---|
| 流程 | flow | 顺序执行的步骤序列 |
| 清单 | checklist | 一次性勾选的项目集合 |
| 分支 | branching | 含条件跳转的步骤 |
| 嵌套 | nesting | 步骤本身是另一个完整 SOP |
| 触发器 | trigger | 决定 SOP 何时被激活的机制 |
| 链式触发 | chained trigger | 上一个 SOP 完成→提醒下一个 |
| 折叠混合 | collapsed hybrid | 整页可见 + 当前步自动展开放大 |
| 减负 | reduce burden | 本 App 的核心设计原则 |
