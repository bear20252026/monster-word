# 【重构28】数据交叉审计：裁定报告间量化分歧

> 身份：中立审计员（BuildScout）。方法：对 lib/ 全部 184 个 dart 文件用统一 pattern 重新计数，再对照各报告原文定位其口径。
> 承接材料：starbucks_migration_plan.md（Architect）、ui_inventory.md（Surveyor）、qa_baseline.md（QA）、test_plan.md、assets_inventory.md、icon_plan.md、motion_spec.md。
> 总裁定：**两份报告的颜色数字都没有造假，是口径不同**；但另有 2 处结论被证伪、2 处需要修正。

---

## 1. 硬编码颜色：精确重测与口径裁定

### 1.1 统一口径重测（2026-08-24，lib/ 全量 184 dart 文件）

| Pattern | 出现次数 | 分布 |
|---|---|---|
| `Color\(0x` | **324 处** | 39 个文件 / 298 行 / **146 个唯一色值** |
| ├─ lib/pages | 116 处（15 文件） | 最大户 profile_screen ×24、my_content ×18、word_machine ×15 |
| ├─ lib/theme/skin_system.dart | 68 处（1 文件） | 皮肤定义层 |
| ├─ lib/widgets | 40 处（16 文件） | |
| ├─ lib/tokens/design_tokens.dart | 38 处（1 文件） | 令牌定义层 |
| ├─ lib/screens | 35 处（3 文件） | |
| ├─ lib/data/wallpaper_data.dart | 22 处（1 文件） | |
| ├─ lib/lock | 3 处 · lib/shell | 2 处 | |
| `Color.fromARGB` / `fromRGBO` | 0 处 | 无 |
| `.withOpacity(` | 106 处（UI 三目录内 76） | 半透明叠加，另一类硬编码 |
| `.withValues(` | 67 处 | 同上，新版 API |
| `Colors.<name>` | **1269 处**（UI 三目录内 989 处 / 68 种不同名 / 52 文件） | Material 调色板 |

### 1.2 两份报告口径还原

| 报告 | 原文 | 实际口径 | 复核结果 |
|---|---|---|---|
| Architect（starbucks_migration_plan.md:75） | "本次全库扫描 **~40 处**" | **数的是"含有 Color(0x 的文件数"**（39 个 ≈ 40），不是处数 | 文件数准确 ✓，但**单位误标**："处"应为"个文件"；且其列举的散点（appearance/my_content(:157-162)/splash(:126-182)/collins 六处/input_controls.dart:12/check_in_widgets.dart:74）逐一抽查**全部真实存在** ✓ |
| Surveyor（ui_inventory.md:38-39） | "Color(0x…) 约 **153 处**（集中于 19 个文件）" | **ui_inventory 自身盘点范围 = pages+screens+shell 三目录（58 个 UI 文件）内的出现次数**：116+35+2 = **153**，分毫不差 ✓；19 文件 = pages 15 + screens 3 + shell 1 ✓ | 在其声明的范围内**精确正确**；但它只是全库的 UI 子集 |

### 1.3 裁定

- **权威数字（全库口径，施工按此排期）：`Color(0x` 共 324 处 / 39 文件 / 146 唯一色值。**
- Surveyor 的 153 处继续有效，但必须加前缀"**UI 层（58 文件范围）**"，否则会被误读为全库总量；
- Architect 的 ~40 改写为"39 个文件含硬编码"，不得再写作"40 处"；
- ⚠️ 双方都漏了更大的坑：`Colors.*` 材料色直引全库 **1269 处**、`withOpacity/withValues` 合计 173 处——这些同样绕过主题系统，重构清零范围应把三者一起纳入。

---

## 2. 其他关键量化结论抽验

| # | 结论 | 来源 | 重测结果 | 判定 |
|---|---|---|---|---|
| 1 | QA 基线 **368 issue**（E4 / W114 / I250）@ commit 5f17e18 | qa_baseline.md | 与 test_plan.md 引用完全同口径同数值，**报告间无冲突** ✓。本次未重跑 analyze：① flutter 工具锁可能与正在跑构建的 QA 冲突；② 重构持续合码，任何重测都只对特定 commit 有效 | ✅ 口径一致；使用时必须带 commit 号 |
| 2 | UI 页面总数 **58**（pages 53 / screens 4 / shell 1） | ui_inventory.md:35 | 实测三目录 dart 文件 53+4+1 = **58** | ✅ 精确 |
| 3 | 组件 "**36 个 widget 仅 7 个在用**" | ui_inventory.md:40 | 实测 lib/widgets = **37 个**文件；页面层直接 import 的恰好 7 个 ✓；另有 **main.dart 全局接线 2 个**（adaptive_scale、transition_widgets）未被计入 | ⚠️ 微修：37 个；"7 个在用"限定于页面层，全局层还有 2 个 |
| 4 | assets/icons/ **9 个 SVG 全部零引用死资产** | assets_inventory.md:15 / icon_plan.md | lib/ 中 `.svg` 与 `flutter_svg` 关键字**零命中** ✓ | ✅ 确认；连带发现 pubspec 里 flutter_svg 是**死依赖**（呼应【重构10】音频库冗余项，建议一并清理） |
| 5 | 动画时长 "实际使用值 100/195/…/800ms **十余种**" | motion_spec.md:177 | 唯一 `Duration(milliseconds:)` = **17 种**：100/150/195/200/225/250/300/350/400/500/600/800/1000/1200/1500/1600/3000；另有 `Duration(seconds:)` 6 种（1/2/3/5/15/30s） | ⚠️ 定性正确、枚举不全；档位设计（fast150/base200/slow300/expressive400-600）仍能覆盖绝大多数现值，但 500/1000/1200/1500/1600/3000 六种长时长需要归入">800ms 仅限环境/循环类"白名单规则 |
| 6 | "`widget_utils.dart` 已有 ScaleDownOnPress **直接复用**" | starbucks_migration_plan.md:50 | widget_utils 仅被 **check_in_widgets.dart 引用，而后者本身就是孤儿组件**；login_page.dart 只 import animations.dart，并未用到它 | ❌ **证伪**：现状是"存在但未接线"，不是"已复用"。影响：按钮改造批次的现成轮子假设不成立，需先决定接线还是重写 |
| 7 | "`Colors.*` 约 **230 处**（分散）" | ui_inventory.md:38 | UI 三目录范围实测 **989 处**（68 种名），全库 1269 处；尝试了次数/行数/去重名三种口径均无法得出 230 | ❌ **无法复现**，疑为估算残留；按 989（UI 范围）修正 |

