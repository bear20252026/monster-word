# 用户体验问题总账（UX Master Ledger）

> 站在最终用户角度（看得懂、用得顺、有获得感）的全站体验体检聚合。
> 数据源：**UX-AUX-1/2/3/4/5/6 全部完成（6/6）**。累计约 143 条发现（跨域去重前）。
> 路径已按当前代码结构核正（部分页面已迁入 `lib/features/*/presentation/`）。
> 严重度：🔴高 / 🟡中 / 🟢低。状态：`待派修` / `已派修` / `已修复`。

---

## 一、审计覆盖（6/6 完成）

| 报告 | 域 | 结果 | 状态 |
|------|----|------|------|
| UX-AUX-1 | 首页/书架/选书 | 17（5高/7中/5低） | 完成 |
| UX-AUX-2 | 单词详情/词典 | 26（5高/12中/9低） | 完成 |
| UX-AUX-3 | 学习/会话流 | 32（3高 P0/P1/…） | 完成 |
| UX-AUX-4 | 账户/登录/设置/打卡/激动币 | 47（3高/18中/16低） | 完成 |
| UX-AUX-5 | 全局一致性/可访问 | 12（1高/6中/5低） | 完成 |
| UX-AUX-6 | 冷启动/全局兜底 | 9（2高/4中/2低/1信息） | 完成 |

---

## 二、🔴 高严重度总表（按域分组）

### 域 A：冷启动 / 全局兜底（来源 UX-AUX-6）
| ID | 痛点 | 位置 | 建议 | 状态 |
|----|------|------|------|------|
| A-1 | **Splash 被绕过**：`home` 直接 `_HomeShell`，品牌动画/登录检查/首次引导全程不展示，新用户零引导 | `lib/app/app.dart:131`（home 接线） | 让 Splash 作为真正的启动入口（展示品牌→检查登录态→按需引导），home 屏作为落地 | 待派修 |
| A-2 | **缺 `runZonedGuarded`**：异步异常无全局兜底，线上崩溃无提示 | `lib/app/app_bootstrap.dart` | 包 `runZonedGuarded` + 顶层 `FlutterError.onError`，统一上报/兜底页 | 待派修 |
| A-3 | 冷启动加载链无进度反馈（DB/SQLite 初始化静默） | 启动链 | 加启动进度/骨架，避免假白屏 | 待派修 |
| A-4 | 首页「开始学习」无词书时仅 SnackBar，无引导 | `lib/screens/home_screen.dart`（_startLearning） | 空态给「去选词书」CTA | 待派修 |
| A-5 | 复习弹窗无空态（dueCount==0 直接进） | `lib/widgets/review_dialog.dart` | dueCount==0 给友好空态 | 待派修 |
| A-6 | URI 深链无品牌过渡 / 错误页返回首页在根路由失效 | `lib/pages/uri_scheme_page.dart` | 深链走品牌过渡 + goHome 兜底 | 待派修 |
| A-7 | Provider 嵌套 10 层过深，加载失败难感知 | `lib/app/app.dart` | 归类重组（info，观察项） | 观察 |

### 域 B：首页 / 书架 / 选书（来源 UX-AUX-1）
| ID | 痛点 | 位置 | 建议 | 状态 |
|----|------|------|------|------|
| B-1 | **首页 Learn 空态无引导**：新用户点开始学习无词书，迷失 | `lib/screens/home_screen.dart` Learn 空态 | 首次引导 + 去选词书 CTA（与 A-4 合并） | 待派修 |
| B-2 | **词书描述硬编码**「考研核心高频 | 2026」，与真实词书不符 | 词书卡片描述 | 从词书元数据取真实标签/释义 | 待派修 |
| B-3 | **「尖叫币」术语困惑**：用户不知何意，无解释 | 首页/词书卡片 | 首次出现给 tooltip/说明，或改名 | 待派修 |
| B-4 | ProfileScreen「学习偏好」点击无导航（假卡片） | `lib/screens/profile_screen.dart` | 接通导航或弱化点击暗示 | 待派修 |
| B-5 | 「装备」卡片 chevron 暗示可点但无 onTap | 首页装备卡 | 加 onTap 或去掉 chevron | 待派修 |
| B-6 | 日期中英混用（如 Jan. / 2026-01） | 多页 date | 统一中文/本地化 | 待派修 |

### 域 C：单词详情 / 词典（来源 UX-AUX-2）
| ID | 痛点 | 位置 | 建议 | 状态 |
|----|------|------|------|------|
| C-1 | **搜索结果无选中态**：点击后不明显，像没反应 | 搜索页结果列表 | 加选中高亮/已选态 | 待派修 |
| C-2 | **dictionary_page 6 tab 无 TabBarIndicator**：看不清当前 tab | `lib/features/dictionary/presentation/dictionary_page.dart` | 加指示条 | 待派修 |
| C-3 | **收藏无动画/haptic**：点收藏无即时体感 | word_detail 收藏按钮 | 加动画 + 触感反馈 | 待派修 |
| C-4 | **收藏/笔记图标无 tooltip**：含义不明 | word_detail | 加语义标签/tooltip | 待派修 |
| C-5 | word_machine 弹出层无拖拽关闭提示 | `lib/pages/word_machine_page.dart` | 加「下滑关闭」提示 | 待派修 |

