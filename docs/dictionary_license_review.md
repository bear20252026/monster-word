# 词典版权合规评估：风险分级与开源替代方案

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 任务：【重构33】，源于 backlog_functional_gaps.md **GAP-18** 的版权风险标记。
> 方法：只读核查代码与既有审计文档；未下载任何数据集；开源资源信息基于公开常识性知识，**许可条款以各官方仓库最新声明为准**，表中以 ⚠️ 标出上线前必须人工复核的点。
> 结论速览：**原版词典数据（simple.db / CollinsData.db 等）确系取自反编译 APK 的加密资源，公开分发风险为🔴高～🔴🔴极高；当前代码尚未接入，处于零分发安全窗口。推荐路线 C：本地内置 ECDICT 精简版 + 在线/可选包兜底，并同步清理"柯林斯"商标文案。**

---

## 一、现状摸底

### 1.1 代码实现状态：UI 已建，词典数据层未接入

| 组件 | 文件 | 状态 |
|---|---|---|
| 查词页 | lib/pages/search_page.dart | ✅ 已实现，下拉联想 |
| 词典详情页 | lib/pages/dictionary_page.dart | ✅ 已实现，含「柯林斯」Tab |
| 学习页弹窗 | lib/widgets/word_dictionary_popup.dart | ✅ 已实现（learn_session.dart L110 调用） |
| 柯林斯详情页 | lib/pages/collins_detail_intro_page.dart | ✅ UI 完成（富格式释义+例句渲染），标题文案「柯林斯词典」 |
| 词典服务 | lib/services/dictionary_service.dart | ✅ 单例；**全部查询只落在 wordbook.db 的 words 表**（前缀/模糊搜索、释义、音标、派生 main_word、词根 word_root、近义 confuse、收藏） |
| 柯林斯数据模型 | lib/models/word_data_models.dart（CollinsDetail / CollinsWordDetail / CollinsExample） | 模型就绪，**无任何数据源** |
| 柯林斯授权协议层 | lib/models/privilege_models.dart、app_preferences_ext.dart（collins/wordroot 特权字段、过期提示、点击埋点） | 从原版协议照搬，纯占位 |

**柯林斯 Tab 实际表现**：dictionary_page.dart L330 显示「暂无柯林斯释义数据」——即 UI 引用了不存在的数据。

### 1.2 数据文件现状

- `assets/db/` 目录**只有一个文件**：`wordbook.db.gz`（31.9 MB，解压后约 121 MB），pubspec.yaml L79 唯一声明的数据库资产；
- **不存在** simple.db / wordroot.db / xyjc.db / variant.db / CollinsData.db 的任何拷贝——原版五部词典均未进入本仓库（好现象：当前无侵权数据分发事实）；
- 词书数据规模（引自 docs/content_audit.md，【重构12】）：191 本词书、32,154 词条、454,196 条词书-单词关联；interpret 释义覆盖率仅 37.8%（20,006 词无释义）——这正是"查词体验缺口"的量化背景；
- 音标现状（引自 docs/ipa_coverage_full_audit.md，【重构20】）：10,636 词（33%）带英美双音标，54 个音标字符全集已被 Inter 字体 100% 覆盖——该字符集可直接复用作替换数据的验收基线；
- 词根功能：word_root_tab.dart 直接解析 wordbook.words.`word_root` 字段内的 JSON（【重构14】自建方案），**不依赖** wordroot.db。

### 1.3 "取自 APK"的证据链（旧报告定位）

