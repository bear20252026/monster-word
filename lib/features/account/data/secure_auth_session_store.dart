// Monster Word App
//
// 服务端会话存储实现（data 层）：flutter_secure_storage 存一个 JSON blob。
//
// 为什么整包存一个 key 而不是拆成多个 key：会话是**原子**的——只有
// access/refresh/expiresAt/userId 四个字段同时有效才有意义。拆开存会出现
// 「新 access + 旧 refresh」这种半新半旧状态，刷新时必然失败且难以排查。
//
// 读取失败一律降级为「无会话」而不是抛异常：会话丢失的后果是重新登录，
// 不该让应用起不来（与 `SecurePasswordAuthStore` 的 fail-closed 不同——
// 那里丢的是**凭据本体**，这里丢的只是**缓存**）。
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/account/application/auth_session_store.dart';

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _storage;

  /// 与 `AppPreferences.userToken` / `SecureTokenStorage` 不同 key，理由见端口文件头。
  static const String storageKey = 'mw.auth.session.v1';

  @override
  Future<AuthSession?> read() async {
    final String? raw;
    try {
      raw = await _storage.read(key: storageKey);
    } catch (e, s) {
      reportSwallowedError('会话读取失败（降级为未登录）', e, s);
      return null;
    }
    if (raw == null || raw.isEmpty) return null;
    final session = AuthSession.tryParse(
      raw,
      onError: (e, s) => reportSwallowedError('会话内容损坏（将清除并要求重新登录）', e, s),
    );
    if (session == null) {
      // 内容损坏（存储被改写 / 版本不兼容）：清掉，避免每次启动都白读一次。
      await clear();
    }
    return session;
  }

  @override
  Future<void> write(AuthSession session) async {
    try {
      await _storage.write(key: storageKey, value: jsonEncode(session.toJson()));
    } catch (e, s) {
      // 写失败 = 本次会话有效但下次冷启动需重新登录。不向上抛：
      // 登录本身已经成功，此时报错会把用户引向「再试一次」的无效动作。
      reportSwallowedError('会话写入失败（本次会话仍有效）', e, s);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: storageKey);
    } catch (e, s) {
      reportSwallowedError('会话清除失败', e, s);
    }
  }
}
