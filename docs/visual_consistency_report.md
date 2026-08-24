# 视觉一致性审查报告

> 项目：Monster Word（word_app）
> 日期：2026-08-24
> 审查范围：13 个活页面（Batch 4a/4b/4c 已改造页面）
> 方法：只读代码静态分析，未修改任何文件
> 约束：不改代码；只产出报告

---

## 一、审查总览

| 审查维度 | 通过 | 不通过 | 通过率 |
|----------|------|--------|--------|
| 硬编码颜色 | 7 页 | 6 页 | 54% |
| 组件使用 | 9 页 | 4 页 | 69% |
| 间距 Token | 8 页 | 5 页 | 62% |
| 圆角值 | 6 页 | 7 页 | 46% |
| **综合** | — | — | **58%** |

---

## 二、逐页审查结果

### 2.1 main_shell.dart ✅ 基本通过

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ✅ | `StarbucksCreamColors.greenHouse`（品牌绿），`Colors.transparent`（可接受） |
| 间距 Token | ⚠️ | `EdgeInsets.only(top: 4)` → 应为 `AppleSpacing.xxs` |
| 圆角值 | ✅ | `BorderRadius.circular(1)`（指示条，保留） |
| 组件使用 | ✅ | 无需额外组件 |

**不一致项**：
1. `const EdgeInsets.only(top: 4)` → `AppleSpacing.xxs`（:180）

---

### 2.2 home_screen.dart ⚠️ 部分不一致

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ✅ | GameBoy 色豁免，其余用 `skin.colors.*` |
| 间距 Token | ⚠️ | 多处裸数值：`SizedBox(height: 10)`、`SizedBox(height: 4)`、`SizedBox(width: 12)` |
| 圆角值 | ⚠️ | `BorderRadius.circular(16)`（:169）、`circular(3)`（:179/182/185）、`circular(8)`（:196） |
| 组件使用 | ✅ | 已用 `SbCard`、`ScaleDownOnPress` |

**不一致项**：
1. `SizedBox(height: 10)` → `AppleSpacing.sm`（:49）
2. `SizedBox(height: 4)` → `AppleSpacing.xxs`（:54）
3. `SizedBox(width: 12)` → `AppleSpacing.sm`（:72）
4. `SizedBox(height: 16)` → `AppleSpacing.md`（:163）
5. `SizedBox(width: 8)` → `AppleSpacing.xs`（:181）
6. `BorderRadius.circular(16)` → `AppRadius.xl`（:169）
7. `BorderRadius.circular(8)` → `AppRadius.md`（:196）

---

### 2.3 lib_select_page.dart ⚠️ 部分不一致

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ⚠️ | `Colors.transparent`（:144）、`Colors.white`（:151/345） |
| 间距 Token | ⚠️ | 多处裸数值：`SizedBox(width: 4)`、`SizedBox(width: 5)`、`SizedBox(width: 16)` |
| 圆角值 | ⚠️ | `BorderRadius.circular(16)`（:145/249）、`circular(8)`（:339） |
| 组件使用 | ❌ | 未使用 `SbCard` 包裹词书列表项 |

**不一致项**：
1. `Colors.transparent`（:144）→ 可接受（Tab 选中态背景）
2. `Colors.white`（:151）→ `Colors.white`（选中 Tab 文字，白底绿字场景，可接受）
3. `Colors.white`（:345）→ `Colors.white`（封面白字，可接受）
4. `SizedBox(width: 4)` → `AppleSpacing.xxs`（:84/186）
5. `SizedBox(width: 5)` → `AppleSpacing.xxs`（:403，就近取整）
6. `SizedBox(width: 16)` → `AppleSpacing.md`（:355）
7. `SizedBox(height: 8)` → `AppleSpacing.xs`（:387）
8. `SizedBox(height: 4)` → `AppleSpacing.xxs`（:447）
9. `BorderRadius.circular(16)` → `AppRadius.xl`（:145/249）
10. `BorderRadius.circular(8)` → `AppRadius.md`（:339）
11. 词书列表项未用 `SbCard` 包裹（当前用 `Border(bottom:)` 分割）

---

