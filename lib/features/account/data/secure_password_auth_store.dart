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
// - 2026-10-13：移除手机号绑定与短信找回（Spug 官方要求验证码由服务端发起，
//   客户端不再持有调用凭证，见 R2-01）

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
    final (_, hash) = await _readCredential(username);
    return hash != null && hash.isNotEmpty;
  }

  @override
  Future<bool> verify(String username, String password) async {
    final prefix = _prefix(username);
    final (salt, hash) = await _readCredential(username);
    if (salt == null || salt.isEmpty || hash == null || hash.isEmpty) return false;

    if (hash.startsWith('$_hashPrefix\$')) {
      // 新格式：解析迭代数后 PBKDF2 比对。
      // MW-66：格式长度 + 迭代数上下界校验——损坏/被篡改的存储值曾可触发
      // RangeError 或让应用执行数十亿次 PBKDF2 轮（CPU 长时间占满）。
      if (!_isValidHashFormat(hash)) return false;
      final parts = hash.split(r'$');
      final iterations = int.tryParse(parts[1])!;
      if (iterations < minIterations || iterations > maxIterations) return false;
      return _constantTimeEquals(_encodePbkdf2(salt, password, iterations), hash);
    }

    // 存量单轮 SHA-256：验证通过则透明升级为 PBKDF2（同盐，无需用户重设）；
    // 升级结果直接落单 Blob（MW-65 读取优先级最高）。
    if (_constantTimeEquals(legacyHashPassword(salt, password), hash)) {
      try {
        final upgraded = jsonEncode({
          'v': 2,
          'algorithm': _hashPrefix,
          'salt': salt,
          'hash': hashPassword(salt, password),
        });
        await _storage.write(key: '$prefix.credential', value: upgraded);
      } catch (e, s) {
        // 升级写失败不影响本次登录结果（下次成功登录会再试）
        reportSwallowedError('密码哈希透明升级写入失败', e, s);
      }
      return true;
    }
    return false;
  }

  @override
  Future<void> setPassword(String username, String password) async {
    final prefix = _prefix(username);
    // 每次设置都换新盐（重置后旧哈希彻底失效）。
    // MW-65：盐+哈希合并为单 credential Blob 一次写入——「新盐×旧哈希」的
    // 中间态从根上消失（安全存储的单键写即原子语义边界）。旧的两键组合
    // 仍被 verify 兼容读取；新写入一律走单键。写失败直接抛（旧凭据从未
    // 被触碰，不存在锁死窗口），不再需要回滚路径。
    final salt = _randomSalt();
    final newHash = hashPassword(salt, password);
    final credential = jsonEncode({'v': 2, 'algorithm': _hashPrefix, 'salt': salt, 'hash': newHash});
    await _storage.write(key: '$prefix.credential', value: credential);
    // 迁移清理：旧的散键一旦新 Blob 写成功即作废（读取优先级低于 Blob），
    // 静默清理失败无碍——旧键残留只是冗余，不构成风险面。
    try {
      await _storage.delete(key: '$prefix.salt');
      await _storage.delete(key: '$prefix.hash');
    } catch (e, s) {
      reportSwallowedError('旧密码散键清理失败（残留无害）', e, s);
    }
    // 2026-10-13：手机号绑定随短信找回一起移除（绑定只服务短信找回，
    // 移除后无消费方；见 R2-01）。
  }

  @override
  Future<void> removePassword(String username) async {
    final prefix = _prefix(username);
    // 三处都要删：单 Blob 与旧散键。少删一个，`hasPassword` 就可能仍报 true，
    // 迁移装饰器会把「本机有旧凭据」误判成「用户输对了密码」。
    // 单键删失败即外抛：调用方（迁移路径）必须知道本机哈希还在。
    await _storage.delete(key: '$prefix.credential');
    try {
      await _storage.delete(key: '$prefix.salt');
      await _storage.delete(key: '$prefix.hash');
    } catch (e, s) {
      reportSwallowedError('本机凭据旧散键清理失败（残留无害）', e, s);
    }
  }

  /// 读取凭据（MW-65）：优先单 Blob；无 Blob 时回退旧散键组合（存量兼容）。
  ///
  /// R2-20：Blob **存在但损坏**时不再回退旧散键。回退等于把「权威凭据损坏」
  /// 解释成「那就试试更老的凭据」——升级路径允许旧散键删除失败，于是
  /// 「新 Blob 损坏 + 旧散键残留」会让升级前的旧密码重新生效。此处改为
  /// fail-closed（返回空凭据 ⇒ 校验必然失败，只能走「忘记密码」重置）；
  /// 只有 Blob **完全不存在**（从未升级过）才允许读旧散键。
  Future<(String?, String?)> _readCredential(String username) async {
    final prefix = _prefix(username);
    final blob = await _storage.read(key: '$prefix.credential');
    if (blob != null && blob.isNotEmpty) {
      try {
        final map = jsonDecode(blob) as Map<String, dynamic>;
        return (map['salt'] as String?, map['hash'] as String?);
      } catch (e, s) {
        reportSwallowedError('密码凭据 Blob 损坏，按 fail-closed 处理（不回退旧散键）', e, s);
        return (null, null);
      }
    }
    final salt = await _storage.read(key: '$prefix.salt');
    final hash = await _storage.read(key: '$prefix.hash');
    return (salt, hash);
  }

  /// MW-66：哈希格式校验（parts 数 = 3、迭代数可解析、hex 段 64 位小写）。
  static bool _isValidHashFormat(String hash) {
    final parts = hash.split(r'$');
    if (parts.length != 3) return false;
    if (int.tryParse(parts[1]) == null) return false;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(parts[2])) return false;
    return true;
  }

  static const int minIterations = 1000;

  /// R2-20：校验侧接受的迭代数上限。此前为 10,000,000——按本文件自身注释
  /// （60,000 迭代在低端机约 0.5～1 秒），10M 相当于单次校验阻塞 CPU 约
  /// 80～170 秒，被篡改/损坏的哈希即可把登录界面卡死（DoS）。改为当前参数的
  /// 8 倍，既留出将来调参的升级余量，又不给异常值留出灾难性开销。
  /// 本应用只会写入 [pbkdf2Iterations]，故不存在「存量哈希超上限」的情况。
  static const int maxIterations = pbkdf2Iterations * 8;

  static String _randomSalt() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
