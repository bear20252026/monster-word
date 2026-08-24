# IPA 全量审计：音标字符集 × 字库覆盖率核验

> 任务：【重构20】。前置：【重构13】曾抽查 19 个常用 IPA 字符，本文为全量版审计。
> 数据源：`assets/db/wordbook.db.gz`（解压至系统临时目录后以 SQLite 只读 URI 访问，原始资产零改动）。
> 工具：Python 3 + sqlite3（`file:...?mode=ro`）+ fontTools 4.x（cmap 逐字符比对）。
> 结论速览：**Inter 四字重对本 App 音标字符全集 100% 覆盖，无缺口；Charter 三样式均缺 5 个字符，若用于音标将影响 9386 个词条（占词库 29.2%）**。主路线（音标回退到 Inter）不需要任何字体补充。

---

## 1. 审计方法

1. 解压 `wordbook.db.gz` 到 `%TEMP%\ipa_audit\wordbook.db`（项目外临时目录）；
2. 以只读 URI 打开：`sqlite3.connect('file:.../wordbook.db?mode=ro', uri=True)`；
3. 对 `words` 表的 `uk_pron`（英音）、`us_pron`（美音）两字段做全列逐字符扫描，统计去重字符集、每字符总频次、分字段频次、涉及词条数（distinct word id）、涉及词书数（经 `word_books` 关联去重）；
4. 用 fontTools 读取 7 个已捆绑字体文件的 `getBestCmap()`，对字符全集逐一判定"有/无字形映射"；
5. 对存在缺口的字体，计算受影响词条并集与受影响词书并集。

## 2. 数据规模

| 项目 | 数值 |
|---|---|
| 词库总词条 | 32,154 |
| 含非空英式音标（uk_pron） | 10,636 |
| 含非空美式音标（us_pron） | 10,636 |
| 音标去重字符全集 | **54 个**（29 个 ASCII + 25 个非 ASCII，其中含 2 个组合变音符） |
| 词书总数 | 191 |

## 3. 覆盖率矩阵

| 字体文件（family） | 覆盖 | 缺口 |
|---|---|---|
| Inter-Regular.otf（Inter 400） | **54/54（100%）** | 无 |
| Inter-Medium.otf（Inter 500） | **54/54（100%）** | 无 |
| Inter-SemiBold.otf（Inter 600） | **54/54（100%）** | 无 |
| Inter-Bold.otf（Inter 700） | **54/54（100%）** | 无 |
| Charter-Roman.ttf（Charter） | 49/54（90.7%） | 见第 4 节 |
| Charter-Italic.ttf（Charter italic） | 49/54（90.7%） | 同下 |
| Charter-BoldItalic.ttf（Charter bold italic） | 49/54（90.7%） | 同下 |

三个 Charter 样式的缺口完全一致，均为下列 5 字符。

## 4. 缺口字符详情（仅影响 Charter）

| 字符 | 码点 | Unicode 名称 | 出现频次 | 涉及词条 | 涉及词书 |
|---|---|---|---|---|---|
| ˈ | U+02C8 | MODIFIER LETTER VERTICAL LINE（主重音符） | 17,263 | 8,632 | 188 |
| ː | U+02D0 | MODIFIER LETTER TRIANGULAR COLON（长音符） | 6,867 | 3,838 | 186 |
| ˌ | U+02CC | MODIFIER LETTER LOW VERTICAL LINE（次重音符） | 2,410 | 1,229 | 188 |
| ŋ | U+014B | LATIN SMALL LETTER ENG | 925 | 455 | 177 |
| ̬ | U+032C | COMBINING CARON BELOW（组合变音符） | 3 | 2 | 18 |

**影响面并集**：任一缺口字符出现的词条共 **9,386 条**（占 32,154 的 29.2%），分布在 **188/191 本词书**。示例：abandon `/əˈbændən/`、abstract `/ˈæbstrækt/`、academic `/ˌækəˈdemɪk/` —— 重音符几乎出现在每一条词典音标里。

> 与【重构13】抽查结论一致且更严重：当时发现缺 4 字符，本次全量扫描额外发现 U+032C；且量化出影响面接近三分之一词库。**任何"用 Charter 显示音标"的想法都应排除**。

## 5. 音标字符全集与频次分布表（供后续参考）

按总频次降序。"英/美"分别为该字符在 uk_pron / us_pron 中的出现次数。

