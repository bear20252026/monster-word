# 文档完整性审查报告

> 审查日期：2026-08-24
> 审查范围：`docs/` 目录下全部 `.md` 文件
> 审查人：DocReviewer (Monster world)

---

## 一、文件清单总览

| # | 文件名 | 行数 | 状态 |
|---|--------|------|------|
| 1 | `answer_feedback_patch_blueprint.md` | 670 | ✅ 完整 |
| 2 | `assets_inventory.md` | 181 | ✅ 完整 |
| 3 | `a11y_contrast_report.md` | 187 | ✅ 完整 |
| 4 | `a11y_dark_mode_report.md` | 175 | ✅ 完整 |
| 5 | `backlog_functional_gaps.md` | 141 | ✅ 完整 |
| 6 | `batch1_tech_spec.md` | 316 | ✅ 完整 |
| 7 | `book_cover_design_spec.md` | 315 | ⚠️ 缺结论节 |
| 8 | `book_display_review_notes.md` | 223 | ⚠️ 结尾偏弱 |
| 9 | `book_name_mapping_plan.md` | 244 | ✅ 完整 |
| 10 | `branding_assets_plan.md` | 198 | ✅ 完整 |
| 11 | `build_config_audit.md` | 136 | ✅ 完整 |
| 12 | `component_spec.md` | 502 | ✅ 完整（2个遗留待办） |
| 13 | `content_audit.md` | 151 | ✅ 完整 |
| 14 | `dark_skin_strategy.md` | 179 | ✅ 完整 |
| 15 | `design_system_onepager.md` | 93 | ✅ 完整 |
| 16 | `DESIGN.apple-alpha.bak.md` | 562 | 📦 归档备份 |
| 17 | `dictionary_license_review.md` | 158 | ✅ 完整 |
| 18 | `execution_runbook.md` | 59 | ✅ 完整（简明） |
| 19 | `findings_cross_audit.md` | 96 | ✅ 完整 |
| 20 | `font_strategy.md` | 289 | ✅ 完整 |
| 21 | `icon_plan.md` | 206 | ✅ 完整 |
| 22 | `imagery_audit.md` | 121 | ✅ 完整 |
| 23 | `ipa_coverage_full_audit.md` | 145 | ✅ 完整 |
| 24 | `launcher_icon_brief.md` | 182 | ✅ 完整 |
| 25 | `learn_flow_comparison.md` | 81 | ✅ 完整 |
| 26 | `learn_flow_motion_storyboard.md` | 220 | ✅ 完整 |
| 27 | `live_pages_hardcode_map.md` | 235 | ✅ 完整 |
| 28 | `live_route_map.md` | 141 | ✅ 完整 |
| 29 | `motion_spec.md` | 334 | ✅ 完整 |
| 30 | `phonetic_data_cleanup_plan.md` | 199 | ✅ 完整 |
| 31 | `pressable_inventory.md` | 253 | ✅ 完整 |
| 32 | `qa_baseline.md` | 45 | ✅ 完整 |
| 33 | `reference_index.md` | 177 | ✅ 完整 |
| 34 | `release_pipeline.md` | 181 | ✅ 完整 |
| 35 | `starbucks_migration_plan.md` | 82 | ✅ 完整 |
| 36 | `starbucks_tokens_draft.md` | ~470 | 📝 草案（非独立文档） |
| 37 | `test_plan.md` | 154 | ✅ 完整 |
| 38 | `touch_target_audit.md` | 122 | ✅ 完整 |
| 39 | `ui_inventory.md` | 146 | ✅ 完整 |
| 40 | `vector_library_design.md` | 28 | ❌ 严重截断 |
| 41 | `contrast_guard_spec.md` | 353 | ⚠️ 缺结论节 |

**合计 41 个文件，约 8,800+ 行**

---

## 二、截断/不完整文件

| 文件 | 行数 | 问题描述 | 严重度 |
|------|------|----------|--------|
| `vector_library_design.md` | 28 | 只有概念描述和文件结构，无实现细节，以代码围栏结尾后截断 | **高** |
| `contrast_guard_spec.md` | 353 | 正文完整，但文件在"预估对比度"表格中间截断，缺少结论节和署名 | 中 |
| `book_cover_design_spec.md` | 315 | 正文完整，但在附录速查表中间结束，缺少结论节 | 中 |
| `book_display_review_notes.md` | 223 | 内容到第四节即结束，缺少正式结论 | 低 |

---

## 三、交叉引用审计

### 3.1 已验证有效的引用

以下引用均指向 `docs/` 中存在的文件：

