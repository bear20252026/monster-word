// 本机账号密码认证（SecurePasswordAuthStore）单元测试。
// flutter_secure_storage 官方 setMockInitialValues 提供测试背板，走真实实现逻辑。
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:word_app/features/account/data/secure_password_auth_store.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('SecurePasswordAuthStore', () {
    test('未创建账号：hasPassword=false、verify=false、boundPhone=null', () async {
      final store = SecurePasswordAuthStore();
      expect(await store.hasPassword('alice'), isFalse);
      expect(await store.verify('alice', 'password123'), isFalse);
      expect(await store.boundPhone('alice'), isNull);
    });

    test('创建后：verify 正密码通过、错密码拒绝', () async {
      final store = SecurePasswordAuthStore();
      await store.setPassword('alice', 'password123');
      expect(await store.hasPassword('alice'), isTrue);
      expect(await store.verify('alice', 'password123'), isTrue);
      expect(await store.verify('alice', 'password124'), isFalse, reason: '错密码必须拒绝（假语义收口的关键守护点）');
      expect(await store.verify('alice', ''), isFalse);
    });

    test('用户名大小写不敏感（Abc 与 abc 同一账号）', () async {
      final store = SecurePasswordAuthStore();
      await store.setPassword('Abc', 'password123');
      expect(await store.hasPassword('abc'), isTrue);
      expect(await store.verify('ABC', 'password123'), isTrue);
    });

    test('手机号用户名自动绑定手机号，供忘记密码找回', () async {
      final store = SecurePasswordAuthStore();
      await store.setPassword('13812345678', 'password123');
      expect(await store.boundPhone('13812345678'), '13812345678');

      await store.setPassword('nonPhoneUser', 'password123');
      expect(await store.boundPhone('nonPhoneUser'), isNull);
    });

    test('重置密码后旧密码彻底失效（每次设置换新盐）', () async {
      final store = SecurePasswordAuthStore();
      await store.setPassword('bob', 'oldpassword');
      await store.setPassword('bob', 'newpassword', phone: '13987654321');
      expect(await store.verify('bob', 'oldpassword'), isFalse);
      expect(await store.verify('bob', 'newpassword'), isTrue);
      expect(await store.boundPhone('bob'), '13987654321', reason: '重置时可保持手机号绑定');
    });

    test('hashPassword：同盐同密码结果一致，不同盐结果不同（防彩虹表）', () {
      final h1 = SecurePasswordAuthStore.hashPassword('saltA', 'password123');
      final h2 = SecurePasswordAuthStore.hashPassword('saltA', 'password123');
      final h3 = SecurePasswordAuthStore.hashPassword('saltB', 'password123');
      expect(h1, h2);
      expect(h1, isNot(h3));
      expect(h1.length, 64, reason: 'SHA-256 十六进制长度');
    });
  });
}
