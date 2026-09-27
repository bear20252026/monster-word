# Phase 5 页面迁移计划 — 分层架构

> 生成时间：2026-08-26
> 目标：将所有页面迁移到 ViewModel → Service → Repository 分层架构

---

## 一、新架构概览

```
┌─────────────────────────────────────────────────────┐
│                    UI Layer (Pages)                  │
│              只依赖 ViewModel/State                  │
├─────────────────────────────────────────────────────┤
│               ViewModel Layer (State)                │
│         LearnState, ReviewState, PlayerState         │
├─────────────────────────────────────────────────────┤
│                Service Layer                         │
│    LearnService, ReviewService, AudioService         │
├─────────────────────────────────────────────────────┤
│              Repository Layer                        │
│    WordRepository, BookRepository, UserRepository    │
├─────────────────────────────────────────────────────┤
│                 Data Layer                           │
│         WordBookDatabase, DAOs                       │
└─────────────────────────────────────────────────────┘
```

**依赖注入**：`lib/core/di/service_locator.dart` (GetIt)
**使用方式**：`final learnService = sl<LearnService>();`

---

## 二、当前页面依赖分析

### 2.1 Learn 模块页面

| 页面 | data/ 依赖 | engine/ 依赖 | player/ 依赖 | 迁移难度 |
|------|-----------|-------------|-------------|---------|
| `learn_page.dart` | - | fsrs6_engine | audio_players | 中 |
| `learn_session.dart` | example_parser | fsrs6_engine | - | 中 |
| `review_page.dart` | wordbook_database, wallpaper_data | core_engine, fsrs6_engine, srs_engine, super_memory_engine | audio_players | 高 |
| `review_session.dart` | example_parser, wordbook_database | core_engine, fsrs6_engine, srs_engine, super_memory_engine | - | 高 |
| `word_detail_page.dart` | example_parser, dictionary_extra, fav_sentence_dao, note_database, wordbook_database | fsrs6_engine | audio_players | 高 |
| `word_machine_page.dart` | - | fsrs6_engine | audio_players | 中 |
| `immersive_swipe_page.dart` | - | fsrs6_engine | - | 低 |
| `lib_select_page.dart` | wordbook_database | - | - | 低 |
| `book_words_page.dart` | wordbook_database | - | - | 低 |
| `dashboard_page.dart` | wordbook_database | - | - | 低 |

### 2.2 Player 模块页面

| 页面 | data/ 依赖 | engine/ 依赖 | player/ 依赖 | 迁移难度 |
|------|-----------|-------------|-------------|---------|
| `listening_player_page.dart` | wordbook_database | - | system_tts | 中 |
| `dictation_session_page.dart` | wordbook_database | - | system_tts | 中 |
| `spell_session_page.dart` | - | - | audio_players | 低 |
| `spell_check_page.dart` | - | - | audio_players | 低 |
| `personal_stereo_page.dart` | - | - | - | 无 |
| `play_order_page.dart` | - | - | - | 无 |
| `list_word_listen_page.dart` | - | - | - | 无 |

### 2.3 CheckIn 模块页面

| 页面 | data/ 依赖 | engine/ 依赖 | player/ 依赖 | 迁移难度 |
|------|-----------|-------------|-------------|---------|
| `check_in_history_page.dart` | - (使用 ScareCoinLedger) | - | - | 低 |
| `scare_coin_history_page.dart` | - (使用 ScareCoinLedger) | - | - | 低 |

### 2.4 User 模块页面

| 页面 | data/ 依赖 | engine/ 依赖 | player/ 依赖 | 迁移难度 |
|------|-----------|-------------|-------------|---------|
| `login_page.dart` | - | - | - | 无 |
| `my_fav_page.dart` | - | - | - | 无 |
| `my_fav_sentence_page.dart` | fav_sentence_dao | - | - | 低 |
| `message_page.dart` | - | - | - | 无 |
| `my_words_page.dart` | - | - | - | 无 |
| `new_words_page.dart` | - | - | - | 无 |
| `mastered_words_page.dart` | - | - | - | 无 |
| `not_learned_words_page.dart` | - | - | - | 无 |
| `reviewing_words_page.dart` | - | - | - | 无 |
| `user_info_manage_page.dart` | app_preferences | - | - | 低 |
| `account_info_page.dart` | app_preferences | - | - | 低 |
| `my_space_page.dart` | app_preferences | - | - | 低 |

