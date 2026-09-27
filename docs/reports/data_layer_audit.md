# 数据层审计报告

> 审计人：DataEngineer（Monster world）· 2026-08-24
> 项目：word_app
> 目的：盘点全部数据层文件、SharedPreferences 键值对、数据库结构，标记星巴克重构相关存储键

---

## 一、数据层文件总览

### 1.1 `lib/data/` 目录（8 个文件）

| 文件 | 职责 | 存储后端 |
|---|---|---|
| `app_preferences.dart` | 应用配置单例（AppPreferences / UserPreferences / GuidePreference）+ UserInfoBean | SharedPreferences |
| `app_preferences_ext.dart` | 扩展偏好层（AppPreferencesExt / UserPreferencesExt / GuidePreferenceExt / AuthDataPreferences） | SharedPreferences |
| `user_database.dart` | 用户收藏数据库（favorites 表） | SQLite（user_data.db） |
| `user_process_dao.dart` | 用户学习进度 DAO（user_process_history 表 + user_sync_v3 表） | SQLite |
| `note_database.dart` | 单词笔记数据库（word_notes 表） | SQLite（notes.db） |
| `wordbook_database.dart` | 只读词库（words / books / word_books 表） | SQLite（wordbook.db，gzip 压缩 asset） |
| `fav_sentence_dao.dart` | 收藏例句（JSON 序列化到 SharedPreferences） | SharedPreferences |
| `wallpaper_data.dart` | 壁纸预设 + 用户选择持久化 | SharedPreferences |
| `example_parser.dart` | 例句 JSON 解析器（纯工具类，无持久化） | 无 |

### 1.2 `lib/state/` 目录（2 个文件）

| 文件 | 职责 | 存储后端 |
|---|---|---|
| `learning_state.dart` | 学习状态管理（SRS 卡片、收藏、已掌握、每日统计、连续天数） | SharedPreferences（散装 getInstance） |
| `wallpaper_state.dart` | 壁纸状态管理（ChangeNotifier） | 委托 WallpaperData |

### 1.3 `lib/theme/` 目录（2 个文件）

| 文件 | 职责 |
|---|---|
| `skin_system.dart` | 皮肤系统（ThemeVars / ThemePreset / SkinSystem / SkinProvider） |
| `app_theme.dart` | 兼容桥接，re-export `design_tokens.dart` |

### 1.4 不存在的目录

- `lib/db/` — 不存在
- `lib/repositories/` — 不存在

---

## 二、数据库清单

### 2.1 SQLite 数据库

| 数据库 | 文件 | 模式 | 表 |
|---|---|---|---|
| 词库 | `wordbook.db`（从 `assets/db/wordbook.db.gz` 解压） | **只读** | `words`（id/word/main_word/interpret/uk_pron/us_pron/phrase/example/confuse/audio_urls/image_urls/word_root）、`books`（id/code/name/word_count）、`word_books`（word_id↔book_id 关联） |
| 用户数据 | `user_data.db` | 读写 | `favorites`（id/word_id/created_at） |
| 学习进度 | 同 `user_data.db`（或独立，由 UserProcessDatabase 管理） | 读写 | `user_process_history`（id/user_id/word/state/level/position/reviewdate/process/success/fail/duration/efactor/r1/r2/reFail/reSuccess/comeFrom/updatetime/learnFrom/zpk/word_id）、`user_sync_v3`（synTime/userId） |
| 笔记 | `notes.db` | 读写 | `word_notes`（id/word_id/word/content/created_at/updated_at） |

### 2.2 SQLite 词库规模

- 词条总数：32,154 条（来源：音标清洗审计）
- 词书数量：191 本（来源：词书名解码方案）
- 存储格式：gzip 压缩后作为 Flutter asset 打包，首次启动解压到 Application Support 目录

---

## 三、SharedPreferences 键值对全清单

### 3.1 AppPreferences（`app_preferences.dart`，key 前缀：`sysData` 等效）

