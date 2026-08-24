# Monster Word v2.0.0 技术总结

> 面向开发者 · 2026-08-24
> 项目：D:\claude\work\cn_com_lange\word_app
> 版本：v2.0.0+2 · Flutter 3.47.0 · Dart 3.13.0

---

## 1. 架构概览

### 1.1 分层结构

```
lib/
├── data/          # 数据层 — WordBookDatabase、UserDatabase、AppPreferences
├── engine/        # 学习引擎 — SRS 间隔重复、Leitner 算法、干扰项生成
│   └── bs/        # 批处理器 — 头像、音效、文本格式化
├── events/        # 事件总线 — 学习/用户/UI/媒体事件解耦
├── hooks/         # 响应式 hooks
├── lock/          # 锁屏功能模块
├── models/        # 数据模型（16 个文件）
├── pages/         # 页面层（56 个页面/屏幕）
├── player/        # 音频播放器
├── screens/       # 主要屏幕（HomeScreen、LearnSession 等顶级容器）
├── services/      # 服务层 — HTTP、后台、统计、API、字典
├── shell/         # 应用壳层 — 底部导航 MainShell
├── state/         # 状态管理 — LearningState、WallpaperState
├── theme/         # 主题系统 — SkinSystem + AppTheme
├── tokens/        # 设计 Token — design_tokens / starbucks_tokens / motion_tokens
├── utils/         # 工具类
└── widgets/       # 通用组件（含 Sb 系列星巴克组件）
```

### 1.2 状态管理

| 机制 | 使用范围 | 说明 |
|---|---|---|
| `provider` (ChangeNotifier) | 全项目（39 个文件） | 唯一状态管理方案，无 get_it/bloc/riverpod 混用 |
| `SkinSystem` | 主题切换 | ChangeNotifier，持久化到 SharedPreferences |
| `LearningState` | 学习流程 | 词书队列、答题状态、SRS 调度 |
| `EventBus` | 跨模块通信 | 学习/用户/UI 事件解耦 |

**依赖流向**（无循环依赖）：
```
main.dart → pages/ → state/ → data/
                    → theme/
                    → services/
                    → engine/
```

### 1.3 数据层

| 组件 | 说明 |
|---|---|
| `WordBookDatabase` | 词书库（191 本词书、32,154 词条），gzip 压缩 SQLite，首启解压至临时区 |
| `UserDatabase` | 用户数据（收藏、学习进度），sqflite |
| `AppPreferences` | 键值偏好（主题、跟随系统、词书选择），SharedPreferences 封装 |
| `DictionaryService` | 字典查询单例，封装前缀/模糊/智能搜索 |

---

## 2. 设计系统（Starbucks Token 体系）

### 2.1 Token 架构

```
lib/tokens/
├── design_tokens.dart      # 过渡期别名（MistralColors → 星巴克 token）
├── starbucks_tokens.dart   # 星巴克专用常量（Cream/Dark 双主题）
└── motion_tokens.dart      # 动效 token（五档时长 + 缓动曲线）
```

### 2.2 主题系统

```
lib/theme/
├── skin_system.dart        # SkinSystem（ChangeNotifier）+ SkinProvider（InheritedWidget）
└── app_theme.dart          # ThemeData 构建器
```

**主题预设**：

| ID | 名称 | 亮度 | 画布色 | 强调色 |
|---|---|---|---|---|
| `starbucks_cream` | 星巴克奶油 | Light | #F2F0EB | #00754A |
| `starbucks_dark` | 星巴克深绿 | Dark | #101B17 | #00A862 |
| `bright` | 明亮（旧） | Light | #F5F5F5 | #E8913A |
| `dark` | 深邃（旧） | Dark | #212532 | #F4A100 |
| `pure_black` | 极夜（旧） | Dark | #040404 | #005F87 |

**ThemeVars 字段**（30 个语义令牌）：
- 画布层：`pageBg` / `cardBg` / `cardBgAlt`
- 文字层：`text1`(α=0.87) / `text2`(α=0.58) / `text3`(α=0.45)
- 品牌色：`accent` / `teal`
- 语义色：`success` / `danger`
- 玻璃态：`glassBg` / `glassBorder` / `onGlassText1` / `onGlassText2`
- 模态：`modalGlassBg` / `modalText1` / `modalText2`
- 答题：`quizCorrectBg/Text` / `quizWrongBg/Text`
- 成就：`vipGoldBg` / `vipGoldText`
- 装饰：`profileDecor`（双色列表）

