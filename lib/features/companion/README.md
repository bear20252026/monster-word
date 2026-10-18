# companion —— 小怪兽的陪伴层

> 定位（业主定稿）：**一只记得你、与你共同完成词汇学习的小怪兽。**

## 为什么这里没有 VPet / N.E.K.O 的代码

业主曾要求「直接照搬这两个仓库的代码」。**技术上不成立**，原因不是许可，是语言：

| 项目 | 语言/形态 | 能否搬进本 App |
|---|---|---|
| [VPet](https://github.com/LorisYounger/VPet) | C# / WPF（`.csproj`） | ❌ Flutter 是 Dart，无法引用 .NET 程序集 |
| [N.E.K.O](https://github.com/Project-N-E-K-O/N.E.K.O) | Python 后端 + 大模型驱动 | ❌ 无法在移动/桌面 Flutter 里嵌 Python 进程，且它依赖联网与 API key |

两者都是 **Apache-2.0**：允许商用与修改，但要求保留版权声明、随分发附带许可证、
标注修改。若将来真要引入其代码或资源（如图标、动画帧），必须同时补齐
`NOTICE` 与许可证文本 —— 这是发版前必须过的检查项。

**本目录搬的是「结构」，不是源码**：VPet 的动画图与数据分离、N.E.K.O 的主动发起，
都是设计思想，用 Dart 从头写。这一点在代码注释里逐处标注了出处。

## 分层

```
core/utils/                    纯 Dart，零依赖（可脱机真跑断言）
  monster_event.dart           数据层 → 演出层的唯一通道（只报事实）
  monster_scene.dart           场景 + 调度参数表（优先级/时长/冷却/可打断）
  monster_initiative.dart      主动发起规则（不需要大模型）

features/companion/
  domain/monster_scene_graph.dart   场景图：事件 → 场景转移的三条判定规则
  application/monster_companion_port.dart  对外只读+窄写端口
  presentation/monster_companion_state.dart  ChangeNotifier 实现
  presentation/companion_feature_providers.dart  装配（app.dart [14]）

widgets/
  monster_presence.dart        全 app 唯一的怪兽浮层（挂在 MaterialApp.builder）
  monster_answer_signal.dart   页面报事实的唯一入口
```

### 怪兽只有一只：对应 VPet 的哪一层

| VPet（C#/WPF） | 本仓（Flutter） |
|---|---|
| `Display/Main.xaml`（唯一显示面，住在透明置顶窗口里） | `widgets/monster_presence.dart` 的 `MonsterPresence`，挂在 `MaterialApp.builder`，**位于 Navigator 之上** |
| `Handle/GameCore`（数据/状态） | `MonsterCompanionState` |
| `Graph/*`（动画图） | `MonsterSceneGraph` |
| `TalkBox.xaml`（气泡是独立窗口） | 浮层内的气泡 |
| 页面（与宠物无关） | 页面只调 `announceMonsterAnswer(context, correct:)` |

**页面一律不画怪兽。** 曾有过「首页 header 一只 96px + 学习页一只 32px + 复习页没有」的版本，
那不是宠物，是三份互不相干的贴图；换页还会重建、重放呼吸相位。
现在浮层在 Navigator 之上 ⇒ 换页不重建、任何页面都只有一只。
`test/widgets/monster_presence_test.dart` 用 `same(before)` 守住「跨路由仍是同一实例」。

### 为什么类型在 `core/utils/` 而不是 `domain/`

架构守卫（R4 / R-widgets）规定：**跨 feature 与 `widgets/` 共享层只能消费对方的
`application/` 层**。而 `widgets/monster_home_stage.dart` 需要 `MonsterScene` 与
`MonsterInitiativeInput` 这两个类型 —— 放在 `companion/domain` 会直接被守卫拦下。

本仓已有先例：`monster_speech` / `monster_bond_prefs` / `monster_rhythm` 都在
`core/utils/`。**怪兽的共享原语统一放 core，feature 里只放本 feature 自己的逻辑**
（这里只剩场景图）。

**单向数据流**（红线）：`domain` 只**读**事实、只**产**场景建议；
它不写任何持久化状态。奖励、羁绊、学习记录全部由各自的域负责。
这样「演出层无权改数据」是结构上成立的，而不是靠自觉。

## 三条调度规则（`monster_scene_graph.dart`）

1. **不可打断**：`interruptible == false` 且仍在演出中 → 谁都不能抢
2. **冷却**：距上次进入不足 `cooldown` → 不切（防「答错→提示→再答错」频闪）
3. **优先级**：当前仍在演出且优先级更高 → 不切

答对与抚摸**有意不产生场景切换**：页面本身已有反馈，演出层再抢一次会把怪兽
变成「点一下就抖一下」的玩具。陪伴的关键是「该出现时才出现」。

## 主动性为什么不用大模型

N.E.K.O 的主动性来自 LLM 驱动器，代价是：联网、延迟、API 费用、离线即废、
行为不可预测（无法写断言）。对背单词 App，规则版能满足需求且更好：
零延迟、可预测、可测试、离线可用。

规则见 `monster_initiative.dart`，产品红线写在文件头：**只用事实、久别只欢迎、
学过就不再催、没话说就闭嘴**。

## 下一步接入（尚未做）

- 主动性补两项事实：`daysSinceLastCheckin` / `daysSinceLastVisit`（需异步读 SP）
- 浮层位置：现在固定在右下角 Dock 上方，**不可拖动**（VPet 可拖动）；拖动/吸附留待后续
- 页面对「浮层遮挡」的适配：目前没有页面申请隐藏宠物（VPet 也没有，宠物始终在）
- 桌面常驻（Windows 真·桌面宠物窗口）：需另开无边框置顶窗口，属独立工程
