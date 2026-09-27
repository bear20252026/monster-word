# 数据层架构总结

> 产出：DataEngineer（Monster world）· 2026-08-24
> 项目：word_app（Monster Word）
> 性质：发布就绪状态下的数据层全景文档

---

## 一、数据层文件清单

### 1.1 `lib/data/`（核心数据层，8 文件）

| 文件 | 职责 | 存储后端 |
|---|---|---|
| `app_preferences.dart` | 应用配置单例（AppPreferences / UserPreferences / GuidePreference） | SharedPreferences |
| `app_preferences_ext.dart` | 扩展偏好（AppPreferencesExt / UserPreferencesExt / GuidePreferenceExt / AuthDataPreferences） | SharedPreferences |
| `wordbook_database.dart` | 只读词库（words / books / word_books） | SQLite（wordbook.db） |
| `user_database.dart` | 用户收藏数据库（favorites） | SQLite（user_data.db） |
| `user_process_dao.dart` | 学习进度 DAO（user_process_history / user_sync_v3） | SQLite |
| `note_database.dart` | 单词笔记（word_notes） | SQLite（notes.db） |
| `fav_sentence_dao.dart` | 收藏例句（JSON 序列化） | SharedPreferences |
| `wallpaper_data.dart` | 壁纸预设与用户选择 | SharedPreferences |
| `example_parser.dart` | 例句 JSON 解析器（纯工具） | 无 |

### 1.2 `lib/state/`（状态管理，2 文件）

| 文件 | 职责 |
|---|---|
| `learning_state.dart` | 学习状态（SRS 卡片、收藏、已掌握、每日统计、连续天数） |
| `wallpaper_state.dart` | 壁纸状态（ChangeNotifier，委托 WallpaperData） |

### 1.3 `lib/theme/`（主题系统，2 文件）

| 文件 | 职责 |
|---|---|
| `skin_system.dart` | 皮肤系统（ThemeVars 30 语义字段 / ThemePreset / SkinSystem / SkinProvider） |
| `app_theme.dart` | 兼容桥接，re-export design_tokens.dart |

---

## 二、数据库结构

### 2.1 SQLite 数据库总览

| 数据库 | 文件 | 模式 | 大小 |
|---|---|---|---|
| 词库 | `assets/db/wordbook.db.gz` → 解压为 `wordbook.db` | 只读 | 压缩 30.1 MB / 解压 114.4 MB |
| 用户数据 | `user_data.db`（运行时生成） | 读写 | 运行时 |
| 学习进度 | 同 user_data.db 或独立 | 读写 | 运行时 |
| 笔记 | `notes.db`（运行时生成） | 读写 | 运行时 |

### 2.2 词库表结构（wordbook.db）

```
words（32,154 行）
├── id          INTEGER  PK
├── word        TEXT     单词原文
├── main_word   TEXT     主词形
├── interpret   TEXT     释义（多词性换行分隔）
├── uk_pron     TEXT     英式音标（IPA，含 ː/ˈ/ˌ 等符号）
├── us_pron     TEXT     美式音标
├── phrase      TEXT     短语
├── example     TEXT     例句 JSON
├── confuse     TEXT     易混词
├── audio_urls  TEXT     音频 URL
├── image_urls  TEXT     图片 URL
└── word_root   TEXT     词根

books（191 行）
├── id          INTEGER  PK
├── code        TEXT     词书编码
├── name        TEXT     词书名称
└── word_count  INTEGER  词条数

word_books（454,196 行）
├── word_id     INTEGER  FK → words.id
└── book_id     INTEGER  FK → books.id
```

### 2.3 用户数据表结构（user_data.db）

