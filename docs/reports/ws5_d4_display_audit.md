# WS-5 D4 显示审计：原始 JSON 显示 & 例句音频接入

> 审计日期：2026-08-28
> 审计范围：`lib/` 下所有页面、组件、屏幕
> 审计目标：排查 `example` / `phrase` / `wordRoot` 字段的原始 JSON 显示，以及例句音频播放接入情况

---

## 一、审计方法

1. **Grep 扫描**：对 `.example`、`.phrase`、`.wordRoot` 字段访问进行全量搜索
2. **逐文件确认**：对每个命中点读取上下文，判断是否经过结构化解析
3. **音频接入检查**：对每个显示例句的组件，检查是否接入 `AudioPlaybackState.playSentence()`

---

## 二、原始 JSON 显示审计

### ✅ 全部合规（无原始 JSON 显示）

| 文件 | 处理方式 | 状态 |
|------|----------|------|
| `lib/pages/word_detail_page.dart` | `ExampleParser.parse()` + `PhraseParser` + `WordRootTab` | ✅ |
| `lib/pages/listening_player_page.dart` | `ExampleParser.parse()` via `_buildStructuredExample` | ✅ |
| `lib/pages/quick_spell_page.dart` | `ExampleParser.parse()` | ✅ |
| `lib/pages/sentence_quiz_page.dart` | `ExampleParser.parse()`（用于题目生成） | ✅ |
| `lib/screens/learn_session.dart` | `ExampleParser.parse()` | ✅ |
| `lib/pages/word_machine_page.dart` | `ExampleParser.parse()` via `_buildExampleSection` | ✅ |
| `lib/widgets/word_dictionary_popup.dart` | `ExampleParser.parse()` via `_buildExample` | ✅ |
| `lib/features/search/presentation/search_page.dart` | `ExampleParser.parse()` via `_buildExampleCard` | ✅ |
| `lib/features/book/presentation/book_words_page.dart` | `ExampleParser.parse()` | ✅ |
| `lib/pages/word_export_page.dart` | `ExampleParser.parse()` | ✅ |
| `lib/widgets/adapter_widgets.dart:1952` | `RootSuffixData.example` 为普通字符串（非 JSON 结构） | ✅ |

### 结论

**未发现原始 JSON 显示违规。** 所有 `example` 字段均通过 `ExampleParser.parse()` 解析为 `ExampleSentence` 列表后展示；所有 `phrase` 字段均通过 `PhraseParser` 处理；所有 `wordRoot` 字段均通过 `WordRootTab` 组件渲染。

---

## 三、例句音频接入审计

### ✅ 已接入音频播放

| 文件 | 接入方式 |
|------|----------|
| `lib/pages/word_detail_page.dart` | `_playExampleAudio()` → `context.read<AudioPlaybackState>().playSentence(url)` + `volume_up` 图标 |

### ❌ 未接入音频播放（已修复 1 处）

| 文件 | 问题 | 修复状态 |
|------|------|----------|
| `lib/screens/learn_session.dart` | `_ExampleCard` 显示解析后例句但无音频按钮 | ✅ 已修复 |

### ⚠️ 未接入音频播放（待后续处理）

| 文件 | 问题 |
|------|------|
| `lib/pages/word_machine_page.dart` | `_buildExampleSection` 显示例句但无音频按钮 |
| `lib/widgets/word_dictionary_popup.dart` | `_buildExample` 显示例句但无音频按钮 |
| `lib/pages/listening_player_page.dart` | `_buildStructuredExample` 显示例句但无音频按钮 |
| `lib/pages/quick_spell_page.dart` | `_buildExampleSection` 显示例句但无音频按钮 |
| `lib/features/search/presentation/search_page.dart` | `_buildExampleCard` 显示例句但无音频按钮 |

---

## 四、修复详情

### 修复文件：`lib/screens/learn_session.dart`

**问题**：`_ExampleCard` 组件显示 `ExampleParser.parse()` 解析后的例句（高亮 + 中文 + 来源），但未提供音频播放按钮。`ExampleSentence` 模型已包含 `audioUrl` 字段，数据已就绪。

**修复内容**：
1. 新增 `import '../core/audio/audio_playback_state.dart';`
2. 在 `_ExampleCard.build()` 末尾（来源下方）添加条件音频按钮：
   - 当 `example.audioUrl` 非空时显示 `volume_up` 图标按钮
   - 点击调用 `context.read<AudioPlaybackState>().playSentence(example.audioUrl!)`

**验证**：`flutter analyze lib/screens/learn_session.dart` → No issues found.

---

## 五、后续建议

1. **批量接入音频**：对 `word_machine_page.dart`、`word_dictionary_popup.dart`、`listening_player_page.dart`、`quick_spell_page.dart`、`search_page.dart` 的例句卡片统一接入音频播放按钮，复用与 `learn_session.dart` 相同的模式。
2. **抽取公共组件**：考虑将例句卡片 + 音频按钮抽取为 `AudioExampleCard` 公共组件，避免重复代码。
3. **数据完整性**：确认后端 `audioUrl` 字段覆盖率，对无音频的例句隐藏按钮（当前已实现）。

---

## 六、审计结论

- **原始 JSON 显示**：✅ 全部合规，无需修复
- **例句音频接入**：⚠️ 6 处未接入，已修复 1 处（最高频使用的学习页），其余 5 处建议后续批量处理
