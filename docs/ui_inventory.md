# Monster Word 全页面清单与「星巴克」改造量级评估

> 盘点范围：`lib/pages/`（53 个）、`lib/screens/`（4 个）、`lib/shell/main_shell.dart`（1 个），共 **58 个 UI 文件**。
> 方法：只读代码静态盘点（文件头注释、路由表 `main.dart`、import 关系、硬编码颜色计数）。
> 目标：为「星巴克风格」视觉重构提供页面底册与工作量排序依据。

---

## 一、图例与统计口径

**样式来源标记**
- `skin` = 引用 `lib/theme/skin_system.dart`（ThemeVars 三主题体系）
- `tokens` = 引用 `lib/tokens/design_tokens.dart`（MistralColors/AppleSpacing 等）
- `C0x×N` = 文件内 `Color(0x……)` 字面量出现次数（真硬编码）
- `Colors×N` = 文件内 Flutter `Colors.*` 出现次数（同属硬编码色）

**改造量级**
| 级别 | 含义 | 参考工时 |
|---|---|---|
| S | 简单页：列表/表单/薄壳，换肤即可 | ≤0.5 天 |
| M | 中等页：有自定义视觉块（渐变头、卡片、图表），需重定色彩与局部结构调整 | ~1 天 |
| L | 大型页：>500 行或强交互/富排版/多弹窗，需要布局级重构配合 | ≥2 天 |

**可达性标记（备注列）**
- ✅ = 已接入主路径（三大 Tab / 启动流可到达）
- ⚠️ = 路由已在 `main.dart` 注册，但全库未发现任何入口调用（死路由）
- ❌ = 未注册路由且无入口（完全未接线）

---

## 二、总览统计

| 维度 | 结果 |
|---|---|
| 页面总数 | 58（pages 53 / screens 4 / shell 1） |
| 改造量级分布 | **S×29 · M×20 · L×9** |
| 样式来源 | 53/53 页面均引用 `skin_system`；44/53 同时引用 `design_tokens` |
| 硬编码颜色总量 | `Color(0x…)` 约 **153 处**（集中于 19 个文件）；`Colors.*` 约 230 处（分散） |
| 重灾区 | profile_screen(C0x×24)、my_content_page(×18)、word_machine_page(×15)、appearance_page(×13)、class_checkin/courses(各×12) |
| 自定义组件复用率低 | `lib/widgets/` 共 36 个组件文件，**页面层实际在用的只有 7 个**（animations、glass_widgets、review_dialog、word_lookup_popup、word_dictionary_popup、exam_phrase_widgets、word_root_tab），其余约 29 个为遗留未接线组件 |

---

## 三、主表

### 3.1 lib/screens/ —— 三大 Tab + 学习会话（现行骨架）

| 文件名 | 用途 | 主要自定义组件 | 当前样式来源 | 量级 | 备注 |
|---|---|---|---|---|---|
| home_screen.dart | **Tab1「学习」首页仪表盘**：壁纸背景+玻璃拟态打卡卡，入口：词库/单词机/查词/复习弹窗 | glass_widgets、review_dialog | skin+tokens｜C0x×5 Colors×10 | **M** | ✅ 高频第一屏；金色/玻璃质感需整体换成星巴克暖调 |
| learn_session.dart | 学习会话页（Figma 03a 版新学流程实现） | animations、word_dictionary_popup | skin+tokens｜C0x×6 | **L** | ⚠️ 仅 `/my_fav → learn_session` 链路可达，而 my_content 本身未接线 → 实际近乎死路；与 learn_page 功能重叠，建议二选一后再改 |
| profile_screen.dart | **Tab3「我的」**：金色渐变头部+酷币/装备卡+菜单（外观/更多设置） | — | skin+tokens｜**C0x×24** Colors×3 | **M** | ✅ 高频；全 App 硬编码色最多，头部渐变是星巴克化重点 |
| review_session.dart | 复习会话页（Figma 03a 版复习流程，四选一反馈） | glass_widgets | skin｜Colors×3 | **M** | ✅ 由首页复习弹窗直达，复习闭环核心 |

### 3.2 lib/shell/

| 文件名 | 用途 | 主要自定义组件 | 当前样式来源 | 量级 | 备注 |
|---|---|---|---|---|---|
| main_shell.dart | 应用外壳：三 Tab 容器+悬浮透明底部导航栏 | animations | skin+tokens｜C0x×2 | **S** | ✅ 全局框架；一处改动全局生效，性价比最高 |

### 3.3 lib/pages/ —— 按拼音/字母序

