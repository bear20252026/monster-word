# 【重构8】图标体系规划：现状盘点与星巴克风格映射

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 依据：项目根 `DESIGN.md`（星巴克视觉规范）+ 对 `lib/` 全量代码盘点（只读分析）
> 结论先行：**全站统一采用内置 Material Icons 的 Outlined 家族作为基线**，关键激活态切换 Filled；不新增任何图标资产依赖（现有 9 个自定义 SVG 全部为死资产，建议清理）；底部导航激活色从 `#1F1F1F` 切换到星巴克绿 `#00754A`。

---

## 一、现状盘点

### 1.1 Material Icons 使用分布

全 `lib/` 共 **388 处 `Icons.*` 调用**，分布在 **69 / 184 个 dart 文件**中。使用最集中的文件：

| 文件 | 调用数 | 主要用途 |
|---|---|---|
| `lib/widgets/adapter_widgets.dart` | 23 | 列表项通用适配器（勾选、书籍、音频、星级、展开箭头等） |
| `lib/pages/class_checkin_page.dart` | 19 | 班级签到 |
| `lib/pages/my_space_page.dart` | 16 | 我的空间宫格入口 |
| `lib/screens/profile_screen.dart` | 14 | 「设置」tab 主页（菜单行图标） |
| `lib/pages/login_page.dart` | 14 | 登录表单 |
| `lib/pages/class_activity_page.dart` | 14 | 班级活动 |
| 其余 63 个文件 | 合计 ~288 | 各页面零散使用 |

### 1.2 底部导航（main.dart → MainShell）

当前 **3 个 tab**，图标由 `main.dart` 以 `TabDef(icon: …)` 传入：

| Tab | id | 当前图标 | 目标页面 |
|---|---|---|---|
| 学习 | `learn` | `Icons.auto_stories_outlined` | HomeScreen |
| 课程 | `course` | `Icons.school_outlined` | LibSelectPage（词书库） |
| 设置 | `settings` | `Icons.settings_outlined` | ProfileScreen |

渲染层（`main_shell.dart`）现状：

- 选中色 `Color(0xFF1F1F1F)`（墨黑）、未选中 `Color(0xFF999999)`（灰）——**与星巴克规范的绿激活色不符，需替换**；
- 图标尺寸走令牌：`AppTabBar.iconSize = 26`（平板 30），经 `resp.tabIconSize` 注入；
- 栏体：白色 60% 透明背景 + 顶部 hairline 描边，无激活态动画过渡。

### 1.3 自定义图标资产（assets/icons/）——全部为零引用死资产

共 9 个 SVG，**在整个 `lib/` 中没有任何一处引用**（无 `.svg` 加载代码，也未接入 `flutter_svg`）：

| 文件 | 网格 | 推测原用途 |
|---|---|---|
| `icons_home_classroom.svg` | 48×48 | 首页·课堂入口 |
| `icons_home_collect.svg` | 48×48 | 首页·收藏入口 |
| `icons_home_dashboard.svg` | 48×48 | 首页·统计入口 |
| `icons_home_listen.svg` | 48×48 | 首页·听力入口 |
| `icons_toolbar_learn_meaning.svg` | 48×48 | 学习工具栏·词义 |
| `icons_toolbar_learn_spell.svg` | 48×48 | 学习工具栏·拼写 |
| `icons_toolbar_learn_trash.svg` | 48×48 | 学习工具栏·删除 |
| `ic_arrow_long_left.svg` | 24×24 | 长返回箭头 |
| `ic_more_h.svg` | 24×24 | 横向更多 |

风格特征：单色 `fill="#000000"` **填充式**图形、几何简洁、大圆角转折。⚠️ 该风格与本项目实际采用的 Material **Outlined 线性**基调并不一致（填充 vs 描边），即使启用也会造成双轨风格。

**处置建议**：删除该目录（或在 pubspec 移除声明后归档）。重构期间以内置 Material 图标为准，避免新增资产依赖。

