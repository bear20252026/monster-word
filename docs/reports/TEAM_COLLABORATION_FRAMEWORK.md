# Monster Word 团队协作架构框架（TEAM FRAMEWORK）

> 版本：v1.0 · 更新：2026-08-28 · 维护：Aion CLI (lead)
> 本文件是**唯一事实源（SSOT）**。任何 Agent（含所有 teammate）提交的代码必须遵从本框架；
> 违反者由 lead 驳回并退回修改。 teammates 开工前先读此文件。

---

## 0. 目标

多 Agent 并行开发时，**必须**避免项目退化成「大杂烩」。本框架通过三件事实现：
1. **统一的架构骨架** —— 所有新代码都必须长成同一个样子。
2. **清晰的目录归属** —— 每个 feature 模块只允许一个 Agent 同时修改，杜绝文件冲突。
3. **强制的边界与规范** —— 依赖方向、读写分离、命名、DI、测试全部硬性规定。

---

## 1. 目标架构骨架（All new code MUST follow）

```
lib/
├── main.dart                      # 入口（只做 bootstrap）
├── app/                           # 装配层：组装 features、MaterialApp（薄，不禁业务）
├── core/                          # 跨切面纯逻辑 + DI
│   ├── di/                        # service_locator.dart：全项目唯一注入点
│   └── <cross_cutting_logic>.dart # 例：import_guard.dart
├── features/<feature>/            # ★ 垂直功能模块（本项目的主角）
│   ├── domain/                    # 纯 Dart：实体、值对象、纯函数（无 Flutter / 无 IO）
│   ├── application/               # port 接口（*_reader / *_writer）+ 用例（orchestration）
│   ├── data/                      # port 的实现（repository_*_reader）、模型映射、IO
│   └── presentation/              # state + providers + widgets（只依赖 application）
├── theme/  tokens/                # 设计系统（ThemeVars / sb_* 组件 / 令牌）
├── pages/  screens/  services/    # ★ 历史遗留，正逐步吸收入 features/（迁移方向见 §3）
├── data/  repositories/  models/  # 遗留数据层（迁移目标：data/ 进 features/<feature>/data）
├── engine/  events/  hooks/  lock/  shell/  state/  widgets/  utils/  player/
└── modules/                       # 平台模块（支付/推送/登录/锁屏渠道）
```

**规则 R1**：新增/改造功能，一律写在 `features/<feature>/` 内；**禁止**在 `pages/`、`screens/`、`services/` 里新建业务逻辑。
**规则 R2**：每个 feature 的目录结构必须为 `domain / application / data / presentation` 四分；缺层的模块要先补齐骨架。

---

## 2. 依赖方向与边界规则（Dependency Rules）

```
presentation  ──►  application  ──►  domain
      │                 │
      └──── data ───────┘   （data 实现 application 里的 port；UI 只触达 application）
```

- **R3 依赖只能向内**：`presentation → application → domain`。任何方向相反的 import 都是违规。
- **R4 禁止跨 feature 环依赖**：feature A **不得** inspect/import 另一个 feature 的内部（`domain/application`）。
  - 需要共享能力时：抽象放到 `core/` 或由 `app/` 装配层传递（依赖注入），而不是直接 `import '../other_feature/...`。
- **R5 domain 纯净**：`domain/` 不得 import Flutter（`package:flutter/...`）、I/O、数据库；只允许 `dart:core`、纯 Dart 数学/集合，以及**共享纯 Dart 实体层 `lib/models/`**（`lib/models/*` 视为全项目共享领域实体/基础模型，可作为依赖，见 §4.3；它**不是** feature 内部，不构成跨 feature 违规）。
- **R6 读写分离（CQRS-lite）**：读取一律通过 `application/*_reader.dart`（port）→ `data/repository_*_reader.dart`（实现）；写入走 writer / store。**禁止**在 presentation 直接调 `lib/data/*` 或 `lib/repositories/*`。

---

## 3. 目录归属 & 所有权（Ownership Map）

> 原则：**同一时间，一个 feature 模块只能由一个 Agent（teammate）拥有**。这是防止冲突的核心。

| 目录 / 模块 | 所有权 | 说明 |
|---|---|---|
| `features/account` `book` `checkin` `dictionary` `learning` `player` `quick_review` `scare_coin` `search` `settings` `word_browse` | **各 1 个 Agent 独占** | 每个 feature = 一个工作单元，互不重叠 |
| `core/` `app/` `theme/` `tokens/` | **lead 独占** | 全局架构与设计系统，改动影响面大，禁止 teammates 私自改 |
| `pages/` `screens/` `services/` `models/` `data/` `repositories/` | **迁移目标按 feature 划归对应 Agent** | 迁移时整块搬入 `features/<feature>/`，避免两个 Agent 改同一遗留文件 |
| `docs/` | **lead 协调** | 每个 Agent 只在已分配的子文档写报告，不擅改共享 SSOT 文档 |
| `test/` | **随 feature** | 每个 feature 的测试与源码同在 `features/<feature>/` 下对应 test 目录，由该 feature 负责人维护 |

**R7**：teammate 开工前向 lead 申请指定 feature 模块；lead 用 `team_task_create`（owner=该 teammate）下发，任务文案里明确「只允许修改 `lib/features/<feature>/**`」。
**R8**：任何 Agent 遇到需要改别人拥有的目录（尤其 `core/`、`app/`、`theme/`），**先** `team_send_message` 给 lead 申请，不得直接改。

---

## 4. 编码规范（Conventions）