### 2.5 Content 模块页面

| 页面 | data/ 依赖 | engine/ 依赖 | player/ 依赖 | 迁移难度 |
|------|-----------|-------------|-------------|---------|
| `search_page.dart` | app_preferences, example_parser, wordbook_database | - | audio_players | 中 |
| `dictionary_page.dart` | example_parser, wordbook_database | - | audio_players | 中 |
| `sentence_quiz_page.dart` | example_parser | - | - | 低 |
| `sentence_detail_page.dart` | - | - | - | 无 |
| `courses_page.dart` | - | - | - | 无 |
| `word_export_page.dart` | wordbook_database | - | - | 低 |
| `quick_spell_page.dart` | wordbook_database | - | - | 低 |
| `exam_quick_review_page.dart` | wordbook_database | - | - | 低 |

### 2.6 Screens 模块

| 页面 | data/ 依赖 | engine/ 依赖 | player/ 依赖 | 迁移难度 |
|------|-----------|-------------|-------------|---------|
| `home_screen.dart` | wordbook_database | - | - | 低 |
| `profile_screen.dart` | app_preferences | - | - | 低 |
| `learn_session.dart` | example_parser | fsrs6_engine | - | 中 |
| `review_session.dart` | example_parser, wordbook_database | core_engine, fsrs6_engine, srs_engine, super_memory_engine | - | 高 |

---

## 三、迁移计划（按模块分批）

### 批次 1：低难度页面（预计 1-2 天）

**目标**：无依赖或简单 data/ 依赖的页面

| 页面 | 迁移步骤 |
|------|---------|
| `login_page.dart` | 无依赖，无需迁移 |
| `my_fav_page.dart` | 已使用 LearningState，无需迁移 |
| `message_page.dart` | 无依赖，无需迁移 |
| `courses_page.dart` | 无依赖，无需迁移 |
| `sentence_detail_page.dart` | 无依赖，无需迁移 |
| `personal_stereo_page.dart` | 无依赖，无需迁移 |
| `play_order_page.dart` | 无依赖，无需迁移 |
| `list_word_listen_page.dart` | 无依赖，无需迁移 |
| `my_words_page.dart` | 无依赖，无需迁移 |
| `new_words_page.dart` | 无依赖，无需迁移 |
| `mastered_words_page.dart` | 无依赖，无需迁移 |
| `not_learned_words_page.dart` | 无依赖，无需迁移 |
| `reviewing_words_page.dart` | 无依赖，无需迁移 |
| `immersive_swipe_page.dart` | 移除 `engine/fsrs6_engine.dart` → 使用 `LearnService` |
| `spell_session_page.dart` | 移除 `player/audio_players.dart` → 使用 `AudioService` |
| `spell_check_page.dart` | 移除 `player/audio_players.dart` → 使用 `AudioService` |
| `check_in_history_page.dart` | 已使用 `ScareCoinLedger`，可迁移到 `CheckInService` |
| `scare_coin_history_page.dart` | 同上 |

### 批次 2：中等难度页面（预计 2-3 天）

**目标**：单一 data/ 或 player/ 依赖的页面

| 页面 | 迁移步骤 |
|------|---------|
| `home_screen.dart` | 移除 `data/wordbook_database.dart` → 使用 `BookRepository` |
| `profile_screen.dart` | 移除 `data/app_preferences.dart` → 使用 `UserRepository` |
| `lib_select_page.dart` | 移除 `data/wordbook_database.dart` → 使用 `BookRepository` |
| `book_words_page.dart` | 移除 `data/wordbook_database.dart` → 使用 `WordRepository` |
| `dashboard_page.dart` | 移除 `data/wordbook_database.dart` → 使用 `BookRepository` + `StatsRepository` |
| `user_info_manage_page.dart` | 移除 `data/app_preferences.dart` → 使用 `UserRepository` |
| `account_info_page.dart` | 移除 `data/app_preferences.dart` → 使用 `UserRepository` |
| `my_space_page.dart` | 移除 `data/app_preferences.dart` → 使用 `UserRepository` |
| `my_fav_sentence_page.dart` | 移除 `data/fav_sentence_dao.dart` → 使用 `FavRepository` |
| `word_export_page.dart` | 移除 `data/wordbook_database.dart` → 使用 `WordRepository` |
| `quick_spell_page.dart` | 移除 `data/wordbook_database.dart` → 使用 `WordRepository` |
| `exam_quick_review_page.dart` | 移除 `data/wordbook_database.dart` → 使用 `WordRepository` |
| `sentence_quiz_page.dart` | 移除 `data/example_parser.dart` → 使用 `LearnService` |
| `search_page.dart` | 移除 data/player 依赖 → 使用 `WordRepository` + `AudioService` |
| `dictionary_page.dart` | 移除 data/player 依赖 → 使用 `WordRepository` + `AudioService` |
| `listening_player_page.dart` | 移除 data/player 依赖 → 使用 `WordRepository` + `AudioService` |
| `dictation_session_page.dart` | 移除 data/player 依赖 → 使用 `WordRepository` + `AudioService` |