### 1.4 风格一致性问题（同义不同型）

同一语义在不同页面混用了 Filled / Outlined / Rounded 三种家族，是最需要收敛的问题：

| 语义 | 现状混用 | 出现位置举例 |
|---|---|---|
| 发音朗读 | `volume_up` / `volume_up_outlined` | adapter_widgets、learn_page、review_page、word_detail、spell_check |
| 书本 | `menu_book` / `menu_book_rounded` / `book` / `book_outlined` / `auto_stories(_outlined)` | profile_screen、adapter_widgets、home_screen |
| 编辑 | `edit` / `edit_outlined` / `edit_note` | profile_screen、word_detail |
| 删除 | `delete` / `delete_outline` | my_fav_page、word_detail |
| 个人 | `person`（filled） | books_page（应为 outlined 基线） |
| 答题错误反馈 | `error`（红色感叹，语气过重） | spell_check_page（宜改 `cancel_outlined`） |

成对状态图标（`star`/`star_border`、`favorite`/`favorite_border`、`check_circle_outline`→`check_circle`）属于**有意的状态切换，予以保留**并固化为规则。

---

## 二、星巴克图标风格定义（结合 DESIGN.md 推断）

DESIGN.md 未设独立 Iconography 章节，以下风格定义由其色彩、组件与交互条款推断归纳：

1. **线条基调：细线几何（Outlined 线性风）**
   - 默认态使用 Material **Outlined** 变体，笔画观感对应 1.5–2px @24px 网格；几何、简洁、去装饰，与星巴克官网的极简线性小图标一致。
   - **激活/选中态切换 Filled** 变体（实心），配合绿色，形成"点亮"隐喻。
   - Rounded 家族仅允许出现在插画化的大图标场景，普通 UI 禁止与 Outlined 混排（现状 `menu_book_rounded` 属违规项）。

2. **双色系统：绿-on-奶油 与 白-on-绿**
   - 常规界面（奶油底）：图标前景用墨黑 `#1F1F1F` / 星巴克 Text Black Soft `rgba(0,0,0,0.58)`；强调与激活态统一用 **Green Accent `#00754A`**。
   - 品牌绿容器上（House Green `#1E3932` 带，如头部横幅、Frap 浮动按钮）：图标一律 **纯白 `#FFFFFF`**。
   - 奖励/星级场景点缀金 `#CBA258`（对应 DESIGN.md 的 200★ Rewards Pill）。

3. **形状语言：圆与环**
   - 可点击图标按钮倾向圆形热区（DESIGN.md：32×32 圆形按钮、50% 圆角用于图标）；选中态用 **`2px solid #00754A` 绿色圆环**包裹（尺寸选择器的 cup-icon 即此范式）。
   - 主行动浮动按钮（Frap 范式）：56px 圆、`#00754A` 填充、居中白色图标 24px、双层阴影 `0 0 6px rgba(0,0,0,.24)` + `0 8px 12px rgba(0,0,0,.14)`。

4. **动效**
   - 遵循规范中的 `--iconTransition: all ease-out 0.2s`：图标颜色/缩放变化统一 200ms ease-out；按压反馈可叠加 `scale(0.95)`。

5. **语义色例外**
   - 成功/危险/警告仍用语义色（现 tokens：success `#4CAF50`、danger `#E3303B`、warning `#F59E0B`）；其中成功色可在后续配色重构中对齐为星巴克绿 `#00754A`，属本次图标工作之外的可选项。

---

## 三、图标映射表

原则：**优先内置 Material Icons，Outlined 为基线，激活切 Filled；不引入新资产依赖。**
图例：`默认态 → 激活态`；「保持」= 现状已合理。

### 3.1 全局导航

