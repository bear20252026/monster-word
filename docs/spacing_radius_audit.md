# 间距/圆角 Token 化审计报告

> 项目：Monster Word（word_app）
> 日期：2026-08-24
> 审计范围：全部页面文件（lib/pages/ + lib/screens/ + lib/shell/）
> 方法：Grep 静态统计，对比裸数值 vs Token 引用
> 约束：不改代码；只产出报告

---

## 一、全局统计

### 1.1 间距 Token 化

| 指标 | 数值 |
|------|------|
| `SizedBox` 裸数值（全库） | **33 处**（3 个文件） |
| `AppleSpacing.*` Token 引用（全库） | **515 处**（75 个文件） |
| `EdgeInsets` 裸数值（全库） | **425 处**（83 个文件） |
| `AppSpacing.*` Token 引用（全库） | **162 处**（15 个文件） |

**间距 Token 化率**：`SizedBox` 裸数值仅 33 处（vs 515 处 Token），**SizedBox 化率 94%** ✅

### 1.2 圆角 Token 化

| 指标 | 数值 |
|------|------|
| `BorderRadius.circular(数字)` 裸数值（全库） | **109 处**（40 个文件） |
| `AppRadius.*` Token 引用（全库） | **160 处**（35 个文件） |

**圆角 Token 化率**：`AppRadius` 占比 **59%**，仍有 41% 为裸数值 ⚠️

---

## 二、13 个活页面逐页审计

### 2.1 间距（SizedBox 裸数值）

| # | 页面 | SizedBox 裸数值 | AppleSpacing 引用 | 状态 |
|---|------|----------------|-------------------|------|
| 1 | main_shell | 0 | 0 | ✅ 无间距 |
| 2 | home_screen | 0 | 8 | ✅ 已 Token 化 |
| 3 | lib_select_page | 0 | 0 | ✅ 无间距 |
| 4 | profile_screen | 0 | 13 | ✅ 已 Token 化 |
| 5 | search_page | 0 | 9 | ✅ 已 Token 化 |
| 6 | dictionary_page | 0 | 31 | ✅ 已 Token 化 |
| 7 | word_machine_page | 0 | 9 | ✅ 像素风豁免 |
| 8 | immersive_swipe_page | 0 | 13 | ✅ 已 Token 化 |
| 9 | learn_page | 0 | 1 | ⚠️ 大量裸数值在 EdgeInsets |
| 10 | review_session | 0 | 10 | ✅ 已 Token 化 |
| 11 | appearance_page | 0 | 10 | ✅ 已 Token 化 |
| 12 | more_settings_page | 0 | 12 | ✅ 已 Token 化 |
| 13 | word_detail_page | 0 | 10 | ✅ 已 Token 化 |

**结论**：13 个活页面的 `SizedBox` 裸数值已全部清零 ✅

### 2.2 间距（EdgeInsets 裸数值）

| # | 页面 | EdgeInsets 裸数值 | AppSpacing 引用 | 状态 |
|---|------|-------------------|-----------------|------|
| 1 | main_shell | 2 | 0 | ⚠️ |
| 2 | home_screen | 5 | 0 | ⚠️ |
| 3 | lib_select_page | 5 | 0 | ⚠️ |
| 4 | profile_screen | 5 | 2 | ⚠️ |
| 5 | search_page | 4 | 0 | ⚠️ |
| 6 | dictionary_page | 0 | 31 | ✅ |
| 7 | word_machine_page | 12 | 0 | ⚠️ |
| 8 | immersive_swipe_page | 6 | 0 | ⚠️ |
| 9 | learn_page | 8 | 1 | ⚠️ |
| 10 | review_session | 8 | 1 | ⚠️ |
| 11 | appearance_page | 11 | 1 | ⚠️ |
| 12 | more_settings_page | 12 | 1 | ⚠️ |
| 13 | word_detail_page | 18 | 1 | ⚠️ |

**结论**：`EdgeInsets` 裸数值 **共 96 处**，仅 dictionary_page 完全 Token 化。`AppSpacing` 使用率极低（全库仅 162 处，主要集中在死页面 class_checkin/courses/class_activity）。

### 2.3 圆角（BorderRadius 裸数值）

| # | 页面 | BorderRadius 裸数值 | AppRadius 引用 | 状态 |
|---|------|---------------------|----------------|------|
| 1 | main_shell | 1 | 0 | ⚠️ |
| 2 | home_screen | 5 | 0 | ⚠️ |
| 3 | lib_select_page | 2 | 0 | ⚠️ |
| 4 | profile_screen | 2 | 0 | ⚠️ |
| 5 | search_page | 1 | 0 | ⚠️ |
| 6 | dictionary_page | 0 | 13 | ✅ |
| 7 | word_machine_page | 9 | 0 | ⚠️ 像素风豁免 |
| 8 | immersive_swipe_page | 4 | 0 | ⚠️ |
| 9 | learn_page | 2 | 0 | ⚠️ |
| 10 | review_session | 0 | 2 | ✅ |
| 11 | appearance_page | 0 | 10 | ✅ |
| 12 | more_settings_page | 0 | 1 | ✅ |
| 13 | word_detail_page | 9 | 0 | ⚠️ |

