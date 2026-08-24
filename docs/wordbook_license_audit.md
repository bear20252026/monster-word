# wordbook.db 来源与合规审计

> 任务：【重构57】。前置：【重构33】dictionary_license_review.md 已评估五部原版词典风险，本文专项评估 wordbook.db。
> 日期：2026-08-24
> 方法：数据库只读访问（解压至 %TEMP%，sqlite3 `file:...?mode=ro`），未写入任何文件；未下载任何外部数据集。

---

## 结论速览

**wordbook.db 的数据全部来自「不背单词」服务端数据库导出**，证据链完整且不可辩驳。14,560 条音频 URL 直指 `audio.beingfine.cn`（不背单词 CDN），6,580 条短语数据含服务端内部 ID（`fid`/`pid`/`oid`）。该数据库与原版五部词典（simple.db 等）属**同一风险家族**，唯一区别是 wordbook.db 已成既成事实（已进入仓库并被 app 使用），而五部词典尚未进入。

**风险等级：🔴高（公开分发）～ 🟡中低（仅本地开发）**

---

## 一、数据结构与内容特征

### 1.1 Schema 概要

```
books      (191 行)  — id, code(UNIQUE), name, word_count
words      (32,154 行) — id, word, main_word, interpret, uk_pron, us_pron,
                         phrase, example, confuse, audio_urls, image_urls, word_root
word_books (454,196 行) — word_id × book_id 多对多关联
```

### 1.2 字段格式特征（指向服务端数据源）

| 字段 | 格式特征 | 来源指向 |
|---|---|---|
| `phrase` | JSON 数组，含 `fid`/`pid`/`oid` 内部 ID + `pseqs` 考试分类映射（CET4/CET6/TOEFL/IELTS/PRO8…） | **不背单词 CMS 后台**的短语表主键 |
| `example` | JSON 对象，含 `oid`（词义 ID）、英文释义 `e`、中文释义 `c` | **不背单词 CMS 后台**的例句表主键 |
| `audio_urls` | JSON 数组，URL 全部指向 `http://audio.beingfine.cn/sentence/audio/…` | **不背单词 CDN 服务器** |
| `confuse` | JSON 数组，近义词/形近词列表 | 不背单词"易混淆词"功能的数据 |
| `word_root` | JSON 对象，含 `prefix`/`roots`/`suffix` 结构化词根词缀 | 不背单词"词根词缀"功能的数据 |
| `interpret` | 纯文本释义，`vt.`/`vi.`/`n.`/`adj.` 词性前缀，多义项换行分隔 | 释义文本（疑似金山词霸等商业授权语料） |

### 1.3 关键量化数据

| 指标 | 数值 | 说明 |
|---|---|---|
| 音频 URL 指向 beingfine.cn | **14,560 词**（45.3%） | 直接引用不背单词 CDN 资源 |
| 含内部 ID 的短语记录 | **6,580 词** | `fid`/`pid`/`oid` 为服务端数据库主键 |
| 词书考试分类标签 | CET4/CET6/考研/高考/托福/雅思/专八/商务英语 等 | 与不背单词产品线完全吻合 |
| 有释义的词 | 12,148（37.8%） | 双峰分布：整组有或整组无，指向批量导入 |

---

## 二、来源证据链

### 2.1 直接证据

| # | 证据 | 来源 | 证明力 |
|---|---|---|---|
| E1 | 14,560 条 audio_urls 全部指向 `audio.beingfine.cn` | 本审计直接查询 | **决定性** — beingfine.cn 是「不背单词」（北京艾宾浩斯智能科技有限公司）的官方域名 |
| E2 | phrase 字段含 `fid`/`pid`/`oid` 内部主键 + `pseqs` 考试分类映射 | 本审计直接查询 | **强** — 这些是服务端数据库的外键关系，不可能由爬虫或第三方工具生成 |
| E3 | example 字段含 `oid` 词义 ID + 英文定义 + 中文释义的结构化 JSON | 本审计直接查询 | **强** — 格式与不背单词 API 返回格式一致 |
| E4 | 旧报告记录："不背单词 v3.2 共 11 个 SQLite 库，从 `R.raw.*` 复制、SQLCipher 加密、统一硬编码密钥 `"arsenal iscool"`" | D:\tools\monster_word_database_analysis.md §1.1 | **强** — 确认原版 app 使用加密 SQLite 体系 |
| E5 | 旧报告记录："词书库本身也是原版'服务端下载的加密 .db'体系的数据（database_analysis §2.x ATTACH 机制、密钥同源）。它与 simple.db 属同一风险家族" | docs/dictionary_license_review.md §1.4 | **强** — 已有定性结论 |

### 2.2 间接证据

