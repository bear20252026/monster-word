# 「Boss 战复习」设计稿（围城 v1）

> 状态：**v1 已实施**（PR #127，`feat/2026-10-05-boss-siege`：围城条带 + 守成庆典 + 阈值单源）；v2 头目波次、v3 图鉴联动未做。
> 实施与设计稿的一处偏离（更好的方案）：**没有做「击退」沿检测，也不需要新状态**——击退数就是协调层已有的
> `done`，而 `done` 由答题与「标记已掌握」两条路径共同递增，用它直接驱动敌列，两条路径天然都掉怪。
> 第三节其余两条口径（敌军数只认会话 `total`、全清判定用 `currentWord == null`）按稿执行。
> 锚点全部按 main `3ecc494`（v2.12.2+128）实地 grep 核对过。
> 上游叙事见《史诗化设计蓝图》「怪兽宇宙」W5 与二档提案；本文只解决"怎么在现有复习链路上落，且不踩守卫"。

## 一、要解决的问题

复习是这款 App 里唯一「义务感 > 成就感」的页面：到期 12 个词，用户看到的是一行红字和一个数字。
而情绪曲线测出来的规律是——**凡有「弹道 + 受体」的地方都是高峰，凡只改数字的地方都是低谷**。
围城把积压翻译成每个玩家都懂的叙事：门口围着 N 只捣蛋兽，答对一题击退一只，全清 = 守城成功。

配合已有的心情机（`monster_mood.dart:43` 的 `dueCount >= 40 → worried`、`:110-111` 的
`dueCount >= 20 → SpeechSlot.needReview`），世界观完全自洽，**不需要新增任何情绪设定**。

## 二、四条不可动的红线

1. **捣蛋兽不是被杀死的，是被击退回雾岭**——只有变好，没有变坏，怪兽永不死（取 Finch/旅行青蛙的无愧疚路线）。
   文案禁用「消灭/击杀/干掉」，用「击退/送回/赶回雾岭」。
2. **积压多只表达"担心"，绝不羞辱**——`needReview` 槽现有文案已守此线，围城文案组沿用同口径。
3. **零账务**。本特性不碰 `ScareCoinStore` 任何方法、不发币、不改日封顶口径；
   金币发放仍只在 `review_session_state.dart:106` `rate()` 的既有路径上。
   这条同时绕开了蓝图遗留的产品未决问题（复习奖励是否与学习共用日封顶），v1 不阻塞。
4. **进化/守护成果绝不与金币挂钩**，只与实际击退数（= 真实复习量）挂钩。

## 三、口径：两个"到期数"不是同一个数（最大的坑）

| 数字 | 来源 | 语义 | 围城怎么用 |
|---|---|---|---|
| `dueCount` | `review_schedule_repository.dart:112`（全词书 SQL 聚合，随评分增量维护） | 全局积压 | **首页入口叙事**：「门口围着 37 只」 |
| 会话队列长度 | `ReviewQueueState.snapshot.dueWords.length`，经 `dueWordsFor`/`dueWordsForAsync`（`:169`）从**当前词表子集**里筛 | 本场要打几只 | **HUD 敌军数与进度**：总数 = 会话 `total` |

词表是子集时 `dueCount > 队列长度`。两个数若混用，HUD 会出现「12 只敌人 / 进度 3/30」这种当场穿帮。
**规则写死：HUD 只认会话 `total`；首页叙事只认 `dueCount`；两者永不并列显示在同一屏。**

「击退一只」有两个计数入口，只挂一个会穿帮：

- `review_session_state.dart:106` `rate(RecallRating)` —— 正常答题（含答对与答错后的重答）
- `review_session_state.dart:128` `markAsKnown()` —— 「我认识这个」，**有意不写 FSRS 评分**（`:124-127` 注释），但 `done` 同样 +1

只挂 `rate()` 的话，点「熟」不掉怪，用户三轮内就会看穿这套叙事是贴皮。**两处都要掉怪**，
掉怪条件统一取「`done` 增加」这一条沿，而不是去区分答对/标记熟。

## 四、v1 切片边界

**做**：围城档位（纯函数）、HUD 敌军列 + 击退进度、答对掉怪动效（复用现成原语）、全清守城庆典 + 第四刻发声。
**不做**（明确留给后续）：波次/头目 AI、捣蛋兽独立形象（v1 用 `MonsterIcon` 换 `bodyColor` + 小屋现有 painter 参数
`mouthOpen/bellyScale/cheekPuff` 驱动；**注意 `MonsterIcon` 没有 `pupilOffset/blink/hop`**，那三个是
`monster_room_painters.dart` 的私有画笔，不可跨用）、任何新音效资产（14 个合成 SFX 已够用）、任何新持久层
（战斗状态 100% 由会话派生，退出即散，不留档）。

## 五、挂载点（已核对）