### 2.3 品牌绿色四层体系

| 层级 | 色值 | 用途 | 常量名 |
|---|---|---|---|
| Starbucks Green | #006241 | 标题、深色背景 | `greenHouse` |
| Green Accent | #00754A | CTA 按钮、强调 | `greenBrand` |
| House Green | #1E3932 | 横幅、深色表面 | `greenBanner` |
| Soft Green | #2B5148 | 辅助深绿 | `greenSoft` |

### 2.4 字体系统

```dart
// 回退链
['Inter', 'PingFang SC', 'Microsoft YaHei', 'Noto Sans SC']

// 字重阶梯
heroWord:  38px / w700 / greenHouse    // 词卡主词
heading1:  52px / w400 / greenHouse
heading2:  36px / w500 / greenHouse
heading3:  28px / w500 / greenHouse
heading4:  22px / w500 / greenHouse
heading5:  18px / w500 / greenHouse
bodyMd:    16px / w400 / text1
bodySm:    14px / w400 / text1
caption:   13px / w400 / text2
micro:     12px / w500 / text2
buttonMd:  14px / w500 / cardBg(白字)
```

**letterSpacing 规则**：纯西文 token 加 -fontSize×0.01，含中文 token 不加。

### 2.5 组件库（10 个 Sb 组件）

| 组件 | 文件 | 用途 | 核心规格 |
|---|---|---|---|
| `SbButton` | `sb_button.dart` | 胶囊按钮 | 50px 圆角、4 变体、scale(0.95) 按压 |
| `SbCard` | `sb_card.dart` | 卡片容器 | 12px 圆角、双层低透明度阴影 |
| `SbFab` | `sb_fab.dart` | 悬浮按钮 | 56px 圆形、触控外扩 8px |
| `SbBanner` | `sb_banner.dart` | 深绿横幅 | #1E3932 底、白字 |
| `SbBadge` | `sb_badge.dart` | 金色徽章 | #CBA258 描边胶囊 |
| `SbDropdown` | `sb_dropdown.dart` | 下拉菜单 | #F9F9F9 底、12px 圆角 |
| `SbModal` | `sb_modal.dart` | 模态对话框 | 12px 圆角、底部弹出/居中 |
| `SbProgress` | `sb_progress.dart` | 进度指示 | 线性 + 环形、绿色系 |
| `SbSegmented` | `sb_segmented.dart` | 分段控件 | 学习模式切换 |
| `ScaleDownOnPress` | `scale_down_on_press.dart` | 按压反馈 | scale(0.95)、200ms ease |

### 2.6 动效规范

| 档位 | 时长 | 用途 |
|---|---|---|
| fast | 150ms | 微交互（图标切换、颜色过渡） |
| base | 200ms | 按钮按压、卡片展开 |
| slow | 300ms | 页面转场、手风琴 |
| spring | 400ms | 弹性反馈（选对确认） |
| stagger | 50ms/项 | 列表错峰入场 |

---

## 3. 代码质量指标

### 3.1 静态分析

| 指标 | 原基线 | v2.0.0 | 变化 |
|---|---|---|---|
| ERROR | 0 | **0** | 持平 |
| WARNING | 114 | **55** | **-51.8%** |
| INFO | 250 | **~117** | **-53.2%** |
| 总计 | 364 | **~172** | **-52.7%** |

### 3.2 测试

| 指标 | 原基线 | v2.0.0 | 变化 |
|---|---|---|---|
| 测试用例 | 1 | **101** | +100 |
| 通过率 | 100% | **100%** | 持平 |
| WCAG 守卫 | 无 | **100 项** | 新增 |

### 3.3 代码规模

| 指标 | 数量 |
|---|---|
| 总文件数 | 196 |
| 页面/屏幕 | 56 |
| 模型文件 | 16 |
| 服务文件 | 7 |
| 组件文件 | 30+（含 10 个 Sb 组件） |
| Token 文件 | 3 |
| 测试文件 | 2（widget_test + contrast_guard_test） |

---