| # | 字符 | 码点 | 名称 | 总频次 | 英/美 | 词条 | 词书 |
|--:|---|---|---|--:|---|--:|--:|
| 1 | ˈ | U+02C8 | MODIFIER LETTER VERTICAL LINE | 17,263 | 8631/8632 | 8,632 | 188 |
| 2 | ɪ | U+026A | LATIN LETTER SMALL CAPITAL I | 15,339 | 7706/7633 | 5,868 | 189 |
| 3 | ə | U+0259 | LATIN SMALL LETTER SCHWA | 12,441 | 6827/5614 | 5,394 | 189 |
| 4 | t | U+0074 | LATIN SMALL LETTER T | 10,599 | 5300/5299 | 4,547 | 189 |
| 5 | r | U+0072 | LATIN SMALL LETTER R | 10,201 | 4360/5841 | 5,119 | 189 |
| 6 | n | U+006E | LATIN SMALL LETTER N | 9,670 | 4834/4836 | 4,093 | 188 |
| 7 | s | U+0073 | LATIN SMALL LETTER S | 8,317 | 4157/4160 | 3,702 | 187 |
| 8 | l | U+006C | LATIN SMALL LETTER L | 7,685 | 3843/3842 | 3,611 | 182 |
| 9 | ː | U+02D0 | MODIFIER LETTER TRIANGULAR COLON | 6,867 | 2962/3905 | 3,838 | 186 |
| 10 | e | U+0065 | LATIN SMALL LETTER E | 6,810 | 3390/3420 | 3,208 | 188 |
| 11 | k | U+006B | LATIN SMALL LETTER K | 6,509 | 3255/3254 | 2,976 | 182 |
| 12 | d | U+0064 | LATIN SMALL LETTER D | 6,027 | 3013/3014 | 2,769 | 188 |
| 13 | i | U+0069 | LATIN SMALL LETTER I | 4,642 | 2326/2316 | 2,187 | 180 |
| 14 | m | U+006D | LATIN SMALL LETTER M | 4,410 | 2205/2205 | 2,084 | 184 |
| 15 | p | U+0070 | LATIN SMALL LETTER P | 4,122 | 2061/2061 | 1,961 | 181 |
| 16 | æ | U+00E6 | LATIN SMALL LETTER AE | 3,338 | 1603/1735 | 1,710 | 178 |
| 17 | b | U+0062 | LATIN SMALL LETTER B | 2,756 | 1378/1378 | 1,333 | 173 |
| 18 | f | U+0066 | LATIN SMALL LETTER F | 2,687 | 1344/1343 | 1,308 | 185 |
| 19 | a | U+0061 | LATIN SMALL LETTER A | 2,655 | 1340/1315 | 1,297 | 189 |
| 20 | ʊ | U+028A | LATIN SMALL LETTER UPSILON | 2,583 | 1287/1296 | 1,271 | 189 |
| 21 | ʃ | U+0283 | LATIN SMALL LETTER ESH | 2,548 | 1275/1273 | 1,261 | 184 |
| 22 | ˌ | U+02CC | MODIFIER LETTER LOW VERTICAL LINE | 2,410 | 1193/1217 | 1,229 | 188 |
| 23 | v | U+0076 | LATIN SMALL LETTER V | 2,104 | 1052/1052 | 1,022 | 187 |
| 24 | ɑ | U+0251 | LATIN SMALL LETTER ALPHA | 1,821 | 509/1312 | 1,429 | 183 |
| 25 | ʌ | U+028C | LATIN SMALL LETTER TURNED V | 1,807 | 914/893 | 911 | 184 |
| 26 | u | U+0075 | LATIN SMALL LETTER U | 1,705 | 856/849 | 849 | 184 |
| 27 | ɡ | U+0261 | LATIN SMALL LETTER SCRIPT G | 1,613 | 807/806 | 791 | 180 |
| 28 | ɔ | U+0254 | LATIN SMALL LETTER OPEN O | 1,581 | 721/860 | 861 | 187 |
| 29 | ʒ | U+0292 | LATIN SMALL LETTER EZH | 1,359 | 667/692 | 688 | 179 |
| 30 | z | U+007A | LATIN SMALL LETTER Z | 1,333 | 670/663 | 665 | 177 |
| 31 | h | U+0068 | LATIN SMALL LETTER H | 1,241 | 622/619 | 612 | 171 |
| 32 | w | U+0077 | LATIN SMALL LETTER W | 1,102 | 551/551 | 545 | 181 |
| 33 | ɒ | U+0252 | LATIN SMALL LETTER TURNED ALPHA | 1,083 | 1081/2 | 1,066 | 176 |
| 34 | j | U+006A | LATIN SMALL LETTER J | 973 | 568/405 | 568 | 176 |
| 35 | ɜ | U+025C | LATIN SMALL LETTER REVERSED OPEN E | 963 | 471/492 | 503 | 171 |
| 36 | ( | U+0028 | LEFT PARENTHESIS | 947 | 946/1 | 944 | 171 |
| 37 | ) | U+0029 | RIGHT PARENTHESIS | 947 | 946/1 | 944 | 171 |
| 38 | ŋ | U+014B | LATIN SMALL LETTER ENG | 925 | 463/462 | 455 | 177 |
| 39 | o | U+006F | LATIN SMALL LETTER O | 841 | 4/837 | 822 | 183 |
| 40 | θ | U+03B8 | GREEK SMALL LETTER THETA | 511 | 255/256 | 255 | 170 |
| 41 | ␠ | U+0020 | SPACE（音标内空格） | 225 | 112/113 | 101 | 145 |
| 42 | ð | U+00F0 | LATIN SMALL LETTER ETH | 179 | 90/89 | 89 | 164 |
| 43 | : | U+003A | COLON（半角冒号混入） | 68 | 67/1 | 62 | 119 |
| 44 | ' | U+0027 | APOSTROPHE（直引号重音混入） | 61 | 30/31 | 35 | 53 |
| 45 | ɛ | U+025B | LATIN SMALL LETTER OPEN E | 51 | 0/51 | 49 | 105 |
| 46 | ɚ | U+025A | LATIN SMALL LETTER SCHWA WITH HOOK | 29 | 0/29 | 29 | 82 |
| 47 | , | U+002C | COMMA | 10 | 2/8 | 10 | 25 |
| 48 | ɝ | U+025D | REVERSED OPEN E WITH HOOK | 8 | 0/8 | 8 | 28 |
| 49 | . | U+002E | FULL STOP | 3 | 0/3 | 1 | 4 |
| 50 | · | U+00B7 | MIDDLE DOT | 3 | 3/0 | 1 | 4 |
| 51 | ̬ | U+032C | COMBINING CARON BELOW | 3 | 1/2 | 2 | 18 |
| 52 | ̃ | U+0303 | COMBINING TILDE | 2 | 2/0 | 2 | 44 |
| 53 | ; | U+003B | SEMICOLON | 1 | 1/0 | 1 | 5 |
| 54 | ʤ | U+02A4 | LATIN SMALL LETTER DEZH DIGRAPH | 1 | 0/1 | 1 | 20 |

