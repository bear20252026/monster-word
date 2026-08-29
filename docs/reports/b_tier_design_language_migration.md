# B 档设计语言整体切换 · 迁移手册

> 目标：把全站的 A 档颜色之外的视觉/形态令牌（**radius / spacing / shadow**，即 B 档）
> 改为**运行时动态读取**，从而实现「6 套品牌设计语言一键整体切换」。
> 本文是迁移的唯一事实源；每个 feature 的负责人按此执行，完成后向 lead 汇报。

## 0. 已完成的基础设施（lead，勿改）

- `lib/tokens/design_language.dart`：
  - `DesignLanguage`（B 档 bundle：`typography` / `radius` / `spacing` / `shadow`）。
  - `DesignLanguages.all` 含 6 套品牌：`starbucks / airbnb / nike / clickhouse / apple / claude`。
- `lib/theme/skin_system.dart`：
  - `SkinSystem.design` 返回当前 B 档设计语言；`SkinSystem.designLanguageId`；`SkinSystem.setDesignLanguage(id)`（持久化 + 通知）。
  - `context.design` 扩展（`BuildContext` 扩展）：读取当前 `DesignLanguage`，隐式订阅 `SkinProvider`，切换即重建——**这是运行时生效点**。
- 参考已迁移样例：`lib/features/scare_coin/presentation/scare_coin_history_page.dart`、`lib/features/scare_coin/presentation/redemption_center_page.dart`（analyze 0，scare_coin 9/9 测试绿）。

## 1. 动态 token API

| 旧（静态） | 新（动态） |
|---|---|
| `AppRadius.xs/sm/md/lg/xl/xxl/pill/card/control/glass/sheet/radiusNormal` | `context.design.radius.xs/sm/md/lg/xl/xxl/pill/card/control/glass/sheet/radiusNormal` |
| `AppleRadius.xs/sm/md/lg/xl/xxl/pill` | `context.design.radius.xs/sm/md/lg/xl/xxl/pill` |
| `AppSpacing.xxs/xs/sm/md/lg/xl/xxl/section/page/rowH/navH` | `context.design.spacing.xxs/xs/sm/md/lg/xl/xxl/section/page/rowH/navH` |
| `AppleSpacing.xxs/xs/sm/md/lg/xl/xxl/section` | `context.design.spacing.xxs/xs/sm/md/lg/xl/xxl/section` |
| （阴影，选做）elevation 相关 | `context.design.shadow.at(1..5).toBoxShadow(color)` |

> `AppleRadius` / `AppleSpacing` 与 `AppRadius` / `AppSpacing` 当前同为星巴克值（别名），迁移后统一走 `context.design`。

## 2. 迁移规则（务必遵守）

1. **只在 widget 的 build 方法内替换**（有 `BuildContext` 的地方）。`AppRadius.md` → `context.design.radius.md`，`AppSpacing.md` → `context.design.spacing.md`，`Apple*` 同理。
2. 替换后若所在 `EdgeInsets` / `BoxDecoration` / `Container` / `ListTile` 等**不再全部是 const**（因为引用了 `context.design`），需**移除其前的 `const`**（含父级 `const` 列表里对应项）。
3. **保留** `import '../../../tokens/design_tokens.dart'`：它仍提供颜色/排版类（`AppColors` / `MistralColors` / `MistralTypography` / `AppTypography` / `AppGlass`），本次**不迁移**（排版/字体属 B 档-2 阶段）。
4. 确保文件 import 了 `skin_system.dart`（提供 `context.design`）。多数页面已为 `context.skin`/`skin.*` 引入；若没有，补 `import '.../theme/skin_system.dart';`。
5. **禁止改动**：
   - `lib/hooks/responsive.dart` 的 `rowHeight` / `navHeight` / `pageMargin` 等**非 build 上下文**的结构常量（保持静态，6 套设计语言里它们一致）。
   - model / state / data 层引用 token 的地方（无 BuildContext，保持静态）。
   - `MistralTypography.*` / `AppTypography.*` / `AppColors.*` / `MistralColors.*`（本次不动）。
6. 阴影为**选做**：只对原本使用 elevation 阴影的卡片/弹层，改为 `context.design.shadow.at(n).toBoxShadow(color)`；不确定就保持原样，不要胡乱给组件加阴影。
7. **不要**改动 `lib/tokens/design_tokens.dart`、`lib/tokens/design_language.dart`、`lib/theme/skin_system.dart`（lead 专属）。若发现缺哪个 token，`team_send_message` 问 lead，不要自己造。

## 3. 验证门槛（完成即向 lead 汇报，勿自行 git commit / push）

1. `flutter analyze` 0 error，且你负责的文件**无新增** warning/info。
2. 跑你负责 feature 的测试（如 `flutter test test/features/<feature>/`）全绿；**不要跑全量 flutter test**（会抢构建锁）。
3. 简单汇报：改了哪些文件 / 替换了多少处 / analyze 与 feature 测试结果。

## 4. 任务分工

| 负责人 | 范围（只允许改这些） |
|---|---|
| 2163 | `lib/widgets/**`、`lib/screens/**` |
| 2903 | `lib/pages/*`、`lib/features/book/**`、`lib/features/content/**` |
| 3061 | `lib/features/word_browse/**`、`lib/features/learning/**`、`lib/features/search/**`、`lib/features/quick_review/**` |
| 3802 | `lib/features/account/**`、`lib/features/settings/**`、`lib/features/checkin/**`、`lib/features/dictionary/**` |

> 注：每个迁移文件若使用了 `AppColors/MistralColors/MistralTypography/AppTypography`，保留 design_tokens 的 import。以各自范围内 grep `AppRadius\.|AppSpacing\.|AppleRadius\.|AppleSpacing\.` 为起点。

## 5. 进度登记

| feature/范围 | 负责人 | 状态 |
|---|---|---|
| scare_coin | lead（样例） | ✅ 完成 |
| pages + book + content | 2903 | ✅ 完成（32 处 / 8 文件；report `b_tier_design_tokens_pages_book_content.md`） |
| account + settings + checkin + dictionary | 3802 | ✅ 完成（223 处 / 25 文件；report `b_tier_design_tokens_account_settings_checkin_dictionary.md`） |
| word_browse + learning + search + quick_review | 3061 | ✅ 完成（59 处 / 18 文件；report `b_tier_design_tokens_browse_learning_search_quickreview.md`） |
| widgets + screens | 2163→lead 接管 | ✅ 完成（lead 接管收尾 adapter_widgets×5 / review_dialog×4 / word_lookup_popup×3 / learn_session×3 / spring_check_in_calendar×2 / class_activity_banner×1 / check_in_stats_card×1；responsive.dart 结构常量保留） |

**✅ 全量门禁已绿**：`flutter analyze` 0 issue / `flutter test` 533/533 全绿 / `import_guard` 全库 0 边界违规 / `app_structure` 全绿。B档迁移全部完成，可进入「设计语言选择 UI」。