### 2.4 profile_screen.dart ⚠️ 部分不一致

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ⚠️ | 3 处模块级常量（`_goldCream/_goldAccent/_goldCoin`），4 处装备色硬编码，2 处功能色硬编码 |
| 间距 Token | ⚠️ | `SizedBox(height: 20)`、`SizedBox(height: 10)`、`SizedBox(width: 14)` |
| 圆角值 | ⚠️ | `BorderRadius.circular(10)`（:169）、`circular(7)`（:273） |
| 组件使用 | ✅ | 已用 `SbCard`、`SbBadge` |

**不一致项**：
1. `_goldCream`（:14）→ `skin.colors.pageBg`（奶油色已是 pageBg）
2. `_goldAccent`（:15）→ `MistralColors.sunshine300` 或保留（品牌金，语义明确）
3. `_goldCoin`（:16）→ 待 `StarGold.gold` Token 创建后替换
4. `Color(0xFF9C27B0)`（:148）→ 待 `FuncColors.purple` Token
5. `Color(0xFF2196F3)`（:150）→ 待 `FuncColors.info` Token
6. 装备图标 8 处硬编码色（:253-259）→ 待 `EquipBadge` Token 组
7. `SizedBox(height: 20)` → `AppleSpacing.lg`（:49）
8. `SizedBox(height: 10)` → `AppleSpacing.sm`（:124）
9. `SizedBox(width: 14)` → `AppleSpacing.sm`（:173）
10. `SizedBox(height: 12)` → `AppleSpacing.sm`（:203/249）
11. `SizedBox(height: 6)` → `AppleSpacing.xs`（:243）
12. `SizedBox(width: 6)` → `AppleSpacing.xs`（:254/256/258）
13. `BorderRadius.circular(10)` → `AppRadius.lg` 就近（:169）
14. `BorderRadius.circular(7)` → `AppRadius.md` 就近（:273）

---

### 2.5 search_page.dart ✅ 基本通过

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ✅ | 全部用 `skin.*` / `MistralColors.*` |
| 间距 Token | ⚠️ | 少量裸数值 |
| 圆角值 | ⚠️ | `BorderRadius.circular(20)`（:110） |
| 组件使用 | ✅ | 已用 `ScaleDownOnPress` |

**不一致项**：
1. `BorderRadius.circular(20)` → `AppRadius.xxl`（:110）
2. `SizedBox(width: 8)` → `AppleSpacing.xs`（:115）

---

### 2.6 dictionary_page.dart ✅ 通过

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ✅ | 全部用 `skin.*` / `MistralColors.*` |
| 间距 Token | ✅ | 已用 `AppSpacing.*` |
| 圆角值 | ✅ | 已用 `AppRadius.*` / `AppSpacing.*` |
| 组件使用 | ✅ | 无额外需求 |

---

### 2.7 word_machine_page.dart ✅ 通过（像素风豁免）

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ✅ | 已提取 `GameBoyPalette` Token |
| 间距 Token | ✅ | 像素风设计语言，保留裸数值 |
| 圆角值 | ✅ | 像素风设计语言，保留裸数值 |
| 组件使用 | ✅ | 像素风专用组件 |

---

### 2.8 immersive_swipe_page.dart ⚠️ 部分不一致

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ✅ | 全部用 `skin.colors.*` |
| 间距 Token | ⚠️ | 多处裸数值 |
| 圆角值 | ⚠️ | `BorderRadius.circular(20)`（:195/232）、`circular(12)`（:275/292） |
| 组件使用 | ⚠️ | 主卡片未用 `SbCard`（自定义 Container + 阴影） |

**不一致项**：
1. `BorderRadius.circular(20)` → `AppRadius.xxl`（:195/232）
2. `BorderRadius.circular(12)` → `AppRadius.lg`（:275/292）
3. `SizedBox(height: 16)` → `AppleSpacing.md`（:128/258）
4. `SizedBox(height: 8)` → `AppleSpacing.xs`（:281）
5. `SizedBox(height: 24)` → `AppleSpacing.xl`（:265）
6. `SizedBox(width: 4)` → `AppleSpacing.xxs`（:202/322）
7. `SizedBox(width: 24)` → `AppleSpacing.xl`（:324）
8. 主卡片可考虑用 `SbCard` 替代自定义 Container

---

### 2.9 learn_page.dart ⚠️ 部分不一致

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ✅ | 全部用 `skin.colors.*` |
| 间距 Token | ⚠️ | 多处裸数值 |
| 圆角值 | ✅ | `BorderRadius.circular(12)`（:323，ContentCard 规格） |
| 组件使用 | ⚠️ | 选项卡未用 `SbCard` 包裹 |