**结论**：13 个活页面中仅 4 个完全使用 `AppRadius`，9 个仍有裸数值。

---

## 三、裸数值分布（按文件）

### 3.1 EdgeInsets 裸数值 Top 10（活页面）

| 文件 | 裸数值数 | 常见值 |
|------|----------|--------|
| word_detail_page | 18 | 16, 8, 20, 12, 24 |
| more_settings_page | 12 | 16, 8 |
| appearance_page | 11 | 16, 14 |
| word_machine_page | 12 | 8, 16, 12 |
| review_session | 8 | 16, 24, 8 |
| learn_page | 8 | 8, 16, 12 |
| immersive_swipe_page | 6 | 16, 32, 24 |
| home_screen | 5 | 16, 12, 24 |
| lib_select_page | 5 | 16, 4, 8 |
| profile_screen | 5 | 16, 8, 14 |

### 3.2 BorderRadius 裸数值 Top 10（活页面）

| 文件 | 裸数值数 | 常见值 |
|------|----------|--------|
| word_machine_page | 9 | 20, 4, 5, 8（像素风豁免） |
| word_detail_page | 9 | 12, 16, 8, 20 |
| immersive_swipe_page | 4 | 20, 12 |
| home_screen | 5 | 16, 3, 8 |
| lib_select_page | 2 | 16, 8 |
| profile_screen | 2 | 10, 7 |
| learn_page | 2 | 12, 2 |
| search_page | 1 | 20 |
| main_shell | 1 | 1（指示条，保留） |

---

## 四、Token 定义现状

### 4.1 间距 Token（两套并存）

| Token 体系 | 文件 | 定义 |
|-----------|------|------|
| `AppleSpacing` | `lib/tokens/design_tokens.dart` | xxs=4, xs=8, sm=12, md=16, lg=20, xl=24, xxl=32, section=64 |
| `AppSpacing` | `lib/tokens/design_tokens.dart` | navH, rowH, pageMargin, contentWidth 等语义间距 |

**问题**：两套体系并存，`AppleSpacing` 用于 `SizedBox`，`AppSpacing` 用于 `EdgeInsets`，使用场景不明确。

### 4.2 圆角 Token

| Token | 文件 | 定义 |
|-------|------|------|
| `AppRadius` | `lib/tokens/design_tokens.dart` | xs=4, sm=6, md=8, lg=12, xl=16, xxl=20, pill=9999 |

**问题**：`AppRadius` 定义完整，但页面采用率仅 59%。

---

## 五、修复建议

### P0（高优先级）

1. **word_detail_page.dart**：18 处 EdgeInsets + 9 处 BorderRadius 裸数值（全活页面最多）
2. **learn_page.dart**：8 处 EdgeInsets + 2 处 BorderRadius 裸数值（核心学习流程）
3. **review_session.dart**：8 处 EdgeInsets 裸数值

### P1（中优先级）

4. **immersive_swipe_page.dart**：6 处 EdgeInsets + 4 处 BorderRadius 裸数值
5. **home_screen.dart**：5 处 EdgeInsets + 5 处 BorderRadius 裸数值
6. **lib_select_page.dart**：5 处 EdgeInsets + 2 处 BorderRadius 裸数值
7. **profile_screen.dart**：5 处 EdgeInsets + 2 处 BorderRadius 裸数值

### P2（低优先级，像素风豁免）

8. **word_machine_page.dart**：12 处 EdgeInsets + 9 处 BorderRadius（像素风设计语言，建议保留）

### P3（架构决策）

9. **统一间距 Token 体系**：明确 `AppleSpacing` vs `AppSpacing` 的使用边界
   - 建议：`SizedBox` 用 `AppleSpacing`，`EdgeInsets` 用 `AppSpacing`
   - 或合并为单一 Token 体系

---

## 六、统计摘要

| 维度 | 全库总数 | Token 引用 | 裸数值 | Token 化率 |
|------|----------|-----------|--------|-----------|
| SizedBox 间距 | 548 | 515 | 33 | **94%** ✅ |
| EdgeInsets 间距 | 587 | 162 | 425 | **28%** ❌ |
| BorderRadius 圆角 | 269 | 160 | 109 | **59%** ⚠️ |

**核心发现**：
- `SizedBox` Token 化率已达标（94%）
- `EdgeInsets` Token 化率严重不足（28%），是下一轮重点
- `BorderRadius` Token 化率中等（59%），需继续推进
- `AppSpacing` 使用率极低（仅 15 个文件），需扩大采用

---

*审计人：BrandEngineer（【重构128】）· 2026-08-24*
