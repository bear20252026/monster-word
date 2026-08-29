# B档设计语言迁移 — word_browse + learning + search + quick_review

**Date**: 2026-08-29  
**Task**: 01a04d43-2799-7dd2-b45b-c66f75a905da  
**Status**: ✅ 完成

## 迁移规则

| 静态 Token | 动态替代 |
|---|---|
| `AppRadius.xxx` | `context.design.radius.xxx` |
| `AppleRadius.xxx` | `context.design.radius.xxx` |
| `AppSpacing.xxx` | `context.design.spacing.xxx` |
| `AppleSpacing.xxx` | `context.design.spacing.xxx` |

## 文件变更清单

### word_browse（1 文件，3 替换）

| 文件 | 替换数 | 特殊处理 |
|------|--------|----------|
| `lib/features/word_browse/presentation/foot_mark_page.dart` | 3 | helper 方法 `_buildStatCard`/`_buildEntryCard` 新增 `BuildContext context` 参数 |

### learning（12 文件，44 替换）

| 文件 | 替换数 |
|------|--------|
| `lib/features/learning/presentation/dashboard_page.dart` | 4 |
| `lib/features/learning/presentation/dictation_session_page.dart` | 4 |
| `lib/features/learning/presentation/listening_player_page.dart` | 5 |
| `lib/features/learning/presentation/list_word_listen_page.dart` | 4 |
| `lib/features/learning/presentation/personal_stereo_page.dart` | 3 |
| `lib/features/learning/presentation/play_order_page.dart` | 1 |
| `lib/features/learning/presentation/quick_spell_page.dart` | 9 |
| `lib/features/learning/presentation/spell_session_page.dart` | 6 |
| `lib/features/learning/presentation/word_machine_page.dart` | 3 |
| `lib/features/learning/presentation/spell_check_page.dart` | 5 |
| `lib/features/learning/presentation/learn_page.dart` | 1（`AppSpacing.navH` → `context.design.spacing.navH`） |
| `lib/features/learning/presentation/widgets/formal_review_header.dart` | 1 |

### search（1 文件，2 替换）

| 文件 | 替换数 |
|------|--------|
| `lib/features/search/presentation/search_page.dart` | 2 |

### quick_review（1 文件，2 替换）

| 文件 | 替换数 |
|------|--------|
| `lib/features/quick_review/presentation/exam_quick_review_page.dart` | 2 |

## 特殊处理

### foot_mark_page.dart
`_buildStatCard` 和 `_buildEntryCard` 是独立 helper 方法，原始签名只有 `SkinSystem skin`，无 `BuildContext`。迁移时：
- 两个方法签名新增 `BuildContext context` 参数
- 所有调用处补充 `context: context`

### learn_page.dart
`AppSpacing.navH` 是该文件唯一使用 `design_tokens.dart` 的地方。迁移后 `design_tokens.dart` import 变为 unused，移除之（文件内无其他颜色/排版/AppGlass 引用）。

## 设计原则
- 仅替换 build 方法内的视觉 token（`AppRadius`/`AppSpacing`/`AppleRadius`/`AppleSpacing`）
- 保留 `design_tokens.dart` import（其他文件中有颜色/排版引用时保留）
- 确保 `skin_system.dart` import 存在（提供 `context.design`）
- 未动 responsive.dart 结构常量（`rowHeight`/`navHeight`/`pageMargin`）
- 未动 state/model 层
- 未加阴影（不确定则不加）

## 验证结果

| 检查项 | 结果 |
|--------|------|
| `dart analyze` 4 feature 目录 | ✅ 0 issues |
| `flutter test` word_browse + search + quick_review | ✅ 34/34 通过 |
| 全库 grep `AppRadius\.\|AppSpacing\.\|AppleRadius\.\|AppleSpacing\.` 在 4 feature 内 | ✅ 0 匹配 |

## 替换总数
59 处替换，18 文件变更
