# 星巴克重构 · 迁移总体规划（精简版 v1）

> 任务：【星巴克重构1】· 2026-08-24 · 只读分析产出，未改任何 .dart 文件。
> 详细依据：`docs/font_strategy.md`（字体）、`docs/motion_spec.md`（动效）、`docs/dark_skin_strategy.md`（深色/壁纸/皮肤）、`docs/a11y_contrast_report.md`(对比度实测)。后续增补：组件级细节、逐页完整清单。

---

## 一、Token 映射速查表

**颜色**（现值均已在代码中核实；新值依据根目录 `DESIGN.md`）

| 现有 token（位置） | 现值 | → 星巴克新值 | 用途说明 |
|---|---|---|---|
| `AppColors.primary` design_tokens.dart:7 | `#E8913A` 橙 | **`#00754A`** House Green | 全局主强调/CTA |
| `AppColors.primaryDeep`:8 / `primaryDark`:14 | `#CC7A2E` / `#F4A100` | **`#006241`** Starbucks Green | 深绿：按下态、描边、标题 |
| `AppColors.charcoal`:32 | `#212532` 蓝灰 | **`#1E3932`** 墨绿 | 深色底/沉浸区/锁屏底 |
| （新增中间层） | — | **`#2b5148`** | 深色模式卡片面、墨绿上的分层 |
| `AppColors.cream`:23 / `creamDeeper`:25 | `#F5F5F5` / `#E8E8E8` | **`#f2f0eb`** / **`#edebe9`** | 奶油画布 / 二级画布 |
| `AppColors.canvas`:40 | `#FFFFFF` | `#FFFFFF` 保留 | 卡片面（压在奶油上，禁做整页画布） |
| `AppColors.sunshine300–900`:15–20 | `#FFD06A…#F4A100` 金家族 | **`#CBA258`** 单一金 | ⚠️ 仅成就场景（见风险4） |
| `AppColors.ink`:29 / `stone`/`muted`:34–35 | `#1F1F1F` / `#8A8A8A`/`#A8A8A8` | `rgba(0,0,0,0.87)` / `rgba(0,0,0,0.58)` | 主/次文字（α红线≥0.55，见 a11y 报告§2） |
| `AppColors.success`:44 | `#4CAF50` | `#00754A`（答题正确可加 10% 透明底） | 成功=主绿，不再另立绿 |
| `AppColors.danger`:46 | `#E3303B` | 保留 | 功能红（答错/删除），不入品牌层 |
| `AppColors.link`:49 | `#4A90E2` 蓝 | `#006241` | 链接/信息类改深绿 |
| `ThemeVars.accent` skin_system.dart:107(bright):129(dark):154(pure_black) | 橙/金/蓝 | bright→`#00754A`；dark/pure_black 见风险1 | 三套皮肤的强调色源 |
| `hairline`:38 / `divider`(skin) | `#E5E5E5` | `rgba(0,0,0,0.08)` on 奶油 | 分隔线 |
| 微信品牌绿 login_page.dart:198、account_info_page.dart:175 | `#07C160` | **保留原样** | 仅限微信 logo/按钮，属第三方品牌色 |

> ThemeAnalyst 的 `docs/starbucks_tokens_draft.md` 截至本文未落盘；上表可直接作为其输入。

**圆角 / 间距 / 字号**（design_tokens.dart:214 `AppRadius` 起）

| token | 现值 | → 新值 |
|---|---|---|
| `AppRadius.card` | 16 | **12**（卡片统一，DESIGN.md 规格） |
| `AppRadius.control`/`radiusNormal`:180 | 8 | 8 保留（输入框/小控件） |
| `AppRadius.sheet` | 24 | 24 保留（底部弹层顶部） |
| `AppRadius.pill` | 9999 | 9999（按钮胶囊化的关键） |
| `AppleRadius.lg`:57 | 12 | 12 与新卡片对齐 |
| `AppDimens.bottomBarHeight`:181 / `AppTabBar.height`:193 | 56 | 56 保留 |
| `AppDimens.pageCommonMargin`:183 | 16 | 16 保留（奶油风靠留白不靠边距加大） |
| `AppTypography.*`:154 | Inter 全套 | 字体不变，颜色换 §一；heroWord 38–40px/w700 保留 |

## 二、字体决策（一句话）

**维持 Inter 不换**——项目已在 pubspec.yaml 捆绑 Inter 400/500/600/700，与 SoDoSans 同属 Helvetica 血统人文无衬线、形似度最高且零迁移成本；仅需补中文 fallback 链与 -0.01em 字距、可选新增 Lora 作成就衬线。详见 `docs/font_strategy.md`（结论速览表）。

## 三、组件改造要点

1. **按钮**：全部主操作钮高 **50px、全胶囊**（`AppRadius.pill`）、填充 `#00754A` 白字（对比度 5.76:1 AA 达标，a11y 报告§3）；按压 **scale(0.95)** —— `lib/widgets/widget_utils.dart` 已有 `ScaleDownOnPress`(scale 0.95/100ms) 直接复用，曲线按 `docs/motion_spec.md` §2 用 `Curves.ease`。改造点：`lib/widgets/component_widgets.dart`（AppButton 统一入口，filled 白字在 :46）+ 各页散落的 FilledButton/ElevatedButton（login_page.dart:333,408 等）。
2. **卡片**：圆角 12 + **双层低透明阴影**（`0 1px 2px rgba(27,27,27,.06)` + `0 6px 16px rgba(27,27,27,.07)`）；玻璃拟态退役——`AppGlass.blur` 已=0（design_tokens.dart:229），`GlassEntryCard`(glass_widgets.dart) 改实心白卡+双层影。
3. **56px 悬浮圆形 CTA（Frap 式）**：对应**学习 Tab 主页的「开始学习」主按钮**（home_screen.dart hero 区）与 books_page 的 Learn/Review 双带；建议停靠内容右下、底栏上方 16px，填充 `#00754A`、白色图标、双层影。
4. **进度条/开关/复选**：轨道奶油画布、进度 `#006241`；开关激活色集中改一处常量 `kSwitchActiveColor`(input_controls.dart:12) 即可全局生效。