```
favorites
├── id          INTEGER  PK AUTOINCREMENT
├── word_id     INTEGER  FK → words.id（UNIQUE）
└── created_at  INTEGER  时间戳

user_process_history
├── id          INTEGER  PK AUTOINCREMENT
├── user_id     VARCHAR  用户 ID
├── word        VARCHAR  单词
├── state       INTEGER  状态（0=未学 1=学习中 2=已掌握）
├── level       INTEGER  等级
├── position    INTEGER  位置
├── reviewdate  VARCHAR  复习日期
├── process     INTEGER  进度
├── success     INTEGER  正确次数
├── fail        INTEGER  错误次数
├── duration    INTEGER  耗时
├── efactor     DOUBLE   难度因子（SM-2）
├── r1/r2       INTEGER  间隔重复参数
├── reFail/reSuccess INTEGER  重学计数
├── comeFrom    INTEGER  来源
├── updatetime  DATETIME 更新时间
├── learnFrom   INTEGER  学习来源
├── zpk         VARCHAR  标记
└── word_id     INTEGER  单词 ID

user_sync_v3
├── synTime     VARCHAR  同步时间
└── userId      VARCHAR  用户 ID（UNIQUE）
```

### 2.4 笔记表结构（notes.db）

```
word_notes
├── id          INTEGER  PK AUTOINCREMENT
├── word_id     INTEGER  单词 ID
├── word        TEXT     单词
├── content     TEXT     笔记内容
├── created_at  TEXT     创建时间
└── updated_at  TEXT     更新时间
```

---

## 三、数据加载流程

### 3.1 启动初始化（main.dart）

```
main()
  ├─ WidgetsFlutterBinding.ensureInitialized()
  ├─ WordBookDatabase.ensurePlatform()        // sqflite FFI 初始化
  ├─ WordBookDatabase.instance.initialize()   // 解压 wordbook.db.gz → 打开只读连接
  ├─ UserDatabase.instance.initialize()       // 创建/打开 user_data.db
  ├─ AppPreferences().init()                   // SharedPreferences 初始化
  └─ runApp(WordApp())                         // 启动 UI
```

### 3.2 词库加载路径

```
assets/db/wordbook.db.gz
  → rootBundle.load() → GZipDecoder → 写入 Application Support/wordbook.db
  → openDatabase(path, readOnly: true)
  → WordBookDatabase.instance 提供查询 API
      ├─ getBooks()           → 词书列表
      ├─ getWordsByBook(id)   → 按词书取词（分页）
      ├─ getWord(word)        → 精确查询
      ├─ searchWords(prefix)  → 前缀搜索
      └─ getWordsByNames(set) → 批量查询
```

### 3.3 用户数据读写路径

```
LearningState (ChangeNotifier)
  ├─ SRS 卡片    → SharedPreferences ('srs_cards_v1')
  ├─ 收藏列表    → SharedPreferences ('favorite_words_v1')
  ├─ 已掌握列表  → SharedPreferences ('mastered_words_v1')
  ├─ 每日统计    → SharedPreferences ('daily_stats_v1')
  └─ 活跃日期    → SharedPreferences ('active_learn_dates_v1')

UserDatabase (SQLite)
  └─ favorites 表 → 收藏单词持久化

UserProcessDatabase (SQLite)
  └─ user_process_history → 学习进度（SM-2 SRS）
```

---

## 四、音标清洗记录

> 来源：重构 #29（方案设计）→ 重构 #39（执行落地）

### 4.1 问题

原始词库中 129 处音标字段包含非标准字符：
- 半角冒号 `:` 应为 IPA 长音符号 `ː`（68 处）
- 半角撇号 `'` 应为 IPA 重音符号 `ˈ`（61 处）

### 4.2 清洗方案

```sql
UPDATE words SET uk_pron = REPLACE(uk_pron, ':', 'ː');
UPDATE words SET uk_pron = REPLACE(uk_pron, "'", 'ˈ');
-- us_pron 同理
```

### 4.3 验证结果

| 检查项 | 清洗前 | 清洗后 |
|---|---|---|
| 词条总数 | 32,154 | 32,154（不变） |
| uk_pron 含 `:` | 68 | 0 |
| us_pron 含 `:` | — | 0 |
| uk_pron 含 `'` | 61 | 0 |
| us_pron 含 `'` | — | 0 |
| uk_pron 含 `ː` | — | 2,897 |
| us_pron 含 `ː` | — | 3,679 |
| uk_pron 含 `ˈ` | — | 8,648 |
| us_pron 含 `ˈ` | — | 8,649 |

