# Monster Word 按压反馈靶点清单（Pressable Inventory）

> 任务：【重构17】全库可交互元素盘点 —— 支撑 docs/motion_spec.md §4.4「按压统一 ScaleDownOnPress(scale 0.95)」的改造落点
> 方法：对 `lib/` 全量 .dart 做静态扫描 + 关键复用组件人工核读（只读分析，未改任何代码）
> 结论先行：**全库可交互构造位点 292 处，其中需补按压反馈的裸 GestureDetector 共 131 处**；已符合 4 处；自带系统水波纹保留 154 处；特殊语义保留 6 处（另计构造外既有包装用法 3 处）。

---

## 1. 扫描范围与判定标准

- **扫描对象**：`InkWell`、`GestureDetector`（仅取带 `onTap` 者）、`ElevatedButton`、`TextButton`、`OutlinedButton`、`IconButton`、`FloatingActionButton`、`PopupMenuButton`、`CupertinoButton`、`DropdownButton` 的构造位置（`.styleFrom` 等样式调用不计入）。
- **「当前按压反馈」判定**：
  - **系统 splash**：Material 按钮与 InkWell 默认水波纹；
  - **scale**：`ScaleDownOnPress` 或自实现缩放（如 Tab 弹跳）；
  - **无**：裸 `GestureDetector(onTap:)` 直接包内容，按下无任何视觉变化。
- **扫描脚本口径**：GestureDetector 向后探测 15 行内是否出现 `onTap`；纯拖拽/滑动类（onPan/onDrag）自动排除。
- 行号基于当前工作区快照，后续代码合入可能产生少量漂移，改造时以符号定位为准。

---

## 2. 总览统计

| 类别 | 数量 | 说明 |
| --- | ---: | --- |
| 可交互构造位点（总） | **292** | GestureDetector(带onTap) 138 + IconButton 83 + TextButton 32 + ElevatedButton 25 + OutlinedButton 10 + InkWell 4 |
| **需改造**（补按压反馈） | **131** | 全部为裸 GestureDetector+onTap，按下无任何视觉反馈 |
| 已符合 | 4 | ScaleDownOnPress 既有用法×2（check_in_widgets 53/133）、底栏 Tab 弹跳（main_shell 156）、自实现缩放（input_controls 277，待并入统一组件） |
| 系统反馈·保留 | 154 | Material 按钮 150 + InkWell 4，自带水波纹，符合克制原则 |
| 特殊语义·保留 | 6 | 遮罩/整屏手势/开关本体反馈等，见 §4.3 |
| 构造外既有包装用法 | 3 | 上列"已符合"中不在 292 口径内的 3 处 |

> **改造杠杆点**：131 处中有 **62 处位于通用组件库**——改组件内部即可让所有引用页面批量生效，实际页面级手工改动约 69 处。

---

## 3. 需改造靶点清单（131 处，按模块分组）

> 「当前按压反馈」除特别注明外均为**无**（裸 GestureDetector，无 splash 无 scale）；「建议处理」除特别注明外均为**包 ScaleDownOnPress**。

### 3.1 通用组件库（P0，62 处 —— 一处改动全局生效）