## 四、页面改造优先级 Top10

| # | 页面（路径） | 关键改造点 |
|---|---|---|
| 1 | `lib/shell/main_shell.dart` 底栏 | :138-139 选中/未选中色→`#006241`/`rgba(0,0,0,0.58)`；:149-156 白玻璃→奶油实心+顶部发丝线；Tab 弹跳动效保留 |
| 2 | `lib/screens/home_screen.dart` 学习主页 | 橙色渐变 hero→奶油+墨绿字；「开始学习」→56px 悬浮圆 CTA；:59,190,201-207 白色半透明描边/装饰在奶油上需重调 |
| 3 | `lib/pages/review_page.dart` 复习 | :104-162 全屏壁纸+scrim→奶油画布（见风险3）；:395 `_FrostedChoiceCard` 磨砂→白卡12px双层影；正确/错误色走 `quizCorrect/Wrong` 语义令牌 |
| 4 | `lib/pages/learn_page.dart` 学习入口 | 答对 Bounce/答错 Shake 动效保留；选项卡同复习页规格；背景壁纸→画布 |
| 5 | `lib/screens/learn_session.dart`(+review_session) | 单词大字区 Charter 衬线保留；:723 硬编码橙→`#00754A`；底部操作条 50px 胶囊化 |
| 6 | `lib/pages/books_page.dart` 词书主页 | 彩色满屏底+白覆盖层组件整体重设计为奶油+白卡；打卡带金饰收敛为 `#CBA258` |
| 7 | `lib/pages/dashboard_page.dart` 数据 | 统计卡 12px+双层影；数字用 Inter tabular figures；图表色入绿系 |
| 8 | `lib/pages/my_space_page.dart` 个人空间 | sunshine 金渐变头部→奶油+墨绿；金只留 VIP/徽章/酷币等成就元素 |
| 9 | `lib/pages/settings_page.dart` + `appearance_page.dart` | 开关/选中色 :217,:223,:259 的 `#FF6800/#E8913A`→绿；皮肤选择器改为 星巴克亮/星巴克暗 两档（见风险1/5） |
| 10 | `lib/pages/courses_page.dart` + `collins_detail_intro_page.dart` | 粉彩课程色去饱和向绿/奶油靠拢；collins :62,126,142,148,220,224 六处硬编码橙→令牌 |

（其余低优：login/splash/my_content/more_settings/search/word_dictionary_popup/message/account_info/lock 屏，均为零散硬编码替换，随批次清扫。）

## 五、风险 Top5

1. **状态栏亮度语义过载**（dark_skin_strategy.md §1.2-3）：`ThemePreset.statusBarBrightness` 被同时喂给 `MaterialApp.theme.brightness`（main.dart:89,93 经 seedColor），bright 皮肤实际生成暗色 ColorScheme，语义反转。迁移第一步必须把「Material 亮度」与「状态栏图标亮度」拆成两个字段，否则新主题的控件配色会系统性错乱。
2. **硬编码 Color 大面积散布**（本次全库扫描 ~40 处）：appearance/more_settings(:103)/my_content(:157-162)/splash(:126-182) 的 `#FF6800/#E8913A`、collins 六处、input_controls.dart:12、check_in_widgets.dart:74、search/my_content 的 `#1F1F1F/#999999` 文字色等。只换 token 无法完成重构——需按第四节顺序逐文件清零；微信绿两处豁免。
3. **壁纸 vs 奶油画布的所有权冲突**：壁纸占据画布位（home_screen:36、learn_page:36、review_page:104-162），渐变素材直接违反"无渐变"规范。采纳 dark_skin_strategy.md 方案 C「画布归品牌、装饰归个性」：三处移除壁纸渲染，壁纸降级为无正文遮挡区的纯色装饰。
4. **金色语义边界**：sunshine 家族 + `vipGoldBg #FFD06A`(skin_system.dart:64) + 打卡火焰分布广；必须立规矩——金 `#CBA258` 仅限成就（VIP、连续打卡、徽章、酷币），任何导航/按钮/链接禁用，防止稀释绿色体系。
5. **双令牌并存 + 机制欠账**：`design_tokens.dart`（Mistral 静态常量）与 `ThemeVars` 并行，迁移期最易漂移——策略：先在 `themes` map 新增 `starbucks_cream/starbucks_dark` 两预设（架构零改动、页面零改动、可回滚），稳定后再清空 design_tokens.dart；同时补 themeId 持久化（现为硬编码 `'bright'`）与"跟随系统"假开关接线（appearance_page.dart 空实现）。对比度安全线：次要文字 α≥0.55（a11y 报告§2 红线）。

---

*验收口径：全部页面无 `Color(0xFFE8913A|#F4A100|#FF6800)` 残留（微信绿除外）；底栏/CTA/卡片三项抽查符合本表；深浅两套皮肤下 WCAG AA 全过。*
