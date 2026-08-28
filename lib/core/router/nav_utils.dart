// 由 Claude 团队生成 | Monster Word App
import 'package:flutter/material.dart';

/// 统一导航安全工具。
///
/// 背景：全站曾存在两类「返回异常」——
/// 1. 返回按钮直接 `Navigator.pop(context)`，若页面处于栈底（唯一路由）会被弹掉，
///    导致黑屏或直接退出 App；
/// 2. 「返回首页」用 `pushReplacementNamed('/')` 替换当前页，而非逐级返回，
///    会在栈里留下首页副本、打断「逐级返回首页」的语义。
///
/// 解决方案：统一约定——
/// - 所有「返回」走 [safePop]（带 `canPop` 守卫，永不在栈底弹出唯一路由）；
/// - 所有「回首页」走 [goHome]（`popUntil` 到根路由，逐级清掉中间页）。
abstract final class NavUtils {
  /// 安全返回：仅当存在上一页（可返回）时执行 pop，否则不动作。
  ///
  /// 避免把唯一的根路由弹掉导致黑屏或退出（移动端系统返回键对根路由的正常
  /// 行为是退到后台，而非黑屏）。
  ///
  /// [result] 为可选返回值，用于 showDialog 等需要传递结果的场景。
  static void safePop(BuildContext context, [dynamic result]) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
    }
  }

  /// 逐级返回首页：弹出所有中间路由，回到根路由（App 的 MainShell 主页）。
  ///
  /// 与 `pushReplacementNamed` 不同，它不替换任何页面、不丢栈帧，而是沿栈逐级
  /// 弹出到 `route.isFirst`，保证「逐级返回首页」的语义。
  static void goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