### 域 D：学习 / 会话 / 背诵（来源 UX-AUX-3）
| ID | 痛点 | 位置 | 建议 | 状态 |
|----|------|------|------|------|
| D-1 | **P0 SessionExitGuard 无差别拦截所有返回**：背完想退出被反复确认 | `lib/widgets/session_exit_guard.dart` | 智能判断：仅进行中/有未完成任务才拦 | 待派修 |
| D-2 | **P1 完成页无错题回顾/总结**：学完没获得感 | 学习完成页 | 加错误词回顾 + 数据总结 | 待派修 |
| D-3 | **P1 4 种拼写页导航风格不统一** | 拼写/听写/造句/快速拼写 | 统一返回/完成导航范式 | 待派修 |
| D-4 | dictation 每词需手动点下一题，无自动推进 | `lib/pages/dictation_session_page.dart` | 自动进入下一词（可配置） | 待派修 |
| D-5 | 文案语气冰冷（鼓励感缺失） | 学习流文案 | 润色为鼓励式 | 待派修 |

### 域 E：全局一致性 / 可访问性（来源 UX-AUX-5）
| ID | 痛点 | 位置 | 建议 | 状态 |
|----|------|------|------|------|
| E-1 | **「签到」vs「打卡」混用**：同一 check-in 功能两种叫法 | `home_screen.dart:316`、`class_checkin_page.dart:244` 用「打卡」；`check_in_history_page.dart` 用「签到」 | 统一（建议「签到」） | 待派修（撞 UX-AUX-4，等合并） |
| E-2 | 返回图标不一致：`dictionary_by_name_page.dart:63/93` 用 `arrow_back`，其余用 `arrow_back_ios_new` | 全库 | 统一返回图标 | 待派修 |
| E-3 | 「单词本」(收藏) vs「词书」(教材) 字面易混 | 全库 | 改「收藏」或「生词本」 | 待派修 |
| E-4 | 装饰字无语义标签：splash Logo `Text('怪')` 屏幕阅读器朗读「怪」 | `lib/features/account/presentation/splash_page.dart`（原 lib/pages/splash_page.dart:137） | 加 `ExcludeSemantics` | 待派修 |
| E-5 | IconButton 缺 tooltip/语义标签（如选书眼睛图标） | `lib/pages/lib_select_page.dart:118` 等 | 遍历补 tooltip | 待派修 |
| E-6 | 空态缺 CTA：`scare_coin_history_page`「还没有记录」无按钮、`my_fav_page.dart:197`「单词本为空」无引导 | 多页空态 | 补「去 XX」CTA | 待派修 |

### 域 F：账户/登录/设置/打卡/奖励（来源 UX-AUX-4）
| ID | 痛点 | 位置 | 建议 | 状态 |
|----|------|------|------|------|
| F-1 | **第三方登录死路**：点击微信/QQ/微博/华为仅「开发中」toast，无替代路径 | `login_page`（已迁 `features/account/presentation/login_page.dart`） | 未接入则隐藏/加「即将上线」标签 | 待派修 |
| F-2 | **兑换中心余额硬编码 `_coins = 1280`**：与真实余额无关，误导 | `redemption_center_page.dart:18` | 从 `ScareCoinStore` 读真实余额 | 待派修 |
| F-3 | **打卡/尖叫币历史空态无 CTA**：`scare_coin_history_page.dart:137-140` 空态无按钮；`check_in_history_page.dart:62-85` 失败无重试、CTA 仅 `pop` | 空态/错误态 | 空态补「去签到」行动入口；错误态补「重试」 | 待派修 |
| F-4 | 导航返回不统一：`class_checkin_page`、`user_info_manage_page.dart:98` 裸 `Navigator.pop`；`more_settings` exit | 多页 | 统一 `NavUtils.safePop` | 待派修 |
| F-5 | 频率限制无倒计时 / 无重试按钮（`login`/`check_in_history`） | 登录/打卡 | 倒计时 + 重试 | 待派修 |
| F-6 | 设置页标题「学习偏好」与入口「设置」不一致；「更多学习偏好/助记顺序/班级打卡设置」均「开发中」无状态标签 | `settings_page`/`class_checkin_page` | 统一标题 + 「即将上线」标记 | 待派修 |
| F-7 | 可访问性：社交登录图标无 Semantics、进度环无语义、正负 delta 仅颜色区分、`GestureDetector` 无涟漪/语义 | `login`/`check_in_history`/`scare_coin_history`/`user_info_manage` | 补 Semantics/图标/InkWell | 待派修 |

