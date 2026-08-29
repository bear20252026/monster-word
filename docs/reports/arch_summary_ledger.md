# Monster Word 架构工作总结汇总表（ARCH 全周期）

> 仓库：`bear20252026/monster-word`（分支 `main`）
> 生成：2026-08-29 ｜ 范围：WS-2 教科书式垂直模块 → WS-3 依赖边界守卫 → WS-6 共享契约 → ARCH-FIX 1-9 系列 → Import 统一 → 遗留层 sink（T1-T6）
> 门禁：`flutter analyze` **0** ｜ `flutter test` **534/534** ｜ `import_guard` **10/10**（全库扫描 0 边界违规）

---

## 一、当前架构快照（最终分区）

### 1.1 `lib/` 顶层 —— 9 个理想目录 + `main.dart`
| 目录 | 职责 | 说明 |
|---|---|---|
| `app/` | 应用装配/组合根 | `app.dart`、DI scope 组装 |
| `core/` | 跨 feature 共享基础设施 + 领域内核 | 12 个关注点桶（见 1.2） |
| `features/` | 教科书式垂直功能模块 | 11 个 feature，多为四层齐全 |
| `models/` | 纯 Dart 值对象/实体 | 共享实体（如 `Word`、`Book`） |
| `screens/` | App 级底栏壳层 | `home_screen`/`learn_session`/`profile_screen`，仅 `app.dart` 导入（正规组合宿主） |
| `theme/` | 视觉主题系统 | `skin_system.dart` + `wallpaper_data/state`（2026 ARCH-FIX-8 并入） |
| `tokens/` | 设计 token | 颜色/排版/玻璃拟态；`gameboy.dart` 为刻意保留的设计皮肤 |
| `utils/` | 共享工具 | `screen_utils.dart` |
| `widgets/` | 跨 feature 共享组件 | 32 个（review_dialog/session_exit_guard 等） |

### 1.2 `core/` —— 12 个关注点桶
| 桶 | 内容 | 共享性核验 |
|---|---|---|
| `audio/` | 播放/音频服务/系统TTS/词音频域 | 多 feature（app/screens/dictionary/search/learning）✅ |
| `auth/` | 会话控制器 | account+settings ✅ |
| `di/` | `service_locator.dart` | 全库 ✅ |
| `engine/` | FSRS/SRS/Leitner 算法子系统 | **共享算法基建**（fsrs6_engine 被 dictionary 用，勿拆）⚠️ |
| `infrastructure/` | 4 个存储适配器 | `app_preferences`/`fav_sentence_dao`/`user_database`/`wordbook_database` |
| `learning/` | 学习领域契约 | `LearningProgressReader` 等共享契约 |
| `parsers/` | 例句/词组解析器 | dictionary/search/word_browse ✅ |
| `presentation/` | 共享展示工具 | `responsive.dart`（多 feature）✅ |
| `repositories/` | 仓储接口+实现 | 经 DI 共享 ✅ |
| `router/` | 路由名/导航工具 | 全库 ✅ |
| `scare_coin/` | 激动币共享契约 | dashboard/profile/checkin/scare_coin ✅ |
| `web/` | 网页基底/URI Scheme | 全库 ✅ |

> `core/services/` 桶已于 2026 ARCH-FIX-9 删除（唯一单归属文件下沉）。

### 1.3 `features/` —— 四层垂直模块（读走端口、写走 store、依赖注入）
| feature | domain | application | data | presentation | 备注 |
|---|---|---|---|---|---|
| dictionary | 3 | 4 | 5 | 5 | 范式模板 |
| book | 1 | 3 | 5 | 8 | 含进度回填 |
| checkin | 2 | 3 | 5 | 6 | |
| search | 1 | 4 | 4 | 2 | |
| account | 1 | 1 | 3 | 14 | 含登录/我的空间 |
| settings | 1 | 2 | 1 | 7 | 含学习偏好 |
| learning | 3 | 18 | 19 | 37 | 最大域 |
| quick_review | 2 | 1 | 1 | 2 | |
| scare_coin | —(纯值对象下沉 models) | —(store 端口在 core) | 1 | 3 | 端口在 core |
| word_browse | —(值对象在 models) | 2 | 2 | 2 | |
| content | — | — | — | 4 | 遗留薄壳（待归并） |

