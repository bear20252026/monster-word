// Monster Word App
//
// 本机账号密码认证实现（data 层）：flutter_secure_storage 存盐值 + 哈希。
// 设计要点：
// - 密码永不落明文：只存随机盐 + SHA-256(salt:password)，校验走同哈希比对
// - 用户名做 key 时统一小写 trim，避免「Abc/abc」视为两个账号
// - 手机号格式的用户名注册时自动绑定，供忘记密码走短信找回

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

import 'package:word_app/features/account/application/password_auth_store.dart';

class SecurePasswordAuthStore implements PasswordAuthStore {
  SecurePasswordAuthStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _storage;

  static const _phonePattern = r'^1[3-9]\d{9}$';

  String _prefix(String username) => 'pwauth.${username.trim().toLowerCase()}';

  /// 纯函数哈希（可单测）：`SHA-256('mw:<salt>:<password>')`。
  static String hashPassword(String salt, String password) =>
      sha256.convert(utf8.encode('mw:$salt:$password')).toString();

  static bool isPhoneFormat(String value) => RegExp(_phonePattern).hasMatch(value.trim());

  @override
  Future<bool> hasPassword(String username) async {
    final hash = await _storage.read(key: '${_prefix(username)}.hash');
    return hash != null && hash.isNotEmpty;
  }

  @override
  Future<bool> verify(String username, String password) async {
    final salt = await _storage.read(key: '${_prefix(username)}.salt');
    final hash = await _storage.read(key: '${_prefix(username)}.hash');
    if (salt == null || salt.isEmpty || hash == null || hash.isEmpty) return false;
    return hashPassword(salt, password) == hash;
  }

  @override
  Future<String?> boundPhone(String username) async {
    final phone = await _storage.read(key: '${_prefix(username)}.phone');
    if (phone == null || phone.isEmpty) return null;
    return phone;
  }

  @override
  Future<void> setPassword(String username, String password, {String? phone}) async {
    final prefix = _prefix(username);
    // 每次设置都换新盐（重置后旧哈希彻底失效）
    final salt = _randomSalt();
    await _storage.write(key: '$prefix.salt', value: salt);
    await _storage.write(key: '$prefix.hash', value: hashPassword(salt, password));
    // 手机号格式的用户名自动绑定（单一事实来源：绑定逻辑只在此处）
    var phoneToBind = phone?.trim();
    if ((phoneToBind == null || phoneToBind.isEmpty) && isPhoneFormat(username)) {
      phoneToBind = username.trim();
    }
    if (phoneToBind != null && phoneToBind.isNotEmpty) {
      await _storage.write(key: '$prefix.phone', value: phoneToBind);
    }
  }

  static String _randomSalt() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