| 证据 | 出处 |
|---|---|
| v3.2 共 11 个 SQLite 库，其中 3 个为"只读内置数据库"，从 `R.raw.*` 复制、SQLCipher 加密、统一硬编码密钥 `"arsenal iscool"` | D:\tools\monster_word_database_analysis.md §1.1 |
| simple.db 结构：26 张按首字母分表的 `t_dict_simple_{a-z}`，字段 word/simple（指向标准形式）；variant.db：拼写变体；wordroot.db：词根词缀 | 同上 §2.9–2.11 |
| 移植建议原文："simple.db 集成……**直接从 APK assets 复制**""内置数据库从 **APK 提取时解密**后以明文存储" | 同上 §五·建议 |
| v5.0 raw/ 清单：**simple.db 20.1MB（简单词典）、wordroot.db 5.9MB、xyjc.db 856KB（词根课程）、variant.db 292KB**；字符串 `collins_not_found_tips`＝"「柯林斯词典」已覆盖 20 万词条" | D:\tools\monster_word_v5_resources.md §八、§四 |
| CollinsData.db＝"柯林斯词典缓存"（collinsTable，getWordCollinsDetail/updateCollinsData） | monster_word_database_analysis.md §2.3 |
| 本项目首次风险标记 | docs/backlog_functional_gaps.md GAP-18 |

### 1.4 关联发现（超范围，仅登记）

1. **wordbook.db 同源性提示**：词书库本身也是原版"服务端下载的加密 .db"体系的数据（database_analysis §2.x ATTACH 机制、密钥同源）。它与 simple.db 属同一风险家族，只是已成既成事实且体量大。**建议另立专项评估**，本文不展开。
2. **有道发音 URL**：audio_players.dart 构建有道词典发音直链——属第三方服务非授权调用，与词典数据同属合规灰区，建议随本项目一并复查。

---

## 二、风险分级

### 2.1 数据性质判定

- **simple.db / variant.db / wordroot.db / xyjc.db**：从反编译 APK 的加密 raw 资源提取。简明释义内容的行业普遍来源为金山词霸（iciba）等商业授权语料——无论最终溯源结论如何，"他人享有著作权的释义文本之汇集"这一性质不变，构成汇编作品层面的侵权客体；
- **CollinsData.db**：柯林斯（HarperCollins COBUILD）为不背单词的**付费特权内容**（见 privilege 协议层），权属清晰、商业化属性最强，是风险最高的一件。

### 2.2 分级矩阵

| 使用场景 | 风险等级 | 说明 |
|---|---|---|
| 仅本地开发调试，不分发 | 🟢 低 | 个人研究范畴，无扩散 |
| 源码仓公开且携带数据文件 | 🔴 高 | 公开传播本身即侵权，与是否收费无关 |
| 应用商店公开发布（内置词典数据，免费 App） | 🔴 高 | 侵犯词典著作权（释义文本＋编排）；应用商店侵权下架通道成熟；金山/哈珀柯林斯均有维权实践 |
| 收费/订阅中将柯林斯作为卖点 | 🔴🔴 极高 | 直击权利人核心商业授权收入，民事索赔风险最大 |
| 改头换面（改格式/改字段名/混合自有数据）后再分发 | 🔴 高 | 释义文本实质性相似即可认定，格式转换不产生新权利 |

**关键时间窗**：上述数据目前**一个字节都未进入本仓库**——现在做决策的成本是最低的；一旦有人图省事"按旧报告建议直接从 APK 复制"，风险立即从 0 变🔴。

---

## 三、开源替代方案对比

