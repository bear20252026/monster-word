// 桌面宠物窗口的 Dart 入口（Windows）。
//
// 这个函数由 `windows/runner/pet_host.cpp` 用
// `DartProject::set_dart_entrypoint("petMain")` 启动 —— 宠物住在**独立的顶层窗口**
// 里，跑的是**第二个 Flutter engine**，与主应用不共享内存。
//
// 为什么必须独立窗口：置顶（TOPMOST）是顶层窗口才有的属性，应用内的浮层压不住
// 别的进程。这也是 VPet 的做法（`MainWindow.xaml` 是一个 WS_POPUP + 玻璃帧 + 置顶
// 的独立窗口）。
//
// ⚠️ 两条硬约束，改动前先读：
//   1. 必须带 `@pragma('vm:entry-point')`，否则 AOT 会把 petMain 裁掉；
//   2. 必须被 `lib/main.dart` 引用（export），否则整个文件不会进 app.so。
//
// ⚠️ 这个 engine **没有注册插件**（RegisterPlugins 只对主 engine 调用），
//    所以这里不能碰 shared_preferences / 音频 / 网络。要加数据只能走启动参数，
//    或在 pet_host.cpp 里给这个 engine 也注册插件。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:word_app/core/utils/monster_rhythm.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 宠物窗口与原生通信（拖动 / 打开主应用 / 关掉自己）。
const MethodChannel petWindowChannel = MethodChannel('monster_word/pet_window');

/// 启动参数解析：原生侧 `set_dart_entrypoint_arguments` 传 `days=12` 这种键值对。
class PetLaunchArgs {
  const PetLaunchArgs({this.days});

  /// 累计签到天数（决定形态与肚皮；null = 不知道，用默认奶泡态）。
  final int? days;

  static PetLaunchArgs parse(List<String> args) {
    int? days;
    for (final arg in args) {
      final eq = arg.indexOf('=');
      if (eq <= 0) continue;
      if (arg.substring(0, eq) == 'days') {
        days = int.tryParse(arg.substring(eq + 1));
      }
    }
    return PetLaunchArgs(days: days);
  }
}

@pragma('vm:entry-point')
void petMain(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PetWindowApp(launch: PetLaunchArgs.parse(args)));
}

class PetWindowApp extends StatelessWidget {
  const PetWindowApp({super.key, required this.launch});

  final PetLaunchArgs launch;

  @override
  Widget build(BuildContext context) {
    // 关键：**不套 Scaffold / Material**，窗口背景才是透明的
    // （DWM 玻璃把桌面透出来）。套了 Scaffold 就变成一块不透明方块。
    return MaterialApp(debugShowCheckedModeBanner: false, home: PetWindowPage(launch: launch));
  }
}

/// 宠物窗口里唯一的一屏。
///
/// 交互（无边框窗口没有标题栏，所以全部靠手势）：
/// - 拖动 → 移动窗口
/// - 单击 → 说一句话
/// - 双击 → 打开主应用
/// - 右键 → 关掉宠物窗口
class PetWindowPage extends StatefulWidget {
  const PetWindowPage({super.key, required this.launch});

  final PetLaunchArgs launch;

  @override
  State<PetWindowPage> createState() => _PetWindowPageState();
}

class _PetWindowPageState extends State<PetWindowPage> with SingleTickerProviderStateMixin {
  late final AnimationController _bobCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  final MonsterSpeech _speech = MonsterSpeech();

  String? _line;
  Timer? _lineTimer;

  bool get _reduceMotion => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  int get _stage => widget.launch.days == null ? 0 : MonsterIcon.stageFor(widget.launch.days!);

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _bobCtrl.repeat();
  }

  @override
  void dispose() {
    _lineTimer?.cancel();
    _bobCtrl.dispose();
    super.dispose();
  }

  void _say() {
    final slot = MonsterRhythm.isSleepTime() ? SpeechSlot.sleepyGreeting : SpeechSlot.dailyGreeting;
    final days = widget.launch.days;
    final text = _speech.pick(slot, vars: {'days': days, 'stage': days == null ? null : MonsterIcon.stageName(_stage)});
    setState(() => _line = text);
    _lineTimer?.cancel();
    // 桌面宠物没有「点进去看详情」这条路，气泡自己收。
    _lineTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _line = null);
    });
  }

  void _drag(DragUpdateDetails details, double pixelRatio) {
    // 原生按物理像素移动窗口，所以逻辑位移要乘 devicePixelRatio。
    unawaited(
      petWindowChannel.invokeMethod<void>('moveBy', [details.delta.dx * pixelRatio, details.delta.dy * pixelRatio]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _say,
      onPanUpdate: (details) => _drag(details, pixelRatio),
      onDoubleTap: () => unawaited(petWindowChannel.invokeMethod<void>('openApp')),
      onSecondaryTap: () => unawaited(petWindowChannel.invokeMethod<void>('close')),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 怪兽本体：占满窗口宽度，留出头顶气泡的位置。
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            height: 190,
            child: AnimatedBuilder(
              animation: _bobCtrl,
              builder: (context, child) {
                if (_reduceMotion) return child!;
                return Transform.translate(offset: Offset(0, 3 * math.sin(2 * math.pi * _bobCtrl.value)), child: child);
              },
              child: MonsterIcon(
                size: 170,
                evoStage: _stage,
                bellyScale: widget.launch.days == null ? 1.0 : MonsterIcon.growthFor(widget.launch.days!),
              ),
            ),
          ),
          if (_line != null)
            Positioned(
              left: 4,
              right: 4,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  // 桌面上什么底色都可能有，气泡用实色卡片才读得清。
                  color: const Color(0xE6202328),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _line!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFF5F5F5), fontSize: 12, height: 1.35),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
