# WS-5 D3 · word_export_page + quick_spell_page 例句/词组可读化

## 问题

- `word_export_page.dart` 导出 TXT/CSV/Markdown 时，短语和例句以原始 JSON 串写入文本。
- `quick_spell_page.dart` 拼写完成后把例句以原始 JSON 字符串显示。

## 修复方案

利用既有 `PhraseParser.flatItems()` / `ExampleParser.parse()` 解析 JSON，输出人类可读文本。

### word_export_page.dart（3 种导出格式全部修复）

| 格式 | 修复前 | 修复后 |
|---|---|---|
| **TXT** | `短语: [{"en":"say hello",...}]` | `短语:\n    say hello　打招呼 [四级]` |
| **CSV** | 短语/例句列填入原始 JSON | 短语列 `say hello　打招呼; hello world　你好世界`；例句列 `He said hello...` |
| **Markdown** | 短语/例句列填入原始 JSON | 短语列 `say hello　打招呼<br>hello world　你好世界`；例句列 `He said hello...` |

空数据时优雅降级（跳过/留空），绝不输出 `{`/`"` 等 JSON 符号。

### quick_spell_page.dart（例句显示修复）

| 修复前 | 修复后 |
|---|---|
| `_currentWord.example` 原始 JSON 串 | `ExampleParser.parse()` → 最多 2 条例句，每条显示 `cleanEn` + 中文翻译 |

## 测试结果

| 指标 | 数值 |
|---|---|
| flutter analyze | 0 error；两文件无新增 warning/info |
| 新增测试 | 6 个（`test/pages/export_readable_test.dart`）|
| 测试结果 | 6 passed / 0 failed |

### 测试覆盖

| 测试 | 验证 |
|---|---|
| PhraseParser.readableText 含短语 | `flatItems()` 返回可读文本，无 `{`，exams 正确解析 |
| PhraseParser.readableText 空短语 | 返回空列表 |
| ExampleParser.readableText 含例句 | `cleanEn` 无 `<b>` 标签，cn/source 正确 |
| ExampleParser.readableText 空例句 | 返回空列表 |
| TXT 格式不含原始 JSON | 输出含可读中英文，不含 `{`/`"e"`/`"c"` |
| 无数据时优雅降级 | 不输出空短语/例句段 |

## 改动文件清单

| 文件 | 变化 |
|---|---|
| `lib/pages/word_export_page.dart` | 新增 import + TXT/CSV/Markdown 三格式可读化 |
| `lib/pages/quick_spell_page.dart` | 新增 import + 例句从 JSON → ExampleParser 渲染 |
| `test/pages/export_readable_test.dart` | 新增 6 个测试 |
| `docs/reports/ws5_d3_export_quick_spell.md` | 本报告 |