| 文件:行号 | 组件类型 | 当前按压反馈 | 建议处理 |
| --- | --- | --- | --- |
| widgets\adapter_widgets.dart:103 | GestureDetector（HTML 移植列表项） | 无 | 包 ScaleDownOnPress（建议改组件内部实现，调用方零改动） |
| widgets\adapter_widgets.dart:181 | GestureDetector（列表项） | 无 | 同上 |
| widgets\adapter_widgets.dart:188 | GestureDetector（列表项内嵌图标钮） | 无 | 包 ScaleDownOnPress（小目标，传 behavior: opaque） |
| widgets\adapter_widgets.dart:307 | GestureDetector | 无 | 包 ScaleDownOnPress |
| widgets\adapter_widgets.dart:375 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:442 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:501 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:566 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:581 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:666 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:679 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:803 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1072 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1092 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1128 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1135 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1216 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1234 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1599 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1750 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1900 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:1910 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:2063 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:2086 | GestureDetector | 无 | 同上 |
| widgets\adapter_widgets.dart:2125 | GestureDetector | 无 | 同上 |
| widgets\cell_widgets.dart:84 | SelectedCell | 无 | 包 ScaleDownOnPress（组件内部包裹） |
| widgets\cell_widgets.dart:142 | SelectCell2 | 无 | 同上 |
| widgets\cell_widgets.dart:206 | SubtitleCell | 无 | 同上 |
| widgets\cell_widgets.dart:265 | IconCell | 无 | 同上（小图标目标，opaque） |
| widgets\cell_widgets.dart:311 | PopFilterCell | 无 | 同上 |
| widgets\cell_widgets.dart:352 | UrlCell | 无 | 同上 |
| widgets\cell_widgets.dart:405 | UserBindItem | 无 | 同上 |
| widgets\helper_widgets.dart:218 | 筛选胶囊（选中切换） | 无 | 包 ScaleDownOnPress |
| widgets\helper_widgets.dart:267 | 信息卡片 | 无 | 同上 |
| widgets\helper_widgets.dart:411 | 「去学习」半区按钮 | 无 | 同上 |
| widgets\helper_widgets.dart:437 | 「去复习」半区按钮 | 无 | 同上 |
| widgets\helper_widgets.dart:489 | 可选中卡片 | 无 | 同上 |
| widgets\header_nav_widgets.dart:47 | AppBar 左侧按钮 | 无 | 包 ScaleDownOnPress（导航栏图标钮，opaque） |
| widgets\header_nav_widgets.dart:55 | AppBar 右侧按钮 | 无 | 同上 |
| widgets\header_nav_widgets.dart:73 | 双标题切换项 | 无 | 包 ScaleDownOnPress |
| widgets\header_nav_widgets.dart:135 | SegmentedSelector 分段项 | 无（选中色即反馈） | 二选一：保留纯色变或轻量包 scale（enableScale 视觉验收后定） |
| widgets\exam_phrase_widgets.dart:71 | 短语考试交互块 | 无 | 包 ScaleDownOnPress |
| widgets\exam_phrase_widgets.dart:127 | 同上 | 无 | 同上 |
| widgets\exam_phrase_widgets.dart:310 | 同上 | 无 | 同上 |
| widgets\card_widgets.dart:160 | 卡片点击区 | 无 | 包 ScaleDownOnPress |
| widgets\card_widgets.dart:260 | 卡片点击区 | 无 | 同上 |
| widgets\card_widgets.dart:356 | 卡片点击区（SpringCurve 入场的卡片） | 无 | 同上（入场弹性≠按压反馈） |
| widgets\badge_label_widgets.dart:76 | 圆形徽标按钮 | 无 | 包 ScaleDownOnPress（圆形小目标，opaque） |
| widgets\badge_label_widgets.dart:232 | 标签选择项 | 无（选中变色） | 轻量包 scale 或保留，视觉验收定 |
| widgets\glass_widgets.dart:88 | GlassEntryCard（学习/复习入口卡） | 无 | 包 ScaleDownOnPress |
| widgets\glass_widgets.dart:151 | GlassPill 胶囊钮 | 无 | 同上 |
| widgets\cell_list_widgets.dart:32 | 复选单元格 | 无（勾选态即反馈） | 包 ScaleDownOnPress（勾选动画保留，二者互补） |
| widgets\class_activity_banner.dart:14 | 活动横幅 | 无 | 包 ScaleDownOnPress（大卡片，幅度可 0.97 微调） |
| widgets\component_widgets.dart:349 | 圆形图片按钮 | 无 | 包 ScaleDownOnPress |
| widgets\custom_text_widgets.dart:211 | 图片点击查看大图 | 无 | 包 ScaleDownOnPress |
| widgets\input_widgets.dart:140 | 输入区交互块 | 无 | 包 ScaleDownOnPress |
| widgets\list_widgets.dart:89 | 分组列表展开头 | 无（箭头旋转有反馈） | 轻量包 scale 或保留（已有展开动效，倾向保留） |
| widgets\misc_widgets.dart:203 | 圆形图标按钮 | 无 | 包 ScaleDownOnPress |
| widgets\special_widgets.dart:120 | 分段选择项 | 无（选中色即反馈） | 同 SegmentedSelector，二选一 |
| widgets\widget_utils.dart:149 | 加载更多点击区 | 无 | 包 ScaleDownOnPress |
| widgets\word_lookup_popup.dart:69 | 弹层内词条操作 | 无 | 包 ScaleDownOnPress |
| widgets\word_lookup_popup.dart:124 | 弹层内词条操作 | 无 | 同上 |

### 3.2 学习 / 复习域页面（P1，24 处）

