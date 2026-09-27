# 触控目标审计：最小命中区域合规排查

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 依据：WCAG 2.5.8（AA，最小 24×24 CSS px，或相邻目标间距 ≥24px 的豁免）、WCAG 2.5.5（AAA，44×44）、**Material 建议最小触控目标 48×48dp（本审计主判定线）**、Apple HIG 44×44pt
> 项目设计规范：DESIGN.md §Touch Targets（L500–504）：药丸按钮 ~32px 高不达标需扩展；Frap 悬浮按钮用 `--frapTouchOffset: calc(-1 * .8rem)` 将命中区外扩 **8px** 至视觉边界之外
> 审计日期：2026-08-24　|　约束：只读代码，仅新建本报告

---

## 一、审计方法与覆盖范围

1. 静态扫描全库 `GestureDetector / InkWell / IconButton / TextButton / ElevatedButton / FilledButton / FloatingActionButton / BottomNavigationBar` 等交互元素（约 60 个 dart 文件、150+ 实例）；
2. 对学习主流程（学习页/学习会话/复习会话/复习页/拼字/例句测验）、词书列表、底部导航、个人中心及全部共享组件逐文件读码测量；
3. 尺寸为逻辑像素（dp），由代码常量与 `fontSize × 行高` 推算；Flutter 中裸 `GestureDetector` 的命中区 = 子组件实际渲染边界（`deferToChild`），这是本项目小目标的主要成因；
4. 主题未显式配置 `materialTapTargetSize / visualDensity`（lib/theme 无相关设置），Material 按钮命中区存在平台差异（Android 默认 padded→48，iOS 默认 shrinkWrap→40），见第 5 节附注。

**判定口径**：主判定线 48×48dp；同时标注"≥44（过 Apple/WCAG AAA）"与"≥24（过 WCAG 2.5.8 AA 法定最低）"两级，避免一刀切误伤。

---

## 二、审计明细表

### A. 页面顶部导航栏 —— 系统性 44dp（14 处容器，约 35+ 按钮）

`AppSpacing.navH = 44`（design_tokens.dart:170）被用作页面顶栏高度，内部裸 IconButton 被 Row 的 44 高度约束压扁（IconButton 自身 min 48 无法生效）：

| 文件:行号 | 元素 | 当前视觉尺寸 | 当前命中区域 | 是否达标(48) | 建议 |
|---|---|---|---|---|---|
| learn_page.dart:117 | 顶栏 + 设置/统计等 3×IconButton | 图标 ~24 | ~48×**44** | ❌ 差 4dp | 改 token（见下） |
| learn_session.dart:237 | 顶栏 + 收藏/发音/设置等 **6×IconButton** | 图标 ~22-26 | ~48×**44** | ❌ | 同上 |
| review_session.dart:123 | 顶栏 + 4×IconButton | 图标 ~24 | ~48×**44** | ❌ | 同上 |
| review_page.dart:181 | 顶栏硬编码 height:44 + 4×IconButton + 2 个纯文字钮(见 B) | 图标 ~24 | ~48×**44** | ❌ | 同上 |
| word_detail_page.dart:120 | 顶栏返回 IconButton | 图标 ~24 | ~48×44 | ❌ | 同上 |
| profile_screen.dart:26 / appearance_page.dart:69 / account_info_page.dart:53 / dictionary_page.dart:78 / courses_page.dart:73 / class_checkin_page.dart:58 / class_activity_page.dart:81 / more_settings_page.dart:172 / sentence_quiz_page.dart:137 | 同模式顶栏 | 图标 ~24 | ~48×44 | ❌ | 同上 |

**修复建议（一处改动全局生效）**：将 `AppSpacing.navH` 从 **44 提到 48**。正面参照已在库内验证可行：lib_select_page.dart:74、my_space_page.dart:44、spell_session_page.dart:297 均为 48 高顶栏，按钮即满血 48×48 ✅。

### B. 严重过小的自定义点击目标（<40dp，共 8 组）

