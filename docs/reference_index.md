# 参考资料索引：旧审核报告在新方向下的甄别归档

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 背景：项目设计方向已由「不背单词像素级还原」切换为「星巴克（Starbucks）风格」。D:\tools\ 下大量旧审核报告基于旧目标产出，需要甄别哪些仍然有效、哪些归档。
> 方式：只读遍历 D:\tools\*.md（48 份）、D:\tools\ui_review\（24 张 PNG）、word_app\docs\（11 份）；本文档为本任务唯一新增文件。

---

## 一、分类标准

| 标注 | 含义 |
|---|---|
| 【仍然有效】 | 功能逻辑 / 词书数据 / 技术架构 / 逆向调研类，与视觉方向无关，继续作为参考资料 |
| 【已过时】 | 以「不背单词像素级还原」为目标产出的审核/对比/打磨报告，或已失效的历史快照，建议归档 |
| 【部分可用】 | 主体已随旧方向失效，但其中某部分（通常是功能缺口清单）仍有效，需注明可用部分 |
| 【外部资料】 | 与本项目重构无直接关联的第三方收藏/调研，不属于本参考资料库核心，建议另行存放 |

---

## 二、D:\tools\*.md 甄别明细（48 份）

### 2.1 【仍然有效】（15 份）—— 功能逻辑 / 数据 / 技术架构

| 文件 | 内容摘要 | 新方向下价值 |
|---|---|---|
| review_functionality.md | 学习流程功能完整性审核（词展示/例句/发音/收藏/进度/统计） | 纯功能盘点，直接有效 |
| monster_word_mvp_mapping.md | Android v3.2 → Flutter 的 MVP 架构映射（锁屏/拼写检查/日历逻辑） | 移植逻辑权威参考 |
| monster_word_database_analysis.md | v3.2 与 Flutter 数据库层逐层对照分析 | 词书数据结构参考 |
| monster_word_network_db_report.md | 数据库与网络层安全审计（SQL 注入/明文密钥/越界路径） | 安全整改依据 |
| monster_word_v32_key_packages.md | v3.2 关键包分析（widget/webservice/lock/API 端点 + 移植状态总览） | API 与移植状态清单 |
| monster_word_v32_vs_v50_diff.md | v3.2 ↔ v5.0 版本差异分析 | 版本演进参考 |
| monster_word_v5_analysis.md | v5.0 APK 逆向分析（SecNeo 加壳、加固对抗结论） | 逆向方法论存档 |
| monster_word_remaining_packages.md | 剩余包分析（补全逆向覆盖面） | 同上 |
| word_root_tab_implementation.md | 词根 Tab 实现记录（数据源 JSON 结构 + 集成方式） | 功能实现记录有效；文中 UI 配色细节将随新方向重调，不影响文档价值 |
| theme_compatibility_check.md | 主题系统接入审计（硬编码颜色/字体排查） | 换任何设计方向都要做令牌迁移，此清单直接服务星巴克改造 |
| review_consistency_fix.md | SkinSystem 接入修复记录（AppColors.xxx → colors.xxx 映射表） | 技术架构迁移记录，映射表对新令牌体系迁移有参考价值 |
| frida_analysis_guide.md | Frida 动态分析方法论 | 逆向方法论存档 |
| blackdex_guide.md | BlackDex 脱壳指南（v5.11.1 实操） | 同上 |
| crawler_research.md | 爬虫工具调研（2025–2026，新闻→学习素材管线） | 与视觉无关的独立调研 |
| new_yorker_learning.md | 英语学习内容素材（精读+词汇） | 内容素材，与视觉无关 |

### 2.2 【部分可用】（12 份）—— 注明可用部分

