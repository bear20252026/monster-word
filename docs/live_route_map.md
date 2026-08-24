# Monster Word 活页面地图：可达性追踪与死活判定

> 追踪方法：只读静态分析。以 `main.dart` 的 `home:` 挂载点为根，沿全部 `Navigator.push / pushNamed / pushReplacementNamed` 调用点逐层展开（覆盖 `lib/pages/`、`lib/screens/`、`lib/widgets/` 全量调用点），并核对 `AndroidManifest.xml` 无深链接 intent-filter、`MaterialApp` 未设 `initialRoute`。
> 结论先行：**58 个 UI 文件中仅 13 个运行时可达（活），45 个不可达（死）**。

---

## 一、【活页面】可达页面树状图

App 冷启动直接进入三 Tab 主框架（不经过 Splash/Login，Manifest 无深链接配置）：

```
启动 main.dart（home: MainShell，无 initialRoute）
└─ 🐚 MainShell (shell/main_shell.dart) —— 三 Tab 底部导航
   │
   ├─ Tab1「学习」🏠 HomeScreen (screens/home_screen.dart)
   │   ├─ 「词库」入口 ──pushNamed──► 📚 LibSelectPage (pages/lib_select_page.dart)   ['/lib_select' :88]
   │   ├─ 「单词机」入口 ──────────► 🎮 WordMachinePage (pages/word_machine_page.dart)['/word_machine':111]
   │   ├─ 「查词」入口 ───────────► 🔍 SearchPage (pages/search_page.dart)           ['/search'     :150]
   │   │                                └─点击结果──MaterialPageRoute──► 📖 DictionaryPage (:179,:285)
   │   │                                                    └─同义词再查──► DictionaryPage（自身递归 :491）
   │   └─ 「复习」打卡卡 ──showReviewDialog──► 💬 ReviewDialog (widgets/review_dialog.dart)
   │        ├─ 「去学习」──► 🟢 LearnPage (pages/learn_page.dart)      ['/learn'          :129]
   │        │                └─点词弹窗 WordLookupPopup(:188)/答案卡(:281)──► 📖 WordDetailPage ['/word_detail']
   │        └─ 「去复习」──► 🔁 ReviewSession (screens/review_session.dart)['/review_session':148]
   │
   ├─ Tab2「课程」📚 LibSelectPage (pages/lib_select_page.dart，Tab 直接挂载)
   │   ├─ 搜索框 ──► 🔍 SearchPage                                    ['/search'          :101]
   │   ├─ 「沉浸刷词」──► 🃏 ImmersiveSwipePage (pages/immersive_swipe_page.dart) ['/immersive_swipe' :236]
   │   └─ 「开始学习」──► 🟢 LearnPage                                 ['/learn'           :296]
   │
   └─ Tab3「我的」👤 ProfileScreen (screens/profile_screen.dart)
       ├─ 「外观 & 沉浸场景」──► 🎨 AppearancePage                     ['/appearance'      :179]
       └─ 「更多设置」────────► ⚙️ MoreSettingsPage                   ['/more_settings'   :185]

辅助组件（随活页面加载）：animations、glass_widgets、review_dialog、word_lookup_popup、word_dictionary_popup(经 learn_session，见死链)
```

### 活页面清单（13 个文件）

| 层级 | 文件 | 角色 |
|---|---|---|
| 根 | shell/main_shell.dart | 三 Tab 框架 |
| Tab | screens/home_screen.dart | Tab1 学习首页 |
| Tab | pages/lib_select_page.dart | Tab2 词库选择 |
| Tab | screens/profile_screen.dart | Tab3 我的 |
| 二级 | pages/search_page.dart | 查词 |
| 二级 | pages/dictionary_page.dart | 词典结果 |
| 二级 | pages/word_machine_page.dart | 单词机游戏 |
| 二级 | pages/immersive_swipe_page.dart | 沉浸滑卡 |
| 二级 | screens/review_session.dart | 复习会话 |
| 二级 | pages/appearance_page.dart | 外观设置 |
| 二级 | pages/more_settings_page.dart | 更多设置 |
| 三级 | pages/learn_page.dart | 4选1 学习流程 |
| 三级 | pages/word_detail_page.dart | 单词详情 |

---

## 二、【死页面】不可达清单（45 个文件）

判定标准（满足其一即死）：① 类未被任何文件构造且路由未注册；② 路由已注册但全库无任何 `pushNamed` 指向；③ 仅被其他死页面引用（死链传播）。

### A. 断头流程链（有内部连线，但链条起点无入口）

