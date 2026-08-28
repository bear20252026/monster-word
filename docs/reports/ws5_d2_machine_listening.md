# [WS-5 D2] word_machine_page + listening_player_page 例句/词根结构化显示

**日期**: 2026-08-28
**目标**: 将两个页面中的例句/词根从原始 JSON 字符串改为结构化正确显示

## 问题

`word_machine_page.dart` 和 `listening_player_page.dart` 直接打印 `word.example` 和 `word.wordRoot` 原始 JSON 字符串，导致乱码、错符号、显示不全。

## 修复

### 1. `lib/pages/word_machine_page.dart`

- **新增 import**: `example_parser.dart`, `word_root_tab.dart`
- **例句显示**: 原来直接 `Text(word.example)` → 改为 `ExampleParser.parse(word.example)` 解析后逐条渲染 `en` 文本
- **词根显示**: 原来直接 `Text(word.wordRoot)` → 改为 `WordRootTab(wordRootJson: word.wordRoot)` 组件渲染
- **空数据降级**: 两者均判断空串/空解析结果后跳过渲染（不显示区块）
- **新增辅助方法**: `_buildExampleSection(Word)` / `_buildWordRootSection(Word)` 返回 `List<Widget>`

### 2. `lib/pages/listening_player_page.dart`

- **新增 import**: `example_parser.dart`
- **例句显示**: 原来直接 `Text(word.example)` → 改为 `_buildStructuredExample(word, skin)` 渲染结构化例句（en/cn 双行），保留原有 `cardBgAlt` 圆角卡片样式
- **TTS 朗读**: `_speakCurrent` 的 `wordExample` 模式改为朗读解析后第一条例句的 `en` 字段（而非原始 JSON 字符串）
- **空数据降级**: `ExampleParser.parse` 返回空时回退到原始文本显示（保证不丢内容）

## 测试

**`test/features/learning/pages/structured_display_test.dart`**（新建，9 项全绿）

| 测试 | 验证 |
|------|------|
| 解析单词例句 JSON 数组 | 词库格式 → 1 条例句正确提取 en/cn/source |
| 解析多条例句 | 2 条例句正确提取 |
| 空数组返回空列表 | `[]` → 空 |
| 非法 JSON 返回空列表 | `not json` → 空 |
| 空字符串返回空列表 | `""` → 空 |
| 渲染词根信息 | `WordRootTab` 正常构建 |
| 空字符串不崩溃 | `WordRootTab` 空输入不抛异常 |
| 含 example + wordRoot 的 Word 构造正确 | Word 对象 → parse 验证 |
| 空 example + wordRoot 优雅降级 | 空字段 → 空解析结果 |

## 验证

| 检查项 | 结果 |
|--------|------|
| `flutter analyze word_machine_page.dart` | **No issues found!** |
| `flutter analyze listening_player_page.dart` | **No issues found!** |
| `flutter test structured_display_test.dart` | **9/9 全绿** |
