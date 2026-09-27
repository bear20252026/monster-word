# 第二阶段施工执行手册（Execution Runbook）

> 【重构26】产出 · 2026-08-24 · 总规划师编排，供队长直接调度。
> 输入：starbucks_migration_plan / font_strategy / dark_skin_strategy / motion_spec / icon_plan / a11y_contrast_report / **test_plan(G1–G5)** / **ui_inventory(58页底册)** / component_spec(PillButton·ContentCard·FrapFab 已带代码) / branding_assets_plan / release_pipeline(v2.0.0 锚点策略)。
> 分支策略：从绿色基线拉出 `refactor/starbucks` 长分支；每批一个独立 PR 合入该长分支并在合并点打 tag；**只有批5 完成后才把 refactor/starbucks 整体合回 main**（对齐 release_pipeline §4：合入点即 v2.0.0）。回滚单位 = 批（revert 该批的 merge commit，禁 force-push）。

---

## 一、批次总表

| 批次 | 任务 | 前置依赖 | 并行度 | 验收门禁（test_plan） | 预估规模 |
|---|---|---|---|---|---|
| **批0 绿基线** | 修 4 个 ERROR(class_checkin×2+word_machine×2)、修 word_machine 测试加载、修 windows debug 构建 | 无（QA 已在办） | 单人串行 | 第一段 **G1–G4 全绿**，QA 更新 qa_baseline.md，打 tag `b0-green` | 0.5–1 天 |
| **批1 架构债** | ①拆分「Material 亮度」与「状态栏亮度」两字段（dark_skin_strategy §1.2-3 过载）②themeId 写 SharedPreferences③"跟随系统"真接线(platformBrightness 监听)④壁纸初始闪变修复(beachWallpaper→读持久化) | 批0 | 主线1人；**并行轨**：Lead 同步裁决死页面「接线or冻结」(ui_inventory §五.1)；QA 搭 golden 目录骨架(test_plan §2.1) | G1′–G4′ + 三主题来回切目检不串味；tag `b1-arch` | 1 天 |
| **批2 Token 层** | themes map 新增 `starbucks_cream/starbucks_dark` 两预设（值按迁移计划§一映射表）；设为默认；**画布归品牌**：home_screen:36/learn_page:36/review_page:104-162 三处撤壁纸渲染改 skin.pageBg（方案C） | 批1（亮度拆分是硬前置，否则新预设 ColorScheme 反转） | 主线1人；**并行轨**：图标组按 icon_plan 清 9 个死 SVG + 底部导航 Outlined→Filled 映射表落地准备（只备不改）；SpecWriter 补 StarSheet/StarHeader 手册 | G1′–G4′ + golden 首批入库(skin_system 消费方≥2态) + 冒烟3.2/3.6 抽查；tag `b2-token` | 1–1.5 天 |
| **批3 组件层** | 按 component_spec.md 实现 **PillButton / ContentCard / FrapFab**（代码已给出，落 lib/widgets/sb/），按压统一复用 widget_utils 的 ScaleDownOnPress(scale .95)+Curves.ease 200ms(motion_spec §2)；AppButton 内部切到 PillButton 或标注废弃 | 批2（组件取色走新 ThemeVars） | 主线1人；**并行轨D**：设计产 icon_master_1024.png(绿底白M怪物)→flutter_launcher_icons 干跑验证(branding §1.3)；QA 写组件 golden | G1′–G4′ + 组件 golden 全绿 + grep 全部使用方页面过六项检查单；tag `b3-components` | 1.5–2 天 |
| **批4 页面层·3小批** | **4a 框架+核心学习流**(main_shell+home_screen+learn_page+review_session)：底栏绿激活/白玻璃→奶油实心、FrapFab 上岗「开始学习」、答题反馈色入令牌；**4b 内容与货架**(word_detail+lib_select+profile_screen)：profile 金渐变头部重做(C0x×24 清零)、word_detail 富排版套 ContentCard；**4c 门面与设置**(appearance+more_settings+splash/login)：appearance 注册新预设选择器、弹窗奶盖化、启动登录品牌色 | 批3 + Lead 死页面裁决（决定 4 批范围） | 每小批主线1人顺序做；**小批间可双线**：4b 与 4c 由第二人力并行走独立子分支；文档组同步拍 before 截图存档(test_plan §2.3) | 每小批 G1′–G4′ + 对应冒烟条目(3.1/3.2/3.3…) + 六项手动单 + before/after 成对归档；tags `b4a/b4b/b4c` | 4a≈2天 4b≈2.5天 4c≈1.5天 |
| **批5 品牌资产** | flutter_launcher_icons 正式跑三平台；launch_background 双模式 XML+values-v31(windowSplashScreenBackground)；四处应用名统一(MonsterWord.exe/android:label/Runner.rc/窗口标题)；INTERNET 权限；删 just_audio；version→2.0.0+2——**全部同一 PR**(release_pipeline §4) | 批4 全部合入 + icon_master 就位 | 主线1人；**并行轨**：QA 预填发布检查单(release_pipeline §3)A/B 组 | G1′–G4′ + 发布检查单A/B 全勾；合入 refactor 主干即打 **tag `v2.0.0-rc1`** | 0.5–1 天 |
| **批6 全量回归** | G1–G5 全量 + 冒烟 3.1–3.6 全走(首装+升级双路径) + 三主题×关键页截图矩阵 + issue 台账收尾对比 368 基线 + 高危区三 service 若被动过补专项(test_plan §5) | 批5 | QA 主导，主线待命修缺陷 | 五门禁+冒烟全绿 → refactor/starbucks 合回 main，merge commit 打 **`v2.0.0`** | 1 天 |

