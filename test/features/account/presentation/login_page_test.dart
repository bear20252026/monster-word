// 登录页回归守卫（2026-10-13 移除短信链路后）。
//
// 为什么需要它：这一批是**净删除**——删掉 3 个文件、登录页从 819 行降到 506 行。
// 分析器不会因为「页面少了个入口」报错，`dart analyze` 全绿也不代表页面还能用；
// 只有真正 pump 一次页面才能发现 UI 回归。这里锁住三件事：
//   1. 账号密码表单仍在（用户名 / 密码 / 登录按钮）；
//   2. 短信相关入口彻底消失（手机号登录、获取验证码、二级选择页）；
//   3. 「忘记密码」走的是「联系管理员」提示，**不提供任何自助重置**——
//      密码哈希只在本机，自助通道会让登录降级成摆设。
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/application/presentation_prefs.dart';
import 'package:word_app/features/account/application/account_authenticator.dart';
import 'package:word_app/features/account/application/legal_consent_store.dart';
import 'package:word_app/features/account/application/password_auth_store.dart';
import 'package:word_app/features/account/data/local_account_authenticator.dart';
import 'package:word_app/features/account/data/prefs_legal_consent_store.dart';
import 'package:word_app/features/account/data/secure_password_auth_store.dart';
import 'package:word_app/features/account/presentation/app_session_state.dart';
import 'package:word_app/features/account/presentation/login_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  Future<void> pumpLoginPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PasswordAuthStore>(create: (_) => SecurePasswordAuthStore()),
          // 登录页只依赖 AccountAuthenticator 端口（R2-01 阶段二换服务端实现
          // 时改的是装配点，页面与测试都不动）。
          Provider<AccountAuthenticator>(
            create: (context) => LocalAccountAuthenticator(context.read<PasswordAuthStore>()),
          ),
          ChangeNotifierProvider<AppSessionState>(create: (_) => AppSessionState(prefs: PresentationPrefs())),
          Provider<LegalConsentStore>(create: (_) => PrefsLegalConsentStore()),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('只保留账号密码登录：表单在、短信入口不在', (tester) async {
    await pumpLoginPage(tester);

    expect(find.text('请输入用户名'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);

    // 短信链路移除后这些入口必须彻底消失
    expect(find.text('手机号登录'), findsNothing);
    expect(find.text('获取验证码'), findsNothing);
    expect(find.text('账号密码登录'), findsNothing, reason: '二级选择页随单入口一起移除');
  });

  testWidgets('忘记密码只提示联系管理员，不提供自助重置', (tester) async {
    await pumpLoginPage(tester);

    await tester.tap(find.text('忘记密码？'));
    await tester.pumpAndSettle();

    expect(find.textContaining('请联系管理员'), findsOneWidget);
    expect(find.text('清空本机账号'), findsNothing, reason: '自助重置会让登录降级为摆设');
    expect(find.text('请输入短信验证码（发往 138****1234）'), findsNothing);
  });
}