| # | 证据 | 说明 |
|---|---|---|
| I1 | 词书命名编码（HZBCET6N、RJB7NJX、PRO8 等）与不背单词内部编码体系完全一致 | 非公开命名规则 |
| I2 | 191 本词书的考试分类（CET4/6、考研、高考、托福、雅思、专八、BEC…）与不背单词产品功能线吻合 | 内容策划产物 |
| I3 | 释义风格统一（`vt. 抛弃；中止，放弃`），格式化模式一致 | 单一数据源批量导入 |
| I4 | 音标误录规律（【重构29】发现 129 处 `:`→`ː`、`'→ˈ` 指向同一导出器降级问题） | 导出工具的字符映射缺陷 |

### 2.3 结论：来源判定

**wordbook.db 是「不背单词」服务端数据库的直接导出**，经过了：
- 解密（原版 SQLCipher 加密 → 明文 SQLite）
- 筛选（原版可能有更多词书/字段，导出时做了裁剪）
- 音标降级（部分 Unicode IPA 符号被降级为 ASCII 相似字符）

**但未做任何权利清洗**：音频 URL 仍指向原版 CDN，内部数据库 ID 完整保留，释义文本原样搬运。

---

## 三、风险分级

### 3.1 各类数据的风险评估

| 数据类型 | 权属方 | 使用场景 | 风险等级 | 说明 |
|---|---|---|---|---|
| 释义文本（interpret） | 疑似金山词霸/柯林斯等商业授权 | 公开分发 | 🔴 高 | 释义文本是汇编作品的著作权客体；"不背单词"本身也是从上游授权获得，不具有再分发权 |
| 音频 URL（audio_urls） | 不背单词 CDN | 引用/播放 | 🔴 高 | 未经授权调用第三方服务器资源（不仅是数据权属问题，还有服务滥用问题）；若 URL 失效则用户体验断裂 |
| 短语数据（phrase） | 不背单词 CMS | 公开分发 | 🔴 高 | 含服务端内部 ID，属商业数据的直接搬运 |
| 例句数据（example） | 不背单词 CMS | 公开分发 | 🔴 高 | 含英文定义（可能来自牛津/朗文等授权词典），中英对照例句为增值内容 |
| 近义词（confuse） | 不背单词 | 公开分发 | 🟡 中 | 词表本身可能基于公开资源（如 WordNet 同义词），但精选组合和形近词推荐是策划产物 |
| 词根词缀（word_root） | 不背单词 | 公开分发 | 🟡 中 | 词根释义（"duct = to lead 引导"）来源广泛，但结构化 JSON 编排方式是不背单词自有的 |
| 词书映射（books + word_books） | 不背单词 | 公开分发 | 🟡 中 | 词书分组和选词策略是内容策划产物 |
| 单词拼写（words.word） | 公有领域 | 不受限 | 🟢 低 | 英语单词拼写本身不受版权保护 |

### 3.2 综合风险等级

| 使用场景 | 风险 | 说明 |
|---|---|---|
| 仅本地开发/学习用途 | 🟡 中低 | 个人使用范畴，无对外传播 |
| 源码公开（GitHub 等） | 🔴 高 | 数据库以 .gz 形式随源码分发，传播行为本身即侵权 |
| 应用商店公开发布 | 🔴 高 | 内置侵权数据的 App 上架，权利人可投诉下架 |
| 移除音频 URL 后分发 | 🔴 高 | 释义/短语/例句文本的著作权不因移除 URL 而消失 |

**关键区别 vs 五部原版词典**：五部原版词典（simple.db 等）**一个字节都未进入仓库**，而 wordbook.db **已经以 `assets/db/wordbook.db.gz` 的形式被 pubspec.yaml 声明、被 app 加载、被 git 跟踪**——侵权分发事实已经存在。

---

## 四、与 ECDICT 替换方案的关系

### 4.1 wordbook.db 的不可替代性

wordbook.db 在当前架构中承担**双重角色**：

| 角色 | 字段 | 能否由 ECDICT 替代 |
|---|---|---|
| **词书数据源**（191 本词书的选词 + 分组） | word, word_books, books | ❌ 不可 — ECDICT 无"词书"概念，只有词条 |
| **基础词典**（释义/音标/短语/例句/词根/近义） | interpret, uk/us_pron, phrase, example, confuse, word_root | ✅ 可 — ECDICT 覆盖量更大（340 万 vs 3.2 万） |

### 4.2 替换策略建议

**不能简单用 ECDICT 替换 wordbook.db**，因为词书分组是核心学习功能的基础。建议分两步：

**第一步（紧急）：数据权利清洗**
- 移除所有 `audio_urls`（指向 beingfine.cn 的 URL）
- 移除 `phrase` 和 `example` 中的 `fid`/`pid`/`oid` 内部 ID
- 评估 `interpret` 释义文本的替换可行性

