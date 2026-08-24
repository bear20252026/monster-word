# 音标数据清洗执行日志

> 任务：【重构39】。执行【重构29】设计的音标清洗方案A。
> 执行时间：2026-08-24

---

## 1. 操作概要

| 项目 | 值 |
|---|---|
| 操作类型 | 构建期一次性清洗（方案A） |
| 目标文件 | `assets/db/wordbook.db.gz` |
| 替换规则 | `uk_pron`/`us_pron` 字段内 `:`(U+003A) → `ː`(U+02D0)、`'`(U+0027) → `ˈ`(U+02C8) |
| 备份位置 | `%TEMP%/phonetic_cleanup_backup/wordbook.db.gz.orig` |

## 2. 哈希记录

| 阶段 | SHA-256 | 文件大小 |
|---|---|---|
| 原始 gz | `6c70ecaeb1ddfa1df242012d5538805de0167a04fe1643773fd3a451afcd9ad8` | 32,688,627 B |
| 清洗后 gz | `ea78a4d46d3f7d5f70ec05724268f04e3e43b4d3ac8107731a4fb4b75f6b0b5c` | 31,561,742 B |

> 大小差异 -1,126,885 B 来自 VACUUM 回收空闲页，非数据丢失。

## 3. 五项校验结果

### ✅ 校验 1：词条总数不变

| | 数值 |
|---|---|
| 基线（清洗前） | 32,154 |
| 清洗后 | 32,154 |
| 结果 | **通过** — 完全一致 |

### ✅ 校验 2：误录字符清零

| 字段 | 字符 | 清洗前 | 清洗后 |
|---|---|---:|---:|
| uk_pron | `:` (冒号) | 67 | 0 |
| us_pron | `:` (冒号) | 1 | 0 |
| uk_pron | `'` (撇号) | 30 | 0 |
| us_pron | `'` (撇号) | 31 | 0 |
| **合计** | | **129** | **0** |

结果：**通过**

### ✅ 校验 3：增量守恒

| 字符 | 字段 | 清洗前 | 清洗后 | 增量 | 预期增量 |
|---|---|---:|---:|---:|---:|
| `ː` (U+02D0) | uk_pron | 2,962 | 3,029 | +67 | +67 |
| `ː` (U+02D0) | us_pron | 3,905 | 3,906 | +1 | +1 |
| `ː` 小计 | | 6,867 | 6,935 | **+68** | **+68** |
| `ˈ` (U+02C8) | uk_pron | 8,631 | 8,661 | +30 | +30 |
| `ˈ` (U+02C8) | us_pron | 8,632 | 8,663 | +31 | +31 |
| `ˈ` 小计 | | 17,263 | 17,324 | **+61** | **+61** |

结果：**通过** — 增量精确守恒（+68 ː、+61 ˈ）

### ✅ 校验 4：其余字符频次不变

抽查 10 个高频 IPA 字符（uk_pron 字段），清洗前后频次完全一致：

| 字符 | 清洗后频次 |
|---|---:|
| ə | 6,827 |
| ɪ | 7,706 |
| æ | 1,603 |
| ŋ | 463 |
| ʃ | 1,275 |
| θ | 255 |
| ð | 90 |
| ʒ | 667 |
| ɒ | 1,081 |
| ʌ | 914 |

结果：**通过** — REPLACE 严格限定于 `:` 和 `'` 两个字符，未波及其他字符

### ✅ 校验 5：30 条 diff 抽样目检

抽样 30 条含误录的记录，逐条核验 before/after：

