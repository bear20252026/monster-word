// 全局唯一的怪兽（桌面宠物式存在）。
//
// ## 为什么是「一层浮层」而不是「每个页面各画一只」
//
// VPet 的做法是：怪兽只有一个显示面（`VPet-Simulator.Core/Display/Main.xaml`），
// 住在一个透明置顶窗口里；数据来自 `Handle/GameCore`，动画来自 `Graph/*`，
// 台词来自 `TalkBox`。**页面根本不参与画怪兽**。
//
// 我们之前的做法是反的：首页 header 画一只 96px、学习页画一只 32px、复习页一只都没有。
// 那不是「一只宠物」，那是三份互不相干的贴图。现在按 VPet 的结构收成一层：
//
//   - 本文件 = `Main`（唯一显示面），挂在 `MaterialApp.builder` 上，位于 Navigator 之上
//     ⇒ 换页不重建、位置固定、永远只有一只；
//   - `MonsterCompanionState` = `GameCore`（数据/状态）；
//   - `MonsterSceneGraph` = `Graph`（动画图）；
//   - 气泡 = `TalkBox`。
//
// 页面只做一件事：`announceMonsterAnswer(context, correct:)` 报事实。
//
// ⚠️ 可测性：所有 Provider 一律**可空读取**（最小装配的 widget 测试没有这些 scope）。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/utils/monster_initiative.dart';
import 'package:word_app/core/utils/monster_rhythm.dart';
import 'package:word_app/core/utils/monster_scene.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/core/utils/monster_voice.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/companion/application/monster_companion_port.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/app_dock.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 怪兽直径。桌面宠物要「在场」但不能挡住操作，72 是两者折中。
const double kMonsterPresenceSize = 72;

/// 场景 → 表情参数（纯函数，便于单测锚定）。
({double mouthOpen, double cheekPuff, bool sad, double bellyScale}) sceneExpression(MonsterScene scene) =>
    switch (scene) {
      MonsterScene.idle => (mouthOpen: 0, cheekPuff: 0, sad: false, bellyScale: 1),
      // 欢迎：张嘴笑 + 鼓脸，最开心的一档。
      MonsterScene.greeting => (mouthOpen: 0.6, cheekPuff: 0.5, sad: false, bellyScale: 1.02),
      // 准备：深吸一口气（肚子微涨），不笑 —— 建立「要开始了」的仪式感。
      MonsterScene.preparing => (mouthOpen: 0.1, cheekPuff: 0.15, sad: false, bellyScale: 1.06),
      // 指提示：专注，不卖萌（此刻用户需要的是帮助，不是可爱）。
      MonsterScene.hinting => (mouthOpen: 0.3, cheekPuff: 0.2, sad: false, bellyScale: 1),
      // 连续困难：陪着难过，不是评判。
      MonsterScene.regrouping => (mouthOpen: 0.15, cheekPuff: 0.3, sad: true, bellyScale: 1),
      // 搬词卡：用力（肚子鼓）。
      MonsterScene.carrying => (mouthOpen: 0.2, cheekPuff: 0.25, sad: false, bellyScale: 1.05),
      // 总结：说话状。
      MonsterScene.summarizing => (mouthOpen: 0.5, cheekPuff: 0.3, sad: false, bellyScale: 1),
      // 庆祝：最夸张一档。
      MonsterScene.celebrating => (mouthOpen: 0.9, cheekPuff: 0.8, sad: false, bellyScale: 1.08),
    };

/// 把怪兽叠在整棵路由树之上（放在 `MaterialApp.builder` 里）。
///
/// 用 Stack 而不是 Overlay：Overlay 会随路由变化重建，而宠物必须**跨路由不重建**
/// （重建会重放呼吸相位、丢掉正在演的场景）。
///
/// [navigatorKey] 的意义：浮层位于 Navigator **之上**，`Navigator.of(context)`
/// 在它这里找不到导航器（导航器是它的子孙）。所以「点击 → 进我的空间」必须经
/// 外部传进来的 key，否则点了没反应。
///
/// 拖动：位置由**本组件**持有（不在 `MonsterPresence` 里），因为只有它知道屏幕尺寸。
/// 宠物自己的 `onTap` 与这里的 `onPan` 走手势竞技场 —— 移动超过 slop 算拖、
/// 没移动算点，两者不会互相误触（这是把它做成「桌面宠物」而不是「按钮」的关键）。
class MonsterPresenceHost extends StatefulWidget {
  const MonsterPresenceHost({super.key, required this.child, this.navigatorKey});