| 文件 | 已过时部分 | 仍然可用的部分 |
|---|---|---|
| original_ui_analysis.md | 色彩/字体/圆角等视觉规范、「99.999% 还原」修复清单 | 页面清单、导航流程图、各页功能项盘点（如学习偏好 6 组 11 个设置项），可作为产品功能参考 |
| review_consistency.md | 针对旧令牌（MistralColors/AppleSpacing）的一致性数值标准 | 「哪些文件硬编码颜色/字体/间距」技术债清单 + SkinSystem 接入率盘点，对迁移到新星巴克令牌体系仍有用 |
| review_animations.md | 与原版 v3.2 曲线/时长的「还原度对比」 | 动画缺失清单（选择反馈、翻卡翻页、锁屏 TODO、自定义曲线未被使用）仍是真实交互缺口 |
| review_responsive.md | 与原版平板截图的对照 | 响应式基础设施审计（contentWidth 未使用、多页未走 resp.pageMargin 等），换方向后依然成立 |
| review_final_report.md | 十维还原度评分与逐条修复项 | 第 8 节「功能完整性」：已实现/缺失模块清单（支付、推送、微信登录、锁屏平台通道） |
| ui_compare_word_list.md | 词书列表页像素对比与还原度评分 | 第 6–7 节功能缺口：底部工具栏五项未实现（沉浸刷词/随身听/听写/随手拼/导出）、封面占位、描述硬编码 |
| ui_compare_word_detail.md | 单词详情页像素对比 | 功能缺口清单：撤销按钮、拼写检查 abc 按钮、笔记 Tab、音频/评论图标缺失、释义关键词标记 |
| ui_polish_summary.md | 1:1 还原打磨的全部像素修正 | 其中明确记录「底部工具栏五项功能未实现」，该功能缺口提醒仍有效 |
| ui_review_round2_appearance.md | 截图用错（实拍为单词详情页），对比本身无效 | 第五节外观页功能完整性检查：缺主题实时预览、壁纸自定义、恢复默认按钮；含代码结构分析 |
| monster_word_v5_resources.md | 原版布局 XML / 主题样式细节（原版视觉） | v5.0 功能模块清单（自习室、跟读评测、剧集视频、随身听三模式）+ assets/raw 内置数据库清单（simple.db、wordroot.db 等） |
| monster_word_quality_check.md | 头部注释覆盖等快照类内容（后续已批量修复，状态失真） | 第 5 节集成点：Provider/路由/模块架构速览 |
| monster_word_design_guide.md | 作为「Apple+Mistral 融合设计规范」本身已被星巴克方向取代 | 第 9 节 Flutter 令牌代码结构与当前 design_tokens.dart/skin_system.dart 对应，迁移期间可作「现状对照」；组件实现模式（响应式断点、阴影层级划分思路）可复用 |

### 2.3 【已过时】（19 份）—— 建议归档

**像素级还原审核/对比/打磨类（16 份）：**

| 文件 | 说明 |
|---|---|
| review_layout_spacing.md | 布局间距还原审核（60px 边距、字号比对） |
| review_color_theme.md | 配色方案还原度报告（对照原版 colors.xml） |
| ui_compare_home.md | 首页截图像素对比 |
| ui_compare_profile.md | 个人中心 + 账号信息页像素对比 |
| ui_compare_settings.md | 设置页对比（当时即用错截图，报告自身已声明无效） |
| ui_compare_settings_v2.md | 学习偏好页像素对比 v2（设置项清单已被 original_ui_analysis 覆盖） |
| ui_review_round2_animations.md | 二轮动画还原对比（动画现状清单可被 motion_spec.md 取代） |
| ui_review_round2_colors.md | 二轮颜色/字体精确对比 |
| ui_review_round2_courses.md | 二轮课程页对比 |
| ui_review_round2_profile.md | 二轮个人中心对比 |
| ui_review_round2_settings.md | 二轮设置页对比 |
| ui_review_my_space_final.md | 三轮「我的」页面终检 |
| button_alignment_report.md | 按钮对齐像素对比 |
| button_alignment_complete_summary.md | 按钮对齐完成总结 |
| my_space_pixel_fixes.md | 「我的」页面像素修正记录 |
| ui_polish_checklist.md | 1:1 还原打磨清单 |

**失效的历史快照类（3 份）：**

| 文件 | 说明 |
|---|---|
| final_verification.md | 历史编译错误快照（dart analyze 结果，代码已演进，状态失真） |
| final_99_999_verification.md | 「99.999% 还原度确认」——该目标本身已被新方向废弃，编译快照同样过时 |
| monster_word_analyze_report.md | 历史编译快照（同上，已被 qa_baseline.md 取代） |

### 2.4 【外部资料】（2 份）—— 与本项目无直接关联

| 文件 | 说明 |
|---|---|
| piracy_resources.md | 第三方资源链接合集（PDF/工具站导航） |
| awesome-piracy-readme.md | Awesome Piracy 仓库 README 存档 |

二者与 Monster Word 重构无关，建议移出本参考资料库单独存放（不必删除）。

### 2.5 任务提到但不存在的文件

| 任务中提及 |实际情况 |
|---|---|
| review_word_list.md | **不存在**（疑为 ui_compare_word_list.md 的旧称或已被清理） |
| review_icons_interaction.md | **不存在** |
| ui_compare_animations.md | **不存在**（疑为 ui_review_round2_animations.md） |

---

## 三、D:\tools\ui_review\ 截图目录