---

## 五、词书名映射方案

> 来源：重构 #22（方案设计）→ 重构 #36（v1 草稿生产）

### 5.1 三层兜底链

1. **API 远程查询**（`sapi.beingfine.cn`）→ 在线获取友好名
2. **规则引擎离线推断**（主方案）→ 解码 book code 生成推荐名
3. **原始 code 兜底** → 无法解码时直接显示 code

### 5.2 命名风格规范

- 主标题 + 副标题制（如"红宝书·四级词汇"）
- 数字后缀转中文语义（688 → "核心高频688词"）
- UI 宽度适配：超长名截断策略

### 5.3 产出物

- `docs/book_display_v1_draft.json` — 191 本词书映射草稿
- `docs/book_display_review_notes.md` — 人工校对指引

---

## 六、数据完整性验证结果

> 来源：数据库完整性验证（2026-08-24）

| 维度 | 状态 | 详情 |
|---|---|---|
| gzip 解压 | ✅ | 114.4 MB，无损坏 |
| SQLite 完整性 | ✅ | 只读打开无错误 |
| 表结构 | ✅ | 4 表，与代码模型一致 |
| 词条总数 | ✅ | 32,154（与基线一致） |
| 词书数量 | ✅ | 191（与解码方案一致） |
| 词书映射 | ✅ | 454,196 条 |
| 音标误录 | ✅ | 零残留（: 和 ' 均为 0） |
| IPA 符号 | ✅ | ː/ˈ 正确存在 |
| 代码引用 | ✅ | 10 处 WordBookDatabase 引用路径正确 |
| pubspec 声明 | ✅ | `assets/db/wordbook.db.gz` 匹配 |

**数据库状态健康，无需修复。**

---

## 七、SharedPreferences 键值对概览

总计约 **120+ 个键**，分布在 7 个类中：

| 类 | 键数 | 职责 |
|---|---|---|
| AppPreferences | 18 + 2（批1新增） | 应用级配置（token/主题/搜索历史等） |
| AppPreferencesExt | ~30 | 扩展配置（壁纸/听力/版本/奖励等） |
| UserPreferences | 18 | 用户级配置（学习/签到/提醒等） |
| UserPreferencesExt | ~20 | 扩展用户配置（同步/收藏/策略等） |
| GuidePreference | 4 | 引导状态 |
| GuidePreferenceExt | ~40 | 详细引导计数/状态 |
| AuthDataPreferences | 动态 | 第三方授权数据 |

### 批1 新增键（星巴克重构）

| 键 | 类型 | 用途 |
|---|---|---|
| `skin_theme_id` | String | 皮肤主题 ID（bright/dark/pure_black） |
| `skin_follow_system` | bool | 跟随系统主题开关 |

### ⚠️ 待治理

- `ui_theme`（int）旧键仍存在，与新 `skin_theme_id`（String）并存，未来需废弃/迁移
- `learning_state.dart` 有 12 处散装 `SharedPreferences.getInstance()`，未走 AppPreferences 封装

---

## 八、相关文档索引

| 文档 | 内容 |
|---|---|
| `docs/data_layer_audit.md` | 数据层完整审计（文件清单 + 120+ SP 键值对 + 冲突分析） |
| `docs/database_integrity_report.md` | 词书数据库完整性验证（sqlite3 只读全量检查） |
| `docs/phonetic_data_cleanup_plan.md` | 音标清洗方案 |
| `docs/book_display_v1_draft.json` | 词书友好名映射草稿 |
| `docs/batch1_tech_spec.md` | 主题持久化技术规格 |
| `docs/dead_assets_cleanup_plan.md` | 死资产清理计划 |

---

*产出：DataEngineer · 2026-08-24 · 基于 data_layer_audit.md + database_integrity_report.md 综合整理*