  final Widget child;

  /// 用于从浮层发起路由跳转（点击怪兽 → 我的空间）。
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<MonsterPresenceHost> createState() => _MonsterPresenceHostState();
}

class _MonsterPresenceHostState extends State<MonsterPresenceHost> {
  /// 宠物左上角坐标；null = 还没拖过（用上次存下的比例，或默认锚点）。
  Offset? _pos;

  /// 上次停的位置，**归一化到 0~1**：换分辨率或横竖屏后仍落在同一相对位置。
  Offset? _savedRatio;

  static const String _posXKey = 'monster_pos_x';
  static const String _posYKey = 'monster_pos_y';

  /// 贴边留白：留条缝才像「浮」在屏幕里，而不是被边缘切掉。
  static const double _edgeInset = 8;

  /// 头顶留给气泡的竖直高度（气泡悬在宠物上方，贴到顶会被裁掉）。
  static const double _bubbleRoom = 28;

  @override
  void initState() {
    super.initState();
    // 读操作在未初始化时安全返回默认值（BaseSharedPreferences 保证），首帧不会抛。
    final prefs = AppPreferences();
    if (prefs.containsKey(_posXKey) && prefs.containsKey(_posYKey)) {
      _savedRatio = Offset(prefs.getDouble(_posXKey), prefs.getDouble(_posYKey));
    }
  }

  /// 松手才写盘：拖动过程中每帧写 SP 是浪费。
  Future<void> _persist(Offset pos, Size screen) async {
    try {
      final prefs = AppPreferences();
      await prefs.setDouble(_posXKey, (pos.dx / screen.width).clamp(0.0, 1.0));
      await prefs.setDouble(_posYKey, (pos.dy / screen.height).clamp(0.0, 1.0));
    } catch (e, s) {
      // 存不下位置不影响使用：下次开机回到默认角而已，不值得打断用户。
      reportSwallowedError('怪兽位置保存失败', e, s);
    }
  }

  /// clamp 在 lo > hi 时会抛（极窄屏），退化到 lo。
  static double _clampAxis(double v, double lo, double hi) => hi <= lo ? lo : v.clamp(lo, hi);

