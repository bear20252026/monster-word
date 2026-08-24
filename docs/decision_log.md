# 设计决策日志（Decision Log）

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 维护人：DocWriter
> 用途：追踪所有已决/待决设计决策，为 Batch 3–6 实施提供权威依据
> 更新规则：每项决策标注状态（✅ 已决 / 🔶 待决）、决策日期、依据文档、影响范围

---

## 一、已决事项

### D1: 死页面冻结——仅改造 13 个活页面

| 字段 | 内容 |
|---|---|
| 决策内容 | ~25 个死路由页面（⚠️/❌标记）默认冻结不动，只保编译；仅改造 13 个可达活页面 |
| 决策依据 | ui_inventory.md §五.1：班级线/听力线/拼写线/收藏线均未接入主路径，改造属浪费工时 |
| 决策日期 | 2026-08-24（execution_runbook §四 缺口1 兜底方案） |
| 影响范围 | 批4 范围缩减：4a(main_shell+home+learn+review) / 4b(word_detail+lib_select+profile) / 4c(appearance+more_settings+splash+login) |
| 状态 | ✅ 已决（默认冻结，Lead 可随时追加"接线"裁决解冻个别页面） |

### D2: 保留 learn_page，弃 learn_session

| 字段 | 内容 |
|---|---|
| 决策内容 | 学习流程保留 `learn_page.dart`（4选1答题），废弃 `learn_session.dart`（Figma 03a 版） |
| 决策依据 | ui_inventory.md §3.1：learn_session 仅 `/my_fav → learn_session` 链路可达，而 my_content 本身未接线 → 实际近乎死路；与 learn_page 功能重叠 |
| 决策日期 | 2026-08-24（ui_inventory Top10 备注） |
| 影响范围 | 批4a 学习流改造只改 learn_page；learn_session 冻结不改 |
| 状态 | ✅ 已决 |

### D3: word_machine 复古风格豁免

| 字段 | 内容 |
|---|---|
| 决策内容 | `word_machine_page.dart` 的 Game Boy 复古配色（C0x×15）豁免于星巴克色板迁移 |
| 决策依据 | ui_inventory.md §五.3：刻意复古配色是设计语言的一部分，建议豁免或单独主题化 |
| 决策日期 | 2026-08-24（execution_runbook §四 缺口6，默认按建议豁免） |
| 影响范围 | 批4 硬编码清零口径排除 word_machine；其余页面 C0x 必清 |
| 状态 | ✅ 已决（Lead 一句话确认即可正式生效） |

### D4: 工具栏五功能保留原形式

| 字段 | 内容 |
|---|---|
| 决策内容 | 底部工具栏五功能（沉浸刷词/随身听/听写/随手拼/导出）保留原版功能形态，入口 UI 随底栏重构预留 |
| 决策依据 | backlog_functional_gaps.md §三：旧报告明确"需产品确认"；execution_runbook 默认按 ui_inventory Top10 取现役可达页 |
| 决策日期 | 2026-08-24 |
| 影响范围 | 五功能为 GAP-08~12，属远期 backlog，不纳入批3–6 范围；底栏重构时预留入口位 |
| 状态 | ✅ 已决（产品未确认前按原形态保留） |

### D5: 词典版权——推荐 ECDICT 替换

| 字段 | 内容 |
|---|---|
| 决策内容 | 现有词典数据（simple.db/wordroot.db 等取自原版 APK）需版权/合规评估；推荐替换为开源 ECDICT |
| 决策依据 | content_audit.md §1.5 + backlog_functional_gaps.md GAP-18：原版内置词典数据资产未接入，⚠️ 需先做版权/合规评估 |
| 决策日期 | 2026-08-24 |
| 影响范围 | 词根 Tab / 查词功能；数据层独立于视觉重构，可正交推进 |
| 状态 | ✅ 已决（推荐方案，实施时间待定） |

### D6: 设计方案 C——画布归品牌，装饰归个性

| 字段 | 内容 |
|---|---|
| 决策内容 | 采用方案 C：画布（pageBg）归品牌统一（奶油 #F2F0EB），壁纸/渐变等装饰功能从画布层移除；个性化可降级到卡片/头像等非画布层 |
| 决策依据 | dark_skin_strategy.md §二 矛盾分析：星巴克规范中奶油色是品牌资产，壁纸机制与之本质冲突；execution_runbook 批2 明确"画布归品牌" |
| 决策日期 | 2026-08-24（execution_runbook 批2 描述） |
| 影响范围 | home_screen/learn_page/review_page 三处撤壁纸渲染改 skin.pageBg；壁纸选择页冻结 |
| 状态 | ✅ 已决 |

### D7: 字体——Inter 替代 SoDoSans

| 字段 | 内容 |
|---|---|
| 决策内容 | 主无衬线字体采用 Inter（已捆绑 400/500/600/700）替代星巴克 SoDoSans；中文回退链 苹方→微软雅黑→Noto Sans SC |
| 决策依据 | font_strategy.md §0/§1.3：Inter 与 SoDoSans 形似度最高、零迁移成本、大字号表现最强、中文搭配最好 |
| 决策日期 | 2026-08-24 |
| 影响范围 | 全局；`lib/tokens/design_tokens.dart` 补 fontFamilyFallback；纯西文 token 补 letterSpacing |
| 状态 | ✅ 已决 |

### D8: 动效——scale(0.95) + 150ms standardCurve

| 字段 | 内容 |
|---|---|
| 决策内容 | 按压反馈统一 scale(0.95)，时长收敛至 150ms（fast 档），曲线用 standardCurve 双向同曲线；全局动效分四档 fast/base/slow/expressive |
| 决策依据 | motion_spec.md §4.1/§4.4：星巴克 --buttonActiveScale 0.95 + 0.2s ease；收敛至 Token 消除散乱裸数值 |
| 决策日期 | 2026-08-24 |
| 影响范围 | ScaleDownOnPress 升级（pressable_inventory §5）+ 292 处交互靶点逐步包装 |
| 状态 | ✅ 已决 |

