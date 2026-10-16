// 本机账号密码认证（SecurePasswordAuthStore）单元测试。
// flutter_secure_storage 官方 setMockInitialValues 提供测试背板，走真实实现逻辑。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:word_app/features/account/data/secure_password_auth_store.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('SecurePasswordAuthStore', () {
    test('未创建账号：hasPassword=false、verify=false', () async {
      final store = SecurePasswordAuthStore();
      expect(await store.hasPassword('alice'), isFalse);
      expect(await store.verify('alice', 'password123'), isFalse);
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

    test('重置密码后旧密码彻底失效（每次设置换新盐）', () async {
      final store = SecurePasswordAuthStore();
      await store.setPassword('bob', 'oldpassword');
      await store.setPassword('bob', 'newpassword');
      expect(await store.verify('bob', 'oldpassword'), isFalse);
      expect(await store.verify('bob', 'newpassword'), isTrue);
    });

    test('hashPassword：PBKDF2 新格式，同盐同密码一致、不同盐不同', () {
      final h1 = SecurePasswordAuthStore.hashPassword('saltA', 'password123');
      final h2 = SecurePasswordAuthStore.hashPassword('saltA', 'password123');
      final h3 = SecurePasswordAuthStore.hashPassword('saltB', 'password123');
      expect(h1, h2);
      expect(h1, isNot(h3));
      expect(h1, startsWith('pbkdf2-sha256\$'), reason: '存储格式必须带算法+迭代数前缀');
      expect(h1.split(r'$').length, 3);
      expect(h1.split(r'$').last.length, 64, reason: '32 字节派生键的十六进制长度');
      // 与 RFC 2898 参考实现的抽查一致性由 pbkdf2Sha256 纯函数单测覆盖
    });

    test('pbkdf2Sha256：RFC 6070 风格参考向量（HMAC-SHA256 已知值）', () {
      // PBKDF2-HMAC-SHA256("password", "salt", 1, 32) 的公开参考值
      final v1 = SecurePasswordAuthStore.pbkdf2Sha256('password'.codeUnits, 'salt'.codeUnits, 1, 32);
      expect(
        v1.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      // 2 轮参考值
      final v2 = SecurePasswordAuthStore.pbkdf2Sha256('password'.codeUnits, 'salt'.codeUnits, 2, 32);
      expect(
        v2.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('deriveInBackground：与同步 hashPassword 逐位一致（R3-D04 移出主 isolate）', () async {
      // 后台 isolate 版必须与同步版产出**完全相同**的哈希，否则存量凭据全部失效
      final sync = SecurePasswordAuthStore.hashPassword('saltA', 'password123');
      final asyncHash = await SecurePasswordAuthStore.deriveInBackground('saltA', 'password123');
      expect(asyncHash, sync, reason: '后台派生不得改变哈希结果');

      // verify 读存量凭据时会传存储里的迭代数（可能是历史值），这条路径也要一致
      const salt = 'saltA';
      const password = 'password123';
      final expected = SecurePasswordAuthStore.pbkdf2Sha256(
        utf8.encode('mw:$salt:$password'),
        utf8.encode(salt),
        1000,
        32,
      );
      final asyncLow = await SecurePasswordAuthStore.deriveInBackground(salt, password, iterations: 1000);
      expect(
        asyncLow,
        'pbkdf2-sha256\$1000\$${expected.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
        reason: '自定义迭代数路径必须与纯函数一致',
      );
    });

    test('存量单轮 SHA-256 哈希：验证通过并透明升级为 PBKDF2', () async {
      // 预置旧版格式（salt + 单轮 SHA-256）
      const username = 'carol';
      const salt = '0123456789abcdef0123456789abcdef';
      final legacyHash = SecurePasswordAuthStore.legacyHashPassword(salt, 'password123');
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'pwauth.$username.salt': salt,
        'pwauth.$username.hash': legacyHash,
      });
      final store = SecurePasswordAuthStore();
      // 旧口令验证通过（走 legacy 分支）
      expect(await store.verify(username, 'password123'), isTrue);
      // 透明升级：MW-65 后落到单 credential Blob（内含 PBKDF2 新格式哈希）
      final credentialJson = await const FlutterSecureStorage().read(key: 'pwauth.$username.credential');
      expect(credentialJson, isNotNull);
      final credentialMap = jsonDecode(credentialJson!) as Map<String, dynamic>;
      expect(credentialMap['hash'] as String, startsWith('pbkdf2-sha256\$'));
      // 升级后新格式仍可验证，错密码仍拒绝
      expect(await store.verify(username, 'password123'), isTrue);
      expect(await store.verify(username, 'password124'), isFalse);
      // 存量错密码：拒绝且不触发升级
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'pwauth.$username.salt': salt,
        'pwauth.$username.hash': legacyHash,
      });
      expect(await store.verify(username, 'wrongpass'), isFalse);
      final notUpgraded = await const FlutterSecureStorage().read(key: 'pwauth.$username.hash');
      expect(notUpgraded, legacyHash, reason: '验证失败不得升级');
    });
  });
}
