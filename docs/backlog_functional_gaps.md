# 功能缺口 Backlog：旧报告遗漏功能正式建档

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 来源：【重构9】参考资料甄别（docs/reference_index.md）中标记为【部分可用】的 12 份旧报告，提取其中与视觉方向无关的功能性缺口。
> 原则：只收录"功能/逻辑/数据"层面的欠账；像素还原类结论一律不再采纳。动画类条目统一以现行 docs/motion_spec.md 为准，本文仅登记"缺口存在"这一事实。
>
> 注：表中"来源报告"列引用的旧报告（标记 📦）已归档至 D:\tools\_archive 或已删除，无需查阅原文件——其发现已全部吸收至本表对应行。

---

## 一、字段说明

| 列 | 含义 |
|---|---|
| 编号 | GAP-xx，便于任务板引用 |
| 用户价值 | 高 = 直接影响核心学习/商业闭环；中 = 明显体验增益；低 = 锦上添花 |
| 实现难度 | S ≈ 0.5 天内；M ≈ 1–3 天；L ≈ 3 天以上或含平台/SDK 工作 |
| 是否依赖星巴克重构完成 | 是 = 建议随重构顺路做（UI 反正重做）；否 = 纯逻辑/平台能力，与重构正交；部分 = UI 顺路、核心逻辑正交 |

---

## 二、A 组：学习核心流程（单词详情 / 学习页）

来源：旧报告 ui_compare_word_detail.md（已归档，发现已吸收至本表）

| 编号 | 缺口 | 来源报告 | 影响页面 | 用户价值 | 难度 | 依赖重构？ |
|---|---|---|---|---|---|---|
| GAP-01 | 详情页第 5 个 Tab「笔记」缺失（现仅派生/词组搭配/词根/近义 4 个） | ui_compare_word_detail.md | learn_session / word_detail_page | 中 | M | 部分（Tab UI 顺路；笔记存储与编辑为正交逻辑） |
| GAP-02 | 学习导航栏「撤销 ↩」按钮缺失（误选答案无法回退） | ui_compare_word_detail.md | learn_session | 高 | M | 否（学习状态栈回退逻辑，按钮位随重构预留） |
| GAP-03 | 「abc」拼写检查按钮缺失（逐字母正误提示） | ui_compare_word_detail.md | learn_session | 中 | M | 否 |
| GAP-04 | 导航栏「更多 …」按钮缺失 | ui_compare_word_detail.md | learn_session | 低 | S | 是 |
| GAP-05 | 音标旁音频播放图标 🔊 缺失（发音为背单词刚需） | ui_compare_word_detail.md | learn_session / word_detail_page | 高 | S | 是 |
| GAP-06 | 释义关键词下划线标记缺失（加粗已实现，仅差标记样式） | ui_compare_word_detail.md | word_detail_page | 中 | S | 是 |
| GAP-07 | 例句右下角评论/笔记 💬 图标缺失 | ui_compare_word_detail.md | word_detail_page | 低 | S | 是（完整能力并入 GAP-01 笔记体系） |

## 三、B 组：底部工具栏五大功能

来源：旧报告 ui_compare_word_list.md §6–7、ui_polish_summary.md §5.2/P1（两处相互印证，均已归档）；形态参考 original_ui_analysis.md

| 编号 | 缺口 | 来源报告 | 影响页面 | 用户价值 | 难度 | 依赖重构？ |
|---|---|---|---|---|---|---|
| GAP-08 | 沉浸刷词未实现（全屏沉浸学习模式） | ui_compare_word_list.md / ui_polish_summary.md | home 底栏 | 高 | L | 部分（入口随底栏重构预留；核心体验需按星巴克方向重新设计） |
| GAP-09 | 随身听未实现（原版含基础/进阶双模式，后台播放列表） | ui_compare_word_list.md / monster_word_v5_resources.md | home 底栏 | 中 | L | 否（播放内核正交；入口 UI 顺路） |
| GAP-10 | 听写未实现（播报音频→输入校验） | 同上 | home 底栏 | 高 | M | 否 |
| GAP-11 | 随手拼未实现（字母乱序组词） | 同上 | home 底栏 | 中 | M | 否 |
| GAP-12 | 导出未实现（单词/学习记录导出分享） | ui_polish_summary.md | home 底栏 | 低 | S | 否 |

> 注：旧报告明确这五项"需产品确认"。在星巴克方向下是否保留全部五个入口、信息架构如何摆放，属产品决策，本表先按原版功能集登记。

## 四、C 组：外观与个性化

来源：ui_review_round2_appearance.md 第五节功能完整性检查

