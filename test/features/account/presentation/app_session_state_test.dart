import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/account/presentation/app_session_state.dart';

void main() {
  group('AppSessionState', () {
    test('初始未登录且未展示引导', () {
      final state = AppSessionState();

      expect(state.isLoggedIn, isFalse);
      expect(state.hasShownInitGuide, isFalse);
    });

    test('账号登录、引导标记和退出遵循应用会话语义', () async {
      final state = AppSessionState();

      expect(await state.login('tester', 'password'), isTrue);
      expect(state.isLoggedIn, isTrue);

      await state.setHasShownInitGuide(true);
      expect(state.hasShownInitGuide, isTrue);

      state.logout();
      expect(state.isLoggedIn, isFalse);
      expect(state.hasShownInitGuide, isTrue);
    });

    test('手机号登录同样建立已登录会话', () async {
      final state = AppSessionState();

      expect(await state.phoneLogin('13800138000', '123456'), isTrue);
      expect(state.isLoggedIn, isTrue);
    });
  });
}
