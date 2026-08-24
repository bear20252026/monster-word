# 【重构22】词书友好名映射方案设计

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 前置：【重构12】内容体检发现 books 表 191 本词书 `name` 全部等于内部编码 `code`（如 `HZBCET6N`），用户在选书页直面乱码名。
> 约束遵守：数据库只读访问；未改任何代码；本文档为本任务唯一新增文件。

---

## 一、侦察结论先行

**内部编码不是随机串，而是一套完整可解码的拼音首字母缩写体系**，覆盖率约 90%。剩余约 10% 存在歧义缩写，需人工确认少量词素。同时发现一条**权威现成映射源**（原服务端 API，接口已在项目中移植），可作为首选回填通道。

---

## 二、编码规律侦察（抽样 30+ 本 → 全量验证）

### 2.1 编码语法模型

```
[来源品牌] + [考试/学段] + [内容类型] + [年份/词数]
   HZB    +    KY      +    HBS    +    2027      →  考研红宝书 2027
   RJB    +   GZ/XZB   +     X     +     -       →  人教版高中选择性必修一
   XDF    +   IELTS    +     -     +     -       →  新东方雅思词汇
```

### 2.2 词素词典（按 191 本全量归纳）

**① 来源/品牌前缀**

| 缩写 | 含义 | 例证 |
|---|---|---|
| HZB | 红宝书 | HZBCET4 / HZBGK / HZBZK / HZB2027 |
| LLY | 恋练有词 | LLYC2027 / LLYCKY2026 |
| XDF | 新东方 | XDFIELTS / XDFTOEFL |
| RYD | 如鱼得水 | RYDSPRO4 / RYDSPRO8 |
| XH / XHPRO | 星火英语 | XHCET4QJ / XHPRO4ZJH / XHGK2024 |
| HY | 华研外语 | HYCET4GP / HY6JGPKP / PRO4HY8000 / PRO8HY1W3 |
| BARRON | 巴朗 | BARRONSAT |
| COCA / LONGMAN / OXFORD / AWL | 语料库/词典品牌 | COCA1-3 / LONGMAN3K / OXFORD3K / AWL |
| ZT | 真题（修饰前缀） | ZTHXCZ / ZTTZCZ |

**② 考试/学段**

| 缩写 | 含义 | 数量 |
|---|---|---|
| CET4 / CET6 | 四级 / 六级 | 10 本 |
| KY | 考研 | 7 本 |
| GAOKAO / GK / TJGK / SHGK | 高考（全国/天津/上海） | 10 本 |
| ZK / SHZKKG | 中考（/上海考纲） | 6 本 |
| TOEFL / TF | 托福 | 8 本 |
| IELTS / YS / YASJ | 雅思（YS=雅思缩写，YASJ=雅思圣经） | 6 本 |
| GRE / GMAT / SAT / PTE / TOEIC / MBA / KAOBO | 出国与研究生 | 12 本 |
| PETS1-5 / BECPRE-VAN-HIGHER / KET / PET / FCE | 等级与剑桥系 | 11 本 |
| PRO4 / PRO8 | 专业四级 / 专业八级（TEM） | 10 本 |

**③ 教材版本（K12 同步类）**

| 缩写 | 含义 | 例证 |
|---|---|---|
| RJB | 人教版 | RJB7NJS/NJX（年级上/下）、RJBJNJS、RJBGZ1-3（高中册）、RJBGZXB（高中必修）、RJBGZXZBX1（高中**选择性必修**1） |
| HWJ | 外研版 | HWJGZBX1-3 / HWJGZXB1-4 |
| HJB | 沪教版 | HJBGZBX1-3 / HJBGZXB1-4 |
| NJSH | 牛津上海版 | NJSHBGZ1-6 |
| NJYLB | 牛津译林版 | NJYLBGZBX |
| XSYD | 新视野大学英语 | XSYDX1-4 / XSYDXYY1-4 |
| XGNYY | 新编大学英语（待确认） | XGNYY1-4 |
| SY4K | 上海教材分册（待确认） | SY4K1-6（每册恰 600 词） |