## 4. 已知技术债务

### 4.1 高优先级

| 债务 | 影响 | 建议 |
|---|---|---|
| **wordbook.db 版权风险** | 公开分发合规 | 用 ECDICT 替换释义/音标字段（方案已就绪） |
| **硬编码颜色 471 处** | 主题一致性 | 活跃页面已迁移，非活跃页面待后续批次 |
| **pages/ 臃肿（56 文件）** | 可维护性 | 按功能域拆分子目录 |

### 4.2 中优先级

| 债务 | 影响 | 建议 |
|---|---|---|
| **screens vs pages 命名混淆** | 代码导航 | screens/ 保留顶级容器，其余归 pages/ |
| **SkinSystem 在 theme/ 而非 state/** | 架构一致性 | 迁移到 state/ 目录 |
| **旧组件命名不一致** | 代码风格 | 统一为 sb_ 前缀或语义化命名 |
| **柯林斯词典 Tab 空数据** | 用户体验 | 移除或改为「详注」中性命名 |

### 4.3 低优先级

| 债务 | 影响 | 建议 |
|---|---|---|
| **lock/ 模块孤立** | 架构清晰度 | 评估是否合并到 screens/ |
| **旧预设（bright/dark/pure_black）保留** | 代码体积 | 确认用户迁移完成后删除 |
| **有道发音 URL 合规** | 法律风险 | 评估 TTS 替代方案 |

---

## 5. 后续改进路线图

### 5.1 短期（v2.1）

| 项目 | 说明 | 预估 |
|---|---|---|
| ECDICT 数据替换 | 构建 ECDICT 精简子集，替换 wordbook.db 释义/音标 | 3–5 天 |
| Launcher 图标素材 | AI 生图 → 品牌 M 图标 → flutter_launcher_icons | 1 天 |
| 剩余硬编码清理 | 非活跃页面 471 处 → 全部迁移到 token | 2–3 天 |

### 5.2 中期（v2.5）

| 项目 | 说明 | 预估 |
|---|---|---|
| 目录重构 | pages/ 按功能域拆分、screens/pages 合并 | 3–5 天 |
| 旧预设下线 | 移除 bright/dark/pure_black，仅保留 starbucks_* | 1 天 |
| 组件库扩展 | StarSheet/StarHeader/StarToggle 等补充组件 | 2–3 天 |
| 柯林斯 Tab 改造 | 改为「详注」或接入 ECDICT 英文定义 | 1 天 |

### 5.3 长期（v3.0）

| 项目 | 说明 | 预估 |
|---|---|---|
| 死页面接线 | 25 个死路由页面评估接线或永久冻结 | 5–10 天 |
| 功能缺口 Backlog | GAP-01~18 按优先级实施 | 10–20 天 |
| iOS 适配 | 当前仅 Windows/Android，补充 iOS 构建和测试 | 5–7 天 |
| 国际化 | 中英双语支持 | 5–7 天 |

---

## 6. 关键文件索引

| 类别 | 文件 | 说明 |
|---|---|---|
| 入口 | `lib/main.dart` | App 初始化、主题应用、系统亮度监听 |
| 主题 | `lib/theme/skin_system.dart` | SkinSystem + ThemePreset + ThemeVars |
| Token | `lib/tokens/starbucks_tokens.dart` | 星巴克双主题常量 |
| Token | `lib/tokens/design_tokens.dart` | 过渡期别名 |
| Token | `lib/tokens/motion_tokens.dart` | 动效常量 |
| 导航 | `lib/shell/main_shell.dart` | 底部 Tab 导航 |
| 学习 | `lib/pages/learn_page.dart` | 4 选 1 答题核心流程 |
| 数据 | `lib/data/wordbook_database.dart` | 词书数据库管理 |
| 数据 | `lib/data/app_preferences.dart` | 偏好持久化 |
| 组件 | `lib/widgets/sb_*.dart` | 星巴克组件库（10 个） |
| 测试 | `test/contrast_guard_test.dart` | WCAG 对比度守卫（100 项） |
| 规范 | `DESIGN.md` | 星巴克设计语言规范 |

---

*Monster Word v2.0.0 — 星巴克设计语言全面重构，63 个 commit，114+ 项任务，101/101 测试全绿。*