**第二步（中长期）：构建合规数据管线**
- 用 ECDICT 替换 `interpret`/`uk_pron`/`us_pron` 字段
- 用 ECDICT 的 `exchange` 字段替换 `confuse`（近义词）
- 用开源词根资源（如 WordNet 词源数据）替换 `word_root`
- 保留 `books` + `word_books` 的分组结构（选词策划是自有内容）
- 音频改用 TTS（Flutter TTS 包）或授权音频源

---

## 五、数据迁移方案概要

### 5.1 方案 A：最小清洗（快速止血）

```
目标：消除最明显的侵权标记，保留大部分数据
工作量：1-2 天

步骤：
1. 清除 audio_urls 全部内容（置空或替换为 TTS 路径标记）
2. 清除 phrase/example 中的 fid/pid/oid（仅保留 en/cn 文本）
3. 清除 confuse 中与 ECDICT 不重叠的形近词推荐
4. 保留 interpret（释义文本）和 word_root（词根）
5. 在 NOTICES 中声明数据来源和清理措施

风险：释义文本的著作权问题未解决，仍为 🔴高
适用：紧急止血，为后续替换争取时间
```

### 5.2 方案 B：ECDICT 全量替换（推荐，配合【重构33】方案 C）

```
目标：用 ECDICT 替换所有受著作权保护的字段
工作量：3-5 天（含数据管线 + 验证）

步骤：
1. 构建 ECDICT 子集（20 万条，覆盖 wordbook.db 32,154 词）
2. 字段映射：
   - ECDICT.translation → words.interpret（中文释义）
   - ECDICT.phonetic → words.uk_pron / words.us_pron（音标）
   - ECDICT.definition → words.example（英文定义）
   - ECDICT.exchange → words.confuse（词形变化 → 推导近义词）
3. 保留不变的字段：
   - words.word（拼写本身无版权）
   - books + word_books（词书分组为自有策划内容）
4. 移除的字段：
   - audio_urls → 改用 TTS
   - phrase → 用 ECDICT 的短语数据（若有）或留空
   - word_root → 用开源词根资源或留空
5. 验收：释义覆盖率 ≥ 原始 37.8%，音标覆盖率 ≥ 原始 33%

风险：释义质量可能与原版有差异（ECDICT 释义风格不同）
适用：正式发布前的合规底线
```

### 5.3 方案 C：混合方案（平衡质量与合规）

```
目标：保留自有策划内容，替换第三方数据
工作量：2-3 天

步骤：
1. 保留：books + word_books + words.word（分组和拼写）
2. 替换：interpret / uk_pron / us_pron → ECDICT
3. 移除：audio_urls / phrase(example中的oid) / confuse / word_root
4. 新增：TTS 音频 + ECDICT 词形变化数据
5. 验收：覆盖率验收同方案 B

风险：短语/词根功能退化（可后续用 ECDICT 或开源数据补充）
适用：中期过渡方案
```

---

## 六、配套行动清单

| # | 行动 | 优先级 | 负责 | 说明 |
|---|---|---|---|---|
| A1 | 移除 audio_urls 中所有 beingfine.cn URL | 🔴 紧急 | 实施批 | 当前 app 已在代码中引用这些 URL（audio_players.dart） |
| A2 | 清除 phrase/example 中的内部 ID（fid/pid/oid） | 🔴 紧急 | 实施批 | 这些 ID 是不背单词服务端主键，公开暴露构成商业数据泄露 |
| A3 | 构建 ECDICT 数据管线（【重构33】方案 C） | 🟡 重要 | 实施批 | 从根本上替换受保护的释义/音标文本 |
| A4 | 在「关于」页添加数据来源声明 | 🟡 重要 | 实施批 | 合规义务（ECDICT CC-BY-SA 署名） |
| A5 | 评估有道发音 URL 合规性 | 🟡 中期 | 另开任务 | audio_players.dart 中还有有道词典发音直链（【重构33】已登记） |
| A6 | 词书分组数据的权属确认 | 🟢 远期 | 法务 | books + word_books 的选词策划是否构成独立作品 |

---

## 七、与【重构33】的关系

| 项目 | wordbook.db（本文） | 五部原版词典（重构33） |
|---|---|---|
| 数据是否在仓库中 | ✅ 是（assets/db/wordbook.db.gz） | ❌ 否（未进入仓库） |
| 侵权分发事实 | 已存在 | 不存在（零窗口） |
| 主要风险字段 | interpret + audio_urls + phrase/example | 全部（simple.db/CollinsData.db 整库） |
| 替换难度 | 中（需保留词书分组结构） | 低（从未接入，不接入即可） |
| 建议处理 | 方案 B：ECDICT 替换受保护字段 | 不接入 + 构建 ECDICT 替代（重构33 方案 C） |

**两份报告的统一行动**：ECDICT 数据管线（重构33 方案 C 的 S1-S7）同时解决 wordbook.db 的释义替换和五部原版词典的替代需求——同一条管线，两处受益。

---

*本文档由【重构57】建立；后续若有法务意见或 ECDICT 实测数据，请直接更新对应章节。*