### 5.1 字符构成分析

- **IPA 核心特殊字符（25 个非 ASCII）**：元音类 ə ɪ ʊ ʌ ɑ ɔ æ ɛ ɜ ɒ ɚ ɝ、辅音类 ʃ ʒ ŋ ɡ θ ð ʤ、韵律符 ˈ ˌ ː ·、组合符 ̬ ̃。覆盖了 DJ 音标/KK 音标的全部常用符号，无生僻 IPA 扩展区字符（U+1D00–U+1D7F 未出现）；
- **ASCII 部分（29 个）**：21 个小写辅音/元音字母 + 括号/逗号/句点/分号等排版符；
- **值得注意的数据质量问题**（不影响字体结论，供词书维护参考）：
  - `:` 半角冒号 68 次（应为 `ː` U+02D0 的误录）；
  - `'` 直撇号 61 次（应为 `ˈ` U+02C8 的误录）；
  - 组合变音符 U+032C/U+0303 仅 5 次且依附于普通字母（如 t̬ 表示美音闪音）；
  - `ʤ` U+02A4 为旧式合字记法，仅 1 处。

## 6. 结论与建议

### 6.1 结论

1. **Inter 是否 100% 覆盖？—— 是。** Inter 四个字重的 cmap 均完整覆盖本词库 54 个音标字符，无任何缺口；且 OTF 内建 GPOS mark 定位，两个组合变音符（U+032C/U+0303）可正常锚定渲染；
2. **无缺口字符，因此无需补充 Noto Sans / SIL 字体**。【重构13】采用的方案（删除未注册的 `'phonetic'` 引用、回退主题默认 Inter）经本次全量审计确认是正确且充分的；
3. **Charter 不具备音标显示能力**：缺 5 字符中含最高频的主重音符（17,263 次），一旦用于音标将造成 29.2% 词条出现"豆腐块/回退混排"，三样式缺口一致，属字库设计取舍而非个别文件问题。

### 6.2 建议

1. **维持现状**：PhoneticText 继续使用主题默认字体（Inter），不加任何 fontFamily 覆盖；不要给音标指定 Charter；
2. **不建议为此新增资产**：Inter 已全覆盖，引入 Noto Sans/Gentium Plus 只会增加体积而无收益；仅当未来切换到不含 IPA 扩展的其他西文字体时，再按 `fontFamilyFallback: ['Inter', ...]` 兜底即可；
3. **组合变音符渲染抽查**（低优先级）：U+032C/U+0303 合计仅 5 处，建议在 UI 冒烟时顺带目检 2 个受影响单词的音标显示是否正常锚定；
4. **数据治理（可选，独立于字体任务）**：`:`→`ː`、`'`→`ˈ` 的规范化清洗可提升音标排版一致性（约 129 处）；如执行请另开词书数据任务，勿在字体任务内改动数据库；
5. **回归用例**：可将第 5 节 54 字符全集固化为音标显示的测试样例集，防止未来更换字体时再次引入缺口。

---

*审计脚本与中间产物（ipa_chars.json / coverage_matrix.json / impact.json）存于 `%TEMP%\ipa_audit\`，未进入仓库；数据库副本亦在临时目录，未触碰 `assets/db/` 原始文件。*