| 常量名 | 键字符串 | 类型 | 用途 | ⭐ 重构相关 |
|---|---|---|---|---|
| `appConfig` | `app_config_list` | String | 应用配置列表 | |
| `appLastRunTime` | `key_appRunLastTime` | — | 上次运行时间 | |
| `appNeedMigrateToV3` | `app_need_migrate_to_v3` | — | v3 迁移标记 | |
| `userToken` | `user_token` | String | 用户 token | |
| `userSecret` | `user_secret` | String | 用户 secret | |
| `userId` | `key_userId` | String | 用户 ID | |
| `pronounce` | `key_pronounceType` | int | 发音类型（0=美音 1=英音） | |
| **`uiTheme`** | **`ui_theme`** | **int** | **旧版 UI 主题** | **⚠️ 冲突键——已被 int 占用，批1 禁用** |
| `bookGroupList` | `key_group_library_List_v3_2` | String | 词书分组列表 | |
| `extensiveMode` | `extensive_mode` | — | 泛在模式 | |
| `studyRemindText` | `study_remind_text` | — | 学习提醒文字 | |
| `netLineType` | `key_net_line_type` | — | 网络线路类型 | |
| `searchHistory` | `key_search_history` | StringList | 搜索历史（最多50条） | |
| `lastLoginInfo` | `key_last_login_info` | String | 最后登录信息 | |
| `historyQuery` | `history_query` | String | 历史查询 | |
| `appUserRulesAgree` | `app_user_rules_agree` | bool | 用户规则同意 | |
| `appPermissionGrantShow` | `app_permission_grant_show` | bool | 权限提示展示 | |
| `keyAppFirstCheckin` | `key_app_first_checkin` | — | 首次签到 | |
| `keyUserTrackEnable` | `key_user_track_enable` | int | 用户追踪开关 | |
| **`skinThemeId`** | **`skin_theme_id`** | **String** | **皮肤主题 ID（bright/dark/pure_black）** | **✅ 批1 新增** |
| **`skinFollowSystem`** | **`skin_follow_system`** | **bool** | **跟随系统主题** | **✅ 批1 新增** |

### 3.2 AppPreferencesExt 补充键（`app_preferences_ext.dart`）

| 常量名 | 键字符串 | 类型 | 用途 |
|---|---|---|---|
| `appOldWordProcessSynced` | `app_old_word_process_synced` | bool | 旧单词进程同步标记 |
| `appUserTestMode` | `app_usre_test_mode` | bool | 测试模式（注意 typo） |
| `calendarPermissionHasApply` | `calendar_permission_has_apply` | bool | 日历权限 |
| `currentWallpaperPre` | `current_wallpater_pre` + themeType | String | 当前壁纸 ID（动态 key） |
| `extensivePlaying` | `extensive_playing` | bool | 泛在播放状态 |
| `keyBgPicLookedPre` | `key_bg_pic_looked_pre` + suffix | bool | 背景图片查看标记 |
| `keyClickBookCount` | `KEY_CLCIK_BOOK_COUNT` | int | 书籍点击计数 |
| `keyClickSentenceCount` | `KEY_CLCIK_SENTENCE_COUNT` | int | 句子点击计数 |
| `keyCloseFloatButtonPre` | `key_close_float_button_` + suffix | bool | 浮窗按钮关闭 |
| `keyCurVersionFirstRuntimeSuffix` | `key_first_runtime_` + version | bool | 版本首次运行 |
| `keyCurVersionHasShowQtSuffix` | `key_has_show_qt_suffix_` + version | bool | QT 展示标记 |
| `keyHasClickCollins` | `key_has_click_collins` | bool | Collins 点击 |
| `keyHasHistoryLogined` | `key_has_history_logined` | bool | 历史登录标记 |
| `keyInstalledType` | `key_install_overlay` | int | 覆盖安装类型 |
| `keyLastErrorUrl` | `key_last_error_url` | String | 最后错误 URL |
| `keyLastStartAppVersionCode` | `key_last_start_app_version_code` | int | 上次启动版本号 |
| `keyLearnCardTitleClickCount` | `key_learn_card_title_click_count` | int | 学习卡片标题点击计数 |
| `keyListListenAdvExampleChSwitch` | `key_list_listen_adv_example_ch_switch` | bool | 听力-例句中文开关 |
| `keyListListenAdvWordInterpretSwitch` | `key_list_listen_adv_word_interpret_switch` | bool | 听力-释义开关 |
| `keyListListenBaseSpellSwitch` | `key_list_listen_base_spell_switch` | bool | 听力-拼写开关 |
| `keyListListenHasOpened` | `key_list_listen_has_opened` | bool | 听力是否已打开 |
| `keyListListenPlayCount` | `key_list_listen_play_count` | int | 听力播放次数 |
| `keyListListenPlayInterval` | `key_list_listen_play_interval` | int | 听力播放间隔 |
| `keyListListenPlayNextAuto` | `key_list_listen_play_next_auto` | bool | 听力自动播放下一首 |
| `keyLocalMessageUnread` | `key_loacal_message_unread` + userId | int | 本地未读消息（动态 key） |
| `keyNewUserAbtestMap` | `key_new_user_abtest_level_map` | String | 新用户 AB 测试 |
| `keyRewardFinishFirstLearn` | `key_reward_finish_first_learn` | bool | 首次学习奖励 |
| `keyRewardFinishFirstSpell` | `key_reward_finish_first_spell` | bool | 首次拼写奖励 |
| `keyRewardFinishTodayReview` | `key_reward_finish_today_review` | bool | 今日复习奖励 |
| `keyUserMessageSuffix` | `key_user_message_suffix_` + userId | int | 用户消息时间（动态 key） |
| `keyVersionAppLaunchCountSuffix` | `key_version_app_launch_count_suffix` + version | int | 版本启动计数（动态 key） |
| `keyVersionRateOptionsSuffix` | `key_version_rate_options_` + version | String | 版本评分选项（动态 key） |
| `keyVersionFirstLaunchTimeSuffix` | `key_vertion_first_launch_time_suffix` + version | int | 版本首次启动时间（动态 key） |
| `needNewWordPeriodData` | `need_new_word_period_data` | bool | 新词周期数据标记 |
| `newWordPeriodData` | `new_word_period_data` | String | 新词周期数据 |
| `nextWallpaperPre` | `next_wallpater_pre` + themeType | String | 下次壁纸 ID（动态 key） |
| `yiwenHasClicked` | `yiwen_has_clicked` | bool | 依文点击标记 |