| 文件名 | 用途 | 主要自定义组件 | 当前样式来源 | 量级 | 备注 |
|---|---|---|---|---|---|
| account_info_page.dart | 账号信息页（绑定微信/QQ/微博） | — | skin+tokens｜C0x×3（品牌色） | **M** | ❌ 无入口；品牌第三方色可豁免 |
| appearance_page.dart | 外观&沉浸场景设置（主题三选一预览卡） | — | skin+tokens｜C0x×13 Colors×12 | **M** | ✅ 「我的」菜单直达；本身是主题控制台，星巴克主题需在此新增预设 |
| base_web_page.dart | 内置 WebView 容器（含广告 Web 变体） | — | skin+tokens | **S** | ⚠️ 仅调试页 uri_scheme 引用 |
| book_words_page.dart | 词书单词列表（继承 ListWordsPage 加短语组件） | exam_phrase_widgets | skin | **S** | ❌ 无入口 |
| books_page.dart | 旧版首页雏形（词书+快捷入口卡） | — | skin｜Colors×15 | **S** | ❌ 无入口，功能已被 HomeScreen/LibSelect 取代，建议评估删除 |
| class_activity_page.dart | 班级活动详情（动态流+报名卡） | — | skin+tokens｜C0x×6 Colors×10 | **L** | ❌ 仅孤儿 courses 页链入 |
| class_checkin_page.dart | 班级打卡（打卡日历+统计图+排行） | — | skin+tokens｜C0x×12 Colors×20 | **L** | ❌ 仅孤儿 courses 页链入；全 App 最大页面（1281 行） |
| collins_detail_intro_page.dart | 柯林斯释义详解富文本页（词性色标） | — | skin+tokens｜C0x×9 | **M** | ❌ 无入口；词性标签色若启用需并入 tokens |
| courses_page.dart | 课程主页（班级/打卡/备考速刷入口） | — | skin+tokens｜C0x×12 Colors×7 | **L** | ❌ 无入口（整条班级链不可达） |
| dashboard_page.dart | 数据仪表盘（进度环+统计卡） | — | skin+tokens | **S** | ⚠️ 仅孤儿 books 页链入 |
| dictionary_page.dart | 词典查询页（释义/同反义/词根三 Tab） | word_root_tab | skin+tokens | **M** | ✅ 查词(search)后进入；无硬编码色，主要是组件换肤 |
| exam_quick_review_page.dart | 备考速刷（限时刷题模式） | — | skin+tokens｜C0x×4 Colors×21 | **L** | ❌ 无入口（仅 courses 文案提及） |
| extensive_model_select_page.dart | 听力模式选择（泛听/精听） | — | skin+tokens | **S** | ⚠️ 死路由 `/listen_mode_select` |
| foot_mark_page.dart | 学习足迹枢纽（跳转 5 类单词统计薄页） | — | skin+tokens | **S** | ⚠️ 死路由 `/foot_mark` |
| help_page.dart | 帮助中心（WebView 包装） | — | skin+tokens | **S** | ⚠️ 死路由 `/help` |
| immersive_swipe_page.dart | 沉浸式滑卡记词（全屏手势） | animations | skin+tokens｜Colors×2 | **M** | ⚠️ 死路由 `/immersive_swipe`；若启用属学习流程高优 |
| learn_page.dart | **学习核心：4选1 答题流程**（选错标红/对绿→词典详情→下一词，壁纸沉浸+音效） | animations、word_lookup_popup | skin+tokens｜C0x×2 Colors×15 | **M** | ✅ Tab1/Tab2 学习入口直达，全 App 最高频页面 |
| lib_select_page.dart | **Tab2「课程」词库/词书选择**：分类卡片+搜索+开始学习 | — | skin｜Colors×4 | **M** | ✅ 任务定义的「词书选择」现役页面 |
| linked_me_middle_page.dart | LinkedMe 联想记忆中转页（深链分发） | — | skin+tokens | **S** | ⚠️ 死路由 `/linked_me` |
| list_word_listen_page.dart | 单词列表听音循环播放 | — | skin+tokens | **S** | ⚠️ 死路由 `/word_listen` |
| list_words_page.dart | 通用单词列表页（多种子类基类） | — | skin+tokens | **S** | ⚠️ 本体无直接入口，被 book_words 继承（亦孤儿） |
| login_page.dart | 登录/注册门面（手机号+协议+动画背景） | animations | skin+tokens｜C0x×1 Colors×5 | **M** | ✅ 启动流 Splash→Login；门面页需与星巴克品牌统一 |
| mastered_words_page.dart | 已掌握单词薄壳页 | — | skin | **S** | ⚠️ 经 foot_mark 才可达（foot_mark 本身死路由） |
| message_page.dart | 消息中心（系统通知列表） | — | skin+tokens | **S** | ⚠️ 经孤儿 my_space 链入 |
| more_settings_page.dart | 更多设置（账号/清理缓存/关于等，7 个底部弹窗） | — | skin+tokens｜C0x×7 | **M** | ✅ 「我的」菜单直达；现役设置主路径 |
| my_content_page.dart | 我的内容聚合（收藏/例句/随身听入口卡） | — | skin+tokens｜**C0x×18** | **M** | ⚠️ 死路由 `/my_content`；硬编码重灾区 |
| my_equip_page.dart | 我的装备（道具/头像框网格） | — | skin+tokens | **S** | ⚠️ 死路由 `/my_equip` |
| my_fav_page.dart | 收藏的单词列表（点击进 LearnSession 重学） | — | skin+tokens｜Colors×3 | **M** | ⚠️ 经孤儿 my_content 链入 |
| my_fav_sentence_page.dart | 收藏的例句列表 | — | skin+tokens｜Colors×5 | **M** | ⚠️ 死路由 `/my_fav_sentence` |
| my_space_page.dart | 我的空间（头像+消息+设置入口） | — | skin+tokens｜Colors×2 | **M** | ❌ 仅孤儿 books 页链入 |
| my_words_page.dart | 我的单词薄壳页 | — | skin | **S** | ⚠️ 同 foot_mark 链 |
| net_diagnosis_page.dart | 网络诊断工具页 | — | skin+tokens | **S** | ⚠️ 死路由 `/net_diagnosis` |
| new_words_page.dart | 生词本薄壳页 | — | skin | **S** | ⚠️ 同 foot_mark 链 |
| not_learned_words_page.dart | 未学单词薄壳页 | — | skin | **S** | ⚠️ 同 foot_mark 链 |
| personal_stereo_page.dart | 个人随身听（后台循环听音） | — | skin+tokens | **S** | ⚠️ 死路由 `/personal_stereo` |
| play_order_page.dart | 播放顺序设置（单选列表） | — | skin+tokens | **S** | ⚠️ 死路由 `/play_order` |
| review_page.dart | 复习四选一页（旧版复习流程，壁纸沉浸） | animations | skin+tokens | **M** | ⚠️ 死路由 `/review`（复习已被 review_session 取代，但 uri_scheme/books 仍指向）；与 learn_page 同构，可与新复习页统一皮肤 |
| reviewing_words_page.dart | 复习中单词薄壳页 | — | skin | **S** | ⚠️ 同 foot_mark 链 |
| search_page.dart | 查词搜索页（历史记录+联想） | — | skin+tokens｜C0x×6 | **M** | ✅ Tab1/Tab2 直达；进入 DictionaryPage 的必经点 |
| sentence_detail_page.dart | 例句详情（跟读/收藏） | — | skin+tokens | **S** | ⚠️ 死路由（带参）`/sentence_detail` |
| sentence_quiz_page.dart | 例句测验（挖空选择+判分动效） | — | skin+tokens｜Colors×4 | **L** | ⚠️ 死路由 `/sentence_quiz` |
| settings_page.dart | 设置主页（659 行，播放/显示/数据 7 组底部弹窗） | — | skin｜Colors×10 | **L** | ⚠️ 仅孤儿 my_space 链入；与 more_settings 功能重叠，建议合并后只改一个 |
| sms_page.dart | 短信验证码页 | — | skin+tokens | **S** | ❌ 登录流未接线 |
| spell_check_page.dart | 单词听写检测（播音频→拼写→反馈） | — | skin+tokens | **S** | ⚠️ 死路由（带参）`/spell_check` |
| spell_session_page.dart | 连续听写单元页 | — | skin+tokens｜Colors×8 | **M** | ⚠️ 死路由 `/spell_session` |
| splash_page.dart | 启动页（品牌 Logo 动画→登录/主页分流） | animations | skin+tokens｜C0x×6 | **S** | ✅ 冷启动必经，一次性页面 |
| ui_theme_select_page.dart | UI 主题选择页（旧版，与 appearance 重叠） | — | skin+tokens｜C0x×2 | **S** | ⚠️ 死路由 `/theme_select`；建议废弃合并入 appearance |
| uri_scheme_page.dart | URI Scheme 调试分发页 | — | skin+tokens | **S** | ⚠️ 开发调试页，可豁免改造 |
| user_info_manage_page.dart | 用户信息管理列表 | — | skin+tokens | **S** | ⚠️ 死路由 `/user_info_manage` |
| user_item_modify_page.dart | 用户资料单项修改（昵称/签名） | — | skin+tokens | **S** | ❌ 无入口 |
| wallpaper_select_page.dart | 壁纸选择（网格预览+应用） | — | skin+tokens｜Colors×19 | **M** | ⚠️ 死路由 `/wallpaper_select`；星巴克化后壁纸体系需重新设计 |
| word_detail_page.dart | **单词详情页**（释义/词形/例句/词根富排版，651 行） | — | skin+tokens｜Colors×2 | **L** | ✅ 学习流程内点词即达，查看频次最高的内容页 |
| word_machine_page.dart | 单词机（Game Boy 复古游戏化刷词） | — | skin+tokens｜C0x×15（刻意复古配色） | **L** | ✅ 首页入口直达；复古绿屏是设计语言的一部分，建议**豁免或单独主题化** |

