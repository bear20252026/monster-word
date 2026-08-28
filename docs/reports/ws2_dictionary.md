# WS-2 范式：dictionary 重构为教科书式垂直功能模块

## 1. 目标

将 `lib/features/dictionary` 从"仅有 port/reader 的薄壳"升级为**教科书式完整垂直模块**（domain / application / data / presentation 四层齐全），作为团队后续迁移的**范式模板**。

## 2. 改了什么

### 2.1 新增文件

| 文件 | 层级 | 职责 |
|------|------|------|
| `domain/phonetic_info.dart` | domain | 音标信息值对象（纯数据） |
| `domain/definition_item.dart` | domain | 单条释义值对象 + 从 `List<Definition>` 转换 |
| `domain/example_sentence.dart` | domain | 例句值对象 |
| `application/dictionary_search_reader.dart` | application | 搜索端口（读） |
| `application/dictionary_favorite_writer.dart` | application | 收藏操作端口（写） |
| `application/dictionary_new_word_writer.dart` | application | 生词本操作端口（写） |
| `data/service_dictionary_search_reader.dart` | data | 搜索适配器（WordBookDatabase） |
| `data/service_dictionary_favorite_writer.dart` | data | 收藏适配器（FavRepository） |
| `data/service_dictionary_new_word_writer.dart` | data | 生词本适配器（NewWordRepositoryImpl） |
| `presentation/dictionary_detail_state.dart` | presentation | ChangeNotifier 聚合状态 |
| `presentation/dictionary_page.dart` | presentation | 详情页 UI |

### 2.2 修改文件

| 文件 | 改动 |
|------|------|
| `presentation/dictionary_feature_providers.dart` | 扩展为四个端口提供者 + 双 scope 工厂 |
| `lib/pages/dictionary_page.dart` | 改为 re-export 兼容层（委托给 feature） |
| `lib/services/dictionary_service.dart` | 移除已迁移的三个内容方法（getDerivedWords / getSynonyms / getExamExamples） |
| `data/service_dictionary_content_reader.dart` | 改为直接使用 WordBookDatabase，移除 DictionaryService 依赖 |
| `test/architecture/app_structure_test.dart` | 更新架构断言以匹配新四层结构 |

### 2.3 新增测试

| 文件 | 覆盖 |
|------|------|
| `test/features/dictionary/domain/phonetic_info_test.dart` | PhoneticInfo 值对象 |
| `test/features/dictionary/domain/definition_item_test.dart` | DefinitionItem 值对象 |
| `test/features/dictionary/domain/example_sentence_test.dart` | ExampleSentence 值对象 |
| `test/features/dictionary/presentation/dictionary_detail_state_test.dart` | 聚合状态与交互逻辑 |

## 3. 怎么分层

```
lib/features/dictionary/
├── domain/                         ← 纯数据 + 纯逻辑，零外部依赖
│   ├── phonetic_info.dart
│   ├── definition_item.dart
│   └── example_sentence.dart
├── application/                    ← 端口（接口），定义读/写契约
│   ├── dictionary_content_reader.dart   (已有)
│   ├── dictionary_search_reader.dart    (新增)
│   ├── dictionary_favorite_writer.dart  (新增)
│   └── dictionary_new_word_writer.dart  (新增)
├── data/                           ← 适配器，实现端口，访问数据库/仓储
│   ├── service_dictionary_content_reader.dart
│   ├── service_dictionary_search_reader.dart
│   ├── service_dictionary_favorite_writer.dart
│   └── service_dictionary_new_word_writer.dart
└── presentation/                   ← UI + 状态 + DI
    ├── dictionary_feature_providers.dart
    ├── dictionary_detail_state.dart
    └── dictionary_page.dart
```

### 依赖方向

```
presentation → application → domain
                  ↑
                 data ──┘
```

- **presentation** 依赖 application 端口 + 自身状态
- **data** 实现 application 端口，依赖 domain + 共享基础设施
- **domain** 零外部依赖，纯 Dart
- **application** 仅定义接口，不依赖 data/presentation

### 读写分离

- 读操作经 `*_reader` 端口（DictionarySearchReader / DictionaryContentReader）
- 写操作经 `writer` 端口（DictionaryFavoriteWriter / DictionaryNewWordWriter）

## 4. 边界

### 4.1 允许的依赖

- `domain/` → 无外部依赖
- `application/` → `domain/` + 共享模型（`lib/models/`）
- `data/` → `application/` + `domain/` + 共享基础设施（`lib/data/`、`lib/repositories/`）
- `presentation/` → `application/` + 共享 UI 基础设施（`lib/theme/`、`lib/tokens/`、`lib/widgets/`）

### 4.2 禁止的依赖

- 任何 feature 目录不得 import 其他 feature 内部文件
- 业务逻辑不得新建在 `pages/screens/services` 下
- presentation 不得绕过端口直接访问 data 层

### 4.3 共享层复用

- 收藏：`FavRepository` / `FavRepositoryImpl`（`lib/repositories/`）
- 生词本：`NewWordRepositoryImpl`（`lib/repositories/`）
- 数据库：`WordBookDatabase`（`lib/data/`）
- UI 基础设施：`MistralTypography`、`MistralColors`、`AppSpacing` 等

## 5. 验证结果

| 检查项 | 状态 |
|--------|------|
| `flutter analyze` 0 error | PASS |
| 本 feature 相关文件无新增 warning/info | PASS |
| 新增单测全绿（25 个） | PASS |
| `flutter test` 全量通过（296 个测试） | PASS |
| 架构测试更新并 PASS | PASS |

## 6. 范式要点（供团队后续迁移参考）

1. **四层齐全**：domain / application / data / presentation 四层必须都存在，缺失层先建骨架
2. **端口先行**：application 层定义 `*_reader` / `*_writer` 接口，data 层实现
3. **状态聚合**：presentation 层用 ChangeNotifier 聚合多个端口为单一状态对象
4. **DI 注入**：依赖经 `*_feature_providers.dart` 的 scope 工厂注入，不绕过
5. **domain 纯净**：domain 层零外部依赖，仅纯数据和纯函数
6. **读写分离**：读走 reader，写走 writer/store
7. **兼容迁移**：旧页面改为 re-export，既有调用方无需改动
