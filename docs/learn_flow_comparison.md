# D2 决策支撑：learn_page vs learn_session 对比裁决

> 【重构38】产出 · 2026-08-24 · 只读分析，未改代码。
> 依据：两文件全文逐行通读（lib/pages/learn_page.dart 362 行 / lib/screens/learn_session.dart 737 行）+ live_route_map.md 可达性图 + learning_state.dart 引擎接口 + ui_inventory/qa_baseline 结论。

---

## 一、功能矩阵

| 能力 | learn_page（4选1 答题流） | learn_session（Figma 浏览卡流） |
|---|---|---|
| 四选项答题 | ✅ 核心流程（_QuizArea，choices 由 LearningState 生成） | ❌ 完全没有答题交互 |
| 选错重选 | ✅ 标红 + Shake 抖动 + 提示文案切换（learn_page.dart:283-287） | ❌ 无 |
| 字典详情跳转 | ✅ 双通道：点词 WordLookupPopup(:188) + 答对后进 /word_detail(:281) | ⚠️ 仅 WordDictionaryPopup→/word_detail(:110-115)，弹窗组件本身挂在死链上 |
| SRS 调度接入 | ✅ **有条件评分**：答对才 `rate(RecallRating.good)`(:277)，信号真实 | ❌ **无条件评分**：每次「下一词」必 rate(good)(learn_session.dart:404)——SRS 数据污染源 |
| 发音 | ✅ 有道 dictvoice 在线发音(:199-208) | ❌ 无任何音频能力 |
| 收藏 | ✅ star 切换 toggleFavorite(:155-157) | ✅ 有，且带 await+setState 刷新(:265-268)，另多出「熟」标记 toggleMastered(:289-294) |
| 笔记入口 | ❌ more 按钮空实现(:159-163) | ⚠️ 仅 SegmentTabs 里一个「笔记」tab 标签(:31)，无内容实现 |
| 进度上报 | ✅ 进度条 + currentIndex/total + rate 驱动 LearningState | ⚠️ jumpTo(page) 支持滑动跳词(:91-95)，但评分失真（见上） |
| 统计埋点 | ➖ 无独立埋点（与全 App 一致） | ➖ 同左；另有假数据：点赞数写死 '1'(:143)、绿点掌握态写死(:130-137) |
| 动效完成度 | ✅ Shake 400ms/Bounce 300ms/TweenAnimationBuilder 进度条 | ✅ 更炫：PageView 弹性滑动、底栏 SpringCurve 滑入、AnimatedPositioned 下划线、渐隐页码点 |
| 内容丰富度 | ➖ 单词+音标+选项释义 | ✅ 音节分隔 in·stinct、美/英音标 pill、例句卡(ExampleParser 高亮)、派生词卡、SegmentTabs |
| 数据真实性 | ✅ 全部真实数据 | ❌ 派生词硬编码 mock（仅 instinct/nature/create/develop 4 词有数据，learn_session.dart:627-649）；撤销/abc拼写/more 三按钮空实现 |
| UI 星巴克改造量级 | **M ≈1 天**（ui_inventory 定级；换肤点：壁纸撤除、白玻璃选项卡→ContentCard、反馈色入令牌） | **L ≈2 天**（GlassBg 重做、6+ 处硬编码色 #4CAF50/#EBFFFBF0/#2FA89F/#E8913A、假数据治理另计） |

## 二、代码质量速评

| 维度 | learn_page (362行) | learn_session (737行) |
|---|---|---|
| 职责清晰度 | 高：TopBar/WordArea/QuizArea 三段私有组件，单一职责 | 中：内容展示堆叠在单个 build 的 PageView itemBuilder 里(:98-200)；混入 mock 数据层(:625-652)与自绘 Painter(:719-737) |
| 引擎耦合方式 | 相同：均只 watch LearningState（provider），经其代理 SRS；直接依赖仅 RecallRating 枚举(engine/srs_engine.dart)。耦合面一致，不构成取舍依据 | 同左，额外用了 jumpTo/queue/isMastered/toggleMastered 四个接口 |
| 已知问题 | qa_baseline 4 个 ERROR 均不在本文件（0 处提及）；硬编码 Colors.white×N 待换肤 | ui_inventory 判 L 级 ⚠️"近乎死路"；假数据+空按钮是产品级缺陷而非样式债 |