---

## 四、Top10 优先改造页（按用户高频路径排序）

> 排序原则（任务指定）：**学习流程页 ＞ 词书选择 ＞ 首页仪表盘 ＞ 我的 ＞ 设置**，同级内按「日活触达频次 × 视觉影响力 ÷ 工作量」细分。

| # | 页面 | 量级 | 入选理由 |
|---|---|---|---|
| 1 | **learn_page.dart**（学习 4 选 1 流程） | M | 全 App 最高频页面：Tab1/Tab2 的「开始学习」都落到这里，用户每天多次经历答题正误的色彩反馈（红/绿）。星巴克化的核心战场——把 Mistral 冷色调反馈改为咖啡暖调体系，直接决定整套改造的观感基调 |
| 2 | **review_session.dart**（复习会话） | M | 复习是背单词 App 的另一半核心闭环（首页复习弹窗直达），与新学流程共享反馈语言，必须与 #1 同批改造保证一致性；已有 glass_widgets 底子，工作量可控 |
| 3 | **word_detail_page.dart**（单词详情） | L | 学习中每次点词都会进入，是停留时长最长的**内容页**；651 行富排版（释义/词形/例句分区块）需要逐区块套用星巴克卡片规范，量大但模板一旦建立可复用到其他详情类页面 |
| 4 | **lib_select_page.dart**（词库/词书选择，Tab2） | M | 任务指定的「词书选择」现役页面且独占整个 Tab2；书店式货架场景与星巴克「门店菜单」气质天然契合，是视觉差异化最容易出彩的页面 |
| 5 | **home_screen.dart**（首页仪表盘，Tab1） | M | 每日打开的第一屏，打卡卡+快捷入口决定第一印象；现有玻璃拟态+壁纸方案偏冷，需换成拿铁奶油色卡片与烘焙棕强调色 |
| 6 | **profile_screen.dart**（我的，Tab3） | M | 三大 Tab 之一，且是**硬编码色冠军（C0x×24）**——金色渐变头部与星巴克绿色系直接冲突，必须重做头部视觉；顺带清理全部字面量颜色入 tokens |
| 7 | **main_shell.dart**（全局外壳/底部导航） | S | 工作量最小但影响面最大：导航栏配色、选中态、毛玻璃底板一处生效全局；建议与 #5/#6 同一 PR 落地，保证 Tab 框架先换装 |
| 8 | **appearance_page.dart**（外观&沉浸场景） | M | 星巴克主题的**落地控制台**：新预设要在这里注册并可预览；不改它，其余页面换了肤色用户也无处切换 |
| 9 | **more_settings_page.dart**（更多设置） | M | 现役设置主路径（ProfileScreen→更多设置）；按任务「设置」优先级压轴，但含 7 个底部弹窗组件，弹窗样式统一成星巴克圆角奶盖风即可批量完成 |
| 10 | **splash_page.dart + login_page.dart**（启动/登录门面） | S/M | 使用者对 App 的第一眼与最后一眼记忆；两页共用 animations 背景，统一替换品牌色与插画氛围成本低、仪式感收益高 |

