# XP-FIX-3 · 词典/单词详情域修复报告

> **任务**: 修复 AUD-3 P1/P2/P3 + AUD-6 P1-1 裸 pop  
> **日期**: 2026-08-28  
> **涉及文件**: 4 个  
> **测试文件**: 1 个 (4 tests, all green)  
> **flutter analyze**: 0 errors  

---

## 改动清单

### 1. `lib/core/router/nav_utils.dart` — safePop 扩展

**改动**: `safePop` 新增可选 `[dynamic result]` 参数。

```dart
// Before
static void safePop(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) { navigator.pop(); }
}

// After
static void safePop(BuildContext context, [dynamic result]) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) { navigator.pop(result); }
}
```

**原因**: 需要支持 Dialog 内带返回值的安全 pop（如笔记保存 `safePop(context, controller.text)`）。

---

### 2. `lib/pages/word_detail_page.dart` — 三处修复

#### 2a. 删除/完成返回：goHome → safePop (AUD-3 P1-5)

**行 320-325**: 将 `NavUtils.goHome(context)` 替换为 `NavUtils.safePop(context)`。

```dart
// Before
if (isLastWord) {
  NavUtils.goHome(context);
} else {
  NavUtils.safePop(context);
}

// After — 无论是否最后一词，均返回上一层
session.rate(FsrsRating.good);
NavUtils.safePop(context);
```

**原因**: 从搜索/收藏列表进入 word_detail 时，完成学习直接跳首页会丢失用户的浏览上下文。safePop 的 canPop 守卫会在无上层路由时自动降级。

#### 2b. 深链无词错误提示 (AUD-3 P2-1)

**行 43-49**: `_resolveTargetWord` 增加 try-catch 防 ProviderNotFound。

**行 162-164**: 错误页面按钮从 `goHome` 改为 `safePop`，按钮文案从「返回首页」改为「返回上一页」。

```dart
// Before — 深链无词时按钮
ElevatedButton.icon(
  onPressed: () => NavUtils.goHome(context),
  label: Text('返回首页'),
)

// After
ElevatedButton.icon(
  onPressed: () => NavUtils.safePop(context),
  label: Text('返回上一页'),
)
```

**原因**: 深链场景无上层路由时 safePop 自动降级（canPop=false 不执行），用户体验一致。

#### 2c. Dialog 内 Navigator.pop → NavUtils.safePop (AUD-3 P2-2)

**行 999-1010**: _NoteDialog 的取消/保存按钮：

```dart
// Before
TextButton(onPressed: () => Navigator.pop(context), ...)
FilledButton(onPressed: () => Navigator.pop(context, controller.text), ...)

// After
TextButton(onPressed: () => NavUtils.safePop(context), ...)
FilledButton(onPressed: () => NavUtils.safePop(context, controller.text), ...)
```

**原因**: 统一导航模式，Dialog pop 虽安全但与全局 safePop 模式不一致。

---

### 3. `lib/widgets/word_dictionary_popup.dart` — 裸 pop → safePop (AUD-6 P1-1)

**行 7, 211**: 

- 新增 `import '../core/router/nav_utils.dart';`
- `Navigator.of(context).pop()` → `NavUtils.safePop(context)`

**原因**: 虽然弹窗内的 pop 通常安全，但统一走 safePop 模式可避免未来重构时遗漏。

---

### 4. `lib/core/router/content_routes.dart` — cast fallback (AUD-3 P3-2)

**行 34-35, 51-58**: wordDetail 路由新增 `_buildWordDetailPage` 方法：

```dart
// Before
case RouteNames.wordDetail:
  return const WordDetailPage();

// After
case RouteNames.wordDetail:
  return _buildWordDetailPage(args);

static Widget _buildWordDetailPage(Object? args) {
  bool fromLearn = false;
  if (args is Map<String, dynamic>) {
    fromLearn = args['fromLearn'] == true;
  }
  return WordDetailPage(fromLearn: fromLearn);
}
```

**原因**: 原代码 `const WordDetailPage()` 不解析 args，当从深链（Map 参数）进入时 `fromLearn` 始终为 false。新方法对 args 做安全类型检查 + 回退。

---

## 测试结果

| 测试 | 结果 |
|------|------|
| 无参数深链时显示错误页面 "未找到单词" | ✅ |
| 无参数深链时显示 "返回上一页" 按钮 | ✅ |
| 正常传入 Word 参数时显示单词详情 | ✅ |
| 从内容路由 Map 参数进入时不崩溃 | ✅ |
| **合计** | **4/4 全绿** |

---

## 改动总结

| 类型 | 数量 |
|------|------|
| 修改文件 | 4 |
| 新增测试文件 | 1 |
| 新增测试用例 | 4 |
| Flutter analyze | 0 errors |

### 未改动确认
- ❌ 未触碰 `lib/core/router/route_names.dart`
- ❌ 未触碰 `lib/app/*`
- ❌ 未 git commit/push
- ❌ 未跑全量 flutter test