| 死链 | 文件 | 推测用途 | 重叠/说明 |
|---|---|---|---|
| 登录流 | splash_page → login_page | 启动动画页 → 手机号登录页 | App 直接进主框架，二者均无人进入；login 成功后 `pushReplacementNamed('/')` 回主页 |
| 旧首页残骸 | books_page | 旧版首页雏形（词书+快捷卡） | 功能被 **home_screen + lib_select** 完全取代；其出口指向 my_space/dashboard/review 也全是死页 |
| ↳ 二级 | my_space_page → message_page、settings_page | 我的空间 → 消息中心/设置主页 | settings(659行) 与现役 **more_settings** 功能重叠 |
| ↳ 二级 | dashboard_page | 数据仪表盘 | 无现役对应（进度数据已在 home_screen 打卡卡呈现雏形） |
| 足迹统计线 | foot_mark_page → my_words / new_words / mastered_words / not_learned_words / reviewing_words | 学习足迹枢纽 + 5 个单词分类薄壳页（各 30 行，继承变体） | 整条线无入口 |
| 收藏线 | my_content_page → my_fav_page → learn_session(screens!) | 我的内容聚合 → 收藏单词 → 新版学习会话 | my_fav_sentence 也属此域但零入度；**learn_session 因此连带死亡**（见第三节配对①） |
| 听力线 | personal_stereo_page → play_order_page；list_word_listen_page；extensive_model_select_page | 随身听循环播放/播放顺序/泛听模式选择 | 无任何入口 |
| 班级线 | courses_page → class_checkin_page、class_activity_page；exam_quick_review_page | 课程主页 → 打卡日历/活动详情；备考速刷 | courses 是死根，整链不可达；class_checkin 为全库最大页面(1281行) |
| 拼写线 | spell_check_page；spell_session_page | 听写检测/连续听写单元 | 无入口 |
| 例句线 | sentence_quiz_page；sentence_detail_page | 例句测验/例句详情 | 无入口（sentence_detail 注册了带参路由但无调用方） |

### B. 零入度单点（注册或未注册，均无任何引用方）

| 文件 | 推测用途 | 说明 |
|---|---|---|
| help_page | 帮助中心 | 已注册 `/help`，无人跳转 |
| net_diagnosis_page | 网络诊断工具 | 已注册，无人跳转 |
| user_info_manage_page | 用户信息管理 | 已注册 `/user_info_manage`，无人跳转 |
| ui_theme_select_page | 旧版主题选择 | 已注册 `/theme_select`，与现役 **appearance** 重叠 |
| my_equip_page | 我的装备 | 已注册 `/my_equip`，无人跳转 |
| linked_me_middle_page | LinkedMe 深链中转 | 已注册，且 Manifest 无深链接配置，双重死亡 |
| my_fav_sentence_page | 收藏例句列表 | 无引用 |
| list_words_page | 通用单词列表基类 | 仅被同样死亡的 book_words 继承 |
| book_words_page | 词书单词列表（含短语组件） | 类未注册、无构造 |
| wallpaper_select_page | 壁纸选择 | 无入口；星巴克化后壁纸体系本就要重做 |
| user_item_modify_page | 资料单项修改 | 无入口 |
| account_info_page | 账号绑定管理 | 无入口 |
| sms_page | 短信验证码页 | 登录流本身已断，此页随之搁浅 |
| collins_detail_intro_page | 柯林斯详解富文本 | 类未注册、无构造 |
| base_web_page | 内置 WebView 容器 | 仅被 uri_scheme(死) 引用；main.dart 的 import 属未使用残留 |
| uri_scheme_page | URI Scheme 调试分发页 | 无深链接配置，仅可手动构造，判死 |

> 更正记录：重构4 清单曾将 `immersive_swipe_page` 标为 ⚠️ 死路由，本次逐行核对发现 **lib_select_page:236 实际挂有 `/immersive_swipe` 入口，该页为活页面**；`dashboard/settings/message` 等维持死判。

---

## 三、新旧流程并存配对表