**④ 内容类型后缀**

| 缩写 | 含义 | 说明 |
|---|---|---|
| DGCH | 大纲词汇 | CET4DGCH / CET6DGCH |
| HXCH / HXCZ | 核心词汇 / 核心常考 | 全系列通用 |
| TZCZ / ZTHXCZ / ZTTZCZ | 拓展常考 / 真题核心 / 真题拓展 | 「ZT=真题」由同书双册结构佐证 |
| GP | 高频 | GKHXGP688 |
| CH / CHSG / SG | 冲刺 / 冲刺高分 / 闪过 | GRECH / CET6CHSG / GKSG2026 |
| QJ / JX / JC / LX / ZJH | 全景 / 精选 / 基础 / 练习(乱序?) / 真题汇 | XHCET4QJ / GREHXKFJX / TPYWJC |
| N / L | 新版 / 乱序（待确认） | HZBCET6N / KYHBS2027L |

**⑤ 数字段**

| 模式 | 含义 | 例证 |
|---|---|---|
| 2024-2027 | 年份版本 | GKSG2026 / KYSG2027 |
| 1600 / 688 / 3K / 5000 / 8000 / 10000 / 1W3 | 卖点词数 | ZK1600 / GKHXGP688 / PRO8HY1W3（华研1万3） |
| 1-6 | 册次/级别 | COCA1-3 / PETS1-5 / SY4K1-6 / NJSHBGZ1-6 |

### 2.3 实证校验（用词汇内容反向验证解码）

| code | 抽样词（中段） | 验证结论 |
|---|---|---|
| RJB7NJX | as, by, ago, bus, car | 初一下水平 ✅ = 人教版七年级下 |
| HZBCET4 | movie, music, nerve, niece | 四级水平 ✅ = 红宝书四级 |
| KYHXCH | compromise, conscience, constitute | 考研核心 ✅ |
| SAT | umber, unify, urban | 高难词 ✅ |
| ZK1600 | AI, ID, PE, TV, ad | 中考基础 ✅ |

### 2.4 已知歧义点（人工校对清单，共 ~15 个词素）

- `GZBX` vs `GZXB`：沪教/外研两套并存，疑为「必修」两个批次排版，需对照封面；
- `WKD`（文都?）/ `TPYW` / `LJ`(LJCHLX) / `MTYK` / `DBCZ` / `CHDLJ` / `SJCHLX` / `ZSLX` / `WL807` / `XYJC` / `GZCGLXL` / `CZCHXKB`：品牌或组合含义待定；
- `XSYDXYY` 的 `YY`（英语 or 视听说）；`HZBCET6N` 的 `N`；`RJ2027`（疑为考研日语 203）；
- `NJYLBGZBX`（牛津译林版高中必修?）。

---

## 三、现成映射源排查结果

| 排查项 | 结果 | 结论 |
|---|---|---|
| assets 内 json/xml | 无任何非 db 资产文件 | ❌ 无本地映射 |
| 项目 docs/ 反编译引用 | reference_index.md 记录原应用为「不背单词」(beingfine.cn)，v3.2 反编译源翻译而来 | 提供线索方向 |
| D:\tools 逆向报告 | monster_word_database_analysis.md 等文件均无 book_code→名称数据；ui_compare_word_list.md 仅证实原版列表项含「书名 + 描述行」结构（示例格式「考研核心高频 \| 2026」） | ❌ 无现成表，但证实 UI 需要 name + desc 两行 |
| ui_review 原版截图 | 文件名为哈希，未逐张 OCR；词书列表页截图可能含真名 | ⚠️ 可作人工校对参考 |
| **原服务端 API** | ✅ `GET https://sapi.beingfine.cn/v3/2/bb/wordbooks` —— **获取词书分组列表接口已移植**（lib/services/api_services.dart:226 `getLexisGroupBooks`，需登录 token）。原版 App 选书页的分组与书名正来自此接口；Flutter 版目前透传响应未落库，这正是 name=code 乱码的根因链 | **最权威映射源** |