### D9: 图标——Material Icons Outlined 优先

| 字段 | 内容 |
|---|---|
| 决策内容 | 全站统一采用 Material Icons Outlined 家族为基线；激活态切 Filled 同名图标；Rounded 家族禁入常规 UI；9 个自定义 SVG 死资产删除 |
| 决策依据 | icon_plan.md §二/§五：388 处 Icons 调用中 Outlined 占主导，Rounded 混排造成双轨风格 |
| 决策日期 | 2026-08-24 |
| 影响范围 | 69 个文件的图标引用收敛；底部导航激活色 #1F1F1F→#00754A |
| 状态 | ✅ 已决 |

### D10: 新旧流程二选一——默认取现役可达页

| 字段 | 内容 |
|---|---|
| 决策内容 | learn_page↔learn_session、settings↔more_settings、ui_theme_select↔appearance 三对新旧实现，默认按 ui_inventory Top10 取现役可达页改造 |
| 决策依据 | ui_inventory.md §五.2 + execution_runbook §四 缺口2 |
| 决策日期 | 2026-08-24 |
| 影响范围 | 批4 范围：learn_page ✅ / learn_session 弃；more_settings ✅ / settings 弃；appearance ✅ / ui_theme_select 弃 |
| 状态 | ✅ 已决（Lead + 产品可随时覆盖） |

---

## 二、待决事项

### L1: Lora 衬线字体是否引入

| 字段 | 内容 |
|---|---|
| 待决内容 | 成就/奖励场景是否引入 Lora 衬线字体（替代 Lander Tall），还是直接复用已捆绑的 Charter |
| 背景 | font_strategy.md §5：Lora 暖调最贴近星巴克 Rewards 仪式感，但需新增 ~500KB 字体资产；Charter 零成本但气质偏"正文" |
| 影响范围 | 成就弹窗标题、徽章名、奖励横幅的标题层；不影响正文 |
| 阻塞批次 | 批3 组件层（GoldPillBadge 标题字体）/ 批4b profile_screen 成就区 |
| 建议 | 零成本方案先用 Charter 验证视觉方向，再决定是否引入 Lora |
| 状态 | 🔶 待决 |

### L2: glassBg 模糊效果是否保留

| 字段 | 内容 |
|---|---|
| 待决内容 | 现有 glass_widgets.dart 的毛玻璃拟态效果（BackdropFilter blur）是否保留，还是替换为星巴克实色卡片 |
| 背景 | dark_skin_strategy.md §1.3：壁纸机制与画布归品牌冲突；glass_widgets 消费壁纸层做模糊，壁纸撤除后玻璃拟态失去基底 |
| 影响范围 | home_screen 打卡卡（GlassEntryCard）、GlassPill 胶囊钮；review_session 已引用 glass_widgets |
| 阻塞批次 | 批4a（首页+复习页改造） |
| 建议 | 方案 C 已决定画布归品牌，glassBg 大概率需替换为 ContentCard 实色白卡；但 review_session 的玻璃底板可保留作为过渡 |
| 状态 | 🔶 待决 |

### L3: pure_black 主题是否保留

| 字段 | 内容 |
|---|---|
| 待决内容 | 现有「极夜」纯黑主题（#040404）是否保留，还是统一为星巴克深色（#101B17 深绿黑） |
| 背景 | dark_skin_strategy.md §1.1：三套皮肤中 pure_black 是 OLED 向旧视觉遗产，与星巴克绿色体系无关 |
| 影响范围 | 深色模式用户；appearance_page 主题选择器 |
| 阻塞批次 | 批2 Token 层（新增 starbucks_cream/starbucks_dark 预设） |
| 建议 | 星巴克深色（#101B17）已覆盖 OLED 场景（近纯黑），pure_black 可废弃；但需确认是否有用户偏好纯黑 |
| 状态 | 🔶 待决 |

### L4: 词书封面可选图形升级

| 字段 | 内容 |
|---|---|
| 待决内容 | 词书封面是否升级为 8% 透明白色书本轮廓图形（品牌化），还是保留现有占位图 |
| 背景 | backlog_functional_gaps.md GAP-16：词书封面为占位图，未加载真实封面资源；content_audit.md §1.5：books.name 191 本全等于 code，封面文字仅做了前缀剔除 |
| 影响范围 | lib_select_page 词书卡、books_page 书籍卡 |
| 阻塞批次 | 批4b（lib_select_page 改造） |
| 建议 | 短期先解决 name=code 的内容硬伤（映射表补全），封面图形作为品牌资产在批5 一并处理 |
| 状态 | 🔶 待决 |

---

## 三、决策依赖关系

```
D6(画布归品牌) ──→ L2(glassBg) ──→ 批4a 首页/复习页方案
D7(Inter字体)  ──→ L1(Lora)    ──→ 批3 GoldPillBadge / 批4b 成就区
D1(死页面冻结) ──→ D2(弃learn_session) ──→ 批4a 范围锁定
D3(word_machine豁免) ──→ 批4 硬编码清零口径
L3(pure_black) ──→ 批2 Token 层预设数量
```

---

## 四、更新记录

| 日期 | 变更 |
|---|---|
| 2026-08-24 | 初始版本：9 项已决 + 4 项待决，从既有文档（execution_runbook / ui_inventory / font_strategy / motion_spec / icon_plan / dark_skin_strategy / backlog_functional_gaps / content_audit / reference_index）提炼 |