### 3.3 UserPreferences（`app_preferences.dart`）

| 常量名 | 键字符串 | 类型 | 用途 |
|---|---|---|---|
| `autoPlay` | `auto_play_voice` | bool | 自动发音 |
| `checkInDate` | `checkIn_date` | String | 签到日期 |
| `enableLockScreen` | `enable_lock_screen` | bool | 锁屏学单词 |
| `learnedNum` | `learnedCount` | int | 今日已学数量 |
| `learnedFinishedGroupList` | `learned_finished_group_list` | String | 已完成学习组列表 |
| `lexisBook` | `library_learning` | String | 当前选择的词书 |
| `includeNewWord` | `includeNewWord` | bool | 是否包含生词本 |
| `settingLearnStrategy` | `setting_learn_strategy_` | String | 学习策略 |
| `settingLearnStrategy20Level` | `setting_learn_strategy20_level_` | String | 学习策略20级 |
| `defaultShowWordroot` | `default_show_wordroot` | bool | 词根展示 |
| `offlineSpeech` | `offLine_speech` | — | 离线语音 |
| `lastClickPanel` | `last_click_panel` | — | 最后点击面板 |
| `lastClickSimplePanel` | `last_click_simple_panel` | — | 最后简单面板点击 |
| `firstGroupLearnComplete` | `first_group_learn_complete` | — | 首组学习完成 |
| `deletedWord` | `firstDelWord` | — | 首个删除单词 |
| `shareDate` | `shared_date` | — | 分享日期 |
| `remindEnable` | `remind_user` | bool | 学习提醒开关 |
| `remindTime` | `remind_time` | String | 提醒时间 |
| `feedbackUnreadCount` | `feedback_unread_count` | — | 反馈未读数 |

### 3.4 UserPreferencesExt 补充键（`app_preferences_ext.dart`）

| 常量名 | 键字符串 | 类型 | 用途 |
|---|---|---|---|
| `collinsExpireHasShowIntro` | `collins_expire_has_show_intro` | bool | Collins 过期提示 |
| `exampleDisplayYiwen` | `example_display_yiwen` | bool | 例句显示译文 |
| `favSentenceLastSentenceId` | `fav_sentence_last_sentence_id` | int | 收藏句子最后 ID |
| `favSentenceLastWordId` | `fav_sentence_last_word_id` | int | 收藏句子最后单词 ID |
| `learnFirstGroupCompleteData` | `learn_first_group_complete_data` | String | 首组完成数据 |
| `learnFirstGroupSpellCompleteData` | `learn_first_group_spell_complete_data` | String | 首组拼写完成数据 |
| `listenPosPrefix` | `listen_pos_prefix_` + suffix | int | 听力位置记录（动态 key） |
| `lockWallpaperPre` | `lock_wallpaper_` + themeType | bool | 锁屏壁纸（动态 key） |
| `newWordLastClickWordId` | `new_word_last_click_word_id` | int | 生词本最后点击 |
| `noMoreLockscreenPermissionTip` | `no_more_lockscreen_permission_tip` | bool | 锁屏权限提示 |
| `password` | `userPwd` | String | 密码（已废弃） |
| `settingStrategyHasArtificiallyTriggered` | `setting_strategy_has_artificallytriggered_` + suffix | bool | 策略人工触发标记 |
| `synTimeLexisOld` | `synTime_lexis` | String | 旧版词书同步时间 |
| `synTimeNewword` | `syn_time_newword` | String | 生词同步时间 |
| `synTimeWordOld` | `synTime_word` | String | 旧版单词同步时间 |
| `synTimeWordProcess` | `syn_time_word_process` | String | 单词进程同步时间 |
| `userConfigPre` | `user_config_` + suffix | String | 用户配置（动态 key） |
| `userInfo` | `userInfo` | String | 用户信息 Bean JSON（用户级 key） |
| `weekLearnSignStatus` | `week_learn_sign_status` | String | 周学习签到状态 |
| `wordLearnCompleteCount` | `word_learn_complete_count` | int | 单词学习完成计数 |