  Offset _clampToScreen(Offset p, Size screen) {
    const pet = kMonsterPresenceSize;
    return Offset(
      _clampAxis(p.dx, _edgeInset, screen.width - pet - _edgeInset),
      _clampAxis(p.dy, _bubbleRoom, screen.height - pet - _edgeInset),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        const pet = kMonsterPresenceSize;
        // 默认锚点：右下角、悬浮 Dock 上方（那一带本就是为 Dock 预留的空白）。
        final anchor = Offset(screen.width - pet - 12, screen.height - FloatingDock.clearance(context) - 6 - pet);
        final restored = _savedRatio == null
            ? null
            : Offset(_savedRatio!.dx * screen.width, _savedRatio!.dy * screen.height);
        final pos = _clampToScreen(_pos ?? restored ?? anchor, screen);
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // 增量累加而不是记起点：_pos 是唯一事实，窗口尺寸变化后仍自洽。
                onPanUpdate: (d) => setState(() {
                  _pos = _clampToScreen((_pos ?? restored ?? anchor) + d.delta, screen);
                  // 手一动就以 _pos 为准：留着旧比例会让下一次计算跳回原位。
                  _savedRatio = null;
                }),
                onPanEnd: (_) {
                  final current = _pos;
                  if (current != null) unawaited(_persist(_clampToScreen(current, screen), screen));
                },
                child: MonsterPresence(
                  navigatorKey: widget.navigatorKey,
                  // 气泡比宠物宽：停右边就朝左长，否则长台词会被屏幕边缘裁掉。
                  bubbleAlignsRight: pos.dx + pet / 2 > screen.width / 2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 怪兽本体（全 app 唯一实例）。
class MonsterPresence extends StatefulWidget {
  const MonsterPresence({super.key, this.navigatorKey, this.bubbleAlignsRight = true});

  final GlobalKey<NavigatorState>? navigatorKey;

  /// 气泡朝哪边生长。气泡比宠物宽，居中会让长台词越过屏幕边缘被裁掉：
  /// 停在屏幕右半边就朝左长（`true`），左半边朝右长。
  final bool bubbleAlignsRight;

  @override
  State<MonsterPresence> createState() => _MonsterPresenceState();
}

class _MonsterPresenceState extends State<MonsterPresence> with TickerProviderStateMixin {
  // 呼吸 bob（2.8s 一循环；档位复用 MotionDurations.splash）。
  late final AnimationController _bobCtrl = AnimationController(vsync: this, duration: MotionDurations.splash);
  // 点击问候：张嘴 0→0.3 的 0.3s 过渡。
  late final AnimationController _mouthCtrl = AnimationController(vsync: this, duration: MotionDurations.slow);
  late final Animation<double> _mouth = CurvedAnimation(parent: _mouthCtrl, curve: Curves.easeInOut);

  bool _gurgleVisible = false;

  /// 台词引擎（可测注入时间/随机源）。
  final MonsterSpeech _speech = MonsterSpeech();

  String _greetingText = '咕噜~';

  /// 台词变量：只装真实读到的数据，读不到的槽位为 null（引擎随即跳过含该占位符的模板）。
  /// 硬编码占位值会让怪兽对金冠用户说「我现在是奶泡形态」「钱包里躺着 0 枚尖叫币」。
  Map<String, Object?> _speechVars = const {'days': null, 'streak': null, 'balance': null, 'stage': null};

  /// 累计签到天数（形态/肚皮的驱动源；null = 读不到 → 默认奶泡态，不猜）。
  int? _checkinDays;

  /// 800ms 问候节拍窗内的重入闸（双击会推开两层「我的空间」）；入页后复位。
  bool _navigating = false;

  bool get _reduceMotion => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _bobCtrl.repeat();
    // 台词变量预热：点击气泡用缓存值，不等取数（点击反馈不能有延迟）。
    unawaited(_refreshSpeechVars());
    // 蓝图 W4：今日首见且距上次打开 ≥1 天 → 主动弹 welcomeBack 气泡（消耗 1 预算，每日 ≤3）。
    // 原在首页 header 里，随怪兽一起搬到这里 —— 宠物自己记得你多久没来。
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeProactiveWelcome());
  }

  Future<void> _maybeProactiveWelcome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const lastVisitKey = 'monster_last_home_visit';
      final today = MonsterSpeech.dayKeyOf(DateTime.now());
      final last = prefs.getString(lastVisitKey);
      if (last == today || !_speech.canSpeak()) return;
      await prefs.setString(lastVisitKey, today);
      if (!mounted || last == null) return; // 首次使用无分离可言，不迎接回归
      // 主动弹是「怪兽开口报数」的场合，等变量取齐再说（取不到就说不带数的台词）。
      final vars = await _loadSpeechVars();
      if (!mounted) return;
      setState(() {
        _speechVars = vars;
        _checkinDays = vars['days'] as int?;
        _greetingText = _speech.pick(SpeechSlot.welcomeBack, vars: vars);
        _gurgleVisible = true;
      });
      _speech.consumeBudget();
      // 「怪兽开口」第二刻：回归时把这句欢迎念出来。点击气泡不发声——
      // 主动弹才是它开口说话，否则每点一下都出声就成了噪音。
      unawaited(MonsterVoice.system.say(_greetingText));
      unawaited(_settleGurgle());
    } catch (e, s) {
      reportSwallowedError('怪兽主动问候失败', e, s);
    }
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    _mouthCtrl.dispose();
    super.dispose();
  }

  /// 取台词变量：累计签到天数 / 连击 / 尖叫币余额 / 由天数换算的进化形态。
  ///
  /// context 一律在 await 之前取（async gap 后禁用 context）。任一路读不到即该槽位为
  /// null——宁可不提这个数字，也不向用户报假数字。
  Future<Map<String, Object?>> _loadSpeechVars() async {
    final reader = context.read<CheckinStatusReader?>();
    final store = context.read<ScareCoinStore?>();
    int? days;
    int? streak;
    int? balance;
    if (reader != null) {
      try {
        final results = await Future.wait([reader.getCheckinDates(), reader.getStreakDays()]);
        days = (results[0] as Set<String>).length;
        streak = results[1] as int;
      } catch (e, s) {
        reportSwallowedError('怪兽台词签到数据读取失败', e, s);
      }
    }
    if (store != null) {
      try {
        balance = await store.balance();
      } catch (e, s) {
        reportSwallowedError('怪兽台词余额读取失败', e, s);
      }
    }
    return {
      'days': days,
      'streak': streak,
      'balance': balance,
      'stage': days == null ? null : MonsterIcon.stageName(MonsterIcon.stageFor(days)),
    };
  }

