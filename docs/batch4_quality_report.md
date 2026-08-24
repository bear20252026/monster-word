# Batch 4 页面改造质量验证报告

- 验证日期：2026-08-24
- 验证范围：Batch 4a/4b/4c 全部已改造页面
- 验证方法：dart analyze + 硬编码颜色扫描 + 新组件使用检查

---

## 一、dart analyze 结果

| 文件 | 结果 | 问题 |
|---|---|---|
| `lib/pages/appearance_page.dart` | ✅ 零问题 | — |
| `lib/pages/learn_page.dart` | ✅ 零问题 | — |
| `lib/pages/lib_select_page.dart` | ✅ 零问题 | — |
| `lib/pages/more_settings_page.dart` | ✅ 零问题 | — |
| `lib/pages/search_page.dart` | ✅ 零问题 | — |
| `lib/pages/word_detail_page.dart` | ✅ 零问题 | — |
| `lib/pages/word_machine_page.dart` | ⚠️ 4 warnings | 未用导入 ×4 |
| `lib/screens/home_screen.dart` | ✅ 零问题 | — |
| `lib/screens/profile_screen.dart` | ✅ 零问题 | — |

**总 ERROR 数：0**（满足 G1 门禁）

### word_machine_page.dart 遗留 warnings

| 行号 | 问题 | 建议 |
|---|---|---|
| 8 | 未用导入 `audioplayers` | 删除 |
| 12 | 未用导入 `example_parser` | 删除 |
| 16 | 未用导入 `skin_system` | 删除 |
| 17 | 未用导入 `design_tokens` | 删除 |

> 注：word_machine_page 为像素风豁免页面（batch4b spec §3.3），导入遗留不影响功能，但应清理以降低 G2 issue 计数。

---

## 二、硬编码颜色残留扫描

### 2.1 `Color(0x...)` 残留统计

| 文件 | 残留数 | 分类 |
|---|---|---|
| `appearance_page.dart` | 2 | 场景插画色（保留） |
| `learn_page.dart` | 3 | 收藏金色 + 阴影色 |
| `lib_select_page.dart` | 6 | 书封渐变色（品牌色直接引用） |
| `more_settings_page.dart` | 2 | 阴影色 |
| `search_page.dart` | 0 | ✅ |
| `word_detail_page.dart` | 0 | ✅ |
| `word_machine_page.dart` | 0 | ✅（像素风豁免） |
| `home_screen.dart` | 4 | 阴影色 |
| `profile_screen.dart` | 9 | 金色系 + 功能色 |
| **合计** | **26** | — |

### 2.2 逐项分析

#### ✅ 可豁免（14 处）

| 文件 | 色值 | 原因 |
|---|---|---|
| appearance_page.dart ×2 | `#87CEEB`, `#B0C4DE`, `#D6E6F2` | 场景插画色，spec 明确保留 |
| learn_page.dart ×2 | `#24000000`, `#3D000000` | SbCard 双层阴影，标准值 |
| more_settings_page.dart ×2 | `#24000000`, `#3D000000` | 同上 |
| home_screen.dart ×4 | `#23000000`, `#3D000000` | SbCard 双层阴影 |
| lib_select_page.dart ×6 | `#006241`, `#00754A`, `#1E3932` 等 | 品牌色直接引用（书封渐变），与 token 同值 |

#### ⚠️ 建议迁移（12 处）

| 文件 | 行号 | 当前值 | 建议替换 | 优先级 |
|---|---|---|---|---|
| learn_page.dart | 103 | `Color(0xFFFFB300)` | `MistralColors.sunshine500` 或 `MistralColors.warning` | P2 |
| profile_screen.dart | 14 | `Color(0xFFF2F0EB)` | `MistralColors.cream` | P2 |
| profile_screen.dart | 15 | `Color(0xFFCBA258)` | `MistralColors.beigeDeep` 或新建 gold token | P2 |
| profile_screen.dart | 16 | `Color(0xFFCC8800)` | 新建 `MistralColors.goldCoin` 或就近 token | P3 |
| profile_screen.dart | 148 | `Color(0xFF9C27B0)` | `FuncColors.purple`（需确认是否存在） | P2 |
| profile_screen.dart | 150 | `Color(0xFF2196F3)` | `FuncColors.info`（需确认是否存在） | P2 |
| profile_screen.dart | 253 | `Color(0xFFFFE0B2)` | 奶油金色系 token | P3 |
| profile_screen.dart | 255 | `Color(0xFFBBDEFB)` | 蓝色系 token | P3 |
| profile_screen.dart | 257 | `Color(0xFFE8F5E9)` | 绿色系 token | P3 |
| profile_screen.dart | 259 | `Color(0xFFF3E5F5)` | 紫色系 token | P3 |
| profile_screen.dart | 253 | `Color(0xFFCC8800)` | 金色 token | P3 |
| profile_screen.dart | 255 | `Color(0xFF1976D2)` | 蓝色 token | P3 |