| # | 单词 | 字段 | before | after | 正确？ |
|--:|---|---|---|---|---|
| 1 | abuzz | us_pron | ə'bʌz | əˈbʌz | ✅ |
| 2 | anemia | uk_pron | əˈni:mɪə | əˈniːmɪə | ✅ |
| 3 | baby boom | uk_pron | ˈbeɪbɪ ˌbu:m | ˈbeɪbɪ ˌbuːm | ✅ |
| 4 | caloric | uk_pron | kə'lɒrɪk; 'kælərɪk | kəˈlɒrɪk; ˈkælərɪk | ✅ |
| 5 | corruptive | us_pron | kə'rʌptɪv | kəˈrʌptɪv | ✅ |
| 6 | counselor | us_pron | 'kaʊnslɚ | ˈkaʊnslɚ | ✅ |
| 7 | counterdrug | uk_pron | 'kauntədrʌɡ | ˈkauntədrʌɡ | ✅ |
| 8 | diarrhea | uk_pron | ˌdaɪəˈri:ə | ˌdaɪəˈriːə | ✅ |
| 9 | distressful | uk_pron | dɪ'stresfʊl | dɪˈstresfʊl | ✅ |
| 10 | doomed | uk_pron | du:md | duːmd | ✅ |
| 11 | fluctuant | uk_pron | 'flʌktjʊənt | ˈflʌktjʊənt | ✅ |
| 12 | forebode | uk_pron | fɔ:ˈbəʊd | fɔːˈbəʊd | ✅ |
| 13 | harbor | uk_pron | ˈhɑ:bə | ˈhɑːbə | ✅ |
| 14 | in principle | uk_pron | ɪn 'prɪnsəpəl | ɪn ˈprɪnsəpəl | ✅ |
| 15 | installment | uk_pron | ɪnˈstɔ:lmənt | ɪnˈstɔːlmənt | ✅ |
| 16 | moonlighting | uk_pron | ˈmu:nˌlaɪtɪŋ | ˈmuːnˌlaɪtɪŋ | ✅ |
| 17 | nonverbal | uk_pron | nɒnˈvɜ:bəl | nɒnˈvɜːbəl | ✅ |
| 18 | northeast | uk_pron | ˌnɔ:θˈi:st | ˌnɔːθˈiːst | ✅ |
| 19 | over and over | uk_pron | 'oʊvər ənd 'oʊvər | ˈoʊvər ənd ˈoʊvər | ✅ |
| 20 | prefrontal | us_pron | pri'frʌntl | priˈfrʌntl | ✅ |
| 21 | pseudo | uk_pron | ˈsu:dəʊ | ˈsuːdəʊ | ✅ |
| 22 | sequent | uk_pron | 'siːkw(ə)nt | ˈsiːkw(ə)nt | ✅ |
| 23 | standardized | uk_pron | 'stændədaizd | ˈstændədaizd | ✅ |
| 24 | underestimation | uk_pron | 'ʌndər,esti'meiʃən | ˈʌndər,estiˈmeiʃən | ✅ |
| 25 | vantage | uk_pron | ˈvɑ:ntɪdʒ | ˈvɑːntɪdʒ | ✅ |
| 26 | willfully | uk_pron | 'wilfəli | ˈwilfəli | ✅ |
| 27 | yourselves | uk_pron | jɔː'selvz | jɔːˈselvz | ✅ |
| 28 | dialog | us_pron | 'daɪə,lɑɡ | ˈdaɪə,lɑɡ | ✅ |
| 29 | flypast | uk_pron | 'flaɪpɑːst | ˈflaɪpɑːst | ✅ |
| 30 | cliche | uk_pron | ˈkli:ʃeɪ | ˈkliːʃeɪ | ✅ |

结果：**通过** — 30/30 全部正确，无误伤

## 4. 结论

五项校验全部通过。`assets/db/wordbook.db.gz` 已替换为清洗后版本。

- 误录字符：129 → 0
- 词条总数：32,154（不变）
- 增量守恒：ː +68、ˈ +61（精确匹配）
- 无副作用：其余字符频次不变

## 5. 回滚方式

```bash
# 从备份恢复
cp "$TEMP/phonetic_cleanup_backup/wordbook.db.gz.orig" assets/db/wordbook.db.gz
git checkout assets/db/wordbook.db.gz
```

原始备份 SHA-256：`6c70ecaeb1ddfa1df242012d5538805de0167a04fe1643773fd3a451afcd9ad8`

---

*执行者：PhoneticsEngineer (Monster world)*
*执行时间：2026-08-24*