- `design_system_onepager.md` → `component_spec.md`、`motion_spec.md`、`icon_plan.md`、`dark_skin_strategy.md`、`font_strategy.md`、`starbucks_migration_plan.md`、`a11y_contrast_report.md` ✅
- `learn_flow_motion_storyboard.md` → `motion_spec.md`、`component_spec.md`、`touch_target_audit.md` ✅
- `a11y_dark_mode_report.md` → `dark_skin_strategy.md`、`a11y_contrast_report.md` ✅
- `book_cover_design_spec.md` → `a11y_contrast_report.md`、`a11y_dark_mode_report.md`、`component_spec.md`、`starbucks_migration_plan.md`、`book_name_mapping_plan.md` ✅
- `starbucks_migration_plan.md` → `font_strategy.md`、`starbucks_tokens_draft.md` ✅

### 3.2 失效引用（8处）

均位于 `backlog_functional_gaps.md`，引用了已被归档或删除的原始分析报告：

| 源文件 | 引用目标 | 状态 |
|--------|----------|------|
| `backlog_functional_gaps.md` | `review_animations.md` | ❌ 不存在（已归档） |
| `backlog_functional_gaps.md` | `review_final_report.md` | ❌ 不存在（已归档） |
| `backlog_functional_gaps.md` | `ui_compare_word_detail.md` | ❌ 不存在 |
| `backlog_functional_gaps.md` | `ui_compare_word_list.md` | ❌ 不存在 |
| `backlog_functional_gaps.md` | `ui_polish_summary.md` | ❌ 不存在 |
| `backlog_functional_gaps.md` | `monster_word_v5_resources.md` | ❌ 不存在 |
| `backlog_functional_gaps.md` | `review_responsive.md` | ❌ 不存在 |
| `backlog_functional_gaps.md` | `review_consistency.md` | ❌ 不存在 |

**评估**：这些引用指向原始分析报告，其发现已被吸收进 backlog 中，属于历史残留引用。不影响当前实施，但建议标注为"已归档"。

---

## 四、数值一致性问题

### 4.1 issue 总数矛盾：364 vs 368

| 文件 | 行号 | 说法 | ERROR/WARNING/INFO |
|------|------|------|--------------------|
| `qa_baseline.md` | 22 | 364 | E0 / W114 / I250 |
| `test_plan.md` | 5 | 368 | E4 / W114 / I250 |
| `findings_cross_audit.md` | 48 | 368 | E4 / W114 / I250 |

**分析**：`qa_baseline.md` 在绿色基线（commit `5a77609`，已修复 4 个 ERROR）后更新，但子项求和：0+114+250=364，而 4+114+250=368。`test_plan.md` 和 `findings_cross_audit.md` 引用的是修复前数据。**需要统一**：建议 `qa_baseline.md` 明确标注"绿色基线后"状态，并说明 368→364 的变化原因。

### 4.2 次要文字 alpha 阈值差异

| 文件 | 阈值 | 说明 |
|------|------|------|
| `a11y_contrast_report.md:181` | α ≥ 0.55 | "不得低于 0.55 (0.52 即 AA 失败)" |
| `a11y_dark_mode_report.md:166` | α ≥ 0.62 | "alpha >= 0.62 为工程线" |

**评估**：不是矛盾——0.62 是更保守的工程线（含安全余量），0.55 是硬红线。但两份报告未交叉引用对方的阈值，建议在两处互相标注。

---

## 五、TODO/FIXME 标记汇总

| 文件 | 行号 | 内容 | 严重度 |
|------|------|------|--------|
| `release_pipeline.md` | 12 | "模板 TODO 未替换"（debug keystore） | **高** — 阻塞发布 |
| `build_config_audit.md` | 80 | "模板 TODO 未替换"（签名配置） | **高** — 阻塞发布 |
| `backlog_functional_gaps.md` | 79 | GAP-25 "AnimationController 驱动逻辑为 TODO" | 中 |
| `imagery_audit.md` | 55-56 | avatar_processor.dart TODO 未接线 | 中 |
| `component_spec.md` | 498 | `- [ ]` 黑色按钮示例 | 低 |
| `component_spec.md` | 499 | `- [ ]` 导航条阴影 | 低 |
| `reference_index.md` | 49, 155 | "锁屏 TODO"（两处提及） | 低 |
| `pressable_inventory.md` | 250-253 | 4 个回归测试待办 | 中 |

---

## 六、重复/重叠内容

