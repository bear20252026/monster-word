# 硬编码颜色分类审计报告

审计日期：2026-08-24
审计人：Batch1Engineer
项目：Monster Word (word_app)

---

## 1. 概览

| 指标 | 数量 |
|------|------|
| 总硬编码颜色 | 169 处 |
| 涉及文件 | 30+ 个 |
| 可迁移 | ~120 处 |
| 可豁免 | ~49 处 |

---

## 2. 分类标准

### 2.1 可迁移（应改为 ThemeVars / skin.colors）

- 功能色：成功（绿）、警告（黄）、错误（红）、信息（蓝）
- 品牌色：强调色、主色调
- 中性色：文字色、背景色、分割线

### 2.2 可豁免（保留硬编码）

- 像素风/复古风：word_machine_page 使用 GameBoyPalette（已用 token）
- 阴影色：BoxShadow 的 rgba 黑色系（通用阴影，非品牌色）
- 场景插画色：壁纸/预览卡的装饰渐变
- 第三方品牌色：微信绿、QQ蓝、微博红

---

## 3. 详细分类清单

### 3.1 可迁移 - 高优先级（核心功能色）

| 文件 | 行号 | 当前值 | 建议替换为 | 说明 |
|------|------|--------|-----------|------|
| lib_select_page.dart | 288 | `#006241` | `skin.colors.accent` | Starbucks Green |
| collins_detail_intro_page.dart | 62,126,148,224 | `#E8913A` | `skin.colors.accent` | 橙色强调 |
| learn_page.dart | 103 | `#FFB300` | `skin.colors.accent` 或新建 gold token | 收藏金色 |
| class_activity_page.dart | 251,361 | `#4CAF50` | `skin.colors.success` | 成功绿 |
| class_activity_page.dart | 259,367 | `#2196F3` | 新建 `FuncColors.info` | 信息蓝 |
| class_activity_page.dart | 373 | `#FF9800` | 新建 `MistralColors.warning` | 警告橙 |
| class_activity_page.dart | 379 | `#9C27B0` | 新建 `FuncColors.purple` | 紫色 |
| class_checkin_page.dart | 284 | `#4CAF50` | `skin.colors.success` | 成功绿 |
| class_checkin_page.dart | 294 | `#2196F3` | `FuncColors.info` | 信息蓝 |
| class_checkin_page.dart | 308 | `#FF9800` | `MistralColors.warning` | 警告橙 |
| class_checkin_page.dart | 318 | `#9C27B0` | `FuncColors.purple` | 紫色 |

**小计：~20 处**

### 3.2 可迁移 - 中优先级（页面装饰色）

| 文件 | 行号 | 当前值 | 建议替换为 | 说明 |
|------|------|--------|-----------|------|
| courses_page.dart | 117-118 | `#9EC5E8`, `#E8C5B8` | 保留或新建课程 token | 渐变装饰 |
| courses_page.dart | 231-273 | 多色系 | `FuncColors.*` 或保留 | 课程卡片装饰 |
| exam_quick_review_page.dart | 73-76 | 浅色系 | `ThemeVars.quizCorrectBg` 等 | 测试背景 |
| my_content_page.dart | 多处 | 各色 | `FuncColors.*` | 内容页装饰 |
| class_checkin_page.dart | 896-898 | 金银铜 | `StarGold.*` 或保留 | 成就徽章 |

**小计：~50 处**

### 3.3 可迁移 - 低优先级（阴影/通用色）

| 文件 | 行号 | 当前值 | 建议替换为 | 说明 |
|------|------|--------|-----------|------|
| learn_page.dart | 329-330 | `#24000000`, `#3D000000` | 保留（标准阴影） | BoxShadow |
| 多个文件 | 多处 | `#000000` with alpha | 保留（通用阴影） | 阴影色 |

**小计：~30 处**

### 3.4 可豁免 - 像素风（word_machine_page）

| 说明 | 数量 |
|------|------|
| 使用 GameBoyPalette token | ~24 处 |
| 已规范化，无需迁移 | ✅ |

**小计：0 处（已用 token）**

### 3.5 可豁免 - 第三方品牌色