---

## 五、补充发现（给后续改造的建议）

1. **大量死页面（~25 个 ⚠️/❌）**：班级线（courses/class_checkin/class_activity/exam_quick_review）、听力线（personal_stereo/list_word_listen/play_order/extensive_model_select）、拼写线（spell_check/spell_session）、收藏线（my_content/my_fav/my_fav_sentence）均未接入主路径。**建议先由 Lead 决策「接线 or 冻结」，避免给死页面浪费改造工时**；冻结页可在表中剔除。
2. **新旧流程并存**：learn_page vs learn_session、review_page vs review_session、settings_page vs more_settings_page、ui_theme_select vs appearance 各有一对新旧实现，建议每对保留一个再改造（本表 Top10 已按现役可达页面取舍）。
3. **硬编码色收敛策略**：153 处 `Color(0x…)` 中，profile_screen(24)、my_content(18)、word_machine(15)、appearance(13)、courses/class_checkin(12×2) 六个文件占约 60%；除 word_machine（刻意 Game Boy 配色，建议豁免）外，其余应在改造时一并迁入 `design_tokens`。
4. **组件层几乎空白**：36 个 widget 仅 7 个在用，页面各自手搓卡片/按钮。星巴克改造建议同步沉淀 3~5 个基础组件（StarCard/StarButton/StarSheet/StarHeader），避免 58 个页面重复造轮子。
5. **范围外备注**：`lib/lock/lock_screen_page.dart`（锁屏页）不在本次盘点目录内，如需纳入请追加任务。
