import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/app_session_controller.dart';
import '../../../core/di/service_locator.dart';
import '../../../services/user_service.dart';
import '../application/account_profile_store.dart';
import '../data/account_profile_repository.dart';
import 'account_profile_state.dart';
import 'app_session_state.dart';

/// 账号功能域的根状态装配入口。
Widget buildAccountFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppSessionState()),
      // 以同实例暴露核心契约，供其它 feature（如 settings）只依赖 AppSessionController，
      // 不再直接 import account 内部（ARCH-FIX-1，去除跨 feature 展示层耦合）。
      ProxyProvider<AppSessionState, AppSessionController>(
        update: (_, session, _) => session,
      ),
      Provider<AccountProfileStore>(create: (_) => AccountProfileRepository(userService: sl<UserService>())),
      ChangeNotifierProvider(
        create: (context) => AccountProfileState(profileStore: context.read<AccountProfileStore>())..refresh(),
      ),
    ],
    child: _AccountFeatureInitializer(child: child),
  );
}

/// 延迟初始化会话状态（恢复登录态），避免在 build 期间调用 setState。
class _AccountFeatureInitializer extends StatefulWidget {
  const _AccountFeatureInitializer({required this.child});
  final Widget child;

  @override
  State<_AccountFeatureInitializer> createState() => _AccountFeatureInitializerState();
}

class _AccountFeatureInitializerState extends State<_AccountFeatureInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppSessionState>().restore();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