| 入口 | 现状 | 建议（默认 → 激活） | 备注 |
|---|---|---|---|
| 学习 tab | `auto_stories_outlined`（单态） | `auto_stories_outlined → auto_stories` | 翻开的书，语义贴切；补激活态 |
| 课程/词书 tab | `school_outlined`（单态） | `menu_book_outlined → menu_book` | 词书库语义；`school` 让位给未来的班级/课堂域 |
| 设置 tab | `settings_outlined`（单态） | `settings_outlined → settings` | 补激活态 |
| 我的/个人 | `person`（books_page 内 filled） | `person_outline → person` | 统一 outlined 基线 |

### 3.2 功能动作

| 动作/入口 | 现状（散点） | 建议 | 备注 |
|---|---|---|---|
| 发音朗读 | `volume_up(_outlined)` 混用 | `volume_up_outlined` 统一 | 播放中可切 `volume_up`(filled)+绿 |
| 收藏 | `favorite_border`/`favorite` | 保持成对 | 已符合"outlined→filled"规则 |
| 重点星标 | `star_border`/`star` | 保持成对 | 奖励语境可染金 `#CBA258` |
| 复习 | 散见 `autorenew`、`undo` | 入口 `replay_outlined → replay` | 会话内撤销仍用 `undo`（保持） |
| 统计/仪表盘 | `dashboard_outlined`（books_page） | `insights_outlined → insights` | 趋势洞察语义；`dashboard` 弃用于此场景 |
| 听写/拼写 | 无独立图标（页面内 `spell` 流程） | `spellcheck_outlined → spellcheck` | 听写练习入口 |
| 听力/泛听 | `headphones`（仅 filled） | `headphones_outlined → headphones` | 补 outlined 默认态 |
| 笔记 | `edit_note` | 保持 `edit_note` | 自身即线性风；列表入口可用 `notes_outlined` |
| 生词/加词本 | `add`、`playlist_add` 类散用 | `playlist_add_outlined → playlist_add` | "加入清单"隐喻 |
| 已掌握 | `check_circle(_outline)` | `task_alt_outlined → task_alt` | 区别于通用"完成"，专指掌握 |
| 未学习 | `radio_button_unchecked` | 保持 | 空心圆语义准确 |
| 答题正确/错误 | `check_circle_outline` / `error` | 正确 `check_circle_outline → check_circle`；错误 `cancel_outlined`（染 danger 红） | `error` 保留给系统异常，不用于答题 |
| 删除 | `delete` / `delete_outline` | `delete_outlined` 统一 | 危险操作染 `danger #E3303B` |
| 编辑 | `edit(_outlined)` | 行内编辑 `edit_outlined`；笔记编辑 `edit_note` | 二者分工固定 |
| 分享 | `share` | `ios_share` | 现代 iOS 风；保守方案可维持 `share` |
| 更多 | `more_horiz`（个别 `more_vert`） | `more_horiz` 统一 | 禁止方向混用 |
| 返回 | `arrow_back_ios_new` | 保持 | 已全局一致 |
| 打卡/日程 | `event_available` | 保持 | class_checkin 域 |
| 视频课程 | `video_library_outlined` | `play_circle_outline` | 播放隐喻更直接 |
| 外观主题 | `palette_outlined` | 保持 | profile_screen |
| 邮件/消息 | `mail_outline` | 保持 | 登录/message 域 |
| 金币/奖励 | `monetization_on` | `stars_outlined → stars`（染金 `#CBA258`） | 呼应星巴克 ★ Rewards；保守可用 `paid_outlined` |
| 搜索 | `search` | 保持 | 无 outline 变体收益 |

### 3.3 学习会话内工具动词（learn_session / review_session / word_detail）

| 动作 | 建议 | 备注 |
|---|---|---|
| 认识/点赞 | `thumb_up_alt_outlined → thumb_up_alt` | 保持现有选择 |
| 撤销 | `undo` | 保持 |
| 通过 | `check_circle_outline → check_circle` | 染 success |
| 单词详情发音 | `volume_up_outlined` | 见 3.2 |
| 详情编辑/删词 | `edit_outlined` / `delete_outlined` | 见 3.2 |

