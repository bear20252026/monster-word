# 硬编码颜色最终扫描报告

扫描日期：2026-08-24
扫描人：Batch1Engineer
项目：Monster Word (word_app)

---

## 1. 扫描范围

- 目录：`lib/pages/` + `lib/screens/`
- 排除：`word_machine_page.dart`（像素风专用，已豁免）
- 模式：`Color(0x...)` + `Colors.xxx`

---

## 2. 总览统计

| 指标 | 数量 |
|------|------|
| 总硬编码颜色 | 471 处 |
| 其中 `Color(0x...)` | ~170 处 |
| 其中 `Colors.xxx` | ~301 处 |
| 涉及文件 | 40+ 个 |

### 2.1 Colors.xxx 分布

| 类型 | 数量 | 说明 |
|------|------|------|
| `Colors.white` | ~120 | 背景、文字、卡片 |
| `Colors.black` | ~15 | 文字、阴影 |
| `Colors.transparent` | ~7 | 透明背景 |
| 其他 Material 色 | ~159 | amber、red、green、blue 等 |

---

## 3. 按文件统计（Top 20）

| 文件 | 总数 | 可迁移 | 可豁免 | 优先级 |
|------|------|--------|--------|--------|
| class_checkin_page.dart | 50 | 45 | 5 | 高 |
| exam_quick_review_page.dart | 37 | 35 | 2 | 中 |
| class_activity_page.dart | 29 | 25 | 4 | 中 |
| wallpaper_select_page.dart | 26 | 0 | 26 | 低（场景色） |
| courses_page.dart | 21 | 18 | 3 | 中 |
| login_page.dart | 19 | 15 | 4 | 高 |
| my_content_page.dart | 18 | 16 | 2 | 中 |
| profile_screen.dart | 17 | 15 | 2 | 高 |
| books_page.dart | 16 | 14 | 2 | 中 |
| spell_check_page.dart | 14 | 12 | 2 | 高 |
| splash_page.dart | 13 | 0 | 13 | 低（品牌展示） |
| my_space_page.dart | 13 | 11 | 2 | 高 |
| my_fav_sentence_page.dart | 12 | 10 | 2 | 中 |
| more_settings_page.dart | 11 | 10 | 1 | 高 |
| collins_detail_intro_page.dart | 11 | 10 | 1 | 高 |
| settings_page.dart | 10 | 8 | 2 | 高 |
| personal_stereo_page.dart | 10 | 8 | 2 | 中 |
| my_fav_page.dart | 10 | 8 | 2 | 中 |
| list_word_listen_page.dart | 10 | 8 | 2 | 中 |
| appearance_page.dart | 10 | 8 | 2 | 高 |

---

## 4. 分类详情

### 4.1 可迁移 - 高优先级（核心页面）

| 页面 | 硬编码数 | 主要问题 | 预计工时 |
|------|----------|----------|----------|
| class_checkin_page.dart | 50 | 功能色（绿/蓝/橙/紫）、成就色（金银铜） | 40 min |
| login_page.dart | 19 | 按钮色、输入框色 | 15 min |
| profile_screen.dart | 17 | 渐变色、图标色 | 20 min |
| spell_check_page.dart | 14 | 拼写检查 UI 色 | 15 min |
| my_space_page.dart | 13 | 个人空间装饰色 | 15 min |
| more_settings_page.dart | 11 | 设置项图标色 | 10 min |
| collins_detail_intro_page.dart | 11 | Collins 词典色 | 10 min |
| settings_page.dart | 10 | 设置项图标色 | 10 min |
| appearance_page.dart | 10 | 主题预览色 | 10 min |

**小计：~145 min（2.4h）**

### 4.2 可迁移 - 中优先级（辅助页面）

| 页面 | 硬编码数 | 主要问题 | 预计工时 |
|------|----------|----------|----------|
| exam_quick_review_page.dart | 37 | 测试背景色、选项色 | 30 min |
| class_activity_page.dart | 29 | 活动装饰色 | 25 min |
| courses_page.dart | 21 | 课程卡片装饰色 | 20 min |
| my_content_page.dart | 18 | 内容页装饰色 | 15 min |
| books_page.dart | 16 | 书籍列表装饰色 | 15 min |
| my_fav_sentence_page.dart | 12 | 收藏句装饰色 | 10 min |
| personal_stereo_page.dart | 10 | 随身听装饰色 | 10 min |
| my_fav_page.dart | 10 | 收藏页装饰色 | 10 min |
| list_word_listen_page.dart | 10 | 单词听写装饰色 | 10 min |