| 文件:行号 | 元素 | 当前视觉尺寸 | 当前命中区域 | 是否达标(48) | 建议 |
|---|---|---|---|---|---|
| review_page.dart:204-213 | 顶栏 'abc'/'熟' 纯文字切换钮 | 文字 ~16×16 | **~30×20** | ❌❌ 仅过 2.5.8 AA | 外包 `padding: EdgeInsets.all(12)` + HitTestBehavior.opaque，扩到 ≥40×44 |
| review_page.dart:315-346 | 底部主 CTA「看答案/继续」 | 文字18+下划线3 | **~70×34** | ❌❌ 核心操作！ | 参照 Frap 思路外包 v12 padding → ≥58 高；或改用高 52 的实心药丸按钮 |
| learn_session.dart:396-440 | 底部主 CTA「下一词」（同款模式） | 文字18+下划线3 | ~80×34 | ❌❌ | 同上 |
| learn_page.dart:199-208 | 单词发音按钮 GestureDetector(Icon 28) | 28×28 | **28×28** | ❌❌ | 与单词文本热区间距仅 12，易误触查词；外包 8px padding 扩至 ≥44，并保持与文本 ≥16 间距 |
| word_detail_page.dart:354-363 | 详情页发音按钮 Icon 28 | 28×28 | 28×28 | ❌❌ | 同上 |
| books_page.dart:263-278 | **底部导航项 _HomeIcon**（图标26+标签10） | 内容列 ~30×42 | **~30×42** | ❌❌ 主导航！ | GestureDetector 仅包内容列；应包满父格（行为 opaque + 全尺寸 SizedBox），参照 main_shell 标签做法 |
| learn_session.dart:595-618 | 「查看详细解析」文字链接 | 字12+icon12 | ~110×20 | ❌ | 外包 v10/h8 padding → ≥36×~126，并保证上方间距 |
| word_detail_page.dart:274-292 | 「添加笔记」pill（padding v6 + micro 字） | ~100×28 | ~100×28 | ❌ | padding 提至 v10 → ≥36；或加 minWidth 48 |

### C. 中等不足 / 贴线（40–47dp 或间距问题）

| 文件:行号 | 元素 | 当前视觉尺寸 | 当前命中区域 | 是否达标(48) | 建议 |
|---|---|---|---|---|---|
| lib_select_page.dart:130-160 | 词书分类选项卡 ×9 | 视觉胶囊 ~17px 行高 | **~宽60-90×高28**（SizedBox 40 − ListView v-padding 12） | ❌❌ 且横向间距仅 8 | 高度提为 ≥44（SizedBox 56 − padding 6）；间距 ≥12 |
| learn_session.dart:308-364 | SegmentTabs 学习阶段切换 ×5 | 高 36 | 宽≈屏/5 × **36** | ❌ 高差 12 | 容器高度提至 48 |
| header_nav_widgets.dart:104-161 | SegmentedSelector 分段选择器 | 段内 padding v8 | 段高 **~35** | ❌ | v8→v14，段高 ≥44 |
| lib_select_page.dart:406-441 | _BottomToolItem 听写/例句等 ×5 | 列内容 ~46×57 | ~46×57 | ⚠️ 宽贴线 46<48 | h-padding 12→14，宽度 ≥48 |
| component_widgets.dart:27 | CustomButton 默认 height=44 | 44×full | 44×full | ⚠️ 默认值隐患 | 默认改 52；**当前全库无调用点**，属死代码，建议随重构统一后启用 |
| header_nav_widgets.dart:184+ | AlphabetSlideBar 字母索引条 | 字母行 ~15 | 整条连续拖拽区 | ➖ 特殊控件 | 拖拽定位型控件（非逐字点按），可接受；建议保留整条可拖拽交互不变 |

### D. 达标确认（无需改动）

| 文件:行号 | 元素 | 命中区域 | 结论 |
|---|---|---|---|
| shell/main_shell.dart:164 | 主底栏自定义标签 ×5 | Expanded 全格宽(~78) × tabBarHeight **56/64**(design_tokens AppTabBar) | ✅✅ 教科书级 |
| pages/books_page.dart:209 | 词书列表行 _LearnReviewBand 等 | 全宽 × **70** | ✅ |
| pages/lib_select_page.dart:209 | 词书列表行 _LibItem | 全宽 × **120** | ✅ |
| screens/profile_screen.dart:195 等全部菜单页 | 菜单行 InkWell | 全宽 × rowH **52**(design_tokens:169) | ✅ |
| learn_page.dart:331-353 / review_session.dart:183-217 / sentence_quiz_page.dart:270-318 / review_page.dart:427-450 | 四选一答题选项 | 全宽 × **54-58** | ✅ 尺寸达标（间距见第三节） |
| spell_session_page.dart | 播放按钮 80×80；跳过/检查 ~48 高 gap16；导航栏 48 | ✅ 全库最佳实践 | ✅ |
| login_page.dart AppBar/suffixIcon、sentence_quiz AppBar(:84) | 标准 Material 槽位 | kToolbarHeight 56 / 输入框后缀默认 48 | ✅ |
| widgets/word_lookup_popup.dart:129 | 查词弹窗卡片 | 280 宽卡片整体可点；触发方式为长按 | ✅ |

---

## 三、专项分析：学习页答题选项误触风险（任务重点）

现状实测：