合规提示：调用原服务端仅应读取公开词库元数据、限频、不绕过鉴权、不批量爬取；若服务端不可用或不允许，直接走第四章离线推断方案即可闭环。

---

## 四、推荐方案：三层兜底显示链

```
显示优先级：API 回填名 → 规则引擎推断名 → 净化 code 兜底
```

### 4.1 层级一：API 回填（权威，可选启用）

登录成功后后台静默调用 `getLexisGroupBooks()`，将响应中的 bookCode → {name, description} 合并进覆盖层缓存并持久化；失败静默降级到层级二。一次性脚本亦可先跑一遍生成静态 JSON 提交仓库。

### 4.2 层级二：规则引擎 BookNameDecoder（离线可用，方案主体）

```dart
class BookNameDecoder {
  // 输入：code, wordCount
  // 输出：BookDisplay{ name, desc, examType, confidence }
  //
  // 流程：
  // 1) Tokenize：用 2.2 词素词典做最长匹配切分（词典以 Dart 常量表内置，
  //    同时支持 JSON 外置热更新）
  // 2) Classify：
  //    - 命中教材词素(RJB/HWJ/HJB...) → textbook 模板：
  //        "{版本}{年级}{册}词汇"   RJB7NJX → 人教版 七年级下册词汇
  //        RJBGZXZBX1 → 人教版高中 选择性必修一
  //    - 命中考试词素 → exam 模板：
  //        "{品牌}{考试}{类型}（{年份}）"  HZBKYS2027 → 红宝书 考研 闪过 2027
  //        GKHXGP688 → 高考核心高频688词
  //    - 命中语料/词典词素 → corpus 模板：
  //        COCA1 → COCA 语料库高频 第1级
  // 3) Score：全部 token 命中词典=high；存在未知段=medium（未知段保留原文）；
  //    切分失败=low（走层级三）
  // 4) desc 自动拼装："examType · 类型 · {word_count}词"
}
```

**前 20 本人工推断示例表**（code 均来自真实库内数据）：

| # | code | 词数 | 推断友好名 | 描述行 | 置信度 |
|---|---|---|---|---|---|
| 1 | CET4DGCH | 4,755 | 四级大纲核心词汇 | CET4 · 大纲 · 核心 | 高 |
| 2 | CET4HXCH | 2,173 | 四级核心词汇 | CET4 · 核心 | 高 |
| 3 | CET4ZTHXCZ | 768 | 四级真题核心词汇 | 真题 · 核心常考 | 高 |
| 4 | HZBCET4 | 6,135 | 红宝书·四级词汇 | 红宝书 | 高 |
| 5 | XHCET4QJ | 2,352 | 星火四级全景词汇 | 星火英语 | 中高 |
| 6 | CET6CHSG | 5,298 | 六级冲刺高分词汇 | 六级 · 冲刺 | 中高 |
| 7 | HZBCET6N | 7,799 | 红宝书·六级词汇（新版） | 红宝书 | 中（N 待确认） |
| 8 | KYHBS2027 | 6,590 | 考研红宝书 2027 | 考研 · 2027 版 | 高 |
| 9 | KYHXCH | 1,883 | 考研核心词汇 | 考研 · 核心 | 高（已实证） |
| 10 | LLYCKY2026 | 7,806 | 恋练有词：考研 2026 | 恋练有词 | 高 |
| 11 | GKHXGP688 | 675 | 高考核心高频 688 词 | 高考 · 高频 | 高 |
| 12 | ZK1600 | 2,444 | 中考 1600 词 | 中考 | 高 |
| 13 | RJB7NJX | 494 | 人教版七年级下册词汇 | 教材同步 · 人教版 | 高（已实证） |
| 14 | RJBGZXZBX1 | 344 | 人教版高中选择性必修一 | 教材同步 | 高 |
| 15 | HWJGZBX1 | 298 | 外研版高中必修一 | 教材同步 · 外研版 | 中高（BX/XB 待确认） |
| 16 | XSYDXYY1 | 922 | 新视野大学英语 1（视听说） | 大学英语 | 中（YY 待确认） |
| 17 | IELTSHXCZ | 755 | 雅思核心常考词汇 | 雅思 · 核心 | 高 |
| 18 | XDFIELTS | 3,835 | 新东方雅思词汇 | 新东方 | 高 |
| 19 | TOEFLHXCZ | 650 | 托福核心常考词汇 | 托福 · 核心 | 高 |
| 20 | SAT | 10,001 | SAT 核心词汇 | SAT · 万词版 | 高 |