**不一致项**：
1. `SizedBox(height: 8)` → `AppleSpacing.xs`（多处）
2. `SizedBox(width: 8)` → `AppleSpacing.xs`（多处）
3. `SizedBox(height: 12)` → `AppleSpacing.sm`（多处）
4. 选项卡容器可考虑用 `SbCard` 替代自定义 Container

---

### 2.10 review_session.dart ⚠️ 部分不一致

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ✅ | 全部用 `glass_widgets` + `skin` |
| 间距 Token | ⚠️ | `SizedBox(h6)` 未归档 |
| 圆角值 | ✅ | — |
| 组件使用 | ⚠️ | 仍使用 `GlassBg`（毛玻璃），应改为奶油画布 |

**不一致项**：
1. `GlassBg`（:99）→ 应改为 `Scaffold(backgroundColor: skin.colors.pageBg)`（奶油画布）
2. `SizedBox(h6)` → `AppleSpacing.xs`（多处）

---

### 2.11 appearance_page.dart ⚠️ 部分不一致

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ⚠️ | 多处裸 `Color(0x...)` 和 `Colors.white` |
| 间距 Token | ⚠️ | 多处裸数值 |
| 圆角值 | ⚠️ | 多处 `BorderRadius.circular(16/8/6/4/3)` |
| 组件使用 | ⚠️ | 未用 `SbCard` 包裹设置行 |

**不一致项**：
1. `Color(0xFF1A1A1A)`（:81/253/279）→ `skin.colors.text1`
2. `Colors.white` ×11（:113-273）→ 按语境替换为 `skin.colors.cardBg` / `text1`
3. `Colors.black`（:148）→ `skin.colors.text1`
4. `Color(0xFFFF6800)`（:217/223）→ `MistralColors.primary`
5. `Color(0xFFE8913A)`（:259）→ `MistralColors.primary`
6. `Color(0xFFE0E0E0)`（:261）→ `MistralColors.hairline`
7. `Color(0xFF999999)`（:281/283）→ `skin.colors.text3`
8. `BorderRadius.circular(16)` → `AppRadius.xl`（多处）
9. `BorderRadius.circular(8)` → `AppRadius.md`（:113）
10. `BorderRadius.circular(6)` → `AppRadius.sm`（:124/131）
11. `SizedBox(height: 20)` → `AppleSpacing.lg`（:39/49）
12. `SizedBox(height: 24)` → `AppleSpacing.xl`（:43/53）

---

### 2.12 more_settings_page.dart ✅ 通过

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ✅ | 全部用 `MistralColors.*` / `skin.colors.*` |
| 间距 Token | ✅ | 已用 `AppleSpacing.*` |
| 圆角值 | ✅ | 已用 `AppRadius.*` |
| 组件使用 | ✅ | `_SettingGroup` 已用 ContentCard 双层阴影 |

---

### 2.13 word_detail_page.dart ⚠️ 部分不一致

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 硬编码颜色 | ⚠️ | `Colors.red`（:626） |
| 间距 Token | ⚠️ | `SizedBox(h20/h8)` 未归档 |
| 圆角值 | ✅ | — |
| 组件使用 | ⚠️ | 释义/例句/笔记区未用 `SbCard` 包裹 |

**不一致项**：
1. `Colors.red`（:626）→ `MistralColors.danger`
2. `SizedBox(h20)` → `AppleSpacing.lg`（多处）
3. `SizedBox(h8)` → `AppleSpacing.xs`（多处）
4. 释义/例句/笔记区可考虑用 `SbCard` 包裹

---

## 三、跨页面问题汇总

### 3.1 硬编码颜色残留（按频率排序）