### 批次 3：高难度页面（预计 3-4 天）

**目标**：多层依赖的复杂页面

| 页面 | 迁移步骤 |
|------|---------|
| `learn_page.dart` | 1. 移除 `engine/fsrs6_engine.dart`<br>2. 移除 `player/audio_players.dart`<br>3. 使用 `LearnService` + `LearnState` |
| `learn_session.dart` | 1. 移除 `data/example_parser.dart`<br>2. 移除 `engine/fsrs6_engine.dart`<br>3. 使用 `LearnService` + `LearnState` |
| `word_machine_page.dart` | 1. 移除 `engine/fsrs6_engine.dart`<br>2. 移除 `player/audio_players.dart`<br>3. 使用 `LearnService` + `AudioService` |
| `review_page.dart` | 1. 移除所有 `data/` 依赖<br>2. 移除所有 `engine/` 依赖<br>3. 移除 `player/audio_players.dart`<br>4. 使用 `ReviewService` + `ReviewState` |
| `review_session.dart` | 1. 移除所有 `data/` 依赖<br>2. 移除所有 `engine/` 依赖<br>3. 使用 `ReviewService` + `ReviewState` |
| `word_detail_page.dart` | 1. 移除 5 个 data/ 依赖<br>2. 移除 engine/ 依赖<br>3. 移除 player/ 依赖<br>4. 使用 `WordRepository` + `NoteRepository` + `FavRepository` + `AudioService` |

---

## 四、迁移步骤模板

每个页面迁移遵循以下步骤：

### 步骤 1：识别依赖
```dart
// 迁移前
import '../data/wordbook_database.dart';
import '../engine/fsrs6_engine.dart';
import '../player/audio_players.dart';
```

### 步骤 2：替换为 Service/Repository
```dart
// 迁移后
import '../core/di/service_locator.dart';
import '../services/learn_service.dart';
import '../repositories/word_repository.dart';
```

### 步骤 3：在 State 中初始化
```dart
class _MyPageState extends State<MyPage> {
  late final LearnService _learnService;
  late final WordRepository _wordRepo;
  
  @override
  void initState() {
    super.initState();
    _learnService = sl<LearnService>();
    _wordRepo = sl<WordRepository>();
  }
}
```

### 步骤 4：替换直接调用
```dart
// 迁移前
final words = await WordBookDatabase.instance.searchWords(query);

// 迁移后
final words = await _wordRepo.searchWords(query);
```

---

## 五、验证清单

每个页面迁移后需验证：

- [ ] 功能正常（核心流程可运行）
- [ ] 无 data/ 层直接 import
- [ ] 无 engine/ 层直接 import
- [ ] 无 player/ 层直接 import
- [ ] 通过 Service/Repository 访问数据
- [ ] 无编译错误
- [ ] 无运行时异常

---

## 六、风险与注意事项

1. **ScareCoinLedger**：当前是静态类，需迁移到 `CheckInService`
2. **ExampleParser**：工具类，可保留或封装到 Service
3. **AppPreferences**：可封装到 `UserRepository`
4. **State 依赖**：部分页面已使用 `LearningState`，需确认与新 `LearnState` 的兼容性
5. **测试覆盖**：迁移后需补充单元测试

---

*计划完成。执行时请按批次顺序进行，每批完成后进行验证。*