| 资源 | 方向 | 规模（约） | 许可 | 音标 | 中文释义 | 例句 | 转换成本 | 备注 |
|---|---|---|---|---|---|---|---|---|
| **ECDICT**（skywind3000） | 英→中 | 340 万词条（含词形变化约 770 万形式） | 代码 MIT；数据 **CC-BY-SA** ⚠️以 README 为准 | ✅ 英/美双 IPA | ✅ | △ 少量 | **低**（CSV/StarDict→SQLite 直映） | 自带 BNC/COCA 词频、CET/考研/托福/雅思/GRE 标签、牛津3000标记、collins 星级（见 4.3 商标提示）；**首选底座** |
| WordNet 3.1（Princeton） | 英英 | 15.5 万词 / 11.7 万 synsets | WordNet License（类 BSD，须署名，可商用） | ✗ | ✗ | △ 英文短释 | 中 | 可作语义关系层（同义/上位词），不能独立承担英汉查询 |
| Open English WordNet（Global Wordnet Assoc.） | 英英 | ≈16 万词 | CC 开放许可 ⚠️核对仓库 LICENSE | ✗ | ✗ | ✗ | 中 | WordNet 的现代化维护分支；选其一即可 |
| CC-CEDICT（MDBG） | **中→英** | ≈12 万条 | CC-BY-SA 4.0 | ✗（拼音） | —（方向相反） | ✗ | 低（TSV） | 仅适合未来"中查英"反向功能，不解决本需求主向 |
| Wiktionary 抽取（wiktextract 等） | 多向 | 数百万条，质量参差 | CC-BY-SA 4.0（文本） | 部分 | 有（参差） | 有 | **高**（需重度清洗去噪） | 作补充源候选，不作底座 |
| Chinese Open WordNet（NTU）/OMW | 英↔中同义网 | 数万 synset 对齐 | 研究许可为主 ⚠️商用需确认 | ✗ | 同义映射 | ✗ | 中 | 学术味浓，商用许可不确定，谨慎 |
| StarDict 社区"免费词典"（朗文/牛津/柯林斯转换版等） | — | — | **表面免费实为盗版转换** | — | — | — | — | **明确排除**：换壳不改变侵权本质，正是本报告要规避的东西 |

> ⚠️ 合规提示：CC-BY-SA 类许可是"弱传染"——分发需**署名＋注明修改＋以相同许可共享衍生数据库**，对本项目可行但必须在「关于/法律信息」页落实；所有许可结论在正式采用前需按官方仓库当日状态复核一遍。

---

## 四、建议路径

### 4.1 三案对比

| 方案 | 内容 | 包体积影响 | 离线体验 | 合规负担 | 主要缺陷 |
|---|---|---|---|---|---|
| A 放弃内置，仅在线查询 | 查词全部走网络 | 0 | 差（弱网不可用） | 取决于所接 API 的 ToS | 背单词场景强离线属性；第三方 API 同样有配额/条款风险 |
| B 全量 ECDICT 内置 | 340 万词条整包 | +数百 MB 起 | 优 | CC-BY-SA 全量分发义务最重 | 体积失控；99% 词条终身不被查询 |
| **C 混合（推荐）** | 本地内置 ECDICT 精简版 + 在线/可选扩展包 | +50–150 MB（可控） | 核心查询全离线 | 仅分发精简子集，义务最小化 | 需要一条一次性的数据管线（见第五章） |

### 4.2 推荐理由（方案 C）

1. **学习主闭环已经不需要大词典**：词书内 32,154 词的释义/音标/例句由 wordbook.db 承担（其自身合规问题另案处理）；查词的真实长尾需求是"生僻词、词形还原"，ECDICT 按 BNC 词频截断前 10–20 万词＋考试标签词即可覆盖 >95% 的真实查词行为，体积压在 50–150 MB；
2. **合规义务最小化**：分发的子集是我们主动构建的衍生库，署名/共享声明一份 NOTICE 即可闭环；避免整包转发带来的全量传播责任；
3. **工程增量小**：DictionaryService 已是单例门面，增加一个 DictRepository 双源路由（先查 wordbook，未命中落 ECDICT 库）即可，上层 UI 无感；柯林斯 Tab 就地改造（见下）；
4. **方案 A 的离线短板与本产品基因冲突，方案 B 的全量分发没有对应收益**——两头的劣势都避开了。

### 4.3 配套清理清单（无论选择哪案都应执行）

| 位置 | 问题 | 动作 |
|---|---|---|
| dictionary_page.dart L282/L310–330、collins_detail_intro_page.dart L267/L301 | 「柯林斯」「柯林斯词典」商标文案 | 改为中性命名（如「详注」「高级释义」），或待取得真实授权后再恢复 |
| ECDICT 的 collins 星级字段 | 星级评价本身源自柯林斯体系 | 导入管线中默认丢弃该字段，或将 UI 改为纯数字等级且不用商标词 ⚠️留法务确认 |
| privilege_models/app_preferences 的 collins/wordroot 特权协议 | 指向不存在的付费内容 | 冻结相关入口与埋点，防止空承诺 |
| audio_players.dart 有道直链 | 第三方服务滥用灰区 | 另开小任务评估（TTS 或授权音频源替代） |