---

## 三、🟡 中 / 🟢 低 汇总（按报告，按下派）

### UX-AUX-1（首/书）：7🟡 5🟢
🟡：词书卡选中态缺失、列表加载 skeleton 缺失、词书切换无过渡、主页统计卡交互歧义、空书架兜底文案生硬、重复加载动画、部分按钮触达 <48dp。
🟢：日期分隔符混乱、图标风格微差、冗余空行、次要文案语气、重复分隔线。

### UX-AUX-2（词/典）：12🟡 9🟢
🟡：例句无分句朗读、词根词缀无展开、发音错字 wav 空态、收藏列表无排序、词典搜索历史无清除、释义分级不够直观、词性标签配色弱、同近义词无入口、笔记字数无上限提示、词组折叠无展开提示、Word 生命周期重复加载、收藏删除无撤销。
🟢：弹出层无遮罩点击关闭、间距不齐、字号偏小、图标冗余、对比度临界、无触感、文案重复、水印发散、布局溢出风险。

### UX-AUX-3（学习）：8🟡 若干🟢（总 32 条）
🟡：学习进度环无动画、做完题无即时音效、vocab 提示层级混杂、答题对错 toast 延迟、退出续学无提示、连续学习无 streak 反馈、完成统计可读性差、生词加入无反馈。
🟢：动画时长不统一、图标歧义、错词无重练入口、间距、文案、占比。

### UX-AUX-5（一致）：6🟡 5🟢
🟡：E-2/E-3/E-4/E-5/E-6 见上；错误处理 catch 静默失败（部分）。
🟢：SnackBar 无封装、开发中措辞乱、装饰色硬编码、辅助字号偏小、加载态缺失。

### UX-AUX-6（冷启动）：4🟡 2🟢 1信息
🟡：A-3/A-4/A-5/A-6；🟢：loading 样式不统一、错误页返回根路由失效（联动 goHome）。

---

## 四、修复派工计划（LEAD 评审后派发）

> 原则：按**域**分组派工，同一文件的并发编辑用「域间互斥」规避；改前先读 `docs/TEAM_COLLABORATION_FRAMEWORK.md`；改后报 LEAD 审查，通过才 commit。

| 卡片 | 域 | 高优先级项 | owner（slot） | 状态 |
|------|----|-----------|-----------|------|
| UX-FIX-A | 冷启动/全局 | A-1 Splash 入口、A-2 runZonedGuarded、A-3 启动进度、A-5 review 空态、A-6 深链/兜底 | 2163 | 已派修 |
| UX-FIX-B | 首页/书架/选书 | B-1 空态引导、B-2 词书描述、B-3 尖叫币说明、B-4 学习偏好、B-5 装备卡、B-6 日期 | 3061 | 已派修 |
| UX-FIX-C | 单词详情/词典 | C-1 选中态、C-2 TabBar、C-3 收藏动画、C-4 tooltip、C-5 拖拽提示 | 3802 | 已派修 |
| UX-FIX-D | 学习/会话 | D-1 SessionExitGuard、D-2 完成页、D-3 导航统一、D-4 自动推进、D-5 文案 | 2903 | 已派修 |
| UX-FIX-E | 账户/登录/设置/打卡/奖励 + 全局一致/可访问 | F-1 第三方登录、F-2 硬编码余额、F-3 空态CTA/重试、F-4 safePop、F-5 倒计时、F-6 标题/「今日上线」、F-7 可访问性；连同 E-1 签到/打卡术语、E-2 返回图标、E-4 ExcludeSemantics、E-5 tooltip、E-6 空态CTA | 9052 | 已派修 |
| UX-FIX-ARCH | 架构耦合（ARCH-FIX-1/2/3/4） | A1 settings→account R4、B1/B2 port 化、C1 provider 扁平化 | 2163/3061/3802/2903/lead | 待派修（等 UX 波收敛） |

> ⚠️ A/B/C/D/E 五张 UX 修复卡文件已核互斥（A 不动 home_screen/review/uri_scheme 之外，B 独占 home_screen/lib_select/profile，C 独占 word/dict/收藏，D 独占学习/会话，E 独占 account/settings/checkin/scare_coin/reward），可并行。ARCH-FIX-4 会动 app.dart，必须等 UX-FIX-A 落地；其余 ARCH 卡待 UX 波收敛后串行派发。

---

## 五、回归门禁（改动完成后统一跑）

1. `flutter analyze` 0 error（且涉及文件无新增 warning/info）。
2. `flutter test` 全量通过（不破坏既有 ~398 测试）。
3. `lib/core/import_guard.dart` 扫描 0 违规（`flutter test test/architecture/import_guard_test.dart`）。
4. 全部改动 + 测试 + 报告齐全后，由 LEAD 审查通过再 git commit & push。
