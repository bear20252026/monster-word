# WS-1 lint 清理（flutter analyze 0 issue）

> 目标：未触发 analyze 0 error 门的 lint（info/warning）清零，保持行为不变。结果：**`flutter analyze` 0 issues / `flutter test` 383 全绿。**

## 基线
- 前态：`flutter analyze` 120 issue（0 error），全为 info/warning（`D:\AI2\ws1_analyze.txt` 存档）。
- 覆盖：`prefer_initializing_formals`（主导）、`unused_import`、`unintended_html_in_doc_comment`、`use_build_context_synchronously`、`deprecated_member_use`（Color alpha/red/green/blue、Radio groupValue/onChanged、withOpacity、translate/scale）、`library_private_types_in_public_api`、`prefer_final_fields`、`unnecessary_underscores`、`dead_code`、`dead_null_aware_expression`、`curly_braces_in_flow_control_structures`、`unnecessary_import`、`use_null_aware_elements`、`depend_on_referenced_packages`、`constant_identifier_names`、`unnecessary_string_interpolations`、`unused_element`、`unnecessary_null_comparison`。

## 执行方式（4 个不相交 batch + lead 专属区）
| 批 | 范围 | 负责人 |
|---|---|---|
| A | `lib/features/learning/**` | 2163 |
| B | `lib/services/** lib/data/** lib/repositories/** lib/utils/** lib/engine/** + test/**` | 3802 |
| C | `lib/features/search/** lib/features/book/** lib/models/** lib/events/**` | 3061 |
| D | `lib/pages/** lib/screens/** lib/widgets/**`（风险最高） | 2903 |
| lead | `lib/app/** lib/core/**`（lead 专属，我处理） | lead |

## 变更要点（lead 亲手处理的边界项）
- `pubspec.yaml` / `pubspec.lock`：`test/data_verification_test.dart` 触发 `depend_on_referenced_packages`，在 `dev_dependencies` 添加 `path_provider_platform_interface`。首版用 `^4.1.0` 与 `path_provider` 2.x 冲突导致 pub get 失败，**改为 `^2.1.3`**（与 path_provider 2.x 兼容）后解析通过。
- `lib/pages/my_fav_sentence_page.dart:328`：`_deleteSelected` 在 `await showDialog` 后于 State 方法内使用 `context`，补 `if (!mounted) return;` 守卫（命中 2903 遗漏的这一处）。
- `lib/core/learning/learning_progress_reader.dart:8,9`：文档注释里 `<LearningProgressReader>` 引发 `unintended_html_in_doc_comment`，用反引号包裹。
- `lib/app/app.dart:6`：删除未用 `import '../core/di/service_locator.dart';`。
- `lib/core/audio/audio_playback_state.dart:12`：构造改为 `required this._audioService`（initializing formal）。

## 明细报告
- A：`docs/reports/ws1_lint_a_learning.md`
- B：`docs/reports/ws1_lint_b_cleanup.md`
- 未来 WS-6（learning 状态契约化）设计：`docs/reports/ws6_design_learning_core_contracts.md`

## 质量门
- `flutter analyze` → `No issues found!`（exit 0）
- `flutter test` → `00:44 +383: All tests passed!`