**质量小结**：两者都是"由账号4生成"的翻译件，风格相近。learn_page 胜在逻辑闭环真实可用；learn_session 胜在视觉信息架构完整，但一半功能是空壳或假数据。

## 三、引用关系（谁在导航链上）

```
活链（learn_page）：
  Tab1 HomeScreen → ReviewDialog「去学习」──pushNamed('/learn')──► LearnPage   [review_dialog.dart:129]
  Tab2 LibSelect「开始学习」────────pushNamed('/learn')──────► LearnPage       [lib_select_page.dart:296]
  LearnPage ──► WordDetailPage ['/word_detail']
  （uri_scheme_page:55 也指向它，但该页自身已判死）

死链（learn_session）：
  my_content(死,未接线) → my_fav(死) → learn_session   [live_route_map §二.A 收藏线]
  运行时唯一注册点 main.dart:148 '/learn_session'，全库零个活调用方
```

**删掉另一个会断什么：**
- **删 learn_session**：断零条活链——它的上游 my_fav 本身不可达，word_dictionary_popup 组件改挂 word_detail 即可保留；净删 737 行死代码。
- **删 learn_page**：**Tab1 复习弹窗和 Tab2 开始学习两个一级入口当场报路由错**（AOT 下 pushNamed 抛 onUnknownRoute）；必须同时改 review_dialog:129 与 lib_select_page:296 两处指向，且用户失去唯一可用的答题式学习。

## 四、裁决：留 learn_page，弃 learn_session

理由三条（不和稀泥）：

1. **可达性碾压**：learn_page 是双活入口的三级核心页面（Tab1 弹窗 + Tab2 主按钮直达）；learn_session 处于死链末端，上游起点本身未接线——为一个用户永远到不了的页面投入 L 级改造是纯浪费。
2. **SRS 数据诚实性是产品正确性问题**：learn_page 答对才评 good（主动回忆范式，信号可信）；learn_session 无条件每词评 good，一旦接线会把所有词标成"已记住"，间隔重复调度系统性失效。这不是审美取舍，是留谁谁正确。
3. **完成度与改造性价比**：learn_page 功能全真、无已知缺陷、M 级 ~1 天完成星巴克化；learn_session 三按钮空实现、核心内容靠 4 词 mock 撑场面，L 级 2 天之外还要先治理假数据。留旧弃新 = 0 迁移成本（live_route_map §三① 同此判断）。

### 若二期做"融合"，移植方向是 word_detail 而非学习流

learn_session 真正值钱的不是它的流程，而是三件内容展示资产。建议移植到 word_detail_page（学后详情页），移植清单：

| 移植项 | 来源 | 目标 | 工时 |
|---|---|---|---|
| 例句卡（ExampleParser 高亮+译文+来源） | learn_session.dart:100,:487-541 | word_detail 新增例句区 | ~0.5 天 |
| 美/英音标 pill + 音节分隔符 | :151-172,:443-461 | word_detail 词头区 | ~0.25 天 |
| SegmentTabs 骨架（笔记 tab 正好补全 learn_page 缺失的笔记入口） | :308-364 | word_detail 底部 tab 区 | ~0.5 天 |

合计 ~1–1.25 天；完成后删除 learn_session，净删 737 行。**一期不做融合也不影响主流程**。

## 五、对批 4a 工期的影响（execution_runbook）

| 方案 | 批4a 工期 | 连锁改动 |
|---|---|---|
| **本裁决（留 learn_page）✅** | 维持原估 **~2 天**不变 | 无入口改动；解锁收藏线决策——my_fav 将来复活后指向 review 流程即可，不再连带 learn_session；runbook 台账缺口 #2 关闭一半 |
| 反向（接 learn_session） | 膨胀至 **~3.5–4 天**（L 级换肤 + 选词逻辑迁移 + 假数据治理 + 两处入口改指） | review_dialog:129、lib_select:296 两处同步改；review 流程与学习流程交互范式不一致风险 |

> 一句话给用户拍板：**留 learn_page（现役答题流），learn_session 冻结并在二期删除；其例句卡/音标/笔记 tab 三个零件择机移植给 word_detail。**
