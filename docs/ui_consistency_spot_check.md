# UI 一致性抽检报告

抽检日期：2026-08-24
抽检人：Batch1Engineer
项目：Monster Word (word_app)

---

## 1. 抽检范围

| 页面 | 文件 | 类型 |
|------|------|------|
| 学习页 | learn_page.dart | 核心页面 |
| 个人中心 | profile_screen.dart | Tab 页面 |
| 设置页 | settings_page.dart | 二级页面 |
| 单词详情 | word_detail_page.dart | 三级页面 |
| 复习页 | review_page.dart | 核心页面 |

---

## 2. 检查维度

| 维度 | 说明 |
|------|------|
| 颜色引用 | 是否使用 `context.skin.colors` 获取颜色（而非硬编码） |
| 按钮组件 | 是否使用 SbButton/PillButton（50px 胶囊） |
| 卡片组件 | 是否使用 SbCard/ContentCard（12px 圆角） |
| 按压反馈 | 是否有 ScaleDownOnPress 包装 |
| 字体大小 | 标题 ≥20sp，正文 ≥14sp |

---

## 3. 逐页检查结果

### 3.1 learn_page.dart（学习页）

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 颜色引用 | ✅ 良好 | `skin.colors` 引用 6 处，硬编码仅 3 处（阴影色） |
| 按钮组件 | ❌ 未使用 | 使用原生 `ElevatedButton`，未用 PillButton |
| 卡片组件 | ✅ 已使用 | ContentCard 引用 2 处 |
| 按压反馈 | ❌ 未使用 | 无 ScaleDownOnPress |
| 字体大小 | ✅ 合理 | 标题 40sp，正文 16sp，辅助 13-14sp |

**问题：**
- 按钮未使用 PillButton 组件
- 缺少 ScaleDownOnPress 按压反馈

---

### 3.2 profile_screen.dart（个人中心）

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 颜色引用 | ⚠️ 一般 | `skin.colors` 引用 15 处，硬编码 17 处（较多） |
| 按钮组件 | ❌ 未使用 | 使用原生按钮 |
| 卡片组件 | ✅ 已使用 | ContentCard 引用 4 处 |
| 按压反馈 | ❌ 未使用 | 无 ScaleDownOnPress |
| 字体大小 | ⚠️ 偏小 | 最小 9sp（徽章文字），建议 ≥12sp |

**问题：**
- 硬编码颜色较多（17处）
- 徽章文字 9sp 过小，影响可读性
- 按钮/按压反馈未规范化

---

### 3.3 settings_page.dart（设置页）

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 颜色引用 | ⚠️ 一般 | `skin.colors` 引用 11 处，硬编码 10 处 |
| 按钮组件 | ❌ 未使用 | 使用原生按钮 |
| 卡片组件 | ❌ 未使用 | 无 ContentCard |
| 按压反馈 | ❌ 未使用 | 无 ScaleDownOnPress |
| 字体大小 | ✅ 合理 | 标题 18sp，正文 14-16sp，辅助 12-13sp |

**问题：**
- 未使用任何星巴克组件（PillButton、ContentCard）
- 硬编码颜色 10 处需迁移

---

### 3.4 word_detail_page.dart（单词详情）

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 颜色引用 | ✅ 优秀 | `skin.colors` 引用 43 处，硬编码 9 处（已标注） |
| 按钮组件 | ⚠️ 部分 | 使用 `FilledButton`，未用 PillButton |
| 卡片组件 | ❌ 未使用 | 使用自定义 Container |
| 按压反馈 | ❌ 未使用 | 无 ScaleDownOnPress |
| 字体大小 | ✅ 合理 | 标题 40sp，正文 16sp，辅助 13-14sp |

**问题：**
- 按钮未使用 PillButton
- 卡片未使用 ContentCard（自定义 Container）

---

### 3.5 review_page.dart（复习页）

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 颜色引用 | ✅ 优秀 | 无硬编码颜色，全部使用 `skin.xxx` |
| 按钮组件 | ❌ 未使用 | 使用原生按钮 |
| 卡片组件 | ❌ 未使用 | 使用 glass_widgets（旧系统） |
| 按压反馈 | ❌ 未使用 | 无 ScaleDownOnPress |
| 字体大小 | ✅ 合理 | 标题 42sp，正文 14-16sp，辅助 12-15sp |

**问题：**
- 按钮未使用 PillButton
- 卡片使用旧 glass_widgets，未迁移到 ContentCard

---

## 4. 统计汇总

| 检查项 | 通过 | 部分 | 未通过 | 通过率 |
|--------|------|------|--------|--------|
| 颜色引用 | 3 | 2 | 0 | 60% |
| 按钮组件 | 0 | 1 | 4 | 0% |
| 卡片组件 | 2 | 0 | 3 | 40% |
| 按压反馈 | 0 | 0 | 5 | 0% |
| 字体大小 | 5 | 0 | 0 | 100% |

**整体通过率：32%（16/50）**

---

## 5. 问题优先级

### 5.1 高优先级（影响一致性）

| 问题 | 影响范围 | 预计工时 |
|------|----------|----------|
| 按钮未使用 PillButton | 全部 5 页面 | 2h |
| 按压反馈缺失 ScaleDownOnPress | 全部 5 页面 | 1h |
| profile_screen 硬编码颜色 | 17 处 | 30min |

### 5.2 中优先级（影响规范性）

| 问题 | 影响范围 | 预计工时 |
|------|----------|----------|
| settings_page 未使用组件 | 设置页 | 1h |
| word_detail_page 卡片未用 ContentCard | 单词详情 | 30min |
| review_page 使用旧 glass_widgets | 复习页 | 1h |

### 5.3 低优先级（可后续优化）

| 问题 | 影响范围 | 预计工时 |
|------|----------|----------|
| profile_screen 徽章文字 9sp | 个人中心 | 15min |
| learn_page 硬编码阴影色 | 学习页 | 保留 |

---

## 6. 建议

### 6.1 立即行动

1. **统一按钮组件**：将原生按钮替换为 PillButton（50px 胶囊）
2. **添加按压反馈**：为核心交互组件添加 ScaleDownOnPress
3. **迁移 profile_screen 硬编码颜色**：17 处 → skin.colors

### 6.2 短期（1周）

1. 完成 settings_page 组件替换
2. 完成 word_detail_page 卡片替换
3. 完成 review_page 迁移到 ContentCard

### 6.3 中期（2周）

1. 建立 UI 规范检查清单
2. 引入 lint 规则强制使用组件库

---

## 7. 结论

**整体评价：🟡 中等**

**优势：**
- 字体大小规范良好（100% 通过）
- 颜色引用基本到位（60% 通过）
- 核心页面（learn_page、review_page）颜色引用优秀

**改进空间：**
- 按钮组件使用率极低（0% 通过）
- 按压反馈完全缺失（0% 通过）
- 卡片组件使用不一致（40% 通过）

**优先级建议：**
1. 立即：统一按钮组件（PillButton）+ 添加按压反馈（ScaleDownOnPress）
2. 本周：迁移硬编码颜色（profile_screen 17 处）
3. 下周：完成组件替换（settings_page、word_detail_page、review_page）

**总预计工时：~6h**

---

*抽检完成于 2026-08-24 · Batch1Engineer*