---

## 3. 报告勘误表

| 报告 | 原结论 | 核验结果 | 修正值 | 影响 |
|---|---|---|---|---|
| starbucks_migration_plan.md:75 | 硬编码 Color "~40 处" | 39 是**文件数**；全库出现 324 次 | **324 处 / 39 文件**（全库口径） | 🔴 高：颜色清零工作量按 324 处排期而非 40，约 **8 倍低估** |
| ui_inventory.md:38 | Color(0x 约 153 处（19 文件） | 其口径（pages+screens+shell）内精确正确 | 保留，**加注"UI 层子集"**；全库总量 324 处 | 🟢 低：数字本身可用，防误读即可 |
| ui_inventory.md:38 | Colors.* 约 230 处 | 三种口径均无法复现；UI 范围实测 989 处 | **989 处（UI 范围）/ 1269 处（全库）** | 🔴 高：Material 直引清理量 4 倍于原估计 |
| ui_inventory.md:40 | 36 个 widget、7 个在用 | 实测 37 个文件；页面层 7 ✓ + main.dart 全局层 2 | **37 个；页面层在用 7、全局接线 2** | 🟢 低：口径补注 |
| motion_spec.md:177 | 时长"十余种"，列举 10 种 | 实测 ms 级 17 种 + 秒级 6 种 | **17 种（ms）+ 6 种（s）**，补齐枚举 | 🟡 中：档位映射表需覆盖新增的 6 种长时长 |
| starbucks_migration_plan.md:50 | ScaleDownOnPress "直接复用" | 仅被孤儿组件 check_in_widgets 引用，主流程未接线 | **未复用**；按钮批次需先接线或改写 | 🟡 中：第 1 批次（按钮）工作量上修 |
| qa_baseline.md | 368 issue（E4/W114/I250） | 各报告引用一致；未重跑（工具锁+快照属性） | 维持 **368 @ 5f17e18**，引用必带 commit | 🟢 低：待 QA 收尾时刷新基线 |

无分歧确认项：58 个 UI 文件 ✓、9 个死资产 SVG ✓、死依赖 flutter_svg（新增发现）。

---

## 4. 结论：哪些数字能直接进施工手册

**✅ 可直接采用（本轮已双源核验）：**

| 数字 | 口径 | 用途 |
|---|---|---|
| **324 处 / 39 文件 / 146 色值** | lib/ 全量 `Color(0x` | 颜色清零总盘子 |
| 153 处 / 19 文件 | UI 三目录子集 | 页面批次切分（Surveyor 原数据继续用） |
| 989 / 1269 处 | `Colors.*`（UI 范围 / 全库） | Material 直引治理（替代原 230） |
| 173 处 | withOpacity(106)+withValues(67) | 透明度硬编码专项 |
| 58 文件 | pages53/screens4/shell1 | 页面改造清单 |
| 37 widget / 7+2 在用 | 文件级 | 孤儿组件清理清单（28 个候选删除） |
| 9 个死 SVG + flutter_svg 死依赖 | 零引用实证 | 资产清理任务 |
| 17+6 种时长 | 全量 Duration 枚举 | MotionDurations 档位收敛依据 |

**⚠️ 使用前需补充动作：**

1. **368 issue 基线**：所有引用必须带 `@ 5f17e18`；QA 任务收尾后在最新 commit 重跑刷新，新旧差值即重构期间引入/消除的问题数；
2. **ScaleDownOnPress**：施工方先做 30 分钟决断（接线 or 重写 or 弃用），再排按钮批次工时；
3. **长时长 6 种**（500~3000ms）：motion_spec §4.1 档位表补一行"环境/循环类白名单"，否则机械归档时会把这些错压到 expressive 档；
4. **颜色清零排期**：以 324 处为准重新切批次——原计划按 ~40 处估的批次粒度偏粗，建议按 39 个文件分组、每文件一次提交（与【重构23】发布检查单的"逐文件提交便于回滚"衔接）。

*审计人：BuildScout（【重构28】）· 2026-08-24 · 方法透明：全部计数可用相同 pattern 一键复现*