| 文件组 | 重叠内容 | 评估 |
|--------|----------|------|
| `book_name_mapping_plan.md` + `book_display_review_notes.md` | 均涉及词书友好名映射 | 互补（一个自动脚本，一个人工校对），但缺少明确的权威性划分 |
| `qa_baseline.md` + `test_plan.md` | 均包含 analyze issue 计数 | 数值不一致（见第四节），需要统一 |

---

## 七、实施就绪度评估

### ✅ 实施就绪（31个文件）

以下文档具有完整的规格、代码示例、行号级定位和验收标准，可直接用于开发：

| 类别 | 文件 |
|------|------|
| **实施核心** | `batch1_tech_spec.md`、`execution_runbook.md`、`phonetic_data_cleanup_plan.md` |
| **组件规格** | `component_spec.md`（502行）、`motion_spec.md`（334行） |
| **无障碍** | `touch_target_audit.md`、`a11y_contrast_report.md`、`a11y_dark_mode_report.md`、`contrast_guard_spec.md` |
| **设计系统** | `dark_skin_strategy.md`、`font_strategy.md`、`design_system_onepager.md`、`starbucks_migration_plan.md` |
| **资产/品牌** | `assets_inventory.md`、`icon_plan.md`、`launcher_icon_brief.md`、`branding_assets_plan.md` |
| **审计/路线图** | `ui_inventory.md`、`live_route_map.md`、`live_pages_hardcode_map.md`、`pressable_inventory.md`、`ipa_coverage_full_audit.md` |
| **补丁蓝图** | `answer_feedback_patch_blueprint.md`、`learn_flow_motion_storyboard.md` |
| **基建** | `test_plan.md`、`build_config_audit.md`、`release_pipeline.md`、`qa_baseline.md` |
| **分析报告** | `content_audit.md`、`dictionary_license_review.md`、`findings_cross_audit.md`、`learn_flow_comparison.md`、`book_name_mapping_plan.md` |

### ⚠️ 需要补充（4个文件）

| 文件 | 问题 | 建议 |
|------|------|------|
| `vector_library_design.md` | 严重截断，仅28行概念描述 | 需补全实现细节，或标记为废弃 |
| `contrast_guard_spec.md` | 缺结论节和署名 | 补充总结段落 |
| `book_cover_design_spec.md` | 缺结论节 | 补充总结段落 |
| `book_display_review_notes.md` | 结尾偏弱 | 可接受，但建议加小结 |

### 📝 草案/归档（2个文件）

| 文件 | 说明 |
|------|------|
| `starbucks_tokens_draft.md` | 草案代码文件，非独立文档，依赖实施者理解上下文 |
| `DESIGN.apple-alpha.bak.md` | 归档备份，不参与当前实施 |

---

## 八、文档健康度评分

| 维度 | 得分 | 说明 |
|------|------|------|
| **完整性** | 88/100 | 36/41 文件完整，4个需补充，1个截断 |
| **引用一致性** | 90/100 | 核心文档引用全部有效，8处历史残留（非阻塞） |
| **数值一致性** | 80/100 | issue 计数存在矛盾，alpha 阈值需交叉引用 |
| **待办处理** | 75/100 | 2个 HIGH 待办阻塞发布，其余可追踪 |
| **实施就绪度** | 92/100 | 31/41 实施就绪，核心规格齐全 |
| **综合评分** | **85/100** | 整体健康，核心实施链完整，有少量需修补之处 |

---

## 九、优先补充建议

### P0 — 立即处理

1. **统一 issue 计数**：`qa_baseline.md` 明确标注"绿色基线后 E0/W114/I250 = 364"，`test_plan.md` 和 `findings_cross_audit.md` 补注"此为修复前数据"。
2. **处理 2 个 HIGH TODO**：`release_pipeline.md` 和 `build_config_audit.md` 中的 debug keystore 签名模板需在发布前替换。

### P1 — 本周内

3. **补全 `vector_library_design.md`**：要么补全实现细节，要么标记为废弃并从 `reference_index.md` 移除。
4. **补充截断文档的结论节**：`contrast_guard_spec.md` 和 `book_cover_design_spec.md` 各加一个总结段落。
5. **alpha 阈值交叉引用**：`a11y_contrast_report.md` 和 `a11y_dark_mode_report.md` 互相标注对方的阈值定义。

### P2 — 实施过程中

6. **清理历史引用**：`backlog_functional_gaps.md` 中 8 个已归档引用加注"已归档"。
7. **统一词书文档权威性**：明确 `book_name_mapping_plan.md`（脚本方案）与 `book_display_review_notes.md`（校对指引）的主从关系。