---

## 五、数据转换管线草案（方案 C 落地稿）

```text
S1 获取锁定   github skywind3000/ECDICT 固定 release tag；记录 SHA256 进 THIRD_PARTY_NOTICES.md（禁止运行时热更数据源）
S2 子集筛选   保留：bnc/frq 词频前 N 万 ∪ tags∈{cet4,cet6,kyk,toefl,ielts,gre,zk,gk} ∪ 用户词书全词表(wordbook.words 32,154 词强制纳入)
              目标规模 ≤ 20 万条，压缩后 ≤ 150 MB
S3 清洗规范   word 归一（NOCASE 去重）；exchange 词形展开为独立索引行；
              音标规范化：':'→'ː'(U+02D0)、'''→'ˈ'(U+02C8)、剥离半角混入——与【重构20】IPA 审计发现的 129 处脏数据同规则；
              校验：清洗后音标字符集 ⊆ Inter 已验证的 54 字符全集（复用重构20 测试样例集）
S4 Schema 映射（新建独立库 dict.db，不动词书结构）
              dict_entries(
                id INTEGER PK,
                word TEXT UNIQUE COLLATE NOCASE,     -- 查询键
                word_stem TEXT,                       -- 还原后的标准形（承接原 simple.db 的 word/simple 语义）
                uk_ipa TEXT, us_ipa TEXT,             -- 替代原版 t_dict_* 的单音标设计
                translation TEXT,                     -- 中文释义（\n 分行，兼容 interpretLines 渲染习惯）
                definition TEXT,                      -- 英文定义
                pos TEXT, exchange TEXT,              -- 词性 / 词形变化 JSON
                tags TEXT, freq_rank INTEGER          -- 考试标签 / 词频序（供排序与精简追溯）
              )
              dict_fts(entry_id, word, translation)   -- FTS5，支撑 search_page 模糊搜索提速
S5 打包分发   dict.db → gzip → assets/db/dict.db.gz，复用 WordbookDatabase.ensureReady() 的"首启解压至临时区、只读 URI 打开"模式（零新依赖）
S6 接入改造   DictionaryService 新增 DictRepository：smartSearch/getWordDetail 未命中时回源 dict.db；getExamExamples 翻译位预留
              （GAP-01 笔记、GAP-06 下划线等 Backlog 项共用该入口）
S7 合规产物   「关于」页新增开源致谢：ECDICT 署名＋许可链接＋修改说明；NOTICES 入版本控制
验收          ①抽查 500 高频词：释义非空率、双语齐全率；②离线飞行模式查词回归；③包体积预算达标；④全库不含"柯林斯"字样扫描通过
预估工作量    S1–S5 脚本一天；S6 接入一天；S7 与验收半天 —— 合计 S~M（对应 GAP-18 从"远期池"提级为"第二批"具备条件）
```

---

## 六、结论

1. 现状：词典 UI 完整、数据层为零，原版五部词典无一进入仓库——**处于零侵权分发的最佳决策窗口**；
2. 原版词典数据（尤其 CollinsData.db）取自反编译 APK 属实（证据链见 1.3），任何形态的公开分发均为🔴高风险，旧报告中"直接从 APK assets 复制"的建议**作废**；
3. 推荐方案 C：ECDICT 精简子集本地内置 + 在线兜底，配套执行 4.3 清理清单；
4. 待决事项上报：①wordbook.db 同源合规专项；②有道发音 URL 专项；③ECDICT 许可与 collins 星级字段的法务终审。

---

*本文档由【重构33】建立；后续若取得法务意见或 ECDICT 实测数据，请直接更新对应章节并追加日期备注。*
