# [UX-AUX-1] 用户视角体检：首页/主导航/词书书架域

## 审计范围

主壳 MainShell 3 标签（首页/词书/我的）、首页 HomeScreen（学情/签到/入口）、词书列表 LibSelectPage、词书仪表盘 BookDashboardPage、ProfileScreen。

## 发现汇总

| 级别 | 数量 | 说明 |
|------|------|------|
| 高 | 5 | 首次引导缺失、核心入口不可达、术语困惑 |
| 中 | 7 | 空态不友好、反馈缺失、摩擦冗余 |
| 低 | 5 | 文案语气、视觉微调、一致性 |

---

## 高优先级

### UX-H1: 首页 Learn 入口：未选词书时点击学习无明确引导
- **文件**: `lib/screens/home_screen.dart:~200-220` (`_startLearning`)
- **现象**: 新用户首次打开 app，Learn 卡片显示 "0 待学"。点击后如果词书列表为空，仅弹 SnackBar `暂无词书，请先添加词书`。用户不知道去哪里添加、为什么没有词书、应该做什么。
- **用户痛点**: 首次使用完全迷失，核心路径（背单词）在第一步就断了。SnackBar 1.5 秒消失，用户可能完全没注意到。
- **建议**: 空态时 Learn 卡片变为引导态，显示"选择你的第一本词书→"按钮直达 LibSelectPage，而非弹隐藏的 SnackBar。

### UX-H2: 首页 Review 入口：未选词书时点击无任何反馈
- **文件**: `lib/screens/home_screen.dart:~120` (`showReviewDialog`)
- **现象**: Review 卡片始终显示 "0 待复习"（即使无词书），点击后弹 ReviewDialog 但队列为空，可能显示"无待复习单词"或空白。
- **用户痛点**: 新用户看到"Review 0"不知道"复习"是什么、为什么是 0、什么时候会有。点击后无获得感。
- **建议**: 新用户状态（未学习过任何单词）下隐藏 Review 卡片或将其变为"完成首次学习后解锁"的预告态。

### UX-H3: 词书列表 LibItem 描述硬编码，不反映实际词书内容
- **文件**: `lib/pages/lib_select_page.dart:~580` (`_LibItem` 硬编码 `'考研核心高频 | 2026'`)
- **现象**: 所有词书的描述都显示"考研核心高频 | 2026"，无论实际是四级、六级还是托福。
- **用户痛点**: 用户无法通过描述区分词书内容，描述信息完全无用。
- **建议**: 使用 `book.description` 或至少根据 `book.code` 显示对应分类描述。

### UX-H4: 术语"尖叫币"令人困惑
- **文件**: `lib/screens/profile_screen.dart:~180-210` (`_CoinCard`)
- **现象**: "尖叫币" 是应用内虚拟货币，但名称与单词学习无语义关联。新用户完全不知道这是什么、怎么获得、怎么用。
- **用户痛点**: 一个正经的背单词 app 出现"尖叫币"令人费解，增加认知负担。
- **建议**: 改为"词力值"、"学分"等与学习语义相关的名称，或在首次展示时加 tooltip 解释。

### UX-H5: 主壳 3 标签"词书"入口冗余
- **文件**: `lib/shell/main_shell.dart`（Tab 1 = 词书）
- **现象**: 首页底部已有"选择词书"卡片，ProfileScreen 菜单也有"学习偏好"入口，底部 Tab 又有一个完整 Tab 专放"词书"。三个入口指向类似功能，用户困惑应该用哪个。
- **用户痛点**: "词书"Tab 和首页"选择词书"卡片功能重叠，但体验不同（Tab 是 BookDashboardPage，卡片是 LibSelectPage）。
- **建议**: 统一入口语义。首页卡片 = 快速切换，Tab = 完整管理。至少在卡片上加提示词"选择"vs"管理"。

---

## 中优先级

### UX-M1: 首页 Learn/Review 数字 0 时无差异化状态
- **文件**: `lib/screens/home_screen.dart:~110-130` (`_EntryCard`)
- **现象**: Learn 和 Review 都显示纯数字（0），样式相同。用户分不清哪个先用、哪个待激活。
- **用户痛点**: 两个卡片几乎一样，缺乏优先级视觉引导。
- **建议**: Learn 为 0 时用引导文案如"开始学习"替代数字；Review 为 0 时用"完成学习后解锁"替代。

### UX-M2: 签到卡片"打卡 +10"提示语义不明
- **文件**: `lib/screens/home_screen.dart:~230-250` (`_buildCheckInCard`)
- **现象**: "+10"没有单位。新用户不知道 +10 什么（积分？经验？币？）。且签到日历在右上角小圆形按钮，首次可能完全忽略。
- **用户痛点**: +10 无语义单位，签到入口太隐蔽。
- **建议**: 改为"+10 尖叫币"或"+10 词力值"，且首次使用时用 pulse 动画高亮签到按钮。

### UX-M3: 词书页底部工具栏功能过多
- **文件**: `lib/pages/lib_select_page.dart:~300-350` (底部 `_BottomToolItem` x 6)
- **现象**: 底部有 6 个工具（词书主页/沉浸刷词/随身听/听写/随手拼/导出），密密麻麻排成一行。且部分工具（听写/随手拼/导出）需要先选词书才能用。
- **用户痛点**: 工具太多、文字太小(11px)、图标挤在一起，移动端触达可能不准确（<48dp）。
- **建议**: 收纳为"更多学习模式"入口，展开二级菜单。或仅保留最高频的 2-3 个。

