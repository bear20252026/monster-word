// 由 Claude 团队生成 | 移植自 v3.2 events/ (greenrobot EventBus → StreamController)
// 事件总线：全局单例，基于 StreamController.broadcast() 实现发布-订阅
// 原版使用 greenrobot EventBus，Flutter 中用 dart:async Stream 替代
import 'dart:async';

/// 全局事件总线（单例模式）
///
/// 使用方式：
///   // 发布事件
///   EventBus.instance.fire(CheckInEvent(checkDate: '2026-08-24'));
///
///   // 监听事件（在 initState 中订阅，在 dispose 中取消）
///   final sub = EventBus.instance.on<CheckInEvent>().listen((event) { ... });
///   sub.cancel(); // dispose 时取消
///
///   // 或者使用 Widget 扩展
///   context.onEvent<CheckInEvent>((event) { ... });
class EventBus {
  EventBus._();
  static final EventBus instance = EventBus._();

  final _controller = StreamController<Object>.broadcast();

  /// 发送事件
  void fire(Object event) {
    _controller.add(event);
  }

  /// 监听特定类型的事件（自动过滤）
  Stream<T> on<T>() {
    return _controller.stream.where((e) => e is T).cast<T>();
  }

  /// 释放资源
  void dispose() {
    _controller.close();
  }
}