| 编号 | 缺口 | 来源报告 | 影响页面 | 用户价值 | 难度 | 依赖重构？ |
|---|---|---|---|---|---|---|
| GAP-13 | 主题切换缺实时预览 | ui_review_round2_appearance.md | appearance_page | 中 | M | 是（外观页即重构对象） |
| GAP-14 | 自定义壁纸上传缺失（相册选取→裁剪→持久化） | 同上 | appearance_page | 中 | M | 是 |
| GAP-15 | 恢复默认按钮缺失 | 同上 | appearance_page | 中 | S | 是 |

## 五、D 组：内容与数据

| 编号 | 缺口 | 来源报告 | 影响页面 | 用户价值 | 难度 | 依赖重构？ |
|---|---|---|---|---|---|---|
| GAP-16 | 词书封面为占位图，未加载真实封面资源 | ui_compare_word_list.md | word_book 相关页 | 中 | S | 是（素材位随 UI 重排落位） |
| GAP-17 | 课程页内容整体硬编码：无 Banner 轮播、无课程封面图、文案写死 | ui_review_round2_courses.md（重构9 附注）/ ui_compare_word_list.md | courses_page | 中 | M | 是（课程页 UI 将重做，数据层一并动态化） |
| GAP-18 | 原版内置词典类数据资产未接入：simple.db（简单词典 20.1MB）、wordroot.db（词根词缀 5.9MB）、xyjc.db（词根课程 856KB）、variant.db（变体 292KB） | monster_word_v5_resources.md | 词根 Tab / 查词 | 中 | M | 否 ⚠️ 数据取自原版 APK，需先做版权/合规评估 |
| GAP-19 | v5.0 新增功能未规划移植：自习室（音频学习中心+柯林斯查询）、剧集视频（中英字幕）、跟读评测（录音跟读+AI 评分+波形） | monster_word_v5_resources.md | 新页面×3 | 中 | L | 否（远期，需独立产品设计） |

## 六、E 组：交互基建（动画 / 响应式 / 令牌技术债）

来源：旧报告 review_animations.md、review_responsive.md、review_consistency.md（均已归档，发现已吸收至本表）。动画数值一律以 docs/motion_spec.md 为准。

| 编号 | 缺口 | 来源报告 | 影响页面 | 用户价值 | 难度 | 依赖重构？ |
|---|---|---|---|---|---|---|
| GAP-20 | 学习页卡片翻页动画完全缺失 | review_animations.md | learn_session | 中 | M | 是 |
| GAP-21 | 选项点击选择反馈动画完全缺失 | review_animations.md | learn_session | 中 | S | 是 |
| GAP-22 | SegmentTab 指示器无过渡动画 | review_animations.md | 设置/详情分段控件 | 低 | S | 是 |
| GAP-23 | 进度条无动画 | review_animations.md | 学习页 | 低 | S | 是 |
| GAP-24 | 已定义的自定义曲线全局未被使用（动画质感平庸）；另有页面视差滚动缺失（低优） | review_animations.md | 全局 | 低 | S | 是 |
| GAP-25 | 锁屏元素动画仅有框架，AnimationController 驱动逻辑为 TODO | review_animations.md / review_final_report.md §7 | lock_screen | 中 | M | 部分（依赖 GAP-28 平台通道落地后才有意义） |
| GAP-26 | 响应式基建欠账：①contentWidth/studyContentWidth 定义后从未使用；②lib/pages/ 下 20+ 页面绕过 resp.pageMargin 硬编码边距；③ScreenUtils 静态缓存不响应窗口尺寸变化；④AdaptiveScale 包裹整个 MainShell 存疑 | review_responsive.md 问题1–5 | 全局 | 中 | M | 否（机械改造，可独立分批执行） |
| GAP-27 | 令牌技术债：14 个页面未接皮肤系统、21 个组件硬编码颜色/字体（adapter_widgets 52 处字号、review_page 26 处颜色+14 处字号、dashboard_page/search_page/cell_widgets/card_widgets 等） | review_consistency.md §六 | dashboard / review / search 等 | 中 | M | 是（星巴克令牌迁移必须清偿，天然并入重构范围） |

## 七、F 组：平台能力

来源：旧报告 review_final_report.md §8.2「未完成/缺失模块」（已归档，该节为功能盘点，非视觉结论）

