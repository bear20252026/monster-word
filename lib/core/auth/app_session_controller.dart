/// 应用登录状态控制器——跨 feature 统一契约（core，lead 维护）。
///
/// 目标：把「登录态」的读写从 account feature 内部抽成共享契约，
/// 让其它 feature（如 settings）只依赖本契约，而不再直接 import
/// `features/account/presentation/app_session_state.dart`（跨 feature 展示层耦合，
/// 违反依赖边界 R4 / 可维护性原则）。
///
/// 契约原则（与 core 内其它契约一致）：
/// - 只暴露稳定的最小读写面：`isLoggedIn`（读）+ `logout()`（命令）。
/// - 具体实现（AppSessionState）在 account feature 装配层注入，见
///   `features/account/presentation/account_feature_providers.dart`。
abstract interface class AppSessionController {
  /// 当前是否已登录。
  bool get isLoggedIn;

  /// 退出登录（清除登录态并通知监听者）。
  void logout();
}
