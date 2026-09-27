# 架构健康度审查报告

审查日期：2026-08-24
审查人：Batch1Engineer
项目：Monster Word (word_app)

---

## 1. 目录结构分析

### 1.1 当前结构

```
lib/
├── data/          # 数据层（数据库、DAO、偏好设置）
├── engine/        # 学习引擎（SRS、Leitner、干扰项等）
│   └── bs/        # 批处理器（头像、音效、文本格式化）
├── events/        # 事件总线（学习、用户、UI、媒体等事件）
├── hooks/         # 响应式 hooks
├── lock/          # 锁屏功能模块
│   └── view/      # 锁屏 UI 组件
├── models/        # 数据模型（16个文件）
├── pages/         # 页面层（56个页面/屏幕）
├── player/        # 音频播放器
├── screens/       # 主要屏幕（学习、复习、首页等）
├── services/      # 服务层（HTTP、后台、统计、API）
├── shell/         # 应用壳层（底部导航）
├── state/         # 状态管理（仅2个文件）
├── theme/         # 主题系统（SkinSystem + AppTheme）
├── tokens/        # 设计 token（3个文件）
├── utils/         # 工具类
└── widgets/       # 通用组件
```

### 1.2 结构评价

**✅ 优点：**
- 分层清晰：data → engine → state → pages/screens
- 主题系统独立：theme/ + tokens/ 分离
- 事件总线解耦：events/ 模块化

**⚠️ 问题：**
- **pages/ 过于臃肿**：56个文件，建议按功能域拆分（学习、设置、个人中心等）
- **lock/ 模块孤立**：锁屏功能独立模块，但与其他模块交互不明确
- **screens vs pages 命名混淆**：screens/ 有4个文件，pages/ 有52个，边界模糊

---

## 2. 依赖分析

### 2.1 状态管理

**✅ 统一性：良好**
- 全项目使用 `provider` 包（39个文件引用）
- 未发现 get_it、bloc、riverpod、mobx 等混用
- 状态集中在 `state/learning_state.dart` 和 `state/wallpaper_state.dart`

**⚠️ 潜在问题：**
- `SkinSystem` 虽然在 `theme/` 目录，但本质是状态管理（ChangeNotifier）
- 建议将 `SkinSystem` 迁移到 `state/` 目录以保持一致性

### 2.2 循环依赖检查

**✅ 未发现明显循环依赖**

主要依赖流向：
```
main.dart → pages/ → state/ → data/
                    → theme/
                    → services/
                    → engine/
```

### 2.3 未使用代码

**⚠️ 问题：**
- 未使用导入：46处
- 未使用字段/元素：41处
- 总计 87 处可清理项

---

## 3. 主题系统一致性

### 3.1 当前使用情况

| 引用方式 | 文件数 | 说明 |
|---------|--------|------|
| `skin.colors.*` | 63 | 主要方式（ThemeVars） |
| `MistralColors.*` | 部分 | 旧 token 引用 |
| `ThemeVars.*` | 少量 | 直接引用 |

### 3.2 问题

**⚠️ Token 混用：**
- `skin.colors.*` 是主流（920处引用）
- `MistralColors.*` 仍存在（旧设计系统残留）
- 建议统一为 `skin.colors.*` 或新建 `AppColors` 门面

**⚠️ 硬编码颜色残留：**
- pages/screens/widgets 中仍有 169 处 `Color(0x...)` 硬编码
- 主要集中在：
  - `word_machine_page.dart`（像素风豁免）
  - `class_checkin_page.dart`
  - `exam_quick_review_page.dart`

### 3.3 Token 层

| 文件 | 用途 | 状态 |
|------|------|------|
| `design_tokens.dart` | 间距、圆角、排版 | ✅ 已使用 |
| `starbucks_tokens.dart` | 星巴克色板 | ✅ 已使用 |
| `gameboy.dart` | 像素风色板 | ✅ 已使用 |

---

## 4. 命名一致性

### 4.1 页面命名

