# UX-FIX-C：单词详情/词典 UX 修复报告

**任务**: #01a04af1-c57b-7311-8446-1f9e8bb0f414  
**日期**: 2026-08-27  
**Owner**: Aion CLI (teammate)  
**Audit 基线**: ux_aux2_word_detail_dict.md

---

## 修复摘要

| 编号 | 维度 | 描述 | 文件 | 状态 |
|------|------|------|------|------|
| C-1 | 搜索结果选中态 | 选中项显示 accent 左边框 + 文字高亮 | search_page.dart | ✅ |
| C-2 | TabBarIndicator 可见性 | indicatorWeight 2→3 + indicatorPadding | dictionary_page.dart | ✅ |
| C-3 | 收藏动画+触觉 | 例句收藏 TweenSequence 弹性动画 + HapticFeedback.lightImpact | word_detail_page.dart | ✅ |
| C-4 | Tooltip 文字标签 | 词典页收藏 star 添加 tooltip（"收藏单词"/"取消收藏"） | dictionary_page.dart | ✅ |
| C-5 | 拖拽提示 | 词霸详情弹窗顶部增加拖拽手柄条 | word_machine_page.dart | ✅ |

---

## 详细变更

### C-1 搜索结果选中态（search_page.dart）

**问题**: 搜索结果默认选中 `results.first`，但无任何视觉区分。用户不知道当前选中了哪个单词。

**修复**: 
- `ListTile` 外包 `Material` + `Container`
- 选中项: accent 半透明背景 (`alpha: 0.08`) + accent 3px 左边框 + accent 文字颜色
- 未选中项: 透明背景，无边框

```dart
// Before: ListTile(selected: isSelected, selectedTileColor: skin.cardBgAlt)
// After:  Material(color: accent_bg) > Container(decoration: left_border) > ListTile
```

### C-2 TabBarIndicator 可见性（dictionary_page.dart）

**问题**: TabBar indicatorWeight=2 太细，在卡片容器内不够明显。

**修复**:
- `indicatorWeight`: 2 → 3
- 新增 `indicatorPadding: EdgeInsets.only(bottom: 2)` 防止与容器底边重叠

### C-3 例句收藏动画+触觉（word_detail_page.dart）

**问题**: 例句收藏按钮点击无视觉/触觉反馈，用户不确定操作是否成功。

**修复**:
- `_ExampleTileState` 添加 `SingleTickerProviderStateMixin`
- `_favAnimController` + `_favScaleAnim`（TweenSequence: 1.0→1.4→1.0，200ms）
- `_toggleFav()` 中先 `HapticFeedback.lightImpact()` 再 `forward(from: 0.0)`
- 收藏图标外包裹 `AnimatedBuilder > Transform.scale` + `Tooltip`

### C-4 Tooltip 文字标签（dictionary_page.dart）

**问题**: 词典页收藏 star IconButton 无 tooltip，可访问性差。

**修复**:
- 添加 `tooltip: state.isFavorite ? '取消收藏' : '收藏单词'`
- 书签按钮已有 tooltip（`'移出生词本' / '加入生词本'`），无需修改
- 添加 `HapticFeedback.lightImpact()` 到收藏 `onPressed`

### C-5 拖拽提示（word_machine_page.dart）

**问题**: 词霸（WordMachine）详情弹窗从底部弹出，但无拖拽提示，用户不知道可以拖拽。

**修复**:
- 在 `showWordDetail` 底部弹窗的 `SingleChildScrollView > Column` 顶部添加 24×3px 的灰色圆角条（`GameBoyPalette.screenMid` 色）

---

## 修改文件清单

| 文件 | 变更类型 |
|------|----------|
| `lib/features/search/presentation/search_page.dart` | 修改 — 选中态 Material + Container |
| `lib/features/dictionary/presentation/dictionary_page.dart` | 修改 — TabBar 指示器 + tooltip + haptic |
| `lib/pages/word_detail_page.dart` | 修改 — 收藏动画 + 触觉 + tooltip |
| `lib/pages/word_machine_page.dart` | 修改 — 拖拽提示条 |
| `test/pages/ux_fix_c_test.dart` | 新增 — 5 个测试 |

---

## 分析结果

```
flutter analyze — No issues found (4 items, 7.0s)
```

## 测试结果

```
flutter test test/pages/ux_fix_c_test.dart
+5 All tests passed!
```

- C-1: 选中项 accent 左边框 + 文字高亮 ✅
- C-1: 未选中项无左边框 ✅
- C-2: TabBar indicatorWeight=3 ✅
- C-3: 未收藏时 favorite_border 图标 ✅
- C-3: 收藏按钮 Tooltip 提示 ✅

---

## Audit 覆盖

| Audit Finding | 状态 | 备注 |
|---------------|------|------|
| H-1 搜索无选中态 | ✅ | accent 边框 + 背景 + 文字 |
| H-2 无 TabBarIndicator | ✅ | 代码已有 indicator，增强至 weight=3 |
| H-3 收藏无反馈 | ✅ | 弹性动画 + 触觉 + tooltip |
| H-4 收藏无文字标签 | ✅ | dictionary_page star tooltip |
| H-5 词霸无拖拽提示 | ✅ | 顶部灰色拖拽手柄 |
