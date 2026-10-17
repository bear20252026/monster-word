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
domain/                     纯 Dart，零依赖（可脱机真跑断言）
  monster_event.dart        数据层 → 演出层的唯一通道（只报事实）
  monster_scene.dart        场景 + 调度参数表（优先级/时长/冷却/可打断）
  monster_scene_graph.dart  场景图：事件 → 场景转移的三条判定规则
  monster_initiative.dart   主动发起规则（不需要大模型）
```

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

- `presentation/`：一个 `MonsterStage` widget 订阅场景，做淡入淡出与静音/减动效适配
- 首页：把怪兽放到首屏主位（当前它只在 profile 与小屋出现）
- 学习/复习页：接 `dispatch(sessionStarted | answerWrong | hardStreak | sessionCompleted)`
- 演出调度器：浮层冲突、静音开关、`MediaQuery.disableAnimations` 支持

**接入前必须先做**：`presentation` 层需要能读到 `ScareCoinStore` 等账本，
而 `learning` scope 在 `scare_coin` 之外（见 `app.dart` 链序注释）——
新增 feature 的 scope 位置需要先定，不要重演 P2 那个「状态层拿不到账本」的坑。