- 共 24 张 PNG = **12 张不背单词原版截图 × 2 种尺寸变体**（`*_0.png` / `*_720.png`，哈希文件名）。
- 用途：曾是像素级还原的唯一视觉基准。
- 甄别结论：【已过时】作为设计基准整体归档；仅当新方向需要对照原版「功能形态 / 信息架构」（例如确认某个功能在原版中的入口位置）时偶尔翻阅。

---

## 四、word_app\docs\ 已有文档归类（11 份）

### 4.1 【仍然有效】（10 份）—— 星巴克新方向现行工作文档

| 文件 | 说明 |
|---|---|
| a11y_contrast_report.md | 星巴克新配色 WCAG 对比度验证 |
| dark_skin_strategy.md | 【重构5】深色模式/皮肤系统兼容策略（基于星巴克 DESIGN.md） |
| font_strategy.md | SoDoSans 替代字体策略（星巴克方向） |
| icon_plan.md | 【重构8】图标方案（星巴克方向） |
| motion_spec.md | 【重构7】动效规范（星巴克方向） |
| build_config_audit.md | 【重构10】构建与发布配置审计 |
| content_audit.md | 【重构12】词书数据抽检与应用内文案盘点 |
| qa_baseline.md | 重构前 QA 质量基线（commit 5f17e18；随重构推进需更新为绿色基线） |
| test_plan.md | 星巴克重构测试与验证计划（四条红线门禁） |
| vector_library_design.md | 预计算词向量库方案（干扰项引擎，功能向） |

### 4.2 【已过时】（1 份）

| 文件 | 说明 |
|---|---|
| DESIGN.apple-alpha.bak.md | 旧「Apple-alpha」方向完整设计规范；`.bak` 后缀已标明弃用，建议随其他旧资料一并归档 |

---

## 五、结论

### 5.1 新方向下真正值得保留的参考清单

**A. 功能 / 数据 / 技术类（D:\tools，15 份全效 + 12 份部分可用）**
- 全量保留 2.1 节 15 份：功能盘点、架构映射、数据库/网络/安全分析、v3.2/v5.0 逆向与方法论、主题接入审计。
- 部分可用 12 份按 2.2 节标注取用；其中以下**功能缺口**建议登记进重构待办（它们与视觉方向无关，属于真实欠账）：
  1. 底部工具栏五项功能未实现：沉浸刷词 / 随身听 / 听写 / 随手拼 / 导出；
  2. 单词详情：撤销按钮、拼写检查入口、笔记 Tab、音频/评论图标；
  3. 课程页数据硬编码、无轮播、无封面图；
  4. 外观页：缺主题实时预览、壁纸自定义、恢复默认；
  5. 响应式基础设施整改（contentWidth 未使用、页面绕过 resp.pageMargin）;
  6. 动画缺失项（选择反馈、翻卡、锁屏 TODO）；
  7. 平台级缺口：支付、推送、微信登录、锁屏平台通道。

**B. 星巴克现行文档（word_app\docs，10 份）**
- 除 DESIGN.apple-alpha.bak.md 外全部保留，是当前唯一有效的设计/质量依据。

### 5.2 建议归档的清单

| 归档对象 | 数量 | 理由 |
|---|---|---|
| D:\tools 像素还原类报告（2.3 节第一组） | 16 份 | 服务对象「不背单词像素级还原」已不存在 |
| D:\tools 历史编译/QA 快照（2.3 节第二组） | 3 份 | 状态失真，已被 qa_baseline.md 取代 |
| D:\tools\ui_review\ 截图目录 | 24 张 PNG | 像素基准失效；仅作原版功能形态偶发查阅 |
| DESIGN.apple-alpha.bak.md | 1 份 | 旧方向规范，已被星巴克 DESIGN.md 取代 |
| piracy_resources.md、awesome-piracy-readme.md | 2 份 | 与本项目无关的外部收藏，建议移出参考资料库另存 |

合计建议归档：**22 份 md + 24 张截图 + 2 份外部资料**。

### 5.3 执行提示（供决策，不在本任务内动手）

1. 归档可采用「移动至 D:\tools\_archive\（及 ui_review 整目录平移）」或在文件头追加 `> [ARCHIVED 2026-08-24] 星巴克方向下已过时，见 docs/reference_index.md` 的轻量标记；后者可保留文件名兼容旧引用。
2. 2.2 节「部分可用」文件不建议删除：其中的功能缺口清单与技术债清单在新方向下仍会被反复查询。
3. 若后续需要，可将 5.1 节 A 组功能缺口正式录入任务板拆分执行。
