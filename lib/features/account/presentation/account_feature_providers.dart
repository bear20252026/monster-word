import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../services/user_service.dart';
import '../data/account_profile_repository.dart';
import 'account_profile_state.dart';
import 'app_session_state.dart';

/// 账号功能域的根状态装配入口。
Widget buildAccountFeatureScope({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppSessionState()),
      Provider<AccountProfileStore>(create: (_) => AccountProfileRepository(userService: sl<UserService>())),
      ChangeNotifierProvider(
        create: (context) => AccountProfileState(profileStore: context.read<AccountProfileStore>())..refresh(),
      ),
    ],
    child: child,
  );
}
