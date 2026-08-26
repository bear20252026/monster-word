// 用户模块：登录、设置、个人信息
//
// 该模块包含：
// - LoginPage（登录页面）
// - SettingsPage（设置页面）
// - MySpacePage（我的空间页面）
// - UserInfoManagePage（用户信息管理页面）
// - UserService（用户业务逻辑）
//
// 依赖：
// - UserRepository（用户数据）
// - NoteRepository（笔记数据）

/// 用户模块配置
class UserModule {
  UserModule._();

  static void register(dynamic sl) {
    // UserService 已在 service_locator.dart 中注册
  }
}
