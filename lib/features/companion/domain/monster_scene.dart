// 怪兽演出场景（companion 域的骨架，纯 Dart 零依赖）。
//
// 为什么需要这一层：现在怪兽的「表情/动作」由各页面各自算（MonsterMood 只在
// profile 里用，完成页自己播庆祝，答错时没有演出），于是同一时刻可能有两个
// 页面同时想让它做不同的事。VPet（C#/WPF，Apache-2.0）的做法是把**动画图与
// 游戏数据彻底分离**：数据层只报「发生了什么」，图决定「演什么、演多久、
// 谁能打断谁」。这里搬的是这个结构，代码是按 Dart 重写的，不是移植源码
// （VPet 是 C#，语言不同；思路不受版权保护，表达受）。
//
// 设计约束（重要）：本文件**只依赖 dart:core**。这样它能在无 Flutter 环境
// 下真跑断言（本机 flutter test 不可用），也天然满足分层守卫。

/// 怪兽能演的场景。命名对齐「它和用户一起做学习任务」的定位。
enum MonsterScene {
  /// 待机：呼吸/眨眼，随时可被打断。
  idle,

  /// 回归欢迎（几天没来）：只欢迎，不催任务。
  greeting,

  /// 开始学习前的准备动作（建立「一起开始」的仪式）。
  preparing,

  /// 答错后的指提示（指向发音/词根/易混义）。
  hinting,

  /// 连续困难 → 提议改成「三词小组」。
  regrouping,

  /// 复习时搬词卡（把积压显示成可完成的数量）。
  carrying,

  /// 会话完成后的总结（学到什么、什么要再练）。
  summarizing,

  /// 发币/升级庆祝。
  celebrating,
}

/// 场景的调度参数。`priority` 越大越优先；`hold` 为一次性演出的时长
/// （[Duration.zero] 表示持续态，不会被时间自动结束）。
class MonsterSceneSpec {
  const MonsterSceneSpec({
    required this.scene,
    required this.priority,
    required this.hold,
    required this.cooldown,
    required this.interruptible,
  });

  final MonsterScene scene;

  /// 抢占优先级。数值只用于比较，没有绝对含义。
  final int priority;

  /// 一次性演出时长；[Duration.zero] = 持续态。
  final Duration hold;

  /// 同一场景的再入场冷却（防「答错→提示→再答错」把画面闪成频闪灯）。
  final Duration cooldown;

  /// 是否允许被更高优先级打断。庆祝这类「演完才算数」的场景设为 false。
  final bool interruptible;

  bool get isOneShot => hold > Duration.zero;
}

/// 场景表（单一事实来源）。
///
/// 优先级顺序的设计理由：**用户的情绪时刻 > 学习帮助 > 仪式 > 待机**。
/// 回归欢迎与庆祝给最高档，因为它们一次性且与用户情绪强绑定；
/// 提示类居中，因为它是「帮忙」而不是「抢戏」。
const Map<MonsterScene, MonsterSceneSpec> monsterSceneCatalog = {
  MonsterScene.idle: MonsterSceneSpec(
    scene: MonsterScene.idle,
    priority: 0,
    hold: Duration.zero,
    cooldown: Duration.zero,
    interruptible: true,
  ),
  MonsterScene.preparing: MonsterSceneSpec(
    scene: MonsterScene.preparing,
    priority: 30,
    hold: Duration(milliseconds: 1200),
    cooldown: Duration(seconds: 3),
    interruptible: true,
  ),
  MonsterScene.hinting: MonsterSceneSpec(
    scene: MonsterScene.hinting,
    priority: 60,
    hold: Duration(milliseconds: 2000),
    cooldown: Duration(seconds: 20),
    interruptible: true,
  ),
  MonsterScene.carrying: MonsterSceneSpec(
    scene: MonsterScene.carrying,
    priority: 55,
    hold: Duration(milliseconds: 1600),
    cooldown: Duration(seconds: 10),
    interruptible: true,
  ),
  MonsterScene.regrouping: MonsterSceneSpec(
    scene: MonsterScene.regrouping,
    priority: 70,
    hold: Duration(seconds: 3),
    cooldown: Duration(seconds: 120),
    interruptible: true,
  ),
  MonsterScene.summarizing: MonsterSceneSpec(
    scene: MonsterScene.summarizing,
    priority: 80,
    hold: Duration(seconds: 3),
    cooldown: Duration(seconds: 5),
    interruptible: true,
  ),
  MonsterScene.celebrating: MonsterSceneSpec(
    scene: MonsterScene.celebrating,
    priority: 85,
    hold: Duration(milliseconds: 2200),
    cooldown: Duration(seconds: 5),
    // 庆祝不被打断：升羁绊/发币的仪式演到一半被别的场景切走，会比不演更差。
    interruptible: false,
  ),
  MonsterScene.greeting: MonsterSceneSpec(
    scene: MonsterScene.greeting,
    priority: 90,
    hold: Duration(seconds: 3),
    cooldown: Duration(minutes: 30),
    interruptible: false,
  ),
};

/// 取场景参数（表里必须齐；缺了直接抛，不要静默给默认值）。
MonsterSceneSpec specOf(MonsterScene scene) {
  final spec = monsterSceneCatalog[scene];
  if (spec == null) {
    throw StateError('场景表缺少 $scene —— 新增场景必须同时补参数，否则调度无法判断优先级');
  }
  return spec;
}
