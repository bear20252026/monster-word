// 兼容旧入口的我的空间页薄适配层。
//
// 原 lib/pages/my_space_page.dart 的全部 UI/逻辑已迁移至
// features/account/presentation/my_space_page.dart。
// 本文件保留 re-export 以兼容既有路由与 import。
//
// 使用账户资料状态（AccountProfileState）展示用户资料。
// 使用尖叫币状态（ScareCoinStore）展示尖叫币余额。
export '../features/account/presentation/my_space_page.dart';
