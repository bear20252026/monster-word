# [WS-2] Settings 垂直模块迁移报告

**日期**: 2026-08-28
**迁移范围**: `lib/features/settings/` → 教科书式四层垂直模块

## 迁移摘要

参照字典/checkin 范式，将 settings 从「数据 + 表示」二层升级为「域 → 应用 → 数据 → 表示」四层垂直模块。两个页面完整 UI/逻辑从 `lib/pages/` 吸收到 `features/settings/presentation/`，原位置保留薄 re-export 适配器。

## 目录结构（迁移后）

```
lib/features/settings/
├── domain/
│   └── learning_preferences.dart          ← 新建：不可变值对象
├── application/
│   ├── settings_reader.dart               ← 新建：读取端口（抽象接口）
│   └── settings_writer.dart               ← 新建：写入端口（抽象接口）
├── data/
│   └── learning_preferences_repository.dart  ← 重构：实现 SettingsReader + SettingsWriter
└── presentation/
    ├── learning_preferences_state.dart      ← 重构：依赖抽象端口而非具体 Repository
    ├── settings_feature_providers.dart      ← 重构：MultiProvider + 延迟初始化
    ├── settings_page.dart                   ← 迁入：完整设置页 UI（691 行）
    └── more_settings_page.dart              ← 迁入：更多设置页 UI（485 行）

lib/pages/
├── settings_page.dart                       ← 薄 re-export
└── more_settings_page.dart                  ← 薄 re-export
```

## 文件变更清单

| 操作 | 文件 | 说明 |
|------|------|------|
| 新建 | `domain/learning_preferences.dart` | LearningPreferences 不可变值对象，零外部导入 |
| 新建 | `application/settings_reader.dart` | `Future<LearningPreferences> load()` |
| 新建 | `application/settings_writer.dart` | `Future<void> save(LearningPreferences)` |
| 重构 | `data/learning_preferences_repository.dart` | `implements SettingsReader, SettingsWriter`；移除内联 LearningPreferences 类 |
| 重构 | `presentation/learning_preferences_state.dart` | 构造器依赖 `SettingsReader` + `SettingsWriter`，使用 `required this._field` 模式 |
| 重构 | `presentation/settings_feature_providers.dart` | MultiProvider 提供 Repository + State；`_SettingsFeatureInitializer` 延迟初始化 |
| 迁入 | `presentation/settings_page.dart` | 从 `lib/pages/settings_page.dart` 完整迁移 |
| 迁入 | `presentation/more_settings_page.dart` | 从 `lib/pages/more_settings_page.dart` 完整迁移 |
| 替换 | `lib/pages/settings_page.dart` | 2 行薄 re-export |
| 替换 | `lib/pages/more_settings_page.dart` | 2 行薄 re-export |

## 新建测试

| 测试 | 覆盖 |
|------|------|
| `test/features/settings/domain/learning_preferences_test.dart` | defaults、copyWith 保留/覆盖、不可变性 |
| `test/features/settings/application/settings_ports_test.dart` | 内存实现端口契约：load/save/多次覆盖 |
| `test/features/settings/presentation/learning_preferences_state_test.dart` | 更新构造器签名（`reader:` + `writer:`） |

## 依赖方向

```
presentation → application ← data
       ↑                ↑
       │                │
    LearningPreferencesState  LearningPreferencesRepository
    (依赖 SettingsReader +    (实现 SettingsReader +
     SettingsWriter 端口)      SettingsWriter 端口)
```

域层 `LearningPreferences` 零外部导入，被 application / data / presentation 三层引用。

## Lint / 分析

```
dart analyze lib/features/settings  → No issues found!
```

## 测试结果

```
flutter test → 372 passed, 1 failed
```

唯一失败：`app_structure_test.dart: 设置功能域拥有学习偏好…` — 该测试直接读 `lib/pages/settings_page.dart` 源码断言包含 `LearningPreferencesState`。现在该文件为薄 re-export，内容已移至 feature 内部。**此测试需 lead 修复**（与 checkin 迁移情况一致）。

## 构造器 Lint 处理

遵循 checkin 迁移经验，所有 data/presentation 构造器使用 `required this._field` 模式（无类型注解），同时满足 `prefer_initializing_formals` 和 `type_init_formals`。
