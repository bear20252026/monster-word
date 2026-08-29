# ARCH-FIX-5 / C2-P1b — Legacy Shell Migration (foot_mark + ui_theme_select)

**Date**: 2026-08-28  
**Task**: 01a04c97-2471-7513-b610-5d5ec6ae9455  
**Status**: ✅ 完成

## 迁移范围

| 源文件 | 目标 Feature | 说明 |
|--------|-------------|------|
| `lib/pages/foot_mark_page.dart` | `lib/features/word_browse/presentation/foot_mark_page.dart` | 足迹页（学习记录入口），含真实 UI 实现 |
| `lib/pages/ui_theme_select_page.dart` | `lib/features/settings/presentation/ui_theme_select_page.dart` | 主题选择页（切换皮肤），含真实 UI 实现 |

## 迁移策略

### 1. foot_mark_page.dart → word_browse

**Import 调整**:
- `learning/presentation/*_state.dart` → `../../../features/learning/presentation/*_state.dart`（相对路径重定位）
- `theme/skin_system.dart` → `../../../theme/skin_system.dart`
- `tokens/design_tokens.dart` → `../../../tokens/design_tokens.dart`
- 子页面引用（`my_words_page.dart` 等 5 个）→ 替换为 `core/router/route_names.dart` 常量（`RouteNames.myWords` 等），消除对 `lib/pages/` 的反向依赖

**架构分析**:
- 此页面消费跨功能状态（learning session/statistics/collections），属「页面消费全局状态」模式
- ImportGuard 全库扫描无 R4 违规 — 扫描 harness 中路径解析将跨功能 state import 正确识别并允许（state 文件位于 presentation 层，属于事实读取）
- 报告中注明此为 C2 技术债：未来可将 learning 摘要数据收敛为 word_browse 域的 port

### 2. ui_theme_select_page.dart → settings

**Import 调整**:
- `theme/skin_system.dart` → `../../../theme/skin_system.dart`
- `tokens/design_tokens.dart` → `../../../tokens/design_tokens.dart`
- 无子页面依赖，无跨功能 import

**架构分析**:
- 此页面仅依赖 core 层的 theme/tokens，完全符合垂直化要求
- ImportGuard 无违规

### Shim 模式

两个原始 `lib/pages/` 文件均转换为 re-export shim:
```dart
// Shim — 实现已迁入 features/<target>/presentation/<file>.dart
export '../../features/<target>/presentation/<file>.dart';
```

## 验证结果

| 检查项 | 结果 |
|--------|------|
| `dart analyze` 4 个受影响文件 | ✅ 0 issues |
| `flutter test test/features/word_browse/` | ✅ 15/15 通过 |
| `flutter test test/features/settings/` | ✅ 10/10 通过 |
| `import_guard_test.dart` 全库扫描 | ✅ 无 R4 新违规 |
| `app_structure_test.dart` | 7 个预存失败（learn_page/word_detail_page 等 shim，与本次无关） |
| `ticker_provider_guard_test.dart` | ✅ 通过 |

## 文件变更清单

| 操作 | 文件 |
|------|------|
| **新增** | `lib/features/word_browse/presentation/foot_mark_page.dart` |
| **新增** | `lib/features/settings/presentation/ui_theme_select_page.dart` |
| **改写为 shim** | `lib/pages/foot_mark_page.dart` |
| **改写为 shim** | `lib/pages/ui_theme_select_page.dart` |
| **新增** | `docs/reports/arch_fix5_c2_p1b.md`（本报告） |

**总计**: 5 文件（2 新增实现 + 2 shim 改写 + 1 报告），0 文件删除

## 技术备注

- foot_mark_page 的子页面引用已全部替换为 `RouteNames` 常量，消除了 feature→pages 的反向依赖
- 子页面（my_words_page/new_words_page/mastered_words_page/not_learned_words_page/reviewing_words_page）仍在 `lib/pages/` 中，后续由对应 feature 迁移时转 shim
- 未改动 `lib/core/router/**`、`lib/app/app.dart`、`lib/screens/**`、`lib/features/learning/**`
- 未执行 `git add`/`git commit`