| 文件:行号 | 组件类型 | 当前按压反馈 | 建议处理 |
| --- | --- | --- | --- |
| pages\learn_page.dart:331 | 4 选项答题 tile | 无（答错标红 200ms 是结果反馈） | 包 ScaleDownOnPress；注意与 motion_spec §6 状态动画共存（先缩放后变色，时序不冲突） |
| pages\learn_page.dart:199 | 顶部工具入口 | 无 | 包 ScaleDownOnPress |
| pages\review_page.dart:198 / 204 | 复习选项对 | 无 | 包 ScaleDownOnPress（同答题选项规则） |
| pages\review_page.dart:250 | 复习交互块 | 无 | 同上 |
| pages\review_page.dart:307 | 复习交互块 | 无 | 同上 |
| pages\review_page.dart:416 | 复习底部操作 | 无 | 同上 |
| screens\learn_session.dart:108 / 322 / 402 / 595 | 会话页交互块 | 无 | 包 ScaleDownOnPress |
| screens\review_session.dart:183 / 264 | 会话页交互块 | 无 | 同上 |
| pages\sentence_quiz_page.dart:267 | 例句测验选项 | 无 | 包 ScaleDownOnPress |
| pages\exam_quick_review_page.dart:265 / 508 | 快速回顾选项 | 无 | 包 ScaleDownOnPress |
| pages\spell_check_page.dart:129 | 拼写检查交互 | 无 | 包 ScaleDownOnPress |
| pages\spell_session_page.dart:186 | 拼写会话交互 | 无 | 包 ScaleDownOnPress |
| pages\list_word_listen_page.dart:86 | 听音辨词项 | 无 | 包 ScaleDownOnPress |
| pages\word_machine_page.dart:528 / 619 | 单词机交互件 | 无 | 包 ScaleDownOnPress（机件自身 elastic 抖动是结果反馈，不冲突） |
| pages\lib_select_page.dart:138 / 292 / 420 | 词库选择卡 | 无 | 包 ScaleDownOnPress |

### 3.3 内容浏览域页面（P1，22 处）

| 文件:行号 | 组件类型 | 当前按压反馈 | 建议处理 |
| --- | --- | --- | --- |
| pages\dictionary_page.dart:140 / 489 | 词典页交互块 | 无 | 包 ScaleDownOnPress |
| pages\search_page.dart:133 / 147 / 229 / 327 | 搜索历史/联想项 | 无 | 包 ScaleDownOnPress |
| pages\books_page.dart:209 / 263 | 书籍卡 | 无 | 包 ScaleDownOnPress |
| pages\foot_mark_page.dart:138 | 足迹项 | 无 | 包 ScaleDownOnPress |
| pages\collins_detail_intro_page.dart:165 | 柯林斯详情交互 | 无 | 包 ScaleDownOnPress |
| pages\courses_page.dart:445 | 课程卡 | 无 | 包 ScaleDownOnPress |
| pages\extensive_model_select_page.dart:75 | 泛读模式卡 | 无 | 包 ScaleDownOnPress |
| pages\my_content_page.dart:339 | 我的内容项 | 无 | 包 ScaleDownOnPress |
| pages\my_fav_sentence_page.dart:130 / 188 | 句子收藏项 | 无 | 包 ScaleDownOnPress |
| pages\word_detail_page.dart:270 / 350 / 431 / 439 / 614 | 详情页功能块 | 无 | 包 ScaleDownOnPress |
| pages\class_checkin_page.dart:724 / 961 | 签到页交互块 | 无 | 包 ScaleDownOnPress |

### 3.4 个人 / 设置 / 其它页面（P2，18 处）

| 文件:行号 | 组件类型 | 当前按压反馈 | 建议处理 |
| --- | --- | --- | --- |
| pages\settings_page.dart:341 / 452 / 485 / 622 | 设置分组行 | 无 | 包 ScaleDownOnPress |
| pages\user_info_manage_page.dart:41 / 92 | 用户信息管理项 | 无 | 包 ScaleDownOnPress |
| pages\wallpaper_select_page.dart:252 / 288 / 337 | 壁纸选择卡 | 无（选中态有边框） | 包 ScaleDownOnPress（选中边框保留） |
| pages\ui_theme_select_page.dart:96 | 主题选择卡 | 无（同上） | 同上 |
| pages\appearance_page.dart:197 | 外观交互块 | 无 | 包 ScaleDownOnPress |
| pages\personal_stereo_page.dart:161 | 个人词库操作 | 无 | 包 ScaleDownOnPress |
| pages\play_order_page.dart:49 | 播放顺序项 | 无 | 包 ScaleDownOnPress |
| pages\my_space_page.dart:234 / 285 | 我的空间卡 | 无 | 包 ScaleDownOnPress |
| pages\login_page.dart:510 | 登录页辅助点击 | 无 | 包 ScaleDownOnPress |
| screens\home_screen.dart:110 | 单词机悬浮圆钮 | 无 | 包 ScaleDownOnPress（圆形悬浮钮，opaque） |
| screens\home_screen.dart:149 | 搜索悬浮圆钮 | 无 | 同上 |

