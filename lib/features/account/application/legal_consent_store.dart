// MW-78：协议同意留痕端口（application 层）。
//
// 此前「登录即同意」只是登录页上的一句文案——没有任何记录说明用户同意了
// 哪一版协议、何时同意的。本端口把该事实落为可读、可审计的本地记录：
// policyVersion（同意时的政策版本）+ acceptedAt（同意时间）。
//
// 实现见 data/prefs_legal_consent_store.dart。

import 'package:word_app/features/account/domain/legal_documents.dart';

class LegalConsentRecord {
  const LegalConsentRecord({required this.policyVersion, required this.acceptedAt});

  /// 用户同意时生效的政策版本。
  final String policyVersion;

  /// 同意时间（本地时区）。
  final DateTime acceptedAt;

  /// 该记录是否覆盖当前生效版本（版本升级后旧记录自动过期）。
  bool get coversCurrentVersion => policyVersion == LegalDocuments.policyVersion;

  Map<String, Object?> toJson() => {'policyVersion': policyVersion, 'acceptedAt': acceptedAt.toIso8601String()};

  static LegalConsentRecord? fromJson(Map<String, dynamic> json) {
    final version = json['policyVersion'] as String?;
    final rawAt = json['acceptedAt'] as String?;
    if (version == null || version.isEmpty || rawAt == null) return null;
    final at = DateTime.tryParse(rawAt);
    if (at == null) return null;
    return LegalConsentRecord(policyVersion: version, acceptedAt: at);
  }
}

abstract class LegalConsentStore {
  /// 读取最近一次同意记录（从未同意过返回 null）。
  Future<LegalConsentRecord?> read();

  /// 记录一次同意。返回 false 表示写入失败（调用方按「未留痕」处理，不阻断登录）。
  Future<bool> record(String policyVersion, {DateTime? acceptedAt});

  /// 当前生效版本是否已被同意。
  Future<bool> isCurrentVersionAccepted();
}