| 页面 | 选项高度 | 垂直间距(gap) | 水平热区 |
|---|---|---|---|
| learn_page.dart:331-353 | 56 ✅ | **8** ← 最紧 | 全宽 ✅ |
| sentence_quiz_page.dart:270-318 | 56 ✅ | 10 | 全宽 ✅ |
| review_session.dart:183-217 | 54 ✅ | 12 | 全宽 ✅ |
| review_page.dart:431 (_FrostedChoiceCard) | 58 ✅ | 10 | 全宽 ✅ |
| review_session.dart:262-278 SRS 三键 认识/模糊/忘记 | 48 ✅ | **水平方向 0（Expanded 直接相邻）** | 各 ≈屏宽1/3 |

结论与建议（套用 DESIGN.md Frap「视觉不变、命中外扩 8px」的思路）：

1. **四选一选项垂直间距**：选项本身已是全宽大目标，问题不在命中面积而在边缘误触。手指触点误差约 ±5-7mm，gap=8 时落在两选项之间空档的概率窗口过窄。建议统一提升到 **16dp**（learn_page 的 8 优先改）；若想视觉更紧凑，可用 Frap 式做法——保持视觉 margin 8，把 GestureDetector 的命中区向内收缩（padding 反向）而非外扩，让"空白带"真正属于谁都不选。
2. **SRS 三键零水平间距是全库最高误触风险**：「认识」「模糊」「忘记」语义相反且后果不对称——误触「忘记」会直接重置记忆进度，代价最大。三个 48 高的热区边贴边共享边界，快速点击时极易滑偏。建议：
   - 三键之间插入 **SizedBox(width: 12)** 间隔带（三键各宽仍 >100，远超 48 下限）；
   - 或按 Frap 外扩思路反向应用：视觉卡片不动，在 Container 外层加 horizontal margin 使命中区彼此脱开；
   - 配合触觉反馈（HapticFeedback.selectionClick）降低"点了没反应再乱点"的二次误触。
3. **learn_page 发音钮 vs 单词查词热区**：两者水平间距仅 12。好在查词弹窗（WordLookupPopup）是长按触发，单击冲突有限，但发音钮 28×28 本身太小，按 B 表建议外扩后此风险自然缓解。

---

## 四、结论：违规总数与修复优先级

**违规统计**（以 48×48dp 为判定线；括号内为同时满足 WCAG 2.5.8 AA≥24 的数量）：

- A 类·顶栏系统性 44dp：**14 个页面 / 约 35+ 按钮实例**（根因集中在一个 token，修复成本极低）
- B 类·严重过小 <40dp：**8 组**
- C 类·中等不足/贴线：**5 组**
- 合计不合规实例约 **48 处**；其中 43 组 ≥44（已过 Apple HIG 与 WCAG AAA 线），全部 ≥24（无 WCAG 2.5.8 AA 硬性违规——即当前状态合法但不达项目自定的 Material 48 基线）。唯二低于 40 的重灾区是 review_page 顶栏小按钮与两个文字型主 CTA。

**修复优先级**：

| 级别 | 事项 | 理由 | 成本 |
|---|---|---|---|
| **P0** | ① review_session SRS 三键加 12dp 间隔 ② 「看答案/下一词」CTA 扩至 ≥52 高 ③ books_page _HomeIcon 命中区包满父格 ④ learn_page 发音钮外扩至 ≥44 | 学习核心路径；误触后果不对称且不可逆 | 均为单文件局部改动 |
| **P1** | ⑤ `AppSpacing.navH` 44→48（一次修复 13 页）⑥ review_page.dart:181 硬编码 44 同步改 ⑦ lib_select 分类卡高 28→44 | 一处 token 改动全局收益最大 | 极低 |
| **P2** | ⑧ SegmentTabs/SegmentedSelector 高度 ⑨ 「添加笔记」「查看解析」pill ⑩ _BottomToolItem 宽度 ⑪ theme 显式声明 materialTapTargetSize.padded（消除 iOS 上 M3 按钮 40 的平台差异） | 低频页面收尾 | 低 |
| 备注 | CustomButton 默认 44 属死代码，重构启用前先把默认值改 52 | 防患于未然 | 一行 |

**一句话总结**：库内没有 WCAG 2.5.8 AA 层面的硬违规，但距离 Material 48dp 基线还有约 48 处差距；其中约七成可以靠「navH token 44→48」一个改动消掉，剩下需要重点投入的是 SRS 三键间距、两个文字型主 CTA 和底部导航命中区这四个 P0 点。

---

*本报告基于静态代码审读（2026-08-24 主干），所有行号以当日代码为准；尺寸推算方法见第一节。*
