// P2-8（架构审计 2026-11-12）：演出共享驱动层。
//
// 此前各演出组件各自为政地管理动画驱动：confetti / coin_fly / monster_feed 都用
// SingleTickerProviderStateMixin + AnimationController 手工拼 ticker 生命周期，
// 签到粒子层则用裸 Ticker + 自定义 _TickSignal 重实现了一套帧信号。
//
// 本文件把「固定时长、线性进度、可重播」的演出驱动收口为单一抽象 [CelebrationDriver]：
// 它封装 AnimationController（Flutter 标准的 ticker+时长+进度+Listenable 驱动），
// 统一命名（play/stop/replay）、统一生命周期（dispose）、暴露 progress 与 Listenable。
// 组件不再需要 SingleTickerProviderStateMixin——用 TickerProviderStateMixin 提供 vsync 即可。
//
// 视觉行为完全不变：内部仍是同一个 AnimationController，forward/reset/value 语义一致。
//
// 边界说明：签到粒子层是**无限循环** ticker（elapsed/dt，无固定时长、无 completed），
// 语义与本驱动（固定时长+进度+完成回调）不同，强行统一会引入视觉风险，故保留其裸 Ticker。
import 'package:flutter/widgets.dart';

/// 固定时长演出驱动：线性进度 0→1，可播放/停止/重播，完成时通知。
///
/// 是 [AnimationController] 的薄封装——共享命名与生命周期，组件经 [progress] 读进度、
/// 经 Listenable（[addListener]）订阅每帧、经 [onCompleted] 接完成回调。
class CelebrationDriver extends ChangeNotifier {
  CelebrationDriver({required TickerProvider vsync, required Duration duration, this.onCompleted})
    : _controller = AnimationController(vsync: vsync, duration: duration) {
    _controller.addListener(_onTick);
    _controller.addStatusListener(_onStatus);
  }

  final AnimationController _controller;

  /// 播放完成（progress 到达 1）时回调一次；重播后再次完成会再触发。
  final VoidCallback? onCompleted;

  /// 线性进度 0→1（等价原 AnimationController.value）。
  double get progress => _controller.value;

  /// 是否正在播放。
  bool get isPlaying => _controller.isAnimating;

  /// 底层控制器：供需要 [CurvedAnimation]/[Interval] 的组件作 parent（如错峰飞币）。
  AnimationController get controller => _controller;

  /// 从头播放（等价 forward(from: 0)）。
  void play() => _controller.forward(from: 0);

  /// 停止并归零（等价 reset）。
  void stop() => _controller.reset();

  /// 重播：归零后再播放。
  void replay() {
    _controller.reset();
    _controller.forward();
  }

  void _onTick() => notifyListeners();

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) onCompleted?.call();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }
}