### UX-M4: 词书加载失败/无数据时错误文案太技术化
- **文件**: `lib/pages/lib_select_page.dart:~230` (`加载失败: ${snapshot.error}` 错误)
- **现象**: 错误信息直接显示 `snapshot.error` 对象内容，可能是 `SocketException` 或 `TimeoutException` 等技术术语。
- **用户痛点**: 用户看到 "SocketException: Connection refused" 完全不知所措。
- **建议**: 包装为用户友好文案如"网络连接失败，请检查网络后重试"。

### UX-M5: ProfileScreen "学习偏好"菜单项点击无导航
- **文件**: `lib/screens/profile_screen.dart:~150` (`_menuRow` 中 `'学习偏好'`)
- **现象**: "学习偏好"菜单项的 `onTap` 未设置（null），点击后无反应。
- **用户痛点**: 用户期望点击进入学习偏好设置，但无任何反应，也没有禁用状态的视觉暗示。
- **建议**: 接入 `LearningPreferencesPage.routeName` 或禁用时显示灰色 + 提示。

### UX-M6: ProfileScreen "装备"卡片 9/9 数字无交互
- **文件**: `lib/screens/profile_screen.dart:~230-270` (`_EquipCard`)
- **现象**: 显示"装备 9/9"和 4 个图标，但整个卡片不可点击（无 onTap）。右侧有 chevron_right 箭头暗示可进入。
- **用户痛点**: 视觉暗示可点击但实际无反应，令人沮丧。
- **建议**: 移除 chevron_right（不可点击时），或接入装备详情页。

### UX-M7: 词书卡片点击加载 50 个词后跳转，中间无加载反馈
- **文件**: `lib/pages/lib_select_page.dart:~530-560` (`_LibItem.onTap`)
- **现象**: 点击词书后先 `await session.loadBook(book, limit: 50)`，这可能是异步 IO。期间无 loading 指示，用户不知道是否在响应。
- **用户痛点**: 点击后可能有 0.5-2 秒无反馈，用户可能重复点击。
- **建议**: 点击后立即显示 loading 状态（如行内进度或全屏 loading overlay）。

---

## 低优先级

### UX-L1: 首页横幅画"BB"按钮不直观
- **文件**: `lib/screens/home_screen.dart:~270-290` (`_buildWordMachineButton`)
- **现象**: 右上角绿色圆形按钮显示"BB"文字（GameBoy 风格），无 tooltip，新用户完全不知道这是什么。
- **用户痛点**: "BB" 是 Monogram 不是常见图标，无文字说明。
- **建议**: 添加 tooltip `'背单词机'` 或改用可识别的图标（如 `Icons.gamepad`）。

### UX-L2: 首页左上角查词按钮图标与实际功能不一致
- **文件**: `lib/screens/home_screen.dart:~300-320` (`_buildSearchButton`)
- **现象**: 按钮显示 `Icons.menu_book_rounded`（书本图标），但功能是"查词"（SearchPage）。书本图标暗示"阅读"而非"搜索"。
- **用户痛点**: 图标暗示"打开书"但实际跳搜索页，首次使用可能困惑。
- **建议**: 改为 `Icons.search` 或 `Icons.translate`。

### UX-L3: 首页励志语无法关闭/自定义
- **文件**: `lib/screens/home_screen.dart:~160-180` (`TestimonialSlider`)
- **现象**: 每日一句自动轮播，固定占据首页 ~120px 高度。无法关闭或自定义。对于已有明确目标的高级用户是噪音。
- **用户痛点**: 无法移除不需要的区块，首页空间利用率低。
- **建议**: 添加关闭按钮或折叠功能。

### UX-L4: BookDashboardPage 无返回首页按钮
- **文件**: `lib/features/book/presentation/books_page.dart:~60` (`_buildHeader`)
- **现象**: "词书"页面头仅有标题，无导航返回按钮（虽然外层 LibSelectPage 有返回）。如果直接路由到此页面则无法返回。
- **用户痛点**: 被直接打开时无法返回（依赖导航上下文）。
- **建议**: 添加 `AppBar` 或 back 按钮。

### UX-L5: 首页日期格式为英文（Mon./Tue.）但界面其余为中文
- **文件**: `lib/screens/home_screen.dart:~40` (`_formatDate`)
- **现象**: 签到卡片日期显示 "08/28 Thu." 英文星期缩写，但全 app 其他文案均为中文。
- **用户痛点**: 语言不一致，中文用户看到英文星期缩写觉得突兀。
- **建议**: 改为 "08/28 周四" 或 "08/28 Thu" 保持一致。

---

## Desktop / 平板布局评估

| 维度 | 状态 | 说明 |
|------|------|------|
| 主壳底部 Dock | ✅ | `FloatingDock` 自适应屏幕宽度 |
| 首页横屏 | ✅ | `_buildLandscapeLayout` 左右分栏 |
| 词书网格 | ✅ | `resp.isDesktop` 时切换 GridView |
| Profile 横屏 | ✅ | `_buildProfileHeader` 横屏改为 Row 布局 |
| 词书描述 | ⚠️ | 硬编码问题在大屏更明显 |
| 底部工具栏 | ⚠️ | 6 项挤一行在平板上尚可但桌面可能过宽 |

---

## 修复优先级建议

| 优先级 | 任务 | 工作量 |
|--------|------|--------|
| 高 | UX-H1: 空态引导 Learn 卡片 | 小 |
| 高 | UX-H3: 词书描述硬编码修复 | 小 |
| 中 | UX-M5: 学习偏好菜单接入导航 | 小 |
| 中 | UX-M6: 装备卡片无交互修复 | 小 |
| 中 | UX-M7: 词书点击加载反馈 | 小 |
| 低 | UX-L1-L5: 一致性/文案/图标微调 | 小 |
