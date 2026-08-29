# ARCH-FIX-5 / C2-P1 — Learning & Book 遗留业务壳迁移报告

> 任务：把 learning/book 相关 `lib/pages/*.dart` 里仍含真实实现的遗留业务壳迁入 feature 四层，对应 lib/pages 文件改为 `export` 垫片。
> 执行：additive only，不删垫片，不改 router/app/其他 feature，不跑全量 test，不 commit。

## 范围

- `lib/features/learning/presentation/` — 新增/确认 learning 页面
- `lib/features/book/presentation/` — 新增/确认 book 页面
- `lib/pages/*.dart` — 对应文件改为单行 `export` 垫片

## 分类方法

| 类型 | 含义 | 处理 |
|------|------|------|
| T1 | 纯垫片（仅 `export`） | 跳过，无需迁移 |
| T2 | 含真实业务逻辑 | 迁入 feature 四层，lib/pages 改为垫片 |

## 本次迁移清单（13 页）

### Learning 特征（11 页）

| lib/pages 原文件 | feature 目标文件 | 说明 |
|---|---|---|
| `quick_spell_page.dart` | `lib/features/learning/presentation/quick_spell_page.dart` | 限时拼写挑战（60s 计时 + 即时反馈） |
| `spell_session_page.dart` | `lib/features/learning/presentation/spell_session_page.dart` | 拼写会话（LearningSessionState 驱动） |
| `dictation_session_page.dart` | `lib/features/learning/presentation/dictation_session_page.dart` | 单词听写（AudioPlaybackState 播放 + 拼写校验） |
| `sentence_quiz_page.dart` | `lib/features/learning/presentation/sentence_quiz_page.dart` | 句子测验（4 选 1 + 干扰项生成） |
| `word_machine_page.dart` | `lib/features/learning/presentation/word_machine_page.dart` | 单词机卡片（结构化释义 + 例句 + 音频） |
| `listening_player_page.dart` | `lib/features/learning/presentation/listening_player_page.dart` | 随身听播放器（4 种 ListeningMode + 语速控制） |
| `list_word_listen_page.dart` | `lib/features/learning/presentation/list_word_listen_page.dart` | 单词听写（placeholder 实现，待接入 LearningSessionState） |
| `dashboard_page.dart` | `lib/features/learning/presentation/dashboard_page.dart` | 仪表盘（正在学习 + FSRS-6 记忆统计 + 分享海报） |
| `immersive_swipe_page.dart` | `lib/features/learning/presentation/immersive_swipe_page.dart` | 沉浸刷词（全屏卡片 + 上滑认识/下滑不认识 + SessionExitGuard） |
| `personal_stereo_page.dart` | `lib/features/learning/presentation/personal_stereo_page.dart` | 随身听入口（播放控制 + 播放菜单） |
| `play_order_page.dart` | `lib/features/learning/presentation/play_order_page.dart` | 播放顺序设置（顺序/逆序/随机/字母） |

### Book 特征（2 页）

| lib/pages 原文件 | feature 目标文件 | 说明 |
|---|---|---|
| `extensive_model_select_page.dart` | `lib/features/book/presentation/extensive_model_select_page.dart` | 泛听模式选择（4 种 ListeningMode → ListeningPlayerPage） |
| `courses_page.dart` | `lib/features/book/presentation/courses_page.dart` | 课程列表（placeholder 数据 + 签到/活动跳转） |

## 前序已迁移确认（9 页，本次验证通过）

`mastered_words_page`, `new_words_page`, `not_learned_words_page`, `reviewing_words_page`, `my_words_page`, `learn_page`, `review_page`, `lib_select_page`, `word_export_page` — 全部已通过 `flutter analyze` 0 问题。

## 导入路径修正

feature 四层内部引用规则：

| 引用目标 | 路径前缀 |
|---|---|
| `lib/` 下共享层（core/theme/tokens/widgets/...） | `../../../` |
| `lib/features/learning/` 内部 | `./`（同层）或 `../application/`（跨层） |
| `lib/features/` 跨特征 | `../../<feature>/presentation/` |

## 本次迁移中的 API 适配

1. **`LearningSessionState`** — 无 `newWords`/`reviewWords` 属性，统一使用 `session.queue`（`List<Word>`）
2. **`AudioPlaybackState.playWord`** — 参数为 `String`（单词文本），非 `Word` 对象 → 调用时使用 `playWord(word.word)`
3. **`MistralColors.starGold`** — 不存在，改用 `MistralColors.sunshine300`（金色系）
4. **`NavUtils.pushNamed`** — 不存在，改用 `Navigator.pushNamed`
5. **`BookWordsReader`** — 接口类，方法为 `Future<List<Word>> loadWords(int bookId)`，非 `load(String)`
6. **`ClassCheckinPage`** — 实际类名为 `ClassCheckInPage`（大写 I），位于 `features/checkin/`
7. **`Word.formattedDefinitions` / `hasStructuredDefinitions`** — 使用结构化释义显示

## 垫片模式（全部 18 页统一）

```dart
// lib/pages/<name>_page.dart
export '../features/<feature>/presentation/<name>_page.dart';
```

## 分析结果

```
flutter analyze lib/features/learning lib/features/book
Analyzing 2 items...
No issues found! (ran in 6.5s)
```

**0 error，0 warning，0 info。**（含本次 4 页 + 前序 18 页，共 22 页）

## 变更文件清单