### 3.5 锁屏模块（P2，5 处）

| 文件:行号 | 组件类型 | 当前按压反馈 | 建议处理 |
| --- | --- | --- | --- |
| lock\lock_screen_page.dart:447 / 480 / 598 / 687 | 锁屏交互件 | 无 | 包 ScaleDownOnPress（锁屏沉浸氛围，可用 enableScale=false 试点对比后再放开） |
| lock\lock_webview_cache.dart:110 | 缓存清理按钮 | 无 | 包 ScaleDownOnPress |

---

## 4. 保留与已符合清单

### 4.1 系统反馈·保留（154 处，不改）

Material 按钮与 InkWell 自带水波纹，符合星巴克克制原则；**不要**再外包 ScaleDownOnPress 造成双重反馈。如后续想给主 CTA 加缩放，应在**主题层**统一处理而非逐个包装。

- **IconButton ×83**：account_info 52；appearance 68；base_web 118,132；books 73；book_words 153；class_activity 83；class_checkin 58,70；collins_detail_intro 291；courses 74；dashboard 36,47；dictionary 86,105；exam_quick_review 226,359；extensive_model_select 133；foot_mark 96；help 102,110；immersive_swipe 181；learn 121,148,159；lib_select 80,97,105,118；linked_me_middle 105；list_words 106,132；list_word_listen 192；login 278,357；message 115；more_settings 178；my_content 112,123；my_equip 58；my_fav 137,178；my_fav_sentence 84；my_space 45,54,73；net_diagnosis 129；personal_stereo 89,125,137,143；play_order 94；review 180,189,193,209；search 208；sentence_detail 131,144；sentence_quiz 82,143；settings 64；sms 162；spell_check 275；spell_session 297；ui_theme 75；user_info_manage 79；user_item_modify 71；wallpaper_select 101；word_detail 127；learn_session 241,251,256,271,281,297；profile_screen 30；review_session 127,136,140,144；word_dictionary_popup 87
- **TextButton ×32**：exam_quick_review 667；list_words 120,127,183,187；list_word_listen 102；login 372；message 123；my_fav 83,84,162,169,173,261,265；my_fav_sentence 97,350,354；sms 117；spell_session 116,123；user_info_manage 123,124；user_item_modify 90,97；word_detail 89,90,496；helper_widgets 137；learn_widgets 192；special_widgets 355
- **ElevatedButton ×25**：base_web 88；class_activity 464；class_checkin 332,567；exam_quick_review 320,462,651；help 72；immersive_swipe 132；login 326,390,495；list_word_listen 161；my_fav 219；my_fav_sentence 310；net_diagnosis 99；search 282；sentence_quiz 394；sms 131；splash 274；spell_check 235；spell_session 266；component_widgets 52,88；review_dialog 142
- **OutlinedButton ×10**：class_checkin 364；exam_quick_review 448,633；list_word_listen 144；login 484；more_settings 144；spell_check 216；spell_session 246；component_widgets 65；review_dialog 123
- **InkWell ×4**：account_info 211,245；more_settings 233；profile_screen 190

### 4.2 已符合（4 处，不动）

| 文件:行号 | 反馈形式 | 备注 |
| --- | --- | --- |
| widgets\check_in_widgets.dart:53 | ScaleDownOnPress | 既有正确用法（升级 API 后无需改动，新参数可选） |
| widgets\check_in_widgets.dart:133 | ScaleDownOnPress | 同上 |
| shell\main_shell.dart:156 | 底栏 Tab 图标弹跳（ScaleTransition + SpringCurve 350ms） | 属仪式性反馈，保留；时长可收敛至 300ms（motion_spec §5） |
| widgets\input_controls.dart:277 | 自实现按压缩放（onTapDown/Up + AnimatedScale） | 功能已符合；建议并入统一组件（§5），删除第二套实现 |

### 4.3 特殊语义·不加缩放（6 处，明确排除）

| 文件:行号 | 场景 | 排除理由 |
| --- | --- | --- |
| widgets\input_controls.dart:89 | 开关本体点击 | 开关滑块动画本身就是状态反馈，叠加缩放过噪 |
| widgets\glass_widgets.dart:217 | 模态遮罩点击关闭 | 全屏遮罩不可缩放 |
| widgets\glass_widgets.dart:222 | 遮罩内容区 onTap:{} 阻断冒泡 | 非按钮 |
| widgets\word_dictionary_popup.dart:50 | 弹窗内容区阻断冒泡 | 非按钮 |
| widgets\image_widgets.dart:192 | 图片浏览器整屏点击关闭 | 全屏手势 |
| widgets\special_widgets.dart:314 | 引导蒙层整屏点击下一步 | 全屏手势（高亮框已有 elasticOut 脉冲） |