| 编号 | 缺口 | 来源报告 | 影响页面 | 用户价值 | 难度 | 依赖重构？ |
|---|---|---|---|---|---|---|
| GAP-28 | 锁屏功能 Android 平台通道未实现（native 层；旧报告标 🔴 高严重度，锁屏因此不可用） | review_final_report.md §8.2 | lock/（12 文件，完成度约 70%） | 高 | L | 否 |
| GAP-29 | 支付系统未实现（华为 HMS 支付） | review_final_report.md §8.2 | 商业化闭环 | 高 | L | 否 |
| GAP-30 | 推送通知未实现（友盟已被排除，需选型替代方案） | review_final_report.md §8.2 | 学习提醒/召回 | 高 | M | 否 |
| GAP-31 | 微信登录/分享未实现（wxapi 包未移植） | review_final_report.md §8.2 | 登录/分享 | 中 | M | 否 |
| GAP-32 | 锁屏上滑解锁的手势箭头指示图标缺失 | review_final_report.md §7 | lock_screen | 低 | S | 是 |

另：original_ui_analysis.md 记载原版首页有「签到卡片 + 签到日历」，当前 App 未见对应功能（GAP-33，用户价值中 / 难度 M / 否）——是否纳入星巴克方向由产品定夺，暂列远期池。

## 八、来源覆盖核对（12 份【部分可用】报告）

| 报告 | 贡献条目 | 备注 |
|---|---|---|
| original_ui_analysis.md 📦 | GAP-33；B 组形态佐证 | 仅取页面清单/功能项盘点 |
| review_consistency.md 📦 | GAP-27 | 技术债清单 |
| review_animations.md 📦 | GAP-20～25 | 数值让位 motion_spec.md |
| review_responsive.md 📦 | GAP-26 | 问题 3（平板专属布局）旧报告自评"不阻塞"，未单列 |
| review_final_report.md 📦 | GAP-25/28/29/30/31/32 | 仅取 §7/§8 功能部分 |
| ui_compare_word_list.md 📦 | GAP-08～12、16 | 工具栏五功能首次成文处 |
| ui_compare_word_detail.md 📦 | GAP-01～07 | |
| ui_polish_summary.md 📦 | GAP-08～12 佐证 | P1 结论与 word_list 一致 |
| ui_review_round2_appearance.md 📦 | GAP-13～15 | |
| monster_word_v5_resources.md 📦 | GAP-09 细化、18、19 | |
| monster_word_quality_check.md | — | 架构健康，无功能缺口（Provider/路由均正常） |
| monster_word_design_guide.md | — | 上一代设计规范，无功能缺口 |

> 📦 = 已归档（原报告已移至 D:\tools\_archive 或已删除），发现已吸收至本表，无需再查阅原文件。

---

## 九、与星巴克重构的关系总览

**顺路型（重构期间同步清偿，错过就要二次返工）：**
GAP-04/05/06/07（详情页元素）、GAP-13/14/15（外观页）、GAP-16/17（封面与课程页）、GAP-20/21/22/23/24（交互动画，规格以 motion_spec.md 为准）、GAP-27（硬编码清偿=令牌迁移本身）、GAP-32。

**正交型（纯逻辑/平台能力，与重构并行推进互不阻塞）：**
GAP-02（撤销）、GAP-03（拼写检查）、GAP-10/11/12（听写/随手拼/导出）、GAP-09 播放内核、GAP-26（响应式）、GAP-28/29/30/31（锁屏通道/支付/推送/微信）、GAP-18（数据资产，先过合规）、GAP-33。

**混合型：** GAP-01（笔记 Tab：UI 顺路、存储正交）、GAP-08（沉浸刷词：入口顺路、体验重设计）、GAP-25（锁屏动画依赖 GAP-28）。

## 十、建议实施批次

**第一批 · 重构期间/收尾顺路（约 15 项，多为 S/M）**
GAP-04、05、06、07、13、14、15、16、17、20、21、22、23、24、27、32
> 特征：都在即将被星巴克重构触碰的页面/组件上；其中 GAP-27 与令牌迁移是同一件事的两面，必须绑定执行。

**第二批 · 重构完成后第一波（学习体验补全，约 8 项）**
GAP-01（笔记存储）、GAP-02（撤销）、GAP-03（拼写检查）、GAP-10（听写）、GAP-11（随手拼）、GAP-12（导出）、GAP-26（响应式整改）、GAP-30（推送，先做选型）
> 特征：不依赖新 UI 定稿，重构期间即可提前启动设计与接口准备；上线即可感知。

**远期池（需产品决策或外部依赖，约 8 项）**
GAP-08（沉浸刷词，需按新方向重定义体验）、GAP-09（随身听）、GAP-18（词典数据资产，⚠️ 先过版权评估）、GAP-19（自习室/剧集视频/跟读评测三件套）、GAP-28（锁屏平台通道——若锁屏仍定位为核心卖点则提级）、GAP-29（支付）、GAP-31（微信登录/分享）、GAP-33（打卡签到）。

---

*本文档由【重构24】建立，后续缺口状态变化请直接更新对应行并在行尾追加日期备注；新增缺口沿用 GAP 编号递增。*
