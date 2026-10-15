// 模块打开次数埋点：把导航事件转成 `recordModuleOpen`。
//
// 为什么用 NavigatorObserver 而不是在每个页面 initState 里各写一行：
//   1. **一处收口**：新增页面不需要记得加埋点，也不会有人漏加。
//   2. 路由名是稳定合同（RouteNames 单源），比散落的页面类名可靠。
//   3. 映射判断被抽到 application/usage_module_map.dart（纯 Dart），本机可跑断言。
//
// 只上报**映射表收录过的**路由；未收录的一律忽略（见 usage_module_map.dart 的口径说明）。

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:word_app/features/telemetry/application/usage_module_map.dart';

class UsageModuleObserver extends NavigatorObserver {
  UsageModuleObserver({required this.onModuleOpen});

  /// 交给宿主注入，避免观察者自己去取 Provider（它活在 MaterialApp 之上，
  /// 拿不到页面级 context）。
  final Future<void> Function(String module) onModuleOpen;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _report(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _report(newRoute);
  }

  void _report(Route<dynamic> route) {
    final module = moduleForRoute(route.settings.name);
    // 不 await：埋点不该给导航让路（collector 内部已吞掉全部失败）。
    if (module != null) unawaited(onModuleOpen(module));
  }
}