| 环节 | 位置 | 做法 |
|---|---|---|
| 掉怪沿检测 | `widgets/formal_review_question.dart:130` 已有 `if (widget.correctRevealed && !oldWidget.correctRevealed)` 先例 | 同型写法改为监听 `done` 变化，驱动一只敌人淡出 |
| HUD | 新建 `widgets/boss_siege_header.dart`，由调用方**纯入参**传 `total/defeated` | 见第六节第 3 条硬约束 |
| 全清判定 | `formal_review_page_content.dart` 的 `formalReviewPagePhase()`：完成态由 `session.currentWord == null` 决定，**不是 `done == total`** | 沿此口径，避免中途队列变化导致庆典不触发 |
| 守城庆典 | `widgets/formal_review_state_views.dart:77` `FormalReviewCompleteView`（`:84` build），纯入参、零 Provider | `ConfettiOverlay`（`direction: explosion`）+ `Sfx.milestone` + `HapticCue.heavy` + `MonsterVoice.system.say(MonsterSpeech.pick(SpeechSlot.milestone, vars:{...}))` |
| 文案 | `monster_speech.dart:33` `SpeechSlot.needReview`、`:62` 变量名单源（含 `{due}` `{name}`） | **不新增槽**；确需围城专属文案时，先扩该槽文案组，别开第 9 个槽 |

## 六、守卫硬约束（改错形态必红灯）

1. **展示组件不得读会话状态**：`app_structure_test.dart:550` 断言 `formal_review_header.dart` /
   `formal_review_session_layout.dart` / `formal_review_question.dart` 源码里不得出现 `ReviewSessionState` 字样。
   → HUD 必须由持有会话的调用方算好 `total/defeated` 传参；把 `context.watch<ReviewSessionState>()` 写进组件即红。
2. **禁 emoji**：`emoji_hygiene_test.dart` 对 lib 非注释行零容忍（含 U+1F000-1FAFF、2600-27BF）。
   「围城」文案一个 emoji 都不能有，图形一律走 `Icons.*` / `MonsterIcon`。
3. **禁裸色**：`color_hygiene_test.dart` 零容忍，敌对配色须具名进 `lib/tokens/effect_palette.dart`。
4. **透明度**用 `.withValues(alpha: AppAlphas.x)`，档位值写数字会被 `alpha_hygiene_test` 拦。
5. **圆角**走 `context.design.radius`；`radius_hygiene_test` 棘轮上限 3，只减不增。
6. **时长字面量**：`motion_hygiene_test` 只管命名参数 `duration/delay/transitionDuration/reverseDuration`
   且命中档位 `{150,200,300,450,700,2800}` 才拦；自定义非档位时长（掉怪淡出这类）安全，
   照 `monster_peek_overlay.dart` 的既有做法并留注释说明为何不落档位。
7. **体积**：lib 单文件 ≤900 行、presentation `build()` ≤120 行（`code_style_guard_test`），白名单已清空，
   新违规不得进清单。
8. 音效/触觉只能走 `SfxPlayer.fire` / `HapticsGate.play` 唯一出口；`review_page.dart` 源码不得出现
   `LearningState`/`SuperMemoryEngine`/`ReviewQueueReader`/`ChoiceGenerator`/`sl<AudioService>()`（`app_structure_test.dart:506-514`）。

## 七、分期

- **v1（本文范围）**：围城档位纯函数 + HUD + 掉怪 + 全清庆典 + 第四刻发声。零新资产、零账务、零持久层。
- **v2**：头目波次——积压 ≥40（= `worried` 阈值，与心情机同数）时出现一只大头目，清完队列才退；档位与心情机共用一个阈值源，避免两处各写一个 40。
- **v3**：与词书图鉴联动（记忆兽/守护兽），届时再谈美术资产，不提前建抽象。

## 八、验收口径（不许虚报）

- 四道门禁全绿：`dart format --set-exit-if-changed`、**裸 `flutter analyze`**（CI 用的就是不带
  `--no-fatal-infos` 的版本，info 级也熔断）、`flutter test test/architecture/`、全量 `flutter test`。
- 新纯函数与 HUD 各带测试；装配范式照 `test/features/quick_review/presentation/exam_quick_review_page_test.dart`
  的「application 端口 Fake + `Provider<T>.value` + MaterialApp.home」；纯入参组件对齐
  `test/features/learning/presentation/formal_review_page_content_test.dart` 的零 Provider 风格。
- **必须覆盖的回归点**：`markAsKnown()` 也掉怪；`dueCount` 与会话 `total` 不同时屏；中途队列变化时全清仍触发。
- **装机实测**（Windows + Android 覆盖安装）未完成前，本特性不得称「已验收」——发声与掉怪手感都是自动化测不到的部分。

## 九、并发提醒

本仓同一工作树可能被多个会话同时占用（`scripts/auto_sync.sh` 每小时只在 main 上提交）。
实施前必须 `git branch --show-current` + `git fetch` 核对基线；checkout 停在他人分支上时不要在此 `git add lib/ test/`。