**小计：~145 min（2.4h）**

### 4.3 可豁免

| 页面 | 硬编码数 | 豁免原因 |
|------|----------|----------|
| wallpaper_select_page.dart | 26 | 场景壁纸预览色（装饰性） |
| splash_page.dart | 13 | 品牌启动页（展示性） |
| 阴影色（多文件） | ~30 | BoxShadow rgba 黑色系（通用阴影） |
| Colors.transparent | ~7 | 透明背景（无语义） |

**小计：~76 处**

---

## 5. Colors.white 特别说明

`Colors.white` 是最常见的硬编码（~120处），需要分类处理：

| 用途 | 数量 | 处理方式 |
|------|------|----------|
| 卡片背景 | ~40 | → `skin.colors.cardBg` |
| 文字颜色 | ~30 | → `skin.colors.text1` 或保留（深色背景上） |
| 按钮文字 | ~20 | → 保留（白字配绿底） |
| 分割线/边框 | ~10 | → `skin.colors.divider` |
| 透明占位 | ~20 | → `Colors.transparent` 或保留 |

**建议：** 不要一刀切替换，按上下文语义逐个判断

---

## 6. Token 缺口补充

基于扫描结果，建议新增以下 token：

| Token | 色值 | 用途 |
|-------|------|------|
| `FuncColors.info` | `#2196F3` | 信息蓝（提示、链接） |
| `FuncColors.warning` | `#FF9800` | 警告橙 |
| `FuncColors.purple` | `#9C27B0` | 紫色功能 |
| `FuncColors.success` | `#4CAF50` | 成功绿（同 skin.colors.success） |
| `StarGold.gold` | `#FFD700` | 成就金 |
| `StarGold.silver` | `#C0C0C0` | 成就银 |
| `StarGold.bronze` | `#CD7F32` | 成就铜 |

---

## 7. 迁移路线图

### 7.1 第一批（核心学习流程，2.4h）

| 优先级 | 页面 | 工时 |
|--------|------|------|
| P0 | class_checkin_page | 40 min |
| P0 | profile_screen | 20 min |
| P0 | login_page | 15 min |
| P1 | spell_check_page | 15 min |
| P1 | my_space_page | 15 min |
| P1 | settings_page | 10 min |
| P1 | more_settings_page | 10 min |
| P1 | collins_detail_intro_page | 10 min |
| P1 | appearance_page | 10 min |

### 7.2 第二批（辅助页面，2.4h）

| 优先级 | 页面 | 工时 |
|--------|------|------|
| P2 | exam_quick_review_page | 30 min |
| P2 | class_activity_page | 25 min |
| P2 | courses_page | 20 min |
| P2 | my_content_page | 15 min |
| P2 | books_page | 15 min |
| P2 | 其他辅助页面 | 40 min |

### 7.3 第三批（装饰/阴影，0.5h）

| 内容 | 工时 |
|------|------|
| 阴影色统一 | 20 min |
| 场景色保留标记 | 10 min |

---

## 8. 建议

### 8.1 立即行动

1. **新建缺失 token**：`FuncColors.info/warning/purple`、`StarGold.gold/silver/bronze`
2. **统一 Colors.white 处理规则**：制定替换标准，避免一刀切

### 8.2 短期（1周）

1. 完成第一批迁移（核心页面，2.4h）
2. 更新组件库：将常用硬编码提取为组件参数

### 8.3 中期（2周）

1. 完成第二批迁移（辅助页面，2.4h）
2. 建立 CI 规则：禁止新增 `Color(0x...)` 硬编码

### 8.4 长期

1. 引入 lint 规则：`avoid_hardcoded_colors`
2. 建立颜色 token 文档站

---

## 9. 结论

**整体评价：🟡 中等**

- 可迁移：~395处（84%）
- 可豁免：~76处（16%）
- 总预计工时：~5.3h（分三批）

**风险点：**
- `Colors.white` 处理需谨慎（120处，语义多样）
- 部分页面（wallpaper_select、splash）颜色是装饰性，保留为宜

**优先级建议：**
1. 新建缺失 token（30 min）
2. 完成第一批核心页面迁移（2.4h）
3. 完成第二批辅助页面迁移（2.4h）

---

*扫描完成于 2026-08-24 · Batch1Engineer*
