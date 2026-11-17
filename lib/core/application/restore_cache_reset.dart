// 第四轮审计 M18（2026-11-17）：备份恢复后的应用层缓存复位总线。
//
// 分层口径：DAO 层句柄/索引失效由 UserDatabase.close 广播负责（各 DAO
// 构造期订阅）；但 Provider 树内的应用层状态（收藏/掌握快照、金币降级
// 裁决态、今日进度、任务/经验 store、会话队列…）不在广播覆盖面内——
// 它们持有恢复前读到的内存值，不复位则 UI 与恢复库脱节。
//
// 本总线是 core 层的纯注册表（不 import features，R-core）：各 feature
// 装配边界（*_feature_providers.dart）在创建状态时登记复位回调，组合根
// 把「跑一遍全部回调」注入 UserDataMaintenanceService.resetFeatureCaches。
// 回调按登记逆序执行（后登记的先复位，贴近依赖倒序）；单个失败只上报
// 不中断其余（复位是尽力通知，恢复结果不被单个 UI 状态故障推翻）。
import 'package:word_app/core/utils/swallowed_error_report.dart';

class RestoreCacheResetBus {
  RestoreCacheResetBus._();

  static final List<Future<void> Function()> _callbacks = [];

  /// 登记复位回调（幂等：同一函数对象不重复登记）。
  static void register(Future<void> Function() callback) {
    if (!_callbacks.contains(callback)) _callbacks.add(callback);
  }

  /// 移除登记（状态 dispose 时调用，防闭包持有已销毁对象）。
  static void unregister(Future<void> Function() callback) {
    _callbacks.remove(callback);
  }

  /// 恢复成功后由维护服务调用：逆序跑全部回调。
  static Future<void> runAll() async {
    for (final callback in List.of(_callbacks.reversed)) {
      try {
        await callback();
      } catch (e, s) {
        reportSwallowedError('恢复后缓存复位回调失败（其余继续）', e, s);
      }
    }
  }

  /// 测试用：清空登记表（防跨用例泄漏）。
  static void clearForTest() => _callbacks.clear();
}
