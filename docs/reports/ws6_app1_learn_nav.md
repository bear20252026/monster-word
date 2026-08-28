# WS-6 APP-1 学习/复习流导航安全化

> 任务：将 review_page / learn_session / learn_page / lib_select_page 的返回/完成导航统一到 `NavUtils.safePop`（返回/关闭）和 `NavUtils.goHome`（完成/回首页），并在 lib_select_page 添加空词表守卫。
> 基石：`lib/core/router/nav_utils.dart`（lead 已建，未修改）。
> ❌ 未 git commit/push，未跑全量 flutter test。

---

## 一、改动总览

| 文件 | 改动点 | 规则 |
|------|--------|------|
| `lib/pages/review_page.dart` | `onReturnHome` pushReplacement → goHome；`onBack` ×2 → safePop | 完成→goHome，返回→safePop |
| `lib/screens/learn_session.dart` | `Navigator.maybePop` / `Navigator.pop` → safePop | 返回→safePop |
| `lib/pages/learn_page.dart` | 返回键 → safePop；"返回首页"按钮 → goHome | 返回→safePop，完成→goHome |
| `lib/pages/lib_select_page.dart` | 返回键 → safePop；空词表守卫（新增） | 返回→safePop，空词表不跳转 |

---

## 二、逐文件改动明细

### 2.1 `lib/pages/review_page.dart`

| 行 | 改动前 | 改动后 | 规则 |
|----|--------|--------|------|
| L60 | `onReturnHome: () => Navigator.of(context).pushReplacementNamed('/')` | `onReturnHome: () => NavUtils.goHome(context)` | 完成→goHome |
| L66 | `onBack: () => Navigator.of(context).pop()` | `onBack: () => NavUtils.safePop(context)` | 返回→safePop |
| L90 | `onBack: () => Navigator.pop(context)` | `onBack: () => NavUtils.safePop(context)` | 返回→safePop |

**根因**：原 `pushReplacementNamed('/')` 把 review 页替换成 MainShell，栈上只剩唯一路由；若用户再按系统返回 → 无 route 可 pop → 黑屏/退出 App。改为 `goHome`（`popUntil(isFirst)`）可逐级安全回到首页。

### 2.2 `lib/screens/learn_session.dart`

| 行 | 改动前 | 改动后 | 规则 |
|----|--------|--------|------|
| L246 | `Navigator.maybePop(context)` / `Navigator.pop(context)` | `NavUtils.safePop(context)` | 返回→safePop |

**根因**：`Navigator.pop` / `maybePop` 在栈底会黑屏；`safePop` 用 `canPop` 守卫，根路由不 pop。

### 2.3 `lib/pages/learn_page.dart`

| 行 | 改动前 | 改动后 | 规则 |
|----|--------|--------|------|
| L138 | `Navigator.pop(context)` | `NavUtils.safePop(context)` | 返回→safePop |
| L257 | `Navigator.pop(context)` ("返回首页"按钮) | `NavUtils.goHome(context)` | 完成→goHome |

**根因**："返回首页"用 `pop` 只退一层，无法回到根；改为 `goHome` 逐级 popUntil 到首页。

### 2.4 `lib/pages/lib_select_page.dart`

| 行 | 改动前 | 改动后 | 规则 |
|----|--------|--------|------|
| L101 | `Navigator.pop(context)` (返回键) | `NavUtils.safePop(context)` | 返回→safePop |
| L518-523 | 无守卫 | 新增空词表守卫（见下） | 空词表不跳转 |

**空词表守卫（新增）**：
```dart
// 空词表守卫：currentWord 为 null 说明词书无单词，提示而非跳转（避免白屏）。
if (session.currentWord == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('该词书暂无单词数据，无法开始学习')),
  );
  return;
}
```

**根因**：原流程 `loadBook` → 直接 push BookWordsPage → 用户点"开始学习" FAB → push `/immersive_swipe`，空队列下 `currentWord == null` → 白屏。守卫在 loadBook 后立即检测，提示且不推栈。

---

## 三、测试结果

### 3.1 flutter analyze（4 文件）

```
Set-Location D:\claude\work\cn_com_lange\word_app
flutter analyze lib/pages/review_page.dart lib/screens/learn_session.dart lib/pages/learn_page.dart lib/pages/lib_select_page.dart
```

**结果**：`No issues found!` — 0 error，0 warning，0 info。

### 3.2 新增 widget 测试

文件：`test/pages/nav_app1_test.dart`（5 个测试）

| # | 测试 | 验证点 |
|---|------|--------|
| 1 | ReviewPage 完成触发 goHome — done 状态"返回首页"按钮 popUntil 回到根路由 | goHome 后根路由可见，review 页不可见 |
| 2 | 多层嵌套路由 goHome 一次性回到根 | learn→review 链路，goHome 直接回 root，中间层全弹出 |
| 3 | LibSelectPage 空词表守卫 — currentWord 为 null 显示 SnackBar 且不导航 | SnackBar 文本出现，无新页面入栈 |
| 4 | 空词表守卫后路由栈未变化 | 守卫前后 `pages.length` 不变 |
| 5 | safePop 回归 — 根路由 safePop 不黑屏不崩溃 | 仍在原页面 |

**运行**：
```
flutter test test/pages/nav_app1_test.dart
flutter test test/pages/nav_safety_test.dart test/pages/nav_app1_test.dart
```

**结果**：`All tests passed!`（5/5 新增 + 8/8 既有 = 13/13 全绿）。

---

## 四、三件套判定

| 项 | 状态 |
|----|------|
| 1. flutter analyze 4 文件 0 error 且无新增 warning/info | ✅ No issues found |
| 2. 新增 widget 测试验证 review 完成触发 goHome + lib_select 空词表不跳转且提示 | ✅ 5/5 绿 |
| 3. 报告 `docs/reports/ws6_app1_learn_nav.md` | ✅ 本文件 |

**三件套齐全 → 报 lead。**