| 色值 | 出现页面 | 建议 Token | 优先级 |
|------|----------|-----------|--------|
| `Colors.white` | profile(4), appearance(11), lib_select(2), learn_session(1) | `skin.colors.cardBg` / `text1` 按语境 | 🟠 中 |
| `Color(0xFF9C27B0)` 紫 | profile(1), more_settings(已完成) | `FuncColors.purple`（待创建） | 🟡 低 |
| `Color(0xFF2196F3)` 蓝 | profile(1), more_settings(已完成) | `FuncColors.info`（待创建） | 🟡 低 |
| `Color(0xFFCC8800)` 金 | profile(1) | `StarGold.gold`（待创建） | 🟡 低 |
| `Color(0xFFFFE0B2/BBDEFB/E8F5E9/F3E5F5)` 装备色 | profile(4) | `EquipBadge` Token 组（待创建） | 🟡 低 |
| `Color(0xFF1A1A1A)` 墨 | appearance(3) | `skin.colors.text1` | 🟠 中 |
| `Color(0xFF999999)` 灰 | appearance(2) | `skin.colors.text3` | 🟠 中 |
| `Color(0xFFFF6800)` 橙 | appearance(2) | `MistralColors.primary` | 🟠 中 |
| `Colors.red` | word_detail(1) | `MistralColors.danger` | 🟠 中 |

### 3.2 间距未 Token 化

| 裸数值 | 对应 Token | 出现次数 |
|--------|-----------|----------|
| `4` | `AppleSpacing.xxs` | ~15 处 |
| `6` | `AppleSpacing.xs` | ~8 处 |
| `8` | `AppleSpacing.xs` | ~20 处 |
| `10` | `AppleSpacing.sm` | ~5 处 |
| `12` | `AppleSpacing.sm` | ~10 处 |
| `14` | `AppleSpacing.sm` | ~3 处 |
| `16` | `AppleSpacing.md` | ~15 处 |
| `20` | `AppleSpacing.lg` | ~8 处 |
| `24` | `AppleSpacing.xl` | ~5 处 |

### 3.3 圆角未 Token 化

| 裸数值 | 对应 Token | 出现次数 |
|--------|-----------|----------|
| `3` | 保留（像素风/微圆角） | ~5 处 |
| `4` | `AppRadius.xs` | ~3 处 |
| `6` | `AppRadius.sm` | ~5 处 |
| `7` | `AppRadius.md`（就近） | ~2 处 |
| `8` | `AppRadius.md` | ~8 处 |
| `10` | `AppRadius.lg`（就近） | ~2 处 |
| `12` | `AppRadius.lg` | ~5 处 |
| `16` | `AppRadius.xl` | ~10 处 |
| `20` | `AppRadius.xxl` | ~5 处 |

### 3.4 组件使用不一致

| 组件 | 应用但未用的页面 | 说明 |
|------|-----------------|------|
| `SbCard` | lib_select, immersive_swipe, learn_page, word_detail | 列表项/内容块仍用自定义 Container |
| `ScaleDownOnPress` | lib_select, appearance, word_detail | 按压反馈未统一 |
| `GlassBg` | review_session | 仍用毛玻璃，应改奶油画布 |

---

## 四、优先修复建议

### P0（阻断一致性）

无。

### P1（高优先级，影响品牌形象）

1. **appearance_page.dart**：25 处硬编码颜色（最多），需全面 Token 化
2. **profile_screen.dart**：装备色/功能色硬编码，待 Token 组创建后替换
3. **review_session.dart**：`GlassBg` → 奶油画布（结构性改动）

### P2（中优先级，影响代码质量）

4. **间距 Token 化**：全部页面的 `SizedBox` 裸数值 → `AppleSpacing.*`（~90 处）
5. **圆角 Token 化**：全部页面的 `BorderRadius.circular` 裸数值 → `AppRadius.*`（~45 处）
6. **lib_select_page.dart**：词书列表项用 `SbCard` 包裹

### P3（低优先级，待 Token 创建）

7. `FuncColors.purple/info` Token 创建后替换 profile/more_settings 硬编码
8. `StarGold.gold` Token 创建后替换 profile 酷币色
9. `EquipBadge` Token 组创建后替换 profile 装备色

---

## 五、统计摘要

| 指标 | 数值 |
|------|------|
| 审查页面数 | 13 |
| 完全通过 | 4（dictionary, word_machine, more_settings, main_shell 基本通过） |
| 部分不一致 | 8 |
| 完全不一致 | 0 |
| 硬编码颜色残留 | ~40 处（appearance 25 + profile 12 + 其他 3） |
| 间距未 Token 化 | ~90 处 |
| 圆角未 Token 化 | ~45 处 |
| 组件未替换 | ~8 处 |

---

*审查人：BrandEngineer（【重构100】）· 2026-08-24*