- **命名**：特征读取 `lib/features/<f>/application/<nouns>_reader.dart`；port 实现 `data/repository_<nouns>_reader.dart`；用例 `application/*_executor.dart` 或 `*_starter.dart`；纯逻辑 `domain/<nouns>.dart`。
- **DI**：一切依赖经 `core/di/service_locator.dart`（或 feature 的 `feature_providers.dart`）注册；**禁止**在页面里 `new` 产生跨层单例/全局状态。
- **状态**：`presentation/*_state.dart` 用 provider / riverpod 风格集中管理；禁止把状态塞进 widget 内部导致难测。
- **组件**：业务无关的通用组件放 `widgets/sb_*`；功能私有的组件放 `features/<f>/presentation/widgets/`。
- **注释**：中文注释与现有项目一致；公共 API 用 `///` 说明意图。
- **类型**：优先 `final`/不可变；避免 `dynamic`；函数体清晰可测。

---

## 5. 协作工作流（Team Workflow）

```
[lead] 定义任务 → team_task_create(owner=teammate, 范围明确)
   → [teammate] 只改自己 feature 目录 → flutter analyze + flutter test 通过
   → [teammate] team_send_message 汇报（改了什么/测试结果/遇到的边界）
   → [lead] 审查（对照框架 R1-R8）+ 抽查 → 通过则引导提交 / 驳回则附原因退回
   → [teammate] git add 仅自己的目录 + 改 docs 对应子文档 → lead 确认提交
```

- **R9 每任务一个 owner**；任务描述必须含**允许修改的文件 glob**（如 `lib/features/learning/**`）。
- **R10 串行依赖**：B 依赖 A 的输出时，先派 A 并等 A 的 idle 通知，**再**派 B；禁止给 B 发「standby 等 A」。
- **R11 冲突预防**：绝不 parallel 派两个 Agent 到同一 feature；共享修改（core/app/theme）走 lead 统一串行。
- **R12 提交粒度**：一个 feature 一处逻辑 = 一个 commit，message 用 `feat(scope):` / `refactor(scope):` / `chore:`。
- **R13 收尾即提交**：任务完成的判定 = 代码 + 测试 + 对应 docs 报告三件套齐全，缺一不算完。

---

## 6. 质量门禁（Quality Gates）

> 未通过以下门禁，lead 一律驳回。

1. `flutter analyze`：**0 个 error**，且不得新增 warning/info 于自己改的文件。
2. 目标测试 `flutter test test/features/<feature>/...` 全绿；新增逻辑必须有新单测。
3. 不破坏既有 44 个测试文件（`flutter test` 全量跑通）。
4. 改动须符合 §1/§2/§4 的规则（分层、依赖方向、命名、DI）。
5. 涉及功能的改动必须更新 `docs/` 对应报告；涉及架构边界的必须 `team_send_message` 通知 lead 同步 `architecture_boundaries.md`。

---

## 7. 可并行工作划分（Workstreams · 互不重叠）

> lead 按下述工作流派活；每列一个工作流，边界严格不重叠，避免「大杂烩」。

| Workstream | 内容 | 归属目录（只许改这里） | 建议 Agent |
|---|---|---|---|
| **WS-0 框架落地** | 本框架文档 + 架构基线 | `docs/`（本文件） | lead（已做） |
| **WS-1 Lint 债清理** | 批量删未使用 import/死代码/废弃 API；**只做净化，不重构** | 逐模块发，`pages/`、`services/`、`widgets/` 等非核心目录 | 1 个 teammate，串行 |
| **WS-2 功能完整化** | 把某个遗留 feature 从 `pages/screens/services` 完整吸入 `features/<f>/` | `features/<f>/**` + 对应 `pages/*<f>*` | 每 feature 1 个 teammate，可多个 feature 并行（不重叠） |
| **WS-3 import_guard 收尾** | 溯源用途 → 接入 or 删除；清除孤儿文件 | `lib/core/import_guard.dart` + 对应测试 | **lead**（`core/` 归 lead 独占，见 R8）；**用户已确认：暂缓**，先归档保留，待明确用例后接入或删 |
| **WS-4 功能缺口 backlog** | `docs/backlog_functional_gaps.md` 中挑 1 个（支付/推送/登录…） | 对应 `features/<f>/` 或 `modules/` | 每任务 1 个 teammate（单点） |
| **WS-5 音频解耦** | 把 word 音频播放能力从 `features/player/presentation/audio_playback_state.dart` 提升为 `core/` 共享抽象，回填所有跨 feature 引用（dictionary/search/learn/word_detail/spell_session/spell_check） | `lib/core/**` + 上述引用点 | **lead 主导**（`core/` 归 lead；涉及多 feature 回填需 lead 统一协调） |

**R14 并行度纪律**：最多同时运行 2 个 teammates 的 implementation（避免 review 积压与合并碎裂）；lint/迁移这类「横切」活**只能单线程**，且每次只动一个 feature。

---

## 8. 冲突规避 Checklists（Do / Don't）

**DO**
- [x] 开工先读 `TEAM_COLLABORATION_FRAMEWORK.md` + `docs/architecture_boundaries.md`
- [x] 只改自己被分配的文件 glob
- [x] 每步跑 `flutter analyze` 确认 0 error
- [x] 卡在边界时 `team_send_message` 问 lead，而不是自作主张改共享层
- [x] 完成后提交「代码+测试+文档」三件套

**DON'T**
- [ ] 不 `flutter pub`/`dart pub get` 之外的任何全局改动（如切依赖、改 pubspec 架构）
- [ ] 不碰别人拥有的 feature/目录
- [ ] 不新建 `lib/pages`、`lib/screens`、`lib/services` 里的业务
- [ ] 不直接 import 其他 feature 内部
- [ ] 不绕过 service_locator 注入单例

---

*本框架为 SSOT。改动须经 lead 批复并更新版本号。*