---

## 三、新组件使用检查

### 3.1 组件使用矩阵

| 文件 | SbCard | SbButton | SbBanner | SbFab | SbBadge | SbDropdown | SbModal | SbProgress | SbSegmented | ScaleDownOnPress |
|---|---|---|---|---|---|---|---|---|---|---|
| appearance_page | — | — | — | — | — | — | — | — | — | — |
| learn_page | — | — | — | — | — | — | — | — | — | — |
| lib_select_page | — | — | — | — | — | — | — | — | — | — |
| more_settings_page | — | — | — | — | — | — | — | — | — | — |
| search_page | — | — | — | — | — | — | — | — | — | 4 |
| word_detail_page | — | — | — | — | — | — | — | — | — | — |
| word_machine_page | — | — | — | — | — | — | — | — | — | — |
| home_screen | ✅ | ✅ | — | ✅ | ✅ | — | ✅ | — | — | ✅ |
| profile_screen | — | ✅ | — | — | ✅ | — | — | — | — | ✅ |

### 3.2 分析

**高采用率页面**：
- `home_screen`（10 处引用）：SbCard、SbButton、SbFab、SbBadge、SbModal、ScaleDownOnPress — 全面接入 ✅
- `profile_screen`（6 处引用）：SbButton、SbBadge、ScaleDownOnPress — 部分接入
- `search_page`（4 处引用）：ScaleDownOnPress — 按压反馈已统一

**低采用率页面**：
- `appearance_page`：未使用新组件（当前用 Container + BoxDecoration 实现卡片，可后续迁移至 SbCard）
- `learn_page`：未使用新组件（学习页有特殊布局需求，Container 直接实现合理）
- `lib_select_page`：未使用新组件（书封网格布局特殊）
- `more_settings_page`：未使用新组件（spec 要求 SbDropdown 但未接入）
- `word_detail_page`：未使用新组件

### 3.3 建议

| 优先级 | 页面 | 建议 |
|---|---|---|
| P1 | more_settings_page | 接入 SbDropdown（spec 要求）和 SbModal/sbShowSheet |
| P2 | appearance_page | 主题预览卡迁移至 SbCard |
| P3 | learn_page, lib_select_page | 评估是否适合迁移（特殊布局可能不适合） |

---

## 四、动效 token 检查

Batch 4 spec 要求动效统一使用 `MotionDurations` / `MotionCurves` token。

| 文件 | 动效 token 使用 | 状态 |
|---|---|---|
| appearance_page.dart | 无动效（静态页面） | N/A |
| home_screen.dart | 待检查 | — |
| search_page.dart | ScaleDownOnPress 内置动效 | ✅ |
| 其他页面 | 待检查 | — |

> 注：动效 token 的全面检查需要深入阅读每个动画实现，建议在 Batch 5 动效收敛阶段统一验证。

---

## 五、门禁对照

| 门禁 | 要求 | 当前值 | 状态 |
|---|---|---|---|
| G1 | analyze ERROR = 0 | **0** | ✅ |
| G2 | 总 issue ≤ 368 且不回升 | **4 warnings**（word_machine 遗留） | ✅ 不影响基线 |
| G3 | flutter test 全过 | 待单独验证 | — |
| G4 | build windows --debug 成功 | 待单独验证 | — |

---

## 六、总结

### ✅ 达标项

1. **零 ERROR**：全部 9 个 Batch 4 页面 dart analyze 无错误
2. **硬编码清理**：appearance_page（13→2）、more_settings_page（9→2）、search_page（0）、word_detail_page（0）等核心页面已基本清理完毕
3. **新组件接入**：home_screen 全面接入 6 种新组件，profile_screen 接入 3 种
4. **阴影标准化**：多处阴影色已统一为 SbCard 标准双层阴影值

### ⚠️ 待改进

1. **word_machine_page**：4 个未用导入需清理（P2）
2. **profile_screen**：9 处硬编码颜色残留（金色系 + 功能色），需新建 token 或引用已有 token（P2）
3. **more_settings_page**：未接入 SbDropdown / sbShowSheet（spec 要求）（P1）
4. **appearance_page**：未使用 SbCard 组件（P2）
5. **learn_page / lib_select_page**：3+6 处硬编码残留（P3）

### 下一步建议

1. 清理 word_machine_page 未用导入（5 min）
2. 为 profile_screen 的功能色（紫/蓝）确认 FuncColors token 是否存在，不存在则新建（15 min）
3. more_settings_page 接入 SbDropdown + sbShowSheet（30 min）
4. 评估 learn_page / lib_select_page 迁移至 SbCard 的可行性
