import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/auth/app_session_controller.dart';
import 'package:word_app/app/service_locator.dart';
import 'package:word_app/features/account/data/auth_server_config.dart';
import 'package:word_app/features/account/data/file_avatar_storage.dart';
import 'package:word_app/features/account/data/local_account_authenticator.dart';
import 'package:word_app/features/account/data/migrating_account_authenticator.dart';
import 'package:word_app/features/account/data/prefs_legal_consent_store.dart';
import 'package:word_app/features/account/data/secure_auth_session_store.dart';
import 'package:word_app/features/account/data/secure_password_auth_store.dart';
import 'package:word_app/features/account/data/supabase_account_authenticator.dart';
import 'package:word_app/features/account/data/user_service.dart';
import 'package:word_app/features/account/application/account_authenticator.dart';
import 'package:word_app/features/account/application/account_profile_store.dart';
import 'package:word_app/features/account/application/auth_session_store.dart';
import 'package:word_app/features/account/application/avatar_storage.dart';
import 'package:word_app/features/account/application/legal_consent_store.dart';
import 'package:word_app/features/account/application/message_store.dart';
import 'package:word_app/features/account/application/password_auth_store.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/account/data/account_profile_repository.dart';
import 'package:word_app/features/account/application/account_profile_state.dart';
import 'package:word_app/features/account/presentation/app_session_state.dart';
import 'package:word_app/core/application/presentation_prefs.dart';

/// 账号功能域的根状态装配入口。
Widget buildAccountFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppSessionState(prefs: PresentationPrefs())),
      // 以同实例暴露核心契约，供其它 feature（如 settings）只依赖 AppSessionController，
      // 不再直接 import account 内部（ARCH-FIX-1，去除跨 feature 展示层耦合）。
      ProxyProvider<AppSessionState, AppSessionController>(update: (_, session, _) => session),
      Provider<AccountProfileStore>(create: (_) => AccountProfileRepository(userService: sl<UserService>())),
      Provider<AvatarStorage>(create: (_) => FileAvatarStorage()),
      Provider<PasswordAuthStore>(create: (_) => SecurePasswordAuthStore()),
      Provider<AuthSessionStore>(create: (_) => SecureAuthSessionStore()),
      // 登录入口。R2-01 阶段二：注入 AUTH_BASE_URL / AUTH_ANON_KEY 即切到服务端
      // 校验；未注入则保持本机模式（CI 与本地开发不注入，见 AuthServerConfig）。
      // 服务端模式下再套一层迁移装饰器：存量用户（本机账号）首次登录时
      // 自动在服务端建号，用户无需任何额外动作。
      Provider<AccountAuthenticator>(
        create: (context) {
          final localStore = context.read<PasswordAuthStore>();
          const config = AuthServerConfig.fromEnvironment;
          if (!config.isConfigured) return LocalAccountAuthenticator(localStore);
          return MigratingAccountAuthenticator(
            remote: SupabaseAccountAuthenticator(
              baseUrl: config.baseUrl,
              anonKey: config.anonKey,
              sessionStore: context.read<AuthSessionStore>(),
            ),
            localStore: localStore,
          );
        },
      ),
      // MW-78：协议同意留痕（policyVersion + acceptedAt），登录成功时写入。
      Provider<LegalConsentStore>(create: (_) => PrefsLegalConsentStore()),
      // 消息中心单一事实来源；跨 feature 仅依赖 checkin 的 application 端口（R4 通道）。
      // 注意：Account 作用域在 CheckIn 作用域之外，create 的 context 读不到
      // CheckinStatusReader（上层无法下探），故此处容错降级为 null，
      // 由入口页在 load 前 attachCheckinReader 补注（见 message_badge_icon）。
      ChangeNotifierProvider(
        create: (context) {
          CheckinStatusReader? reader;
          try {
            reader = context.read<CheckinStatusReader>();
          } on ProviderNotFoundException catch (_) {
            reader = null;
          }
          return MessageStore(checkinReader: reader);
        },
      ),
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