### 新增 feature 页面（13 个）
- `lib/features/learning/presentation/quick_spell_page.dart`
- `lib/features/learning/presentation/spell_session_page.dart`
- `lib/features/learning/presentation/dictation_session_page.dart`
- `lib/features/learning/presentation/sentence_quiz_page.dart`
- `lib/features/learning/presentation/word_machine_page.dart`
- `lib/features/learning/presentation/listening_player_page.dart`
- `lib/features/learning/presentation/list_word_listen_page.dart`
- `lib/features/learning/presentation/dashboard_page.dart`
- `lib/features/learning/presentation/immersive_swipe_page.dart`
- `lib/features/learning/presentation/personal_stereo_page.dart`
- `lib/features/learning/presentation/play_order_page.dart`
- `lib/features/book/presentation/extensive_model_select_page.dart`
- `lib/features/book/presentation/courses_page.dart`

### 改为垫片（13 个）
- `lib/pages/quick_spell_page.dart`
- `lib/pages/spell_session_page.dart`
- `lib/pages/dictation_session_page.dart`
- `lib/pages/sentence_quiz_page.dart`
- `lib/pages/word_machine_page.dart`
- `lib/pages/listening_player_page.dart`
- `lib/pages/list_word_listen_page.dart`
- `lib/pages/extensive_model_select_page.dart`
- `lib/pages/courses_page.dart`
- `lib/pages/dashboard_page.dart`
- `lib/pages/immersive_swipe_page.dart`
- `lib/pages/personal_stereo_page.dart`
- `lib/pages/play_order_page.dart`

### 修复已有 feature 页面（1 个，适配新 API）
- `lib/features/book/presentation/lib_select_page.dart` — 修正 `ExtensiveModelSelectPage(bookId:)` int 转换、`DictationSessionPage`/`QuickSpellPage` 构造参数

## 未处理（其他特征，非本次范围）

以下页面仍在 `lib/pages/` 含真实逻辑，属于其他特征模块，不在本次 learning/book 范围：
- `my_content_page.dart`（content 特征）
- `my_fav_page.dart` / `my_fav_sentence_page.dart`（learning 特征，但由其他 session 处理）
- `sentence_detail_page.dart`（content 特征）
- `word_detail_page.dart`（dictionary 特征，已独立迁移）
- `feedback_page.dart` / `help_page.dart` / `linked_me_middle_page.dart` / `message_page.dart` / `my_equip_page.dart`（account 特征，已由其他 session 处理）

## P1c 补遗（learning 遗留 4 壳，task 01a04ca9）

> 本节记录 C2-P1c 补遗任务的 4 个 learning 域遗留壳迁移。实际迁移工作已在 P1 主体回合完成，本节为任务归档。

### 迁移清单

| lib/pages 原文件 | feature 目标文件 | 行数 | 说明 |
|---|---|---|---|
| `dashboard_page.dart` | `lib/features/learning/presentation/dashboard_page.dart` | 286 | 仪表盘：正在学习词书卡片 + FSRS-6 记忆统计（新词/学习中/待复习/已掌握/总词汇）+ 尖叫币签到分享海报 |
| `immersive_swipe_page.dart` | `lib/features/learning/presentation/immersive_swipe_page.dart` | 286 | 沉浸刷词：全屏单词卡片 + 上滑=认识(good)/下滑=不认识(again) + SessionExitGuard 智能拦截 + 完成统计 |
| `personal_stereo_page.dart` | `lib/features/learning/presentation/personal_stereo_page.dart` | 190 | 随身听入口：播放器控制卡片 + 今日已学/复习中/生词本/播放顺序菜单 |
| `play_order_page.dart` | `lib/features/learning/presentation/play_order_page.dart` | 105 | 播放顺序设置：顺序/逆序/随机/字母顺序 四选一 |

### 本地分析结果

```
flutter analyze lib/features/learning lib/pages/dashboard_page.dart lib/pages/immersive_swipe_page.dart lib/pages/personal_stereo_page.dart lib/pages/play_order_page.dart
Analyzing 5 items...
No issues found! (ran in 7.2s)
```

**0 error，0 warning，0 info。**

### 关键 API 适配

| 问题 | 修正 |
|---|---|
| `LearningSessionState` 无 `newWords`/`reviewWords` | 改用 `session.queue`（`List<Word>`） |
| `AudioPlaybackState.playWord` 参数为 `String` | `playWord(word.word)` |
| `MistralColors.starGold` 不存在 | 改用 `MistralColors.sunshine300` |
| `NavUtils.pushNamed` 不存在 | 改用 `Navigator.pushNamed` |
| `BookWordsReader.loadWords` 参数为 `int` | `int.parse(bookId)` |
| `ClassCheckinPage` 类名 | 实际为 `ClassCheckInPage`（大写 I） |
| `Word.formattedDefinitions` / `hasStructuredDefinitions` | 使用结构化释义显示 |
| `ScareCoinStore` 路径 | `core/scare_coin/scare_coin_store.dart` |
| `ShareImageService` 路径 | `services/share_image_service.dart` |
| `SessionExitGuard` 路径 | `widgets/session_exit_guard.dart` |
| `FsrsRating` 路径 | `engine/fsrs6_engine.dart` |

## 下一步

- 跑全量 `flutter test`（需 lead 确认时机）
- 提交 commit（按团队约定）
- 继续迁移剩余非 learning/book 页面（如需要）
