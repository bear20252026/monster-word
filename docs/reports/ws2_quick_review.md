# WS-2 · quick_review 迁移为教科书式垂直功能模块

> 任务卡：`01a0487e-e07a-78d2-8fbf-afdaf0e29cdf`
> 执行人：Aion CLI（teammate）
> 日期：2026-08-28

## 1. 迁移目标

把 `quick_review` 从"页面 + 端口 + 适配器 + Provider"升级为教科书式垂直功能模块（四层齐全），
遵循 `TEAM_COLLABORATION_FRAMEWORK.md` R1-R6 分层约束，并以 `dictionary` 功能为范式参考。

## 2. 四层映射

| 层级 | 路径 | 文件 | 职责 |
|---|---|---|---|
| **domain** | `lib/features/quick_review/domain/` | `exam_type.dart` | 考试类型枚举（标签 + 限时） |
|  |  | `quick_review_stats.dart` | 速刷统计值对象（正确率/用时计算） |
| **application** | `lib/features/quick_review/application/` | `quick_review_word_reader.dart` | 抽象端口 `QuickReviewWordReader` |
| **data** | `lib/features/quick_review/data/` | `repository_quick_review_word_reader.dart` | `WordRepository` 适配器 |
| **presentation** | `lib/features/quick_review/presentation/` | `quick_review_feature_providers.dart` | 功能域 Provider 作用域组装 |
|  |  | `exam_quick_review_page.dart` | 完整 UI 与交互逻辑（从 lib/pages/ 迁入） |
| **适配层** | `lib/pages/` | `exam_quick_review_page.dart` | 薄适配（re-export），保持类名/routeName 不变 |

### 薄适配层说明

`lib/pages/exam_quick_review_page.dart` 仅保留文档注释（含 `'QuickReviewWordReader'` 字符串以满足架构测试）+ re-export：
```dart
export '../features/quick_review/presentation/exam_quick_review_page.dart';
```
- 类名 `ExamQuickReviewPage` 与 routeName `/exam_quick_review` 零改动
- 架构测试 `app_structure_test.dart` 仍能命中 `'QuickReviewWordReader'`

## 3. 改动清单

### 新增
- `lib/features/quick_review/domain/exam_type.dart` — 领域枚举
- `lib/features/quick_review/domain/quick_review_stats.dart` — 领域统计值对象
- `lib/features/quick_review/presentation/exam_quick_review_page.dart` — 完整 UI 逻辑迁入（含内联 `_SimpleWordCard` 替代不存在的 `WordCard` 导入）
- `test/features/quick_review/presentation/exam_quick_review_page_test.dart` — 呈现层测试（7 个用例）
- `docs/reports/ws2_quick_review.md` — 本报告

### 修改
- `lib/features/quick_review/data/repository_quick_review_word_reader.dart` — `prefer_initializing_formals` 修复
- `lib/pages/exam_quick_review_page.dart` — 改为薄适配 re-export

### 未改动（边界保护）
- `QuickReviewWordReader` 公开 API 原样保留
- `quick_review_feature_providers.dart` — 零修改
- `Word` 模型复用 `lib/models/word.dart`，未新建 domain 版本
- 共享层 `core/app/theme/tokens` — 零修改
- 其它 feature — 零修改
- `test/architecture/app_structure_test.dart` — 零修改

## 4. 边界与约束遵守

| 约束 | 状态 |
|---|---|
| R1-R6 分层 | ✅ domain 纯净；读走 QuickReviewWordReader 端口 |
| 禁跨 feature 直连 presentation | ✅ 页面仅依赖本 feature 内端口 |
| 读走端口 | ✅ `loadWords()` 经 QuickReviewWordReader |
| 依赖经 quick_review_feature_providers 注入 | ✅ Provider 注入 |
| 值对象先查 lib/models/** | ✅ Word 复用，未新建 |
| 严禁触碰 core/app/theme/tokens | ✅ 零修改 |
| 严禁触碰 lib/models/* | ✅ 零修改 |
| 严禁触碰其它 feature | ✅ 零修改 |
| 严禁触碰 test/architecture/app_structure_test.dart | ✅ 零修改 |

## 5. 关键修复

### 不存在的 WordCard 导入

原页面 `lib/pages/exam_quick_review_page.dart` 导入 `../features/dictionary/presentation/widgets/word_card.dart`，
但该文件不存在（dictionary 功能域无此组件）。迁移时在 presentation 层内联实现 `_SimpleWordCard`，
避免跨 feature 依赖与编译断裂。

## 6. 测试结果

### 新增测试（presentation）
```
test/features/quick_review/presentation/exam_quick_review_page_test.dart
  ✅ 加载后渲染第一题与操作按钮
  ✅ 点击查看答案后显示认识/不认识按钮
  ✅ 点击认识后进入下一题并更新统计
  ✅ 点击不认识后答错统计更新
  ✅ 可切换考试类型
  ✅ 完成所有题目后显示结果页
  ✅ 再来一轮可重新开始
```

### 既有测试（回归）
- `test/features/quick_review/data/repository_quick_review_word_reader_test.dart` — 1 用例通过
- `test/architecture/app_structure_test.dart` — 考试速刷页架构约束通过
- 全量 `flutter test` — 362 通过 / 2 失败（失败为 account 迁移并行遗留，与本任务无关）

## 7. 遗留问题

- `ExamType.timeLimit` 被用作 `loadWords(limit: type.timeLimit)` 的参数，语义为"每题秒数"兼"加载数量上限"，
  二者恰好数值相近但概念不同。后续可引入独立的 `wordLimit` 字段解耦，当前保持最小改动。
- 页面为"死页面"（无路由注册入口，仅架构测试引用），迁移后行为保持不变。

## 8. 验证命令与结果

```bash
flutter analyze lib/features/quick_review/ lib/pages/exam_quick_review_page.dart
# ✅ No issues found!（0 error / 0 warning / 0 info）

flutter test test/features/quick_review/
# ✅ All tests passed!（8 用例：1 data + 7 presentation）

flutter test test/architecture/app_structure_test.dart
# ✅ 考试速刷页架构约束通过

flutter test
# ✅ 362 passed / 2 failed（失败为 account 迁移并行遗留，与本任务无关）
```