合计 ≈ 8–9 人日主线；双人力并行下约 6–7 个自然日。

## 二、谁先谁后（关键路径）

```
批0 ──→ 批1 ──→ 批2 ──→ 批3 ──→ 4a ──→ 4b ──→ 4c ──→ 批5 ──→ 批6
 │        │        │        │        ↑(Lead死页面裁决须在批1末给出)
 │        └─并行:死页面裁决/golden骨架   ├─并行:icon_master设计(D轨,批3起)
 │                 └─并行:SVG清理/组件手册└─并行:4b∥4c(双人时)
```
- **硬前置链只有一条**：批0→批1→批2（亮度语义不拆，Token 层必然返工）。
- 批3 起，页面层与资产/文档轨道完全解耦，可双班倒。
- main_shell 必须与 home/profile 同一小批合入（ui_inventory Top10 备注：Tab 框架先行换装，避免半旧半新观感）。

## 三、回滚点设计

| 时点 | 动作 | 回滚方式 |
|---|---|---|
| 批0 完成 | tag `b0-green`（基线锚点，永久保留） | 一切灾难最终退路 |
| 每批合入 | refactor/starbucks 上打 `bN-xxx` tag + 该批单 PR | 出问题 `git revert -m 1 <该批merge>`，禁止 reset/force |
| 页面小批 | b4a/b4b/b4c 各自 tag | 可单独 revert 单页小批而不牵连他批 |
| 用户可见面 | 批5 前所有改动仍可通过切回旧皮肤预设兜底（ThemeVars 架构保留旧 bright/dark 不删，迁移计划风险5） | 运行时回滚，无需发版 |
| 发布 | `v2.0.0-rc1`(批5) → `v2.0.0`(批6 后 main) | rc 发现致命问题：revert 批5 PR 重打 rc |

## 四、等待中的信息缺口（阻塞点台账）

| # | 缺口 | 阻塞哪些批 | 责任方 | 兜底 |
|---|---|---|---|---|
| 1 | **~25 个死路由页面的「接线 or 冻结」裁决**（班级线/听力线/拼写线/收藏线，ui_inventory §五.1） | 批4 范围与工期（若全接线，4b/4c 各 +2 天） | **Lead，批1 结束前必须给** | 未裁决前默认冻结不动，只保编译 |
| 2 | 新旧流程二选一（learn_page↔learn_session、settings↔more_settings、ui_theme_select↔appearance） | 批4a/4c | Lead + 产品判断 | 默认按 ui_inventory Top10 取现役可达页改造 |
| 3 | component_spec「待增补」清单（StarSheet/StarHeader/进度条/开关手册） | 批3 后半、批4c 弹窗批量改造 | SpecWriter | 缺失则批3 只交付三主件，弹窗沿用现样式延后 |
| 4 | icon_master_1024.png 母版图（需设计/AI 生图） | 批5 全部 | 设计轨（批3 期间交付即可） | 缺失则批5 降级为先做启动屏+应用名，图标顺延 |
| 5 | 批0 完成时间（当前 4 ERROR 修复进度） | 全部（串行源头） | QA | 若 >2 天未绿，Lead 考虑加人或由主线代修 |
| 6 | word_machine_page 复古配色豁免确认（C0x×15 刻意 Game Boy 风） | 批4 硬编码清零口径 | Lead 一句话确认 | 默认按 ui_inventory §五.3 建议：豁免 |
| 7 | Android12+ 启动屏 v31 与 iOS LaunchImage 是否纳入本期 | 批5 范围 | Lead | 默认纳入（branding §2 已给全套写法） |

## 五、验收口径（全文一句话版）

每批合入必过 G1(ERROR=0)/G2(issue≤368 且不回升)/G3(test 全绿)/G4(build 成功)，页面批加 G5 冒烟与 before/after 归档；批6 收官时五门禁+冒烟 3.1–3.6 全绿、issue 台账对比基线归档，refactor/starbucks 合回 main 打 `v2.0.0`。