### 3.5 GuidePreference（`app_preferences.dart`）

| 常量名 | 键字符串 | 类型 | 用途 |
|---|---|---|---|
| `guideLearn` | `guide_learn` | bool | 学习引导已展示 |
| `guideReview` | `guide_review` | bool | 复习引导已展示 |
| `guideMain` | `guide_main` | bool | 主页引导已展示 |
| `guideSpell` | `guide_spell` | bool | 拼写引导已展示 |

### 3.6 GuidePreferenceExt 补充键（`app_preferences_ext.dart`）

约 40+ 个引导相关键，包括：

- `guide_app_start_count` / `guide_click_fix_word` / `guide_click_sound_switch`
- `guide_example_*` 系列（例句相关引导，约 8 个）
- `guide_root_*` 系列（词根相关引导，约 3 个）
- `guide_recall_tip_click_count` / `guide_word_right_count` / `guide_word_select_choice`
- `v3_guide_*` 系列（v3 引导状态，约 12 个）
- `guide_finished_learn_group_count` / `guide_learn_record_migrated` / `guide_share_achievement_migrated`
- `guide_list_word_listen_setting_showed` / `guide_show_lrsetting` / `headset_option_introduce`

### 3.7 AuthDataPreferences（独立 SP 文件 `"auth_data"`）

| 键模式 | 类型 | 用途 |
|---|---|---|
| `platforms` | StringList | 已授权平台集合 |
| `current_auth_platform` | String | 当前授权平台 |
| `{platform}_uid` | String | 平台用户 ID |
| `{platform}_at` | String | 平台 Access Token |
| `{platform}_rt` | String | 平台 Refresh Token |
| `{platform}_ei` | String | 平台 Token 过期时间 |

### 3.8 散装 SharedPreferences（直接 getInstance，未走 AppPreferences 封装）

| 文件 | 键 | 类型 | 用途 |
|---|---|---|---|
| `learning_state.dart` | `srs_cards_v1` | String | SRS 卡片 JSON |
| `learning_state.dart` | `favorite_words_v1` | StringList | 收藏单词列表 |
| `learning_state.dart` | `mastered_words_v1` | StringList | 已掌握单词列表 |
| `learning_state.dart` | `daily_stats_v1` | String | 每日学习统计 JSON |
| `learning_state.dart` | `active_learn_dates_v1` | StringList | 活跃学习日期集合 |
| `learning_state.dart` | `daily_new_words_v1` | int | 每日新学词数 |
| `wallpaper_data.dart` | `selected_wallpaper_id` | String | 用户选择的壁纸 ID |
| `fav_sentence_dao.dart` | `fav_sentence_list` | String | 收藏例句 JSON |
| `settings_page.dart` | 未确认 | — | 设置页散装读写 |

---

## 四、uiTheme 键冲突详细分析

### 4.1 现状

- **键名**：`ui_theme`
- **定义位置**：`app_preferences.dart:65` — `static const String uiTheme = 'ui_theme';`
- **类型**：`int`（通过 `AppPreferencesExt.getUITheme()` / `setUITheme()` 读写，`app_preferences_ext.dart:263-264`）
- **用途**：旧版 UI 主题选择器（整数编码，具体含义待查）

### 4.2 冲突风险

批1 新增的 `skinThemeId`（`skin_theme_id`）和 `skinFollowSystem`（`skin_follow_system`）**使用了独立的新键**，与 `ui_theme` 完全隔离。