---

## 二、演进总览（阶段矩阵）

| 阶段 | 目标 | 交付物 | 门禁 |
|---|---|---|---|
| WS-2 基线 | 12 个 feature 教科书化（四层齐全） | 见 2.1 | analyze 0 / test 全绿 |
| WS-1 Lint | 全库 lint 清零 | 委托 A/B/C/D 四卡 | analyze 0 |
| WS-3 | 依赖边界守卫 | `core/import_guard.dart`（R3/R4/R5 + core 纯净） | import_guard 0 |
| WS-6 | 学习状态提升为共享契约 | `LearningFavoritesStore`/`NewWordsStore`/`LearningSessionStarter` | test 389 |
| ARCH-FIX 1-9 | 结构收敛/死码/归位/单归属 | 见第三节 | test 534 |
| Import 统一 | 相对导入→绝对导入 | 906 转换 / 231 文件 | analyze 0 |

### 2.1 WS-2 教科书式模块（已完成）
`dictionary`（范式模板）、`book`、`checkin`、`search`、`scare_coin`、`word_browse`、`quick_review`、`account`、`settings` —— 均先报 lead 审查后提交。要点：读走 `*_reader` port、写走 writer/store、domain 纯净、经 `*_feature_providers.dart` 注入。

---

## 三、ARCH-FIX / 遗留层 sink 逐项汇总表（commit 按序）

### 3.1 遗留层 sink（T1-T6，未推送 20 提交含 T5 起）
| 项 | commit | 动作 | 影响 |
|---|---|---|---|
| T5 | `e3f1a97` | 删死码 `lib/lock` + `lib/modules` | 保留 `state/wallpaper_state` |
| T6a | `4f37560` | 删 `lib/services`/`lib/data` 7 个零引用 | 死码 |
| T6b | `7e93eb6` | 删 `dictionary_service` 死码；`dictionary_extra` 归位 feature | 死码+归位 |
| T6c | `2adc016` | `checkin_service`(2) → feature（单归属） | 归位 |
| T6d | `2cd7c6b` | `user_service`(2) → feature（account 单归属） | 归位 |
| T6e | `1a6067b` | `mastered_repository`(2) → feature（learning 单归属） | 归位 |
| T6f | `1ffa698` | `book_repository`(2) → feature（book 单归属） | 归位 |
| T6g | `2458219` | 共享解析器 → `core/parsers` | 归位 |
| T6h | `f0b41bf` | 共享音频服务 → `core/audio` + 删死 `lock_media` | 归位+死码 |
| T6i | `41cb889` | 共享仓储 → `core/repositories` | 归位 |
| T6j | `b9d9209` | `lib/data`(6) → `core/infrastructure`；25 importer repoint；修 3 条 stale `export ../models`→`../../models` | 归位 |
| T6k | `a684fef` | services → `core/services`；删死 `http_client.dart`(33KB) | 归位+死码 |
| T6l+T6m | `7a10db3` | `state/hooks` → core；`wallpaper_state`→infra、`responsive`→presentation；37 importer repoint | 归位 |

### 3.2 ARCH-FIX-7 死码扫除（批次）
| 批次 | commit | 移除 | 成果 |
|---|---|---|---|
| B1 | `96d97af` | 56 孤儿文件 | widgets 34 桶/models 10/core-engine 3/note_database/4 死页/utils/adapter_widgets |
| B2 | `d73562f` | 13 孤儿文件 | 整个 `core/engine/bs` 子系统 5 文件 + `api_services.dart` 952 行 God-file + app_theme + 2 models |
| B3 | `0db9420` | 5 孤儿文件 | `learning_models` + app/crypto/data/date_utils |

**死码扫除合计**：74 文件 / 约 17,221 行；lib 382→308 文件、60,633→43,412 行；总量 71,318→54,097 行。

### 3.3 Import 统一 + 收尾
| commit | 动作 |
|---|---|
| `730a0e2` | 906 条相对 import/export → `package:word_app/` 绝对路径，跨 231 文件 |
| `b96f46b` | 清出误入库的一性脚本 `convert_imports.py` |