### 4.3 层级三：净化 code 兜底

低置信时展示净化后的编码：去 `MonsterWord_` 前缀、在字母↔数字边界插空格并首词大写（如 `HZBCET6N` → `HZB CET6 N`），保证「不像乱码」的底线体验。

---

## 五、落地设计

### 5.1 映射数据放哪：**assets JSON 覆盖层（推荐）**，不改 db

| 方案 | 评估 |
|---|---|
| ✅ `assets/config/book_display.json` 覆盖层 | 与只读资产解耦：wordbook.db.gz 保持不变（避免重打包 32MB 资产与解压迁移问题）；JSON 仅数 KB；支持后续远程热更覆盖 |
| ❌ db 加 `name_friendly` 新表 | 需修改 gzip 资产 + 解压迁移逻辑 + 版本升级兼容，成本高收益低 |

JSON 结构草案：

```json
{
  "version": 1,
  "updated": "2026-08-24",
  "books": {
    "HZBCET4": { "name": "红宝书·四级词汇", "desc": "红宝书 · 6135词", "tags": ["CET4"], "conf": "high" },
    "RJB7NJX": { "name": "人教版七年级下册词汇", "desc": "教材同步 · 494词", "tags": ["教材","初一"] }
  }
}
```

### 5.2 加载时机

1. 启动：现有 `WordbookDatabase.ensureReady()` 不动；
2. 新增 `BookNameRepository.load()`：读取 assets JSON → `Map<String, BookDisplay>` 内存单例；
3. 渲染：`books_page` / `lib_select_page` 取 `display?.name ?? fallback(code)`；顺带修复 `book_words_page.dart` 中依赖 `bookName.contains('六级')` 的分类判断（友好名落地后自动受益）；
4. 可选：登录成功后静默调 API merge，结果持久化 SharedPreferences，下次离线可用。

### 5.3 UI 兜底策略

- 名称缺失/低置信 → 层级三净化 code；
- 描述行缺失 → 显示「{word_count} 词」；
- 封面前 4 字改取 friendly name（沿用 `_coverText()` 逻辑换数据源）。

---

## 六、工作量评估与人机分工

| 工作项 | 耗时估算 | 执行者 |
|---|---|---|
| BookNameDecoder 规则引擎（词素表+模板+打分） | 0.5~1 天 | AI/开发 |
| 全量 191 本自动推断跑批 | 分钟级 | 脚本 |
| 高置信结果抽查（预计 120~140 本，62%~73%） | ~0.5 小时 | 人工 |
| 中低置信逐本定名（预计 50~70 本，含 §2.4 歧义词素） | 1~1.5 小时 | 人工（可对照 ui_review 截图） |
| （可选）API 回填脚本 + 校验 | 0.5 天 | 开发 |
| 固化 book_display.json 入仓库 + 接入渲染 | 0.5 天 | 开发 |

**建议路径**：AI 规则引擎出 v1 全量草稿 → 人工 2 小时校对修正 → 固化为 assets/config/book_display.json 提交仓库（一次到位，运行时零推理开销）。若能取得原服务端访问权，API 回填可将人工压缩至 30 分钟以内。

---

## 附：本次侦察过程记录

- 数据库经 gzip 解压至系统临时目录，全程以 `sqlite3 file:...?mode=ro` 只读访问，检查后临时副本已删除；
- 未改动任何源码/资产；项目内仅新增本文档。
