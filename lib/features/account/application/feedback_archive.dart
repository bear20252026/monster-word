// 由 Claude 团队生成 | Monster Word App

// 反馈提交：本地存档兜底 + Sentry User Feedback 上报（复用已配置的
// sentry_flutter，无需后端）。内容永不静默丢弃。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 上报回调：隔离 Sentry 依赖以便测试注入。
typedef FeedbackUploader = Future<void> Function(FeedbackEntry entry);

/// 单条反馈（本地存档与上报共用的值对象）。
@immutable
class FeedbackEntry {
  final String content;
  final String? contact;
  final DateTime submittedAt;

  const FeedbackEntry({required this.content, required this.submittedAt, this.contact});

  Map<String, dynamic> toJson() => <String, dynamic>{
    'content': content,
    if (contact != null) 'contact': contact,
    'submittedAt': submittedAt.toIso8601String(),
  };
}

class FeedbackArchive {
  FeedbackArchive({FeedbackUploader? upload, this.prefsOverride}) : upload = upload ?? _sentryUpload;

  static const String _storageKey = 'mw.feedback.archive';

  final FeedbackUploader upload;
  final SharedPreferences? prefsOverride;

  /// 提交反馈：先本地存档（必成功），再尽力上报 Sentry（失败不影响提交语义）。
  /// 返回本地存档后的完整历史。
  Future<List<FeedbackEntry>> submit({required String content, String? contact}) async {
    final entry = FeedbackEntry(content: content.trim(), contact: contact?.trim(), submittedAt: DateTime.now());

    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final history = _decode(prefs.getString(_storageKey))..add(entry);
    await prefs.setString(_storageKey, jsonEncode(history.map((e) => e.toJson()).toList()));

    try {
      await upload(entry);
    } catch (_) {
      // 上报失败不阻断提交：内容已在本地存档，下次诊断/反馈可复查。
    }
    return history;
  }

  /// 读取本地反馈历史（供设置页后续展示/导出扩展）。
  Future<List<FeedbackEntry>> history() async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    return _decode(prefs.getString(_storageKey));
  }

  static List<FeedbackEntry> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <FeedbackEntry>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (dynamic e) => FeedbackEntry(
              content: (e as Map<String, dynamic>)['content'] as String,
              contact: e['contact'] as String?,
              submittedAt: DateTime.parse(e['submittedAt'] as String),
            ),
          )
          .toList();
    } catch (_) {
      return <FeedbackEntry>[];
    }
  }

  /// 默认上报：Sentry User Feedback。邮箱格式才填 contactEmail，
  /// 其余联系方式并入消息体。
  static Future<void> _sentryUpload(FeedbackEntry entry) async {
    final email = entry.contact;
    final isEmail = email != null && RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(email);
    final message = isEmail || email == null || email.isEmpty ? entry.content : '${entry.content}\n联系方式：$email';
    final feedback = SentryFeedback(message: message, contactEmail: isEmail ? email : null);
    await Sentry.captureFeedback(feedback);
  }
}