**关键约束**（来源：`batch1_tech_spec.md` §2.1）：
> ⚠️ 禁用已被 int 占用的 uiTheme 键（app_preferences.dart:65 / app_preferences_ext.dart:263-264）。若往同一 key 写 String，SharedPreferences 将出现类型冲突（读 int 得到异常）。

**当前状态**：批1 实施已遵守此约束，使用了新键。但 `ui_theme` 键本身仍存在于代码中，未来需要决定是否废弃/迁移。

---

## 五、星巴克重构相关存储键标记

### 5.1 批1 已新增（✅ 已落地）

| 键 | 类型 | 来源文件 | 用途 |
|---|---|---|---|
| `skin_theme_id` | String | `app_preferences.dart:79` | 皮肤主题 ID（bright/dark/pure_black） |
| `skin_follow_system` | bool | `app_preferences.dart:80` | 跟随系统主题开关 |

### 5.2 需要关注的旧键（⚠️ 待迁移/废弃）

| 键 | 问题 | 建议 |
|---|---|---|
| `ui_theme` (int) | 旧版主题编码，与新皮肤系统并存 | 建议批2+ 废弃，读取时做迁移映射（int→skin_theme_id） |
| `selected_wallpaper_id` (String) | 壁纸系统独立于主题，星巴克重构后壁纸是否保留？ | 待产品决策：若星巴克主题接管全量配色，壁纸系统可能需要对齐 |
| `current_wallpater_pre{themeType}` (String) | 壁纸按主题类型分，但 key 有 typo（wallpater） | 批2+ 统一修复 typo |

### 5.3 ThemeVars 语义令牌与存储的关系

当前 `ThemeVars`（`skin_system.dart:6-83`）有 **30 个语义字段**：

```
pageBg, cardBg, cardBgAlt, text1, text2, text3, divider, accent, success, danger, teal,
tabBarIcon, onGlassText1, onGlassText2, onGlassAccent, glassBg, glassBgStrong, glassBorder,
wallpaperScrim, modalGlassBg, modalText1, modalText2, quizCorrectBg, quizCorrectText,
quizWrongBg, quizWrongText, vipGoldBg, vipGoldText, profileDecor
```

这些字段**不直接持久化**——它们由 `skin_system.dart` 中的 `themes` 表硬编码（三个主题预设），通过 `SkinSystem.currentTheme.vars` 运行时访问。星巴克重构（重构16 Token 草案）将替换这些硬编码值为新的星巴克色值。

---

## 六、存储架构健康度评估

### 6.1 问题清单

| # | 问题 | 严重度 | 说明 |
|---|---|---|---|
| P1 | **散装 SharedPreferences 调用** | 中 | `learning_state.dart` 有 12 处直接 `getInstance()`，`wallpaper_data.dart` 2 处，`fav_sentence_dao.dart` 2 处，`settings_page.dart` 2 处。未走 `AppPreferences` 单例，导致：①初始化时序不可控 ②无法统一管理 key ③测试困难 |
| P2 | **ui_theme 键 int/String 类型冲突** | 高 | `app_preferences_ext.dart:263` 以 int 读取，若未来任何代码往同 key 写 String 将崩溃。批1 已规避，但该键仍"活着" |
| P3 | **UserPreferencesExt 用户级 key 隔离方案** | 低 | 使用 `{userId}.{key}` 前缀模拟多用户隔离（`app_preferences_ext.dart:612-615`），但 Android 原版用独立 SP 文件。当前无多用户并发场景，风险可控 |
| P4 | **FavSentenceDao 自建 SP 实例** | 低 | `fav_sentence_dao.dart` 自己 `getInstance()` 而非复用 `AppPreferences`，与 P1 同类问题 |

### 6.2 架构亮点

- **读写分离**：`wordbook_database.dart` 严格只读（`openDatabase(dbPath, readOnly: true)`），用户数据独立数据库
- **单例模式一致**：所有数据库类（WordBookDatabase / UserDatabase / NoteDatabase）均使用 `static final instance` 单例
- **批1 持久化方案规范**：新增键走 `AppPreferences` 封装，读盘放 `main()` await 段，fire-and-forget 写盘

---

## 七、参考文档

- `docs/batch1_tech_spec.md` — 批1 技术规格（亮度拆分 / 主题持久化 / 跟随系统）
- `lib/theme/skin_system.dart` — 皮肤系统实现（ThemeVars 30 字段、三主题预设、SkinSystem 状态机）
- `lib/data/app_preferences.dart` — 基础偏好层
- `lib/data/app_preferences_ext.dart` — 扩展偏好层