### 3.4 ARCH-FIX-8/9（本会话，见第四节详述）
| commit | 动作 |
|---|---|
| `519aa17` | ARCH-FIX-8：wallpaper 簇 `core/infrastructure` → `lib/theme` |
| `3ec4f13` | ARCH-FIX-9：单归属 `share_image_service` `core/services` → `features/learning/data`，`core/services/` 桶删除 |

---

## 四、本会话详细说明

### 4.1 工具与审计方法
- **死码检测**：Python 脚本扫描 lib+test 的 import/export/part，同时解析 `package:` 与相对路径到 lib 相对路径，按 0 引用判定孤儿；另加「路由注册核对」（页面若经 routeName 引用则非死码）。
- **单归属扫描**：Python 统计每个 core 文件被哪些 feature 导入分组 → 识别单归属。**局限**：DI-registered 文件经 `service_locator` 消费，扫描器读不到（呈"UNUSED"假阳性），**结论仅供提示，不可直接动**。

### 4.2 关键发现与经验教训
1. **路由注册核对**：页面可能经 routeName 被引用而非静态 import → 判死码前必须核对 router 表。
2. **`gameboy.dart` 是刻意保留的设计皮肤**：虽无引用，不可删。
3. **git autocrlf（LF→CRLF）警告是良性**：git 自愈，内容 diff 已核对。
4. **相对深度 bug**：`../` 深度 bump 反复致解析失败（T4/T6j）→ 是引入 import 统一的直接动机。
5. **`export` 与 `import` 的替换差异**：T6j 仅替换 `import` 未替换 `export`，导致 `Book isn't a type` 52 错误 —— 教训：批量替换须同时覆盖 import/export/part。
6. **`core/engine` 勿拆**：fsrs6_engine 仍被 `dictionary/word_detail_page` 跨 feature 用，整个算法子系统是共享基建；单归属扫描仅标记其中 learning-only 成员，是子系统内部分工，非可下沉对象。
7. **`system_tts`（core/audio）保留**：虽单归属 learning，但属可复用系统 TTS 基建，留在 core 合理。
8. **`core/{audio,parsers,scare_coin,auth,di,presentation,web}` 均核为多 feature 共享**，正确在 core，未误迁。
9. **`lib/screens/` 是正规组合宿主**（仅 `app.dart` 导入），非遗留 smear。

### 4.3 已登记技术债
- **ARCH-FIX-10 deferred**（任务 `01a04dfb-458b-…`）：test/ 结构对齐 —— `test/{pages,data,unit}` 是陈腐桶（lib/pages、lib/data 已删，lib/unit 从未存在）；`test/widgets` 正确镜像 `lib/widgets`（保留）。全 `package:` 导入、仅移动不改内容=import-safe；安全子集已列，因归属判断偏主观、纯美学，留作后续滚动项。
- **wallpaper 系统下线**：`wallpaper_data.dart` 内有「待'壁纸系统下线'重构统一清理」备注（`lib/theme/wallpaper_data.dart` —— 2026-08-29 迁入后路径）。

---

## 五、累计门禁与指标

### 5.1 门禁
| 门禁 | 结果 |
|---|---|
| `flutter analyze` | **0 issues** |
| `flutter test` | **534/534 通过**（108 测试文件） |
| `import_guard` 全库扫描 | **0 边界违规**（10/10 例） |

### 5.2 指标
| 维度 | 数值 |
|---|---|
| lib | 308 文件 / 43,412 行 |
| test | 108 文件 / 10,685 行 |
| 合计 | 416 文件 / 54,097 行 |
| lib/core 桶数 | 12 |
| feature 数 | 11（多为四层齐全） |
| 死码扫除 | 74 文件 / ~17,221 行 |
| import 统一 | 906 转换 / 231 文件 |

---

## 六、未推送提交清单（20 个，自 `origin/main` @ `1b98ce6`）

已随本报告一并 `git push`。清单见第三节各表（T5→ARCH-FIX-9）。

> 说明：`docs/reports/` 下 78 个既有分析/迁移/UX/QA 报告与本节所有技术资料一同推送至 GitHub。
