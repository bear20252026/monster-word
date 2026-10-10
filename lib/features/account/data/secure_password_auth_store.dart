// Monster Word App
//
// 本机账号密码认证实现（data 层）：flutter_secure_storage 存盐值 + 哈希。
// 设计要点：
// - 密码永不落明文：只存随机盐 + KDF 哈希，校验走同哈希比对
// - 审计 I42：哈希从单轮 SHA-256 升级为 PBKDF2-HMAC-SHA256（快速哈希在
//   安全存储被提取后可被 GPU 秒级爆破弱口令）。存量单轮哈希在首次验证
//   成功时透明升级为 PBKDF2（无需用户重设密码）
// - 哈希存储带算法+迭代数前缀（`pbkdf2-sha256$<n>$<hex>`），未来调参
//   无需再迁移
// - 用户名做 key 时统一小写 trim，避免「Abc/abc」视为两个账号
// - 手机号格式的用户名注册时自动绑定，供忘记密码走短信找回

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/account/application/password_auth_store.dart';

class SecurePasswordAuthStore implements PasswordAuthStore {
  SecurePasswordAuthStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _storage;

  static const _phonePattern = r'^1[3-9]\d{9}$';

  /// PBKDF2 迭代数。基准（本机 Windows/JIT）：6 万次 ≈190ms，AOT 更快，
  /// 低端 Android 约 0.5-1s（仅登录/设密码时执行，可接受）。
  /// 存储格式自带迭代数，后续上调无需迁移。
  static const int pbkdf2Iterations = 60000;

  static const _hashPrefix = 'pbkdf2-sha256';

  String _prefix(String username) => 'pwauth.${username.trim().toLowerCase()}';

  /// PBKDF2-HMAC-SHA256 纯函数（RFC 2898，可单测）。
  static Uint8List pbkdf2Sha256(List<int> password, List<int> salt, int iterations, int dkLen) {
    final hmac = Hmac(sha256, password);
    final blockCount = (dkLen + 31) ~/ 32;
    final out = BytesBuilder();
    for (var block = 1; block <= blockCount; block++) {
      var u = hmac.convert(Uint8List.fromList([...salt, 0, 0, 0, block])).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < 32; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(Uint8List.fromList(t));
    }
    return Uint8List.fromList(out.toBytes().sublist(0, dkLen));
  }

  /// 纯函数哈希（可单测）：`PBKDF2-HMAC-SHA256(salt, password, 6 万轮)`，
  /// 存储格式 `pbkdf2-sha256$<iterations>$<hex>`。
  static String hashPassword(String salt, String password) => _encodePbkdf2(salt, password, pbkdf2Iterations);

  static String _encodePbkdf2(String salt, String password, int iterations) {
    final derived = pbkdf2Sha256(utf8.encode('mw:$salt:$password'), utf8.encode(salt), iterations, 32);
    return '$_hashPrefix\$$iterations\$${_toHex(derived)}';
  }

  /// 旧版单轮哈希（仅用于存量验证与透明升级，新写入不再使用）
  static String legacyHashPassword(String salt, String password) =>
      sha256.convert(utf8.encode('mw:$salt:$password')).toString();

  static bool isPhoneFormat(String value) => RegExp(_phonePattern).hasMatch(value.trim());

  /// 常量时间字节比较（防时序侧信道；长度不齐直接不等）
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  @override
  Future<bool> hasPassword(String username) async {
    final hash = await _readHash(username);
    return hash != null && hash.isNotEmpty;
  }

  @override
  Future<bool> verify(String username, String password) async {
    final prefix = _prefix(username);
    final salt = await _storage.read(key: '$prefix.salt');
    final hash = await _readHash(username);
    if (salt == null || salt.isEmpty || hash == null || hash.isEmpty) return false;

    if (hash.startsWith('$_hashPrefix\$')) {
      // 新格式：解析迭代数后 PBKDF2 比对
      final parts = hash.split(r'$');
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 1) return false;
      return _constantTimeEquals(_encodePbkdf2(salt, password, iterations), hash);
    }

    // 存量单轮 SHA-256：验证通过则透明升级为 PBKDF2（同盐，无需用户重设）
    if (_constantTimeEquals(legacyHashPassword(salt, password), hash)) {
      try {
        await _storage.write(key: '$prefix.hash', value: hashPassword(salt, password));
      } catch (e, s) {
        // 升级写失败不影响本次登录结果（下次成功登录会再试）
        reportSwallowedError('密码哈希透明升级写入失败', e, s);
      }
      return true;
    }
    return false;
  }

  Future<String?> _readHash(String username) => _storage.read(key: '${_prefix(username)}.hash');

  @override
  Future<String?> boundPhone(String username) async {
    final phone = await _storage.read(key: '${_prefix(username)}.phone');
    if (phone == null || phone.isEmpty) return null;
    return phone;
  }

  @override
  Future<void> setPassword(String username, String password, {String? phone}) async {
    final prefix = _prefix(username);
    // 每次设置都换新盐（重置后旧哈希彻底失效）。
    // 两键非原子：无论先写哪个，崩溃落在中间都是「新盐×旧哈希」组合——
    // 新旧两个密码都验不过，用户被永久锁死。对策：先读旧值，任一写失败就回滚到旧组合（保持可登录）并抛错。
    final oldSalt = await _storage.read(key: '$prefix.salt');
    final oldHash = await _storage.read(key: '$prefix.hash');
    final salt = _randomSalt();
    final newHash = hashPassword(salt, password);
    try {
      await _storage.write(key: '$prefix.salt', value: salt);
      await _storage.write(key: '$prefix.hash', value: newHash);
    } catch (e) {
      // 回滚：两键一起写回旧值（旧值为空则移除，维持「未设密码」初态）。
      try {
        if (oldSalt != null) {
          await _storage.write(key: '$prefix.salt', value: oldSalt);
        } else {
          await _storage.delete(key: '$prefix.salt');
        }
        if (oldHash != null) {
          await _storage.write(key: '$prefix.hash', value: oldHash);
        } else {
          await _storage.delete(key: '$prefix.hash');
        }
      } catch (rollbackError, rollbackStack) {
        reportSwallowedError('密码设置失败后回滚也失败（可能已锁死，需短信重置）', rollbackError, rollbackStack);
      }
      rethrow;
    }
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
