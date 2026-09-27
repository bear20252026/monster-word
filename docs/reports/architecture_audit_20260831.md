# Monster Word 第二轮架构审计报告（2026-08-31）

> 口径：lib/ 293 文件、40,781 行（较上轮 -2,000 行：screens/ 退役 + 拆分）
> 上轮（8/30）问题修复验证：✅ 全部落地（拆分/壳层退役/DI 统一/音频实例化/lint 加固）

## 整体架构健康度：8.3 / 10（上轮 7.0 → 8.3）

| 维度 | 得分 | 依据 |
|---|---|---|
| 架构 | 8.5 | 分层完整、import_guard+架构测试双守卫、跨域污染 0 实锤 |
| 耦合 | 8.0 | core 遗留模块是唯一显著耦合源（46 个引用文件） |
| 可维护性 | 8.5 | 命名统一（mw_）、规约守卫测试化、注释决策记录成体系 |
| 可扩展性 | 8.0 | 端口-适配器成熟；新功能按"逻辑进 application/state"即可无债扩展 |

---

## 当前耦合现状（实测数据）

### ✅ 已收敛
- 跨 feature 直接 import：**4 条**（全部走 application 端口，合法）
- core→features 反向依赖（守卫豁免外）：**0**
- presentation 层跨域 read：**0 违规**（全部经装配文件）
- 全局可变 static：仅 design_tokens 3 个 TextStyle（非 const）
- 文件行数：全部 ≤900 守卫内（最大 class_checkin_page 1149 为豁免项）

### ⚠️ 唯一显著耦合源：core 遗留模块（上轮 M3，未迁移）

| 模块 | 被引用文件数 | 主要引用方 |
|---|---|---|
| `core/learning/`（8 文件） | **19** | book 域 5、learning 域 6、content/dashboard 等 |
| `core/repositories/`（5 组） | **18** | service_locator 注册、account/checkin/dictionary data |
| `core/scare_coin/` | **9** | account/my_space、checkin、dashboard、scare_coin 自身 |

---

## 分级问题清单

### P1（架构债主源，建议下一迭代）

**A1. `core/learning/` 8 文件 → learning 域**
- **位置**：`lib/core/learning/`（session starter/reader、favorites store、statistics reader、new_words store 等）
- **耦合度：中高**——19 个引用文件横跨 book/learning/content/dashboard
- **方案**：文件物理迁移至 `lib/features/learning/application/`（端口已在同层模式成熟）+ import 全量替换（机械操作，import_guard 会立即捕获遗漏）；`core/learning/learning_session_starter.dart` 因包装 presentation 状态（starter_impl 注释已说明）随同迁移
- **收益**：消除"公共抽屉"，learning 成为自洽域；book 等域对 learning 的依赖变为明确的 `features/learning/application` 端口引用（R4 已允许）

**A2. `core/repositories/` 5 组 → 各自域 data 层**
- **位置**：word/user/note/fav/new_word 5 组 Xxx+XxxImpl
- **耦合度：中**——18 个引用文件，其中 12 个是 service_locator/data 层（合法装配）
- **方案**：按域拆分——word→`features/word_browse/data/`（或新 word_data 域）、note/fav→word_browse、user→account、new_word→learning；service_locator 只改 import 路径
- **收益**：repository 与使用方同域，消除"双家"寻址

**A3. `core/scare_coin/` → `features/scare_coin/data/`**
- **耦合度：低**——9 文件，store 端口与 features/scare_coin 现有 data 天然同域
- **方案**：直接物理迁移 + import 替换（半小时机械操作）

### P2（质量，建议下下迭代）

**B1. `class_checkin_page.dart` 1149 行（守卫豁免项）**
- 拆法同 word_detail 先例：签到日历/班级列表/操作栏 → 3-4 个区块文件
- **B2. `audio_players.dart` 771 行**：BBAudioPlayer/PhoneticAudioPlayer/SentenceAudioPlayer/TextAudioPlayer 4 个类 → 分 4 文件（类间已无静态耦合，纯物理拆分）
- **B3. design_tokens 3 个 static TextStyle**（tokens/design_tokens.dart:168,184,200）→ const 化（若被运行时改写处依赖，先排查）

### P3（持续改进）

- **C1** 表现层注释补齐（learn_page/class_activity 等大文件注释密度 <1%）
- **C2** 聚合页豁免清除：home_screen/profile_screen 按域拆分入口逻辑后，从 import_guard 豁免清单删除（依赖 A1 完成后）
- **C3** `sb_button` 类死代码复查（改名后引用 1 处的组件再评估去留）

---

## 重构路线图（投入产出排序）

| 阶段 | 内容 | 投入 | 收益 |
|---|---|---|---|
| 快赢（<1 天） | A3 scare_coin 迁移；B3 TextStyle const | 0.5 天 | 消除 1 个遗留模块，全局状态清零 |
| 中成本（1-2 天） | A1 core/learning 迁移（19 文件 import 替换） | 1.5 天 | 最大耦合源消除，learning 自洽 |
| 中成本（1-2 天） | A2 core/repositories 按域拆分 | 1.5 天 | 仓库双家合一 |
| 高成本（按需） | B1 class_checkin 拆分；C2 聚合页豁免清除 | 按需 | 守卫豁免清零 |

**执行注意**：A1/A2 每完成一个文件即跑 `flutter test test/architecture/`——import_guard 会实时捕获遗漏的 import，是迁移的安全网。

---

## 上轮（8/30）问题闭环验证

| 上轮问题 | 状态 |
|---|---|
| H1 word_detail 1346 行 | ✅ 拆分完成（725 行 + 4 区块） |
| H2 双壳层 | ✅ screens/ 退役（-817 行） |
| M1 三套 DI | ✅ 约定成文 + NewWordsState 迁出 |
| M5/M6 UI 反馈/超长 build | ✅ mw_feedback + 守卫测试 |
| M7 音频静态单例 | ✅ 实例化完成 |
| M3 core 遗留模块 | ⚠️ 本轮 P1 主体（A1-A3） |
| L3 static TextStyle | ⚠️ 本轮 B3 |