| 文件 | 行号 | 当前值 | 说明 |
|------|------|--------|------|
| account_info_page.dart | 175 | `#07C160` | 微信绿 |
| account_info_page.dart | 185 | `#12B7F5` | QQ蓝 |
| account_info_page.dart | 196 | `#E6162D` | 微博红 |

**小计：3 处**

### 3.6 可豁免 - 场景插画色

| 文件 | 行号 | 当前值 | 说明 |
|------|------|--------|------|
| appearance_page.dart | 102 | 天空渐变 | 场景预览卡 |
| splash_page.dart | 多处 | 启动页装饰 | 品牌展示 |

**小计：~10 处**

---

## 4. 按文件统计

| 文件 | 总数 | 可迁移 | 可豁免 | 优先级 |
|------|------|--------|--------|--------|
| my_content_page.dart | 16 | 16 | 0 | 中 |
| courses_page.dart | 12 | 12 | 0 | 中 |
| class_checkin_page.dart | 12 | 9 | 3 | 高 |
| word_dictionary_popup.dart | 11 | 11 | 0 | 高 |
| profile_screen.dart | 10 | 10 | 0 | 高 |
| collins_detail_intro_page.dart | 8 | 8 | 0 | 高 |
| learn_session.dart | 6 | 6 | 0 | 高 |
| splash_page.dart | 6 | 0 | 6 | 低 |
| lib_select_page.dart | 6 | 6 | 0 | 高 |
| class_activity_page.dart | 6 | 6 | 0 | 中 |
| 其他文件 | 76 | 36 | 40 | 混合 |

---

## 5. 迁移优先级建议

### 5.1 第一批（高优先级，核心学习流程）

| 页面 | 预计工时 | 说明 |
|------|----------|------|
| learn_session.dart | 15 min | 学习会话核心 |
| learn_page.dart | 10 min | 答题页面 |
| word_dictionary_popup.dart | 20 min | 词典弹窗 |
| profile_screen.dart | 25 min | 个人中心（重灾区） |
| collins_detail_intro_page.dart | 15 min | 词典详情 |

**小计：~85 min**

### 5.2 第二批（中优先级，辅助页面）

| 页面 | 预计工时 | 说明 |
|------|----------|------|
| class_checkin_page.dart | 20 min | 签到页 |
| class_activity_page.dart | 15 min | 活动页 |
| my_content_page.dart | 20 min | 内容页 |
| courses_page.dart | 20 min | 课程页 |

**小计：~75 min**

### 5.3 第三批（低优先级，装饰/阴影）

| 页面 | 预计工时 | 说明 |
|------|----------|------|
| 阴影色统一 | 30 min | BoxShadow 通用色 |
| 场景插画色 | 20 min | 壁纸/启动页 |

**小计：~50 min**

---

## 6. Token 缺口分析

当前 token 体系中缺失的颜色：

| 需求 | 建议 Token | 用途 |
|------|-----------|------|
| 信息蓝 | `FuncColors.info` (#2196F3) | 提示、链接 |
| 警告橙 | `MistralColors.warning` (#FF9800) | 警告状态 |
| 紫色 | `FuncColors.purple` (#9C27B0) | 特殊功能 |
| 成就金 | `StarGold.gold` (#FFD700) | 成就徽章 |
| 成就银 | `StarGold.silver` (#C0C0C0) | 成就徽章 |
| 成就铜 | `StarGold.bronze` (#CD7F32) | 成就徽章 |

**建议：** 在 `lib/tokens/` 下新建 `func_colors.dart` 和扩展 `star_gold.dart`

---

## 7. 结论

**整体评价：🟡 中等**

- 可迁移比例：~71%（120/169）
- 可豁免比例：~29%（49/169）
- 核心学习流程：基本已用 token，残留较少
- 辅助页面：硬编码较多，需优先清理

**建议行动：**
1. 立即：新建缺失 token（FuncColors.info/warning/purple）
2. 本周：完成第一批迁移（核心学习流程，85 min）
3. 下周：完成第二批迁移（辅助页面，75 min）
4. 后续：阴影/装饰色统一（50 min）

**总预计工时：~210 min（3.5h）**

---

*审计完成于 2026-08-24 · Batch1Engineer*
