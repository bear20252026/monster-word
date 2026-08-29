# ARCH-FIX-4（C1）— app.dart provider 嵌套「语义化」草案（LEAD 备施）

> 预期成果：把 `lib/app/app.dart:37-65` 的 11 层嵌套 feature scope，改为**显式依赖 DAG + 逐层语义注释**，让「分层图」清晰可读而非「11 层括号堆」。
> 状态：**草案（只读规划，未改代码）**——提交时机：UX-FIX-A + ARCH-FIX-2/3 全部落库后再贴到 `app.dart`。
> C1 结论（详见 `arch_coupling_audit.md`）：**不整体扁平化**（会抬高全局可达性=耦合↑），保留嵌套作渠道方向（ancestor=上游渠道）。

---

## 一、当前结构（外→内）

```
buildWordAudioScope(            // [1] core/audio 音频会话
  buildAccountFeatureScope(     // [2] AppSessionController/State, AccountProfile
    buildLearningFeatureScope(  // [3] LearningSession/Queue/Review/Favorites/NewWords/LearningProgressReader
      buildSettingsFeatureScope(// [4] LearningPreferences
        buildSearchFeatureScope(// [5] WordSearch/SearchHistory/ExampleReader/FavoritesAccessor
          buildQuickReviewFeatureScope( // [6] QuickReviewWordReader
            buildBookFeatureScope(      // [7] BookCatalog/BookWords/BookState（依赖 learning 祖先）
              buildScareCoinFeatureScope(// [8] ScareCoinStore（checkin 的祖先渠道）
                buildCheckInFeatureScope(// [9] CheckInHistory/Status/Writer（消费 ScareCoin）
                  buildDictionaryFeatureScope( // [10] 词典 Reader/Writer
                    buildWordBrowseFeatureScope( // [11] WordNotes/SentenceFavorites
                      MultiProvider([SkinSystem, WallpaperState], _AppLifecycle) // 主题/墙纸，内层
                    ))))))))))
```

## 二、各层语义注释（待贴到 app.dart，逐行）

> 原则：每条注明「本 scope 提供什么 / 谁会向它的下层消费 / 它依赖哪个祖先」。已核实的标 ✅，待确认的标 ⚠️（贴码前须再核实）。

- **[1] WordAudio**（最外层）— `core/audio` 音频会话/播放态。`✅ 被全部下游会话页（learn/review/spell/dictation）消费；无上游 provider 依赖，故放最外。`
- **[2] Account** — `AppSessionState(implements AppSessionController)` + AccountProfile。`✅ settings(更多设置)经 AppSessionController.logout 消费（ARCH-FIX-1 渠道化）；Splash 登录检查依赖。无上游依赖。`
- **[3] Learning** — `LearningSessionState/LearningQueue*/Review*/LearningFavoritesStore(core)/NewWordsStore(core)/LearningProgressReader(core)/BookWordsReader(learning 侧)`。`✅ 是 book(G3.2 LearningProgressReader)、search(FavoritesAccessor)、词书会话(LearningSessionStarter) 等的上游渠道；✅ 已核实【不依赖 Account】（learning 无 import features/account、无 AppSession 引用），置于 Account 内层为 DAG 链序选择，非依赖驱动。`
- **[4] Settings** — `LearningPreferencesState`。`消费 Account（ARCH-FIX-1 more_settings 经 AppSessionController.logout）；被 profile/school preference 消费。✅ 已核实【不依赖 learning feature】（LearningPreferences 属 settings 自有领域类，非 learning 模块），位于 learning 内层为链序选择，非依赖驱动。`
- **[5] Search** — `WordSearchReader/SearchHistoryStore/ExampleReader/FavoritesAccessor(经 LearningFavoritesStore)`。`✅ 依赖 learning 祖先(收藏)；无自身上游。`
- **[6] QuickReview** — `QuickReviewWordReader`。`仅读词；依赖较浅。`
- **[7] Book** — `BookCatalogReader/BookWordsReader(book 侧)/BookState`。`✅ 必须位于 learning 内层：BookState 消费 learning 祖先的 LearningProgressReader（WS-4 G3.2）+ LearningSessionStarter（WS-6 C3）。故 [7] 在 [3] 之后。`
- **[8] ScareCoin** — `ScareCoinStore`。`✅ 是 checkin 的上游渠道（XP-FIX-5 已把 ScareCoin 移到 CheckIn 外层，checkin 的 class_checkin 消费 ScareCoinStore）。亦被 profile/redemption/日历消费。`
- **[9] CheckIn** — `CheckInHistoryReader/CheckinStatusReader/CheckinWriter`。`✅ 消费 [8] ScareCoinStore，故必须在其内层。[8]→[9] 即渠道方向。`
- **[10] Dictionary** — 词典 Reader/Writer。`被 word_detail/查词页消费；✅ 已核实【无上游 feature 依赖】（dictionary 仅引 lib/repositories 全局遗留类，无 features/* 内部 import）。`
- **[11] WordBrowse** — `WordNotesStore/SentenceFavoritesStore`。`被 word_detail/my_fav 消费；无上游 feature 依赖，最内层 feature scope。`
- **MultiProvider[SkinSystem, WallpaperState]** — 主题皮肤/墙纸。`被 MaterialApp(_AppLifecycle) 与所有页面消费；内置于所有 feature scope 之后——注意：这使 feature scope 的 provider 无法 `context.read<SkinSystem>()`（Skin 在它们之下，非祖先），如需 feature 层读皮肤应改注入；当前无此需求，保留。`

## 三、落地方案（待执行）

1. 在 `app.dart:37-65` 每个 `build*FeatureScope(` 上插入上表对应一行语义注释（`/// ...`），不改任何 provider 顺序/内容。
2. 不改嵌套顺序（保持依赖 DAG 方向不变）。
3. 不改 `lib/app/**` 之外任何文件。
4. 门禁：`flutter analyze` 0 新增 + `flutter test` 全量绿 + `import_guard` 0（注释改动，理论全绿，仍需跑全量确认）。

## 四、依赖核实结论（2026-08-29 已全部核实完成）

- ✅ [3] Learning **不依赖** Account：`features/learning/**` 无 `import features/account/`，亦无 `AppSession(Controller/State)` 引用 —— learning 会话不读登录态。
- ✅ [4] Settings **不依赖** learning feature：`features/settings/**` 无 `import features/learning/`；`LearningPreferences*` 为 settings 自有领域类（与应用同名的 learning 模块无关）。
- ✅ [10] Dictionary **无上游 feature 依赖**：`features/dictionary/**` 无 `import features/{learning,book,search,account,settings,quick_review}/`；仅引全局 `lib/repositories/word_repository.dart`（遗留耦合，另记 residual）。

> 结论：C1 草案的 3 处 ⚠️ 全部解除；嵌套顺序无需改动（各层间依赖方向描述以「✅ 已核实」标注为准）。ARCH-FIX-4 落地仅需把上表语义注释贴到 `app.dart`，不改 provider 顺序。
