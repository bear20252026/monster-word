# 音标数据清洗二次验证报告

> 任务：【重构60】。独立校验【重构39】的清洗结果。
> 验证时间：2026-08-24
> 验证者：PhoneticsEngineer (Monster world)

---

## 1. 验证方法

从已清洗的 `assets/db/wordbook.db.gz` 解压后以 **只读模式** 打开数据库，独立执行全部校验查询，不依赖【重构39】的执行日志中的数字。

## 2. 校验结果

### ✅ 2.1 词条总数

| 指标 | 期望值 | 实测值 | 结果 |
|---|---|---|---|
| COUNT(*) FROM words | 32,154 | 32,154 | **通过** |

### ✅ 2.2 误录字符归零

| 检查项 | 字段 | 期望值 | 实测值 | 结果 |
|---|---|---|---|---|
| 半角冒号 `:` (U+003A) | uk_pron + us_pron | 0 | 0 | **通过** |
| 半角撇号 `'` (U+0027) | uk_pron + us_pron | 0 | 0 | **通过** |

### ✅ 2.3 正确字符出现次数

| 字符 | 字段 | 期望值 | 实测值 | 结果 |
|---|---|---|---|---|
| `ː` (U+02D0) 长音符 | uk_pron | ≥ (2962+67) | 3,029 | **通过** |
| `ː` (U+02D0) 长音符 | us_pron | ≥ (3905+1) | 3,906 | **通过** |
| `ː` 合计 | | ≥ 6,935 | 6,935 | **通过** |
| `ˈ` (U+02C8) 主重音 | uk_pron | ≥ (8631+30) | 8,661 | **通过** |
| `ˈ` (U+02C8) 主重音 | us_pron | ≥ (8632+31) | 8,663 | **通过** |
| `ˈ` 合计 | | ≥ 17,324 | 17,324 | **通过** |

### ✅ 2.4 与【重构39】执行日志交叉核验

| 指标 | 【重构39】报告值 | 本次独立实测 | 一致？ |
|---|---|---|---|
| 词条总数 | 32,154 | 32,154 | ✅ |
| 残余冒号 | 0 | 0 | ✅ |
| 残余撇号 | 0 | 0 | ✅ |
| ː uk_pron | 3,029 | 3,029 | ✅ |
| ː us_pron | 3,906 | 3,906 | ✅ |
| ˈ uk_pron | 8,661 | 8,661 | ✅ |
| ˈ us_pron | 8,663 | 8,663 | ✅ |

## 3. 抽样 20 条 before/after 对照

从原始备份数据库（清洗前）中选取 20 条含误录的记录，与清洗后数据库中同一单词逐字段比对：

| # | 单词 | 字段 | before | after | 正确？ |
|--:|---|---|---|---|---|
| 1 | aboveboard | uk_pron | əˌbʌvˈbɔ:d | əˌbʌvˈbɔːd | ✅ |
| 2 | abuzz | us_pron | ə'bʌz | əˈbʌz | ✅ |
| 3 | aftereffect | uk_pron | ˈɑ:ftəɪˌfekt | ˈɑːftəɪˌfekt | ✅ |
| 4 | anemia | uk_pron | əˈni:mɪə | əˈniːmɪə | ✅ |
| 5 | anesthetize | uk_pron | əˈni:sθətaɪz | əˈniːsθətaɪz | ✅ |
| 6 | ardor | uk_pron | ˈɑ:də | ˈɑːdə | ✅ |
| 7 | baby boom | uk_pron | ˈbeɪbɪ ˌbu:m | ˈbeɪbɪ ˌbuːm | ✅ |
| 8 | caloric | uk_pron | kə'lɒrɪk; 'kælərɪk | kəˈlɒrɪk; ˈkælərɪk | ✅ |
| 9 | centimeter | uk_pron | ˈsentəˌmi:tə | ˈsentəˌmiːtə | ✅ |
| 10 | cliche | uk_pron | ˈkli:ʃeɪ | ˈkliːʃeɪ | ✅ |
| 11 | communique | uk_pron | kəˈmju:nəkeɪ | kəˈmjuːnəkeɪ | ✅ |
| 12 | corruptive | us_pron | kə'rʌptɪv | kəˈrʌptɪv | ✅ |
| 13 | counselor | us_pron | 'kaʊnslɚ | ˈkaʊnslɚ | ✅ |
| 14 | counterdrug | uk_pron | 'kauntədrʌɡ | ˈkauntədrʌɡ | ✅ |
| 15 | counterintuitive | uk_pron | ˌkaʊntərɪnˈtu:ɪtɪv | ˌkaʊntərɪnˈtuːɪtɪv | ✅ |
| 16 | dialog | us_pron | 'daɪə,lɑɡ | ˈdaɪə,lɑɡ | ✅ |
| 17 | diarrhea | uk_pron | ˌdaɪəˈri:ə | ˌdaɪəˈriːə | ✅ |
| 18 | disenchant | uk_pron | dɪsɪnˈtʃɑ:nt | dɪsɪnˈtʃɑːnt | ✅ |
| 19 | distressful | uk_pron | dɪ'stresfʊl | dɪˈstresfʊl | ✅ |
| 20 | doomed | uk_pron | du:md | duːmd | ✅ |

**20/20 全部正确**，替换精确命中误录字符，无误伤。

## 4. 结论

独立校验 **全部通过**。【重构39】的清洗执行结果完整、正确、无副作用。

| 维度 | 状态 |
|---|---|
| 词条完整性 | ✅ 32,154 不变 |
| 误录清零 | ✅ 0 冒号 + 0 撇号 |
| 增量守恒 | ✅ ː +68、ˈ +61 |
| 无副作用 | ✅ 其余字符不受影响 |
| 目检抽样 | ✅ 20/20 正确 |

---

*验证者：PhoneticsEngineer (Monster world)*
*验证时间：2026-08-24*
