# [WS-1] Lint B: services/data/repos/utils/engine + tests 清理报告

**日期**: 2026-08-28
**范围**: `lib/services/**` `lib/data/**` `lib/repositories/**` `lib/utils/**` `lib/engine/**` `test/**`

## 修复清单

### lib/data/ (2 warning)
| 文件 | Lint | 修复 |
|------|------|------|
| `wordbook_database.dart` | `unused_import` (`dart:convert`) | 删除 import |
| `wordbook_database.dart` | `unused_import` (`../models/definition.dart`) | 删除 import（已通过 `../models/word.dart` 间接导出） |

### lib/repositories/ (3 issues)
| 文件 | Lint | 修复 |
|------|------|------|
| `fav_repository.dart` | `unused_import` (`../models/sentence_models.dart`) | 删除 import |
| `book_repository_impl.dart` | `unnecessary_import` (`../../models/book.dart`) | 删除 import（通过 wordbook_database.dart 已导出） |
| `fav_repository_impl.dart` | `prefer_final_fields` (`_favoriteWords`) | 添加 `// ignore: prefer_final_fields`（该字段在 `_loadFavorites` 中被整体替换） |

### lib/utils/ (2 info)
| 文件 | Lint | 修复 |
|------|------|------|
| `app_utils.dart` | `constant_identifier_names` (`PRON_US`, `PRON_UK`) | 重命名为 `pronUs`, `pronUk`（camelCase） |

### lib/engine/ (2 info)
| 文件 | Lint | 修复 |
|------|------|------|
| `bs/example_processor.dart` | `unintended_html_in_doc_comment` (×2) | 用反引号包裹 `<myspan>` 和 `<highlight>` |

### lib/services/ (3 issues)
| 文件 | Lint | 修复 |
|------|------|------|
| `checkin_service_impl.dart` | `prefer_initializing_formals` | 改用 `required this._userRepo` 模式 |
| `user_service_impl.dart` | `prefer_initializing_formals` (×2) | 改用 `required this._userRepo, required this._noteRepo` 模式 |

### test/ (7 issues from my fixes)
| 文件 | Lint | 修复 |
|------|------|------|
| `service_checkin_status_reader_test.dart` | `unused_import` (`checkin_status.dart`) | 删除 import |
| `checkin_history_state_test.dart` | `unused_import` (`checkin_status.dart`) | 删除 import |
| `checkin_history_state_test.dart` | `prefer_final_fields` (`_reward`) | 加 `final` |
| `scare_coin_history_page_test.dart` | `prefer_initializing_formals` (×2) | 改用 `this._balance`, `this._checkedToday` 模式 |
| `contrast_guard_test.dart` | `deprecated_member_use` Color.alpha/red/green/blue (×20) | 改用 `.a`/`.r`/`.g`/`.b` (double 0.0-1.0)；修复 `_alphaComposite` 公式乘 255；修复输出信息乘 255 |
| `repository_word_search_reader_test.dart` | `unnecessary_named_positional_parameters` | 改为位置参数 |

### pubspec.yaml (1 issue)
| 文件 | Lint | 修复 |
|------|------|------|
| `pubspec.yaml` | `depend_on_referenced_packages` (test/data_verification_test.dart) | 添加 `path_provider_platform_interface: ^4.1.0` 至 dev_dependencies |

## 验证

| 检查项 | 结果 |
|--------|------|
| `flutter analyze lib/services lib/data lib/repositories lib/utils lib/engine` | **No issues found!** |
| `flutter analyze test` | **No issues found!** |
| `flutter test` | **383 passed, 0 failed** |