| # | 现役（活） | 旧版（死） | 判断依据 | 建议 |
|---|---|---|---|---|
| ① | learn_page（4选1，362行） | learn_session（Figma 03a 新版，737行） | learn_page 被 Tab1 复习弹窗(:129)、Tab2 开始学习(:296) 双入口直达；learn_session 仅能从死链 my_fav 进入 | **二选一后统一**：求稳→留旧弃新（0 改动）；要 Figma 形态→改接 learn_session 并迁移 learn_page 的选词/进度逻辑（约 1~2 天），随后冻结 learn_page。⚠️ 两者不可同时保留两套皮肤 |
| ② | review_session（Figma 新版，347行） | review_page（旧四选一，452行） | review_session 由首页复习弹窗(:148)直达；review_page 仅剩死页 books/uri_scheme 引用 | **留新弃旧**：冻结并最终删除 review_page；注意其壁纸沉浸交互若有保留价值可先移植到 review_session |
| ③ | more_settings_page（322行，现役设置路径） | settings_page（659行，7 组底部弹窗更全） | profile_screen 只接 more_settings(:185)；settings 只被死页 my_space 引用 | **合并**：把 settings 独有的播放/显示/数据弹窗能力迁入 more_settings（约 1 天），完成后删除 settings_page；避免两套设置皮肤 |
| ④ | appearance_page（外观&沉浸场景） | ui_theme_select_page（旧主题选择） | appearance 由 Tab3 直达且已含三主题预览卡；ui_theme_select 零入度 | **留新弃旧**：冻结 ui_theme_select；其 C0x×2 硬编码色无需处理 |
| ⑤ | lib_select_page（Tab2 词库货架） | books_page（旧首页雏形含书架卡） | lib_select 是 Tab 直接挂载；books 无入口 | **留新弃旧**：books_page 建议直接删除（278 行，含 15 处 Colors.*） |

---

## 四、结论

### 4.1 冻结名单（本次星巴克改造跳过，共 45 个文件）

> 以下页面不投入任何换肤工时；其中标注 🗑️ 的 16 个建议后续直接删除（功能已被取代/调试用途/断头流程），其余保持冻结待产品决策。

**断头链根**：🗑️splash_page、🗑️login_page、🗑️books_page、foot_mark_page、my_content_page、🗑️courses_page、🗑️uri_scheme_page、personal_stereo_page
**链内成员**：🗑️message_page、🗑️settings_page、🗑️dashboard_page、🗑️review_page、my_words_page、new_words_page、mastered_words_page、not_learned_words_page、reviewing_words_page、my_fav_page、🗑️learn_session(screens)、play_order_page、🗑️class_checkin_page、🗑️class_activity_page、exam_quick_review_page、spell_check_page、spell_session_page、sentence_quiz_page、sentence_detail_page
**零入度单点**：help_page、net_diagnosis_page、user_info_manage_page、🗑️ui_theme_select_page、my_equip_page、🗑️linked_me_middle_page、my_fav_sentence_page、🗑️list_words_page、🗑️book_words_page、wallpaper_select_page、🗑️user_item_modify_page、🗑️account_info_page、🗑️sms_page、🗑️collins_detail_intro_page、🗑️base_web_page
（🗑️ 计 16 个；learn_session 是否删除取决于第三节配对①的决策）

**本次改造实际范围 = 13 个活页面**（见第一节清单），恰好覆盖用户高频路径的全部触点。

### 4.2 若要接线的最小工作量估计

| 接线项 | 做法 | 估计 |
|---|---|---|
| 激活登录流（splash→login） | main() 加首启/token 判断，`home:` 条件切换或设 `initialRoute:'/splash'`；login 成功已有回 `'/'` 逻辑 | ~0.5 天 |
| 激活足迹统计线 | ProfileScreen 菜单加一项 `pushNamed('/foot_mark')`（一行代码） | ~0.1 天（6 页样式换肤另计，均为 S 级） |
| 激活收藏线 | ProfileScreen 菜单加入口 → my_content；连带复活 my_fav/learn_session | ~0.1 天接线；⚠️ 需先完成配对①决策，否则复活的是将被废弃的新版学习页 |
| 激活班级线 | HomeScreen 加入口卡片 → courses | ~0.2 天接线（class_checkin/activity 本体为 L 级改造，另计 ≥4 天） |
| 激活拼写线 | learn_page 结果页/word_detail 加「听写巩固」入口 → spell_session | ~0.2 天 |
| 激活例句线 | word_detail 例句区加测验/详情入口 | ~0.2 天 |
| 激活听力线 | learn/复习流程加「随身听」入口 → personal_stereo | ~0.3 天（3 页联动） |
| 其余零散页（help/net_diagnosis/user_info_manage/wallpaper_select 等） | 均有现成路由名，在 more_settings/profile 补菜单即可，每项 ≤0.1 天 | 但多数建议**保持冻结或删除**，不值得投入 |

**总评**：接线成本普遍极低（多为 1 行导航代码），真正的成本在被唤醒页面的 L/M 级视觉改造本身。建议星巴克改造一期只做 **13 个活页面**；二期按配对表清理 5 组新旧并存（可净删约 2400 行死代码）；三期再按产品需要选择性接线。
