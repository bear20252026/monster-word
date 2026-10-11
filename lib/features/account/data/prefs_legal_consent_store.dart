// MW-78：协议同意留痕的本地实现（data 层）。
//
// 用 SharedPreferences 存单条 JSON。协议正文随包（domain/legal_documents.dart），
// 因此只需记录「同意的是哪一版 + 何时」——正文本身无需持久化，版本号即可
// 追溯到当时的文本。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/account/application/legal_consent_store.dart';
import 'package:word_app/features/account/domain/legal_documents.dart';

class PrefsLegalConsentStore implements LegalConsentStore {
  static const String prefsKey = 'legal_consent_v1';

  @override
  Future<LegalConsentRecord?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return LegalConsentRecord.fromJson(decoded);
    } catch (e, s) {
      // 读取失败按「无记录」降级，但必须可观测（否则重新征得同意的判断会失真）。
      reportSwallowedError('协议同意记录读取失败', e, s);
      return null;
    }
  }

  @override
  Future<bool> record(String policyVersion, {DateTime? acceptedAt}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = LegalConsentRecord(
        policyVersion: policyVersion,
        acceptedAt: acceptedAt ?? DateTime.now(),
      ).toJson();
      return await prefs.setString(prefsKey, jsonEncode(payload));
    } catch (e, s) {
      reportSwallowedError('协议同意记录写入失败', e, s);
      return false;
    }
  }

  @override
  Future<bool> isCurrentVersionAccepted() async {
    final record = await read();
    return record?.coversCurrentVersion ?? false;
  }
}
