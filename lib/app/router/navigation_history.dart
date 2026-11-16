// Monster Word — 全局导航历史栈（多层级前进/返回）
//
// 背景：Flutter Navigator 只内建「返回」（pop），没有「前进」概念。桌面端用户
// 期望浏览器式的多级 back/forward。本服务通过 NavigatorObserver 记录路由轨迹：
// - goBack(): 逐级 pop（真返回，页面实例与状态保留）
// - goForward(): 按离开时的快照（name+arguments）重新 push（新实例）
// - didPush/didReplace 时清空 forward 栈（与浏览器语义一致：分叉即作废）
//
// 注意：pop 的 Dialog/BottomSheet 也会触发 didPop，故只在 page-route 层面记录
// （opaque 路由），弹层不进入导航历史。
import 'dart:async';

import 'package:flutter/material.dart';

/// 单条路由快照（用于前进恢复）。
@immutable
class RouteSnapshot {
  final String name;
  final Object? arguments;

  const RouteSnapshot(this.name, this.arguments);

  @override
  bool operator ==(Object other) => other is RouteSnapshot && other.name == name && other.arguments == arguments;

  @override
  int get hashCode => Object.hash(name, arguments);
}

/// 导航历史服务。通过 [navigatorObservers] 挂入 MaterialApp。
class NavigationHistoryService extends ChangeNotifier {
  NavigationHistoryService._();

  static final NavigationHistoryService instance = NavigationHistoryService._();

  // late final：惰性求值。若在构造期直接读 instance 会因 static 初始化未完成而递归。
  late final NavigationHistoryObserver observer = NavigationHistoryObserver._(this);

  /// 可前进的路由快照（栈顶 = 最近的下一个页面）。
  final List<RouteSnapshot> _forward = [];

  /// 当前栈顶路由名（用于 UI 展示/禁用态）。
  String? currentRouteName;

  bool get canGoForward => _forward.isNotEmpty;

  /// 仅供测试观测前进栈深度。
  @visibleForTesting
  int get historyDepthForTest => _forward.length;

  /// 是否可能可返回（栈深 > 1）。真实判定以 Navigator.canPop 为准。
  bool _mayGoBack = false;
  bool get mayGoBack => _mayGoBack;

  /// 前进：恢复最近的下一条路由。
  ///
  /// 注意不能 await pushNamed——该 Future 直到目标路由被 pop 才完成，
  /// await 会导致调用方死锁。fire-and-forget 即可。
  void goForward() {
    if (_forward.isEmpty) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final snap = _forward.removeLast();
    // 恢复期间的 push 不清空 forward 栈（这是导航还原，不是新分叉）。
    // 审计 C2（2026-11-15）：_restoring 只覆盖本次还原 push（didPush 同步触发），
    // push 返回后立即复位——旧实现等被恢复路由出栈才复位，导致恢复页上再 push
    // 新页不清 forward（违反浏览器分叉语义）。
    _restoring = true;
    try {
      unawaited(
        navigator.pushNamed(snap.name, arguments: snap.arguments).catchError((Object e) {
          // 路由名未注册等导航异常：吞掉防 unhandled（体验降级，不应崩应用）。
          return null;
        }),
      );
    } finally {
      _restoring = false;
    }
    notifyListeners();
  }

  /// 返回（供 UI 调用；真实 pop 由调用方对具体 Navigator 执行，这里仅清 forward）
  /// 不直接持有 navigator：多 Navigator（嵌套）场景由 UI 层结合 canPop 判定。
  void notePop({String? previousRouteName}) {
    // 由 observer 驱动，无需手动调用。
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// goForward 恢复中标志：还原型 push 不清空 forward 栈
  bool _restoring = false;

  void _onPushed(Route<dynamic> route, Route<dynamic>? previous) {
    if (route is! PageRoute || !route.opaque) return;
    if (!_restoring) {
      _forward.clear(); // 用户主动导航 = 新分叉，作废前进栈（浏览器语义）
    }
    currentRouteName = route.settings.name;
    // 有前页才可能可返回（首路由 push 时 previous 为 null）
    _mayGoBack = previous != null;
    notifyListeners();
  }

  void _onPopped(Route<dynamic> route, Route<dynamic>? previous) {
    if (route is PageRoute && route.opaque) {
      final name = route.settings.name;
      if (name != null && name.isNotEmpty) {
        _forward.add(RouteSnapshot(name, route.settings.arguments));
      }
    }
    if (previous != null) {
      currentRouteName = previous.settings.name;
    }
    _mayGoBack = previous != null;
    notifyListeners();
  }

  void _onRemoved(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 清栈型移除（popUntil/goHome/登出）：作废前进栈，只刷新当前路由/可返回态。
    _forward.clear();
    if (previousRoute != null) currentRouteName = previousRoute.settings.name;
    _mayGoBack = previousRoute != null;
    notifyListeners();
  }

  void _onReplaced(Route<dynamic> newRoute, Route<dynamic>? oldRoute) {
    if (newRoute is! PageRoute || !newRoute.opaque) return;
    _forward.clear();
    currentRouteName = newRoute.settings.name;
    notifyListeners();
  }

  /// 应用重启/登出等场景手动重置。
  void reset() {
    _forward.clear();
    _mayGoBack = false;
    currentRouteName = null;
    notifyListeners();
  }
}

/// 挂在 MaterialApp.navigatorObservers 上的观察者。
class NavigationHistoryObserver extends NavigatorObserver {
  final NavigationHistoryService _service;
  NavigationHistoryObserver._(this._service);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _service._onPushed(route, previousRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _service._onPopped(route, previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _service._onReplaced(newRoute, oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 审计 C2（2026-11-15）：didRemove 来自 popUntil/goHome/登出清栈，不是用户
    // 返回，不应记前进快照（否则把中间页乃至 '/' 塞进 forward，Alt+→ 跳错页）。
    // 只更新当前路由名/可返回态，并作废 forward（清栈=新起点）。
    _service._onRemoved(route, previousRoute);
  }
}