  Future<void> _refreshSpeechVars() async {
    final vars = await _loadSpeechVars();
    if (!mounted) return;
    setState(() {
      _speechVars = vars;
      _checkinDays = vars['days'] as int?;
    });
  }

  /// 点击：冒一句（夜间说睡话）→ 800ms 后进「我的空间」。
  ///
  /// 行为沿用原 header 版（含 800ms 节拍窗防双击叠路由）。
  Future<void> _greet() async {
    if (_navigating) return;
    _navigating = true;
    _mouthCtrl.forward();
    final slot = MonsterRhythm.isSleepTime() ? SpeechSlot.sleepyGreeting : SpeechSlot.dailyGreeting;
    setState(() {
      _greetingText = _speech.pick(slot, vars: _speechVars);
      _gurgleVisible = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _navigating = false;
    // 浮层在 Navigator 之上 ⇒ 只能用外部传进来的 key 跳转（见 MonsterPresenceHost 注释）。
    final navigator = widget.navigatorKey?.currentState;
    if (navigator != null) {
      unawaited(
        navigator.pushNamed(RouteNames.mySpace).then((_) {
          if (mounted) unawaited(_refreshSpeechVars());
        }),
      );
    }
    unawaited(_settleGurgle());
  }

  Future<void> _settleGurgle() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _gurgleVisible = false);
    _mouthCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    // 可空读取：最小装配的单测没有 companion scope，退回待机表情。
    final companion = context.watch<MonsterCompanionController?>();
    // 事实由**这里**喂（不在页面里）：宠物在任何页面都要知道「今天还差多少」。
    // post-frame 而不是 build 期间改状态（build 里 notifyListeners 会抛）。
    final today = context.watch<TodayProgressStore?>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      companion?.refreshInitiative(
        MonsterInitiativeInput(dueCount: today?.due ?? 0, studiedToday: (today?.learned ?? 0) > 0),
      );
    });
    final scene = companion?.scene ?? MonsterScene.idle;
    final expr = sceneExpression(scene);
    // 主动台词：companion 有话要说就直接冒（这才是「它会找你」）。
    // 点击冒泡期间以点击文案为准，避免两句话打架。
    final proactive = companion?.line;
    final bubbleText = _gurgleVisible ? _greetingText : proactive;
    final showBubble = _gurgleVisible || proactive != null;

    return Semantics(
      label: '小怪兽',
      hint: '可以拖到别处，点一下跟我说话',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _greet,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            AnimatedBuilder(
              animation: _bobCtrl,
              builder: (context, child) {
                if (_reduceMotion) return child!;
                return Transform.translate(offset: Offset(0, 2 * math.sin(2 * math.pi * _bobCtrl.value)), child: child);
              },
              child: AnimatedBuilder(
                animation: _mouth,
                builder: (context, _) => MonsterIcon(
                  size: kMonsterPresenceSize,
                  // 点击张嘴优先于场景表情：用户刚动手，必须有即时反馈。
                  mouthOpen: math.max(0.3 * _mouth.value, expr.mouthOpen),
                  cheekPuff: expr.cheekPuff,
                  sad: expr.sad,
                  evoStage: _checkinDays == null ? 0 : MonsterIcon.stageFor(_checkinDays!),
                  bellyScale: (_checkinDays == null ? 1.0 : MonsterIcon.growthFor(_checkinDays!)) * expr.bellyScale,
                ),
              ),
            ),
            // 气泡悬在头顶：默认隐藏，有话/被点才出现。
            // 宽度可达宠物 2.6 倍 ⇒ 贴边一侧对齐，让它只朝屏幕内侧长。
            Positioned(
              bottom: kMonsterPresenceSize * 0.92,
              right: widget.bubbleAlignsRight ? 0 : null,
              left: widget.bubbleAlignsRight ? null : 0,
              child: AnimatedOpacity(
                opacity: showBubble ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: kMonsterPresenceSize * 2.6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: ShapeDecoration(
                      color: colors.cardBg,
                      shape: StadiumBorder(side: BorderSide(color: colors.divider)),
                    ),
                    child: Text(
                      bubbleText ?? '',
                      key: const ValueKey('monster-greeting-bubble'),
                      textAlign: TextAlign.center,
                      style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: colors.text2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
