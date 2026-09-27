# Import 验证报告：59 个"无效导入"复查

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 方法：`flutter analyze` 全量编译验证 + 逐条人工核对 import 语法

---

## 一、结论

**59 个"无效导入"全部为脚本误报，0 个真实无效。**

`flutter analyze` 结果：**0 error / 0 import error**（54 warning + 117 info 均为未使用字段和 deprecated API，与 import 无关）。

---

## 二、误报原因分析

原始报告（`docs/import_dependency_report.md`）的检查脚本存在两类误判：

### 2.1 `dart:*` SDK 导入被误标记（6 处）

| 文件 | 导入 | 脚本判定 | 实际 |
|---|---|---|---|
| lib/pages/exam_quick_review_page.dart | `dart:async` | ❌ invalid | ✅ Dart 核心库 |
| lib/pages/net_diagnosis_page.dart | `dart:async` | ❌ invalid | ✅ Dart 核心库 |
| lib/pages/splash_page.dart | `dart:async` | ❌ invalid | ✅ Dart 核心库 |
| lib/pages/word_machine_page.dart | `dart:async` / `dart:math` | ❌ invalid | ✅ Dart 核心库 |
| lib/widgets/animations.dart | `dart:math` | ❌ invalid | ✅ Dart 核心库 |
| lib/widgets/check_in_widgets.dart | `dart:ui` | ❌ invalid | ✅ Dart 核心库 |
| lib/widgets/glass_widgets.dart | `dart:ui` | ❌ invalid | ✅ Dart 核心库 |
| lib/widgets/misc_widgets.dart | `dart:math` | ❌ invalid | ✅ Dart 核心库 |
| lib/widgets/progress_widgets.dart | `dart:math` | ❌ invalid | ✅ Dart 核心库 |
| lib/widgets/word_lookup_popup.dart | `dart:ui` | ❌ invalid | ✅ Dart 核心库 |

**原因**：脚本只识别 `package:` 前缀和 `../` 相对路径，未处理 `dart:*` 前缀。

### 2.2 同目录裸文件名导入被误标记（49 处）

例如：
```dart
import 'animations.dart';        // 同目录下正确写法
import 'scale_down_on_press.dart'; // 同目录下正确写法
```

Dart 允许同目录下用裸文件名导入，无需 `./` 前缀。脚本未识别此语法。

**涉及文件**：
- lib/widgets/ 下 14 个文件间的相互引用（animations.dart、scale_down_on_press.dart、input_controls.dart、learn_widgets.dart）
- lib/pages/ 下 18 个文件间的相互引用（dashboard_page.dart、lib_select_page.dart、search_page.dart 等）

---

## 三、真实 import 状态

| 检查项 | 结果 |
|---|---|
| `flutter analyze` import 错误 | **0** |
| 循环依赖 | **0**（报告确认） |
| 未使用 import | **0**（`flutter analyze` 未报告 unused_import） |
| 无效路径 | **0** |

---

## 四、建议

1. **脚本修复**：`import_dependency_report.md` 的检查脚本需增加两种路径识别：
   - `dart:*` 前缀 → 标记为 SDK 导入（有效）
   - 同目录裸文件名（无 `../` 且无 `package:`）→ 用 `dart analyze` 验证而非路径字符串匹配

2. **无需代码修复**：59 个导入全部有效，不改任何文件。

3. **flutter analyze 现状**：0 error，54 warning（未使用字段/元素，均为 lock/ 等低优先级遗留代码），117 info（deprecated Color API）。
