import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/auth/app_session_controller.dart';
import 'package:word_app/core/di/service_locator.dart';
import 'package:word_app/features/account/data/file_avatar_storage.dart';
import 'package:word_app/features/account/data/secure_password_auth_store.dart';
import 'package:word_app/features/account/data/spug_sms_code_service.dart';
import 'package:word_app/features/account/data/user_service.dart';
import 'package:word_app/features/account/application/account_profile_store.dart';
import 'package:word_app/features/account/application/avatar_storage.dart';
import 'package:word_app/features/account/application/message_store.dart';
import 'package:word_app/features/account/application/password_auth_store.dart';
import 'package:word_app/features/account/application/sms_code_service.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/account/data/account_profile_repository.dart';
import 'package:word_app/features/account/application/account_profile_state.dart';
import 'package:word_app/features/account/presentation/app_session_state.dart';

/// 账号功能域的根状态装配入口。
Widget buildAccountFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppSessionState()),
      // 以同实例暴露核心契约，供其它 feature（如 settings）只依赖 AppSessionController，
      // 不再直接 import account 内部（ARCH-FIX-1，去除跨 feature 展示层耦合）。
      ProxyProvider<AppSessionState, AppSessionController>(update: (_, session, _) => session),
      Provider<AccountProfileStore>(create: (_) => AccountProfileRepository(userService: sl<UserService>())),
      Provider<AvatarStorage>(create: (_) => FileAvatarStorage()),
      Provider<SmsCodeService>(create: (_) => SpugSmsCodeService()),
      Provider<PasswordAuthStore>(create: (_) => SecurePasswordAuthStore()),
      // 消息中心单一事实来源；跨 feature 仅依赖 checkin 的 application 端口（R4 通道）。
      ChangeNotifierProvider(create: (context) => MessageStore(checkinReader: context.read<CheckinStatusReader>())),
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
