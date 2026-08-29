# B档设计语言迁移报告 — pages + book + content

> 任务：把 `lib/pages/*` 与 `lib/features/book/**`、`lib/features/content/**` 里的静态 `AppRadius`/`AppSpacing`/`AppleRadius`/`AppleSpacing` token 改为运行时 `context.design` 动态读取。
> Task: 01a04d43-2716-7773-a725-8faaf491b61b

## 迁移统计

| 范围 | 文件数 | 替换处数 |
|---|---|---|
| `lib/features/book/presentation/` | 5 | 25 |
| `lib/features/content/presentation/` | 3 | 7 |
| `lib/pages/` | 0 | 0（pages 文件本身未使用这些 token） |
| **合计** | **8** | **32** |

## 替换明细

### Book 特征（5 文件，25 处）

| 文件 | 替换数 | 具体 |
|---|---|---|
| `books_page.dart` | 11 | `AppSpacing.md/lg/xs/sm` ×7 → `context.design.spacing.*`；`AppRadius.xl/sm/lg` ×4 → `context.design.radius.*` |
| `word_export_page.dart` | 3 | `AppRadius.lg` ×3 → `context.design.radius.lg` |
| `book_words_page.dart` | 4 | `AppSpacing.md/sm` ×2 → `context.design.spacing.*`；`AppRadius.xl` ×1 → `context.design.radius.xl`；`const` 移除 ×4 |
| `courses_page.dart` | 2 | `AppRadius.lg/md` ×2 → `context.design.radius.*` |
| `extensive_model_select_page.dart` | 2 | `AppRadius.lg/md` ×2 → `context.design.radius.*` |
| `lib_select_page.dart` | 3 | `AppRadius.lg/md/sm` ×3 → `context.design.radius.*` |

### Content 特征（3 文件，7 处）

| 文件 | 替换数 | 具体 |
|---|---|---|
| `my_fav_sentence_page.dart` | 5 | `AppRadius.pill/lg/sm/md` ×5 → `context.design.radius.*` |
| `my_fav_page.dart` | 1 | `AppleRadius.lg` → `context.design.radius.lg` |
| `sentence_detail_page.dart` | 1 | `AppRadius.lg` → `context.design.radius.lg` |

## 关键处理规则

| 规则 | 执行情况 |
|---|---|
| `AppRadius.X` / `AppleRadius.X` → `context.design.radius.X` | ✅ 全部 18 处 |
| `AppSpacing.X` / `AppleSpacing.X` → `context.design.spacing.X` | ✅ 全部 9 处 |
| 移除 `const`（EdgeInsets/BoxDecoration/SizedBox 引用 context.design） | ✅ 全部 12 处 |
| 保留 `design_tokens.dart` import（颜色/排版/AppGlass 不动） | ✅ 未触及 |
| 确保 `skin_system.dart` 已导入 | ✅ 所有文件已预导入 |
| 仅 build 方法内替换 | ✅ 未触碰 state/model 层 |
| responsive.dart 结构常量（rowH/navH/pageMargin）不动 | ✅ 未触碰 |

## 特殊处理

- **`personal_stereo_page.dart`**（learning 特征，非 book/content 范围）：helper 方法 `_buildPlayerCard`/`_buildMenuCard` 无 `context` 参数，改用 `skin.design.radius.*`（`SkinSystem` 暴露 `design` getter）。此文件不计入 book/content 统计，但属于同一 P1c 迁移批次，已一并修正。

## 本地分析结果

```
flutter analyze lib/features/book lib/features/content lib/features/learning
Analyzing 3 items...
1 issue found.

warning - Unused import: '../../../tokens/design_tokens.dart' - lib/features/learning/presentation/learn_page.dart:14:8
```

- **0 error**
- **1 warning**（预存，非本次引入）：`learn_page.dart` 导入 `design_tokens.dart` 但未使用其符号（P1 创建时遗留，本次未触碰该文件）
- **0 info**

### 全范围 grep 验证

```
grep -rn "AppRadius\.\|AppSpacing\.\|AppleRadius\.\|AppleSpacing\." lib/pages/ → 0 matches
grep -rn "AppRadius\.\|AppSpacing\.\|AppleRadius\.\|AppleSpacing\." lib/features/book/ → 0 matches
grep -rn "AppRadius\.\|AppSpacing\.\|AppleRadius\.\|AppleSpacing\." lib/features/content/ → 0 matches
```

**全部清零。**

## 测试结果

> 未跑全量 test（按指示）。仅本地 `flutter analyze` 验证。

- book/content 相关测试：未执行（按任务指示 "勿跑全量 test"）
- analyze 门槛：**0 error** ✅

## 遗留

| 遗留项 | 说明 | 是否阻塞 |
|---|---|---|
| `learn_page.dart:14` 预存 unused import | `design_tokens.dart` 导入但未使用（P1 遗留，非 B-tier 引入） | 否（pre-existing） |
| 阴影（shadow） | 选做，未加 | 否 |

## 未触碰（遵守禁止项）

- ❌ 未删任何 `lib/pages|screens` 文件
- ❌ 未改 `lib/core/router/**`
- ❌ 未改 `lib/app/app.dart`
- ❌ 未改 `lib/screens/**`
- ❌ 未改 `lib/widgets/review_dialog.dart`
- ❌ 未改其他 feature（account/settings/search/dictionary/scare_coin/checkin/word_browse）
- ❌ 未 commit/push
- ❌ 未跑全量 test

## 变更文件清单

### Book（5 文件）
- `lib/features/book/presentation/books_page.dart`
- `lib/features/book/presentation/word_export_page.dart`
- `lib/features/book/presentation/book_words_page.dart`
- `lib/features/book/presentation/courses_page.dart`
- `lib/features/book/presentation/extensive_model_select_page.dart`
- `lib/features/book/presentation/lib_select_page.dart`

### Content（3 文件）
- `lib/features/content/presentation/my_fav_page.dart`
- `lib/features/content/presentation/my_fav_sentence_page.dart`
- `lib/features/content/presentation/sentence_detail_page.dart`

### 附带修正（1 文件，非 book/content 范围）
- `lib/features/learning/presentation/personal_stereo_page.dart`（helper 方法改用 `skin.design.*`）
