# 词书数据库完整性验证报告

> 验证人：DataEngineer（Monster world）· 2026-08-24
> 项目：word_app
> 方法：gzip 解压 → sqlite3 只读模式全量验证

---

## 一、文件概况

| 项目 | 值 |
|---|---|
| 压缩文件 | `assets/db/wordbook.db.gz` |
| 解压后大小 | 119,992,320 B ≈ **114.4 MB** |
| 解压状态 | ✅ 正常解压，无损坏 |
| SQLite 完整性 | ✅ 只读模式打开成功，无错误 |

---

## 二、表结构

共 4 张表：

| 表名 | 字段 | 说明 |
|---|---|---|
| `words` | id, word, main_word, interpret, uk_pron, us_pron, phrase, example, confuse, audio_urls, image_urls, word_root | 单词主表 |
| `books` | id, code, name, word_count | 词书目录 |
| `word_books` | word_id, book_id | 单词↔词书关联表 |
| `sqlite_sequence` | name, seq | SQLite 自增序列（系统表） |

与 `lib/data/wordbook_database.dart` 中的模型定义完全一致。

---

## 三、数据量验证

| 指标 | 实测值 | 预期值 | 状态 |
|---|---|---|---|
| 词条总数 | **32,154** | 32,154（音标清洗审计基线） | ✅ 一致 |
| 词书数量 | **191** | 191（词书名解码方案） | ✅ 一致 |
| 词书-单词映射数 | **454,196** | — | ✅ 正常（平均每词书 ~2,378 词） |
| 含英式音标的词 | **10,636** | — | ✅ |
| 含美式音标的词 | **10,636** | — | ✅ |

---

## 四、音标字段误录检查

来源：重构 #39 音标数据清洗（129 处 → 0）

| 检查项 | 实测值 | 状态 |
|---|---|---|
| uk_pron 含半角冒号 `:` | **0** | ✅ 无残留 |
| us_pron 含半角冒号 `:` | **0** | ✅ 无残留 |
| uk_pron 含半角撇号 `'` | **0** | ✅ 无残留 |
| us_pron 含半角撇号 `'` | **0** | ✅ 无残留 |
| uk_pron 含 IPA 长音符号 `ː` | **2,897** | ✅ 正确使用 |
| us_pron 含 IPA 长音符号 `ː` | **3,679** | ✅ 正确使用 |
| uk_pron 含 IPA 重音符号 `ˈ` | **8,648** | ✅ 正确使用 |
| us_pron 含 IPA 重音符号 `ˈ` | **8,649** | ✅ 正确使用 |

**音标样例：**
- abandon: uk=[əˈbændən] us=[əˈbændən]
- abnormal: uk=[æbˈnɔːml] us=[æbˈnɔːrml]
- abstract: uk=[ˈæbstrækt] us=[ˈæbstrækt]
- academic: uk=[ˌækəˈdemɪk] us=[ˌækəˈdemɪk]
- access: uk=[ˈækses] us=[ˈækses]

---

## 五、数据加载代码引用检查

`WordBookDatabase` 在以下位置被正确引用：

| 文件 | 引用方式 | 状态 |
|---|---|---|
| `main.dart:61-62` | `ensurePlatform()` + `initialize()` 启动初始化 | ✅ |
| `lib/data/wordbook_database.dart:116` | `rootBundle.load('assets/db/wordbook.db.gz')` | ✅ 路径匹配 |
| `lib/services/dictionary_service.dart:14` | `WordBookDatabase.instance` 字典服务封装 | ✅ |
| `lib/state/learning_state.dart:277,323,566` | 收藏/学习队列/词书查询 | ✅ |
| `lib/pages/lib_select_page.dart:39` | 词书列表加载 | ✅ |
| `lib/pages/search_page.dart:63` | 单词搜索 | ✅ |
| `lib/pages/review_page.dart:45` | 复习页单词加载 | ✅ |
| `lib/pages/exam_quick_review_page.dart:95` | 快速复习 | ✅ |
| `lib/screens/review_session.dart:43` | 复习会话 | ✅ |
| `lib/widgets/word_lookup_popup.dart:106` | 单词查询弹窗 | ✅ |

pubspec.yaml 声明：`- assets/db/wordbook.db.gz`（:79）✅ 与实际路径一致。

---

## 六、结论

| 维度 | 状态 |
|---|---|
| 文件完整性 | ✅ gzip 解压正常，SQLite 打开无错误 |
| 表结构 | ✅ 4 张表，字段与代码模型一致 |
| 数据量 | ✅ 32,154 词条 / 191 词书 / 454,196 映射 |
| 音标清洗 | ✅ 零残留误录字符，IPA 符号正确 |
| 代码引用 | ✅ 10 处引用路径正确，pubspec 声明匹配 |

**数据库状态健康，无需任何修复操作。**

---

*产出：DataEngineer · 2026-08-24 · 基于 sqlite3 只读模式全量验证*