**✅ 良好：**
- 统一使用 `_page.dart` 后缀（56个文件）
- 路由名与文件名对应（如 `/word_detail` → `word_detail_page.dart`）

**⚠️ 混淆：**
- `screens/` vs `pages/` 边界不清
- 建议：screens/ 保留为顶级容器（HomeScreen、LearnSession），其余归 pages/

### 4.2 组件命名

**✅ 良好：**
- 组件文件使用描述性名称
- 新组件（SbDropdown、SbSegmented）遵循 `Sb` 前缀规范

**⚠️ 问题：**
- 旧组件命名不一致（`glass_widgets.dart` vs `content_card.dart`）
- 建议统一为 `sb_` 前缀或语义化命名

---

## 5. 代码质量指标

### 5.1 静态分析

| 指标 | 数量 | 评价 |
|------|------|------|
| ERROR | 0 | ✅ 优秀 |
| WARNING | 114 | ⚠️ 主要是未使用导入 |
| INFO | 250 | ⚠️ 主要是废弃 API 使用 |
| **总计** | 364 | 可接受 |

### 5.2 代码规模

| 指标 | 数量 |
|------|------|
| 总文件数 | 196 |
| 页面/屏幕 | 56 |
| 模型文件 | 16 |
| 服务文件 | 7 |
| 组件文件 | 30+ |

---

## 6. 风险点

### 6.1 高风险

| 风险 | 影响 | 建议 |
|------|------|------|
| pages/ 膨胀 | 维护困难、编译慢 | 按功能域拆分子目录 |
| Token 混用 | 主题切换不一致 | 统一到 `skin.colors.*` 或门面类 |
| 硬编码残留 | 深色模式适配困难 | 逐页清理，优先核心页面 |

### 6.2 中风险

| 风险 | 影响 | 建议 |
|------|------|------|
| 未使用代码 | 包体积、可读性 | 定期清理（46 imports + 41 elements） |
| SkinSystem 位置 | 状态管理一致性 | 迁移到 state/ 或保持现状并文档化 |
| lock/ 模块孤立 | 代码复用差 | 评估是否保留或重构 |

---

## 7. 改进建议

### 7.1 短期（1-2天）

1. **清理未使用导入**：46处，自动化工具可快速完成
2. **统一 Token 引用**：将 `MistralColors.*` 迁移到 `skin.colors.*`
3. **文档化架构决策**：记录 screens/ vs pages/ 的边界定义

### 7.2 中期（1周）

1. **拆分 pages/ 目录**：
   ```
   lib/pages/
   ├── learn/        # 学习相关（learn_page, word_detail, dictionary）
   ├── settings/     # 设置相关（more_settings, appearance, play_order）
   ├── profile/      # 个人中心（my_space, my_fav, foot_mark）
   ├── review/       # 复习相关（review_page, reviewing_words）
   └── misc/         # 其他（help, net_diagnosis, uri_scheme）
   ```

2. **迁移 SkinSystem**：从 `theme/` 移到 `state/`，保持状态管理一致性
3. **清理硬编码颜色**：优先处理核心学习流程页面

### 7.3 长期（1个月）

1. **引入路由管理**：考虑 go_router 替代手写路由
2. **组件库规范化**：统一 `Sb` 前缀，建立组件文档
3. **性能优化**：大文件拆分（word_machine_page 770行、sentence_quiz_page 600行）

---

## 8. 结论

**整体健康度：🟡 中等偏上**

**优势：**
- 分层架构清晰，依赖方向正确
- 状态管理统一（provider）
- 主题系统完整（SkinSystem + ThemeVars）
- 静态分析 ERROR=0

**改进空间：**
- 页面层过于扁平（56个文件）
- Token 引用混用（skin.colors vs MistralColors）
- 硬编码颜色残留（169处）
- 未使用代码较多（87处）

**优先级建议：**
1. 立即：清理未使用导入（46处）
2. 本周：统一 Token 引用
3. 下周：拆分 pages/ 目录

---

*审查完成于 2026-08-24 · Batch1Engineer*