---

## 四、尺寸与颜色规范

### 4.1 尺寸阶梯（延续现有令牌体系 `lib/tokens/design_tokens.dart`）

| 场景 | 尺寸 | 令牌建议 |
|---|---|---|
| 底部导航图标 | 26（手机）/ 30（平板） | `AppTabBar.iconSize`（保持不变） |
| AppBar 返回/动作 | 24 | 新增 `IconSizes.appBar = 24` |
| 列表/卡片行内 | 20–22 | 新增 `IconSizes.inline = 20`、`IconSizes.listItem = 22` |
| 会话内大操作键 | 28–32 | 新增 `IconSizes.action = 28` |
| 浮动主行动钮内图标 | 24（56px 圆钮内居中） | Frap 范式 |
| 触控热区 | ≥ 44×44（IconButton 默认 48） | 所有可点图标强制 |

> 建议将上述值沉淀进 `design_tokens.dart` 的 `IconSizes` 类，替代散落的魔法数字（现状如 `component_widgets.dart` 默认 `iconSize: 16` 可保留为紧凑行场景特例）。

### 4.2 颜色规范

| 场景 | 颜色 | 来源 |
|---|---|---|
| **导航激活态**（亮色） | `#00754A`（Green Accent） | DESIGN.md / 任务要求 |
| **导航非激活态**（亮色） | `rgba(0,0,0,0.58)`（Text Black Soft） | 任务要求 |
| 导航非激活态（暗色） | `rgba(255,255,255,0.58)` | 对称推导（待设计确认） |
| 导航激活态（暗色） | 建议 `#00A862` 提亮保证对比度，保守可沿用 `#00754A` | 建议 |
| 页面主图标 | `#1F1F1F`（ink） | 现有 token |
| 页面次级图标 | `#8A8A8A`（stone）或 `rgba(0,0,0,0.58)` | 现有 token |
| House Green 容器上 | `#FFFFFF` | DESIGN.md「Icon: #ffffff」 |
| 奖励/星级点缀 | `#CBA258`（gold） | DESIGN.md Rewards Pill |
| 危险操作 | `#E3303B`（danger） | 现有 token |
| 成功反馈 | `#4CAF50`（success；后续可对齐 `#00754A`） | 现有 token |
| 尺寸选择器选中环 | `2px solid #00754A` 圆环 | DESIGN.md cup-icon 范式 |

### 4.3 动效

- 图标颜色/透明度/缩放过渡统一 **200ms ease-out**（对应 `--iconTransition`）；
- 底部导航切换建议增加选中态 `scale` 微弹（0.95→1.0），按压反馈 `scale(0.95)`。

---

## 五、实施注意事项（给后续重构任务）

1. **清理死资产**：删除 `assets/icons/` 下 9 个零引用 SVG；同步核查 `pubspec.yaml` 的 assets 声明。
2. **不加依赖**：全程使用内置 Material Icons，不引入 `flutter_svg`。
3. **收敛顺序**：先修"同义不同型"（volume/edit/delete/book/person 五组），再切换导航配色，最后补激活态成对图标。
4. **成对状态规则固化**：默认 `*_outlined`，选中/激活切 filled 同名图标；禁止 Rounded 家族进入常规 UI。
5. **落点文件预估**：`main_shell.dart`（配色+激活态）、`design_tokens.dart`（新增 `IconSizes` 与绿色令牌）、`adapter_widgets.dart`、`profile_screen.dart`、各核心 pages（按 3.2 表逐项替换）。
6. **风险提示**：`class_*` 系列（班级域）图标密度高但多为本域语义，本轮只统一风格不改动语义映射；`login_page` 表单图标同理低优先级。

---
*产出：IconPlanner · 2026-08-24 · 基于 lib/ 只读盘点（388 处图标调用 / 69 文件 / 9 个死资产 SVG）*
