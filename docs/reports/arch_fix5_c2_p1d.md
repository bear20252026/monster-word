# ARCH-FIX-5 / C2-P1d — T2 遗留壳迁移（11 页）

**Date**: 2026-08-29  
**Task**: 01a04cab-1827-7693-b16a-40c1e24f94b9  
**Status**: ✅ 完成

## 迁移决策总表

| # | 源文件 (`lib/pages/`) | 行数 | 决策 | 目标 |
|---|----------------------|------|------|------|
| 1 | `appearance_page.dart` | 395 | **迁移** | `lib/features/account/presentation/appearance_page.dart` |
| 2 | `user_item_modify_page.dart` | 97 | **迁移** | `lib/features/account/presentation/user_item_modify_page.dart` |
| 3 | `wallpaper_select_page.dart` | 579 | **迁移** | `lib/features/account/presentation/wallpaper_select_page.dart` |
| 4 | `sms_page.dart` | 144 | **迁移** | `lib/features/account/presentation/sms_page.dart` |
| 5 | `class_activity_page.dart` | 650 | **迁移** | `lib/features/checkin/presentation/class_activity_page.dart` |
| 6 | `book_words_page.dart` | 43 | **保留 adapter** | 路由兼容适配器（传入 bookId+bookName → Book 对象，委托 feature BookWordsPage） |
| 7 | `list_words_page.dart` | 208 | **迁移** | `lib/features/book/presentation/list_words_page.dart` |
| 8 | `spell_check_page.dart` | 260 | **迁移** | `lib/features/learning/presentation/spell_check_page.dart` |
| 9 | `collins_detail_intro_page.dart` | 239 | **迁移** | `lib/features/dictionary/presentation/collins_detail_intro_page.dart` |
| 10 | `base_web_page.dart` | 184 | **INFRA** | WebView 基类 + AdWebPage，非业务 UI 壳，留 `lib/pages/` 等 P2 归入 `lib/core/` |
| 11 | `uri_scheme_page.dart` | 104 | **INFRA** | 深度链接处理器，非业务 UI 壳，留 `lib/pages/` 等 P2 归入 `lib/core/` |

## Import 调整要点

### account (4 files)
- **appearance_page**: `../hooks/responsive.dart` → `../../../hooks/responsive.dart`；保留 `../pages/immersive_swipe_page.dart` 路由引用（2903 并行文件，不导入新位置）
- **user_item_modify_page**: `../theme/` → `../../../theme/`，`../tokens/` → `../../../tokens/`
- **wallpaper_select_page**: `../data/wallpaper_data.dart` → `../../data/wallpaper_data.dart`（同 level data/）。适配真实 `WallpaperItem` API（`colors` 字段替代 `vars`/`gradientColors`）
- **sms_page**: 同上 theme/tokens 路径调整

### checkin (1 file)
- **class_activity_page**: 仅 skin_system + design_tokens，路径调整

### book (2 files)
- **book_words_page**: 保留为路由兼容 adapter（43 行 → 35 行），接收 bookId+bookName Map 参数转 Book 对象，委托给 feature BookWordsPage
- **list_words_page**: `../core/router/route_names.dart` → `../../../core/router/route_names.dart`；`../models/word.dart` → `../../../models/word.dart`

### learning (1 file)
- **spell_check_page**: `../core/audio/audio_playback_state.dart` → `../../../core/audio/audio_playback_state.dart`。仅新增此一个文件，未动 2903 正在收敛的其它 learning 文件

### dictionary (1 file)
- **collins_detail_intro_page**: `../models/word_data_models.dart` → `../../../models/word_data_models.dart`

## Shim 转换

| 原文件 | 内容 |
|--------|------|
| `lib/pages/appearance_page.dart` | `export '../../features/account/presentation/appearance_page.dart';` |
| `lib/pages/user_item_modify_page.dart` | `export '../../features/account/presentation/user_item_modify_page.dart';` |
| `lib/pages/wallpaper_select_page.dart` | `export '../../features/account/presentation/wallpaper_select_page.dart';` |
| `lib/pages/sms_page.dart` | `export '../../features/account/presentation/sms_page.dart';` |
| `lib/pages/class_activity_page.dart` | `export '../../features/checkin/presentation/class_activity_page.dart';` |
| `lib/pages/list_words_page.dart` | `export '../../features/book/presentation/list_words_page.dart';` |
| `lib/pages/spell_check_page.dart` | `export '../../features/learning/presentation/spell_check_page.dart';` |
| `lib/pages/collins_detail_intro_page.dart` | `export '../../features/dictionary/presentation/collins_detail_intro_page.dart';` |
| `lib/pages/book_words_page.dart` | 保留 adapter（路由兼容层），不改为 shim |

## INFRA 标记

| 文件 | 原因 | 建议 |
|------|------|------|
| `base_web_page.dart` | WebView 基类 + AdWebPage 广告组件，通用基类非业务 UI | P2 归入 `lib/core/web/` |
| `uri_scheme_page.dart` | 深度链接处理，纯路由逻辑 | P2 归入 `lib/core/router/` |

## 验证

```
dart analyze 17 文件（9 个 shim/adapter + 8 个 feature 实现）: ✅ 0 issues
```

## 文件变更清单

| 操作 | 文件 |
|------|------|
| **新增** | `lib/features/account/presentation/appearance_page.dart` |
| **新增** | `lib/features/account/presentation/user_item_modify_page.dart` |
| **新增** | `lib/features/account/presentation/wallpaper_select_page.dart` |
| **新增** | `lib/features/account/presentation/sms_page.dart` |
| **新增** | `lib/features/checkin/presentation/class_activity_page.dart` |
| **新增** | `lib/features/book/presentation/list_words_page.dart` |
| **新增** | `lib/features/learning/presentation/spell_check_page.dart` |
| **新增** | `lib/features/dictionary/presentation/collins_detail_intro_page.dart` |
| **改写为 shim** | `lib/pages/appearance_page.dart` |
| **改写为 shim** | `lib/pages/user_item_modify_page.dart` |
| **改写为 shim** | `lib/pages/wallpaper_select_page.dart` |
| **改写为 shim** | `lib/pages/sms_page.dart` |
| **改写为 shim** | `lib/pages/class_activity_page.dart` |
| **改写为 shim** | `lib/pages/list_words_page.dart` |
| **改写为 shim** | `lib/pages/spell_check_page.dart` |
| **改写为 shim** | `lib/pages/collins_detail_intro_page.dart` |
| **保留 adapter** | `lib/pages/book_words_page.dart`（路由兼容，非 shim） |
| **未改动** | `lib/pages/base_web_page.dart`（INFRA） |
| **未改动** | `lib/pages/uri_scheme_page.dart`（INFRA） |
| **新增** | `docs/reports/arch_fix5_c2_p1d.md`（本报告） |

**总计**: 18 文件（8 新增 + 8 shim + 1 adapter 改写 + 1 报告），2 文件未改动（INFRA），0 文件删除

## 与并行任务的隔离

- 未动 `lib/core/router/**`、`lib/app/app.dart`、`lib/screens/**`、`lib/widgets/review_dialog.dart`
- 未动 2903 正在收敛的 `lib/features/learning/**` 文件（仅新增 `spell_check_page.dart`）
- 未动 9052/3802 已迁移页面
- 未执行 `git add`/`git commit`