另：纯拖拽/滑动手势的 GestureDetector（lock_screen 339/643、scroll_top_bottom_layout 111、immersive_swipe 153、card_widgets 140、header_nav 字母条 184、misc_widgets 下拉 97、special_widgets 字母条 45、layout_widgets 滑动删除 83/170/245、word_lookup_popup 遮罩 29、widget_utils 76）不属于按压靶点，全部排除。

---

## 5. ScaleDownOnPress 通用包装组件推荐 API

现有实现：`lib/widgets/widget_utils.dart:12`，签名为 `{child, scale=0.95, duration=100ms, onTap}`，standardCurve 双向，回调在"松开且恢复完成后"触发（含 _hasGivenUp 取消语义）。推荐在其基础上做**增量演进**（存量 2 处用法零破坏）：

```dart
/// 统一按压缩放包装 —— 星巴克 --buttonActiveScale: 0.95（docs/motion_spec.md §4.4）
class ScaleDownOnPress extends StatefulWidget {
  const ScaleDownOnPress({
    super.key,
    required this.child,
    this.onTap,                            // null ⇒ 整体禁用：不响应、不缩放
    this.enableScale = true,               // 【新增】缩放开关：false ⇒ 退化为纯点击区域
                                           //   用于灰度对比、以及 §4.3 类场景的临时豁免
    this.enabled = true,                   // 【新增】语义禁用位：列表项禁用态用
                                           //   （enabled=false 且 onTap!=null 时也不响应）
    this.scale = MotionPress.scale,        // 0.95（沿用星巴克规范值）
    this.duration = MotionDurations.fast,  // 100ms → 150ms（收敛至 motion_spec fast 档）
    this.curve = MotionCurves.standard,    // standardCurve，双向同曲线
    this.behavior,                         // 【新增】透传 GestureDetector.behavior；
                                           //   小尺寸图标目标建议传 HitTestBehavior.opaque
    this.triggerAfterRestore = true,       // 【新增】true=维持现状（恢复后回调，防误触）；
                                           //   false=抬起立即回调（追求跟手时可开）
  });
  ...
}
```

设计要点：

1. **三个必用参数**：`child` / `onTap` / `enableScale`——满足任务要求的最低面；其余全部可选且有合理默认。
2. **禁用三态合一**：`onTap == null`、`enabled == false`、`enableScale == false` 各管一件事——响应性、语义禁用、视觉缩放，互不纠缠。
3. **回调时机不变**：默认保持"松开 → reverse 完成 → 回调"，这是 Android 版翻译过来的防误触语义；需要更跟手的场景显式传 `triggerAfterRestore: false`。
4. **默认时长变更需评审**：duration 默认 100ms → 150ms 是全局手感变化（更接近星巴克 0.2s ease 的感知），属预期内的规范收敛，建议在 P0 批次一起生效并真机验收。
5. **不做的事**：不内置涟漪（与 Material 按钮区分职责）、不内置长按（保持单一职责）、不自动判重（外层再包 Material 按钮会出现双重反馈，靠 §4.1 清单约束 code review）。

---

## 6. 落地批次建议

| 批次 | 范围 | 位点数 | 理由 |
| --- | --- | ---: | --- |
| **P0** | 通用组件库（§3.1）+ ScaleDownOnPress API 升级 + 默认时长收敛 | 62 | 一次组件级改动覆盖全部引用页；先立 Token 与组件 |
| **P1** | 学习/复习域（§3.2）+ 内容浏览域（§3.3） | 46 | 高频核心路径，用户感知最强；答题选项需与 motion_spec §6 联调 |
| **P2** | 个人/设置域（§3.4）+ 锁屏模块（§3.5） | 23 | 低频路径收尾；锁屏可先 enableScale=false 灰度 |

每批次的验收清单：
- [ ] 无双重反馈（未把 ScaleDownOnPress 叠在任何 Material 按钮/InkWell 外层）
- [ ] 禁用态（onTap:null / enabled:false）既不缩放也不响应
- [ ] 回调时机仍为"恢复后触发"（除非显式改参）
- [ ] 列表快速滑动误触时无残留缩放态（_hasGivenUp 语义回归）
