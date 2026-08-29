# ARCH-FIX-5 / C2-P1: content+search+dictionary 遗留壳迁移

**任务**: #01a04c8b-79a6-7911-ae3c-7b72de78b686  
**日期**: 2026-08-29  
**Owner**: Aion CLI (teammate)

---

## 分类结果

| lib/pages/*.dart | 类型 | 操作 |
|---|---|---|
| `search_page.dart` | T1 (re-export) | ✅ 跳过 |
| `dictionary_page.dart` | T1 (re-export) | ✅ 跳过 |
| `splash_page.dart` | T1 (re-export) | ✅ 跳过 |
| `word_detail_page.dart` | **T2 (1257+ 行)** | → `lib/features/dictionary/presentation/word_detail_page.dart` |
| `my_content_page.dart` | **T2** | → `lib/features/content/presentation/my_content_page.dart` |
| `my_fav_page.dart` | **T2** | → `lib/features/content/presentation/my_fav_page.dart` |
| `my_fav_sentence_page.dart` | **T2** | → `lib/features/content/presentation/my_fav_sentence_page.dart` |
| `sentence_detail_page.dart` | **T2** | → `lib/features/content/presentation/sentence_detail_page.dart` |
| `immersive_swipe_page.dart` | T2 (learning) | ⚠️ 跳过 — 属 learning feature，本卡范围外 |

---

## 迁移详情

### 1. word_detail_page.dart → dictionary feature

**旧路径**: `lib/pages/word_detail_page.dart`  
**新路径**: `lib/features/dictionary/presentation/word_detail_page.dart`  
**Shim**: `lib/pages/word_detail_page.dart` → `export '../features/dictionary/presentation/word_detail_page.dart'`

- 1257+ 行完整迁移
- 所有 `import '../xxx'` 改为 `import '../../../xxx'`（lib/pages → lib/ 1层，lib/features/dict/pres → lib/ 3层）
- 无新增跨 feature 依赖（imports 已经是正确的 learning/word_browse/core 引用）

### 2. my_content_page.dart → content feature

**旧路径**: `lib/pages/my_content_page.dart`  
**新路径**: `lib/features/content/presentation/my_content_page.dart`  
**Shim**: `lib/pages/my_content_page.dart` → re-export

- 含 `LearningCollectionsState` 引用（content→learning 跨 feature 耦合，**既有技术债**）

### 3. my_fav_page.dart → content feature

**旧路径**: `lib/pages/my_fav_page.dart`  
**新路径**: `lib/features/content/presentation/my_fav_page.dart`  
**Shim**: `lib/pages/my_fav_page.dart` → re-export

- 含 `LearningFavoritesState` + `LearningSessionState` 引用（content→learning 跨 feature 耦合，**既有技术债**）

### 4. my_fav_sentence_page.dart → content feature

**旧路径**: `lib/pages/my_fav_sentence_page.dart`  
**新路径**: `lib/features/content/presentation/my_fav_sentence_page.dart`  
**Shim**: `lib/pages/my_fav_sentence_page.dart` → re-export

- 含 `SentenceFavoritesStore` 引用（content→word_browse 跨 feature 耦合，**既有技术债**）

### 5. sentence_detail_page.dart → content feature

**旧路径**: `lib/pages/sentence_detail_page.dart`  
**新路径**: `lib/features/content/presentation/sentence_detail_page.dart`  
**Shim**: `lib/pages/sentence_detail_page.dart` → re-export

- 无跨 feature 依赖（仅 theme/tokens）

---

## 验证结果

### flutter analyze
```
flutter analyze lib/features/content/ lib/features/dictionary/presentation/word_detail_page.dart lib/pages/word_detail_page.dart lib/pages/my_content_page.dart lib/pages/my_fav_page.dart lib/pages/my_fav_sentence_page.dart lib/pages/sentence_detail_page.dart
→ No issues found! (ran in 6.5s)
```

### flutter test (search + dictionary)
```
flutter test test/features/search/ test/features/dictionary/
→ 36/36 All tests passed!
```

### 跳过说明
- `test/features/content/` 目录不存在 — content feature 是新建的，无对应测试。现有测试通过 shim 仍可覆盖。

---

## 跨 Feature 耦合（既有技术债，登记后续清理）

| 来源 Feature | 目标 Feature | 依赖 |
|---|---|---|
| content | learning | `LearningCollectionsState`, `LearningFavoritesState`, `LearningSessionState` |
| content | word_browse | `SentenceFavoritesStore` |
| content | screens | `LearnSession`（旧屏） |

这些依赖在迁移前已存在，本次仅搬迁文件位置，未引入新耦合。

---

## 跳过清单（范围外）

| 文件 | 原因 |
|---|---|
| `immersive_swipe_page.dart` | 属 learning feature，本卡范围是 content+search+dictionary |
| `search_page.dart` | 已是 T1 re-export shim |
| `dictionary_page.dart` | 已是 T1 re-export shim |
| `splash_page.dart` | 已是 T1 re-export shim（属 account feature） |
