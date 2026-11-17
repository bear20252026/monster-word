// 审计 R3（2026-11-16）：上报脱敏收口——FormatException.source（用户原文）不得进上报。
// 第三轮 T16：网络异常 toString 含带查询词的完整 URL，同样必须剥离。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

void main() {
  test('FormatException 带 source：脱敏后不含原文，保留 message 分组', () {
    const secret = '用户笔记原文-手机号13800000000';
    final e = FormatException('Unexpected character', secret, 3);
    final safe = sanitizeErrorForReport(e);
    expect(safe.contains(secret), isFalse, reason: 'source 原文不得出现在上报描述');
    expect(safe.contains('Unexpected character'), isTrue, reason: 'message 保留供 Sentry 分组');
    expect(safe.contains('FormatException'), isTrue);
  });

  test('jsonDecode 真实异常：source=原文被剥离', () {
    const raw = '{"笔记":"私密内容", 坏';
    Object? caught;
    try {
      // ignore: avoid_dynamic_calls
      jsonDecodeLike(raw);
    } catch (e) {
      caught = e;
    }
    expect(caught, isA<FormatException>());
    final safe = sanitizeErrorForReport(caught!);
    expect(safe.contains('私密内容'), isFalse);
  });

  test('非 FormatException 且无 URL：原样保留（不影响其他异常分组）', () {
    final e = StateError('db closed');
    expect(sanitizeErrorForReport(e), '$e');
  });

  test('第三轮 T16：SocketException 含发音 URL（带查询词）——URL 整体剥离', () {
    const word = '私密学习词';
    final e = SocketException(
      'Connection failed',
      osError: OSError('拒绝访问。', 5),
      address: InternetAddress.tryParse('127.0.0.1'),
      port: 443,
    );
    // 真实形态：HttpException/ClientException 的 message 直接嵌 URL。
    final withUrl = HttpException(
      'Connection closed before full header was received, '
      'uri = https://dict.youdao.com/dictvoice?audio=$word&type=2',
    );
    final safe = sanitizeErrorForReport(withUrl);
    expect(safe.contains(word), isFalse, reason: '查询词不得随崩溃事件离开本机');
    expect(safe.contains('dict.youdao.com'), isFalse);
    expect(safe.contains('URL 已脱敏'), isTrue);
    expect(safe.contains('HttpException'), isTrue, reason: '类型保留供分组');
    // SocketException 本身无 URL 时不受影响。
    expect(sanitizeErrorForReport(e), contains('SocketException'));
  });

  test('第三轮 T16：多 URL 与括号边界都剥离', () {
    final e = StateError('fetch failed (https://a.example/x?q=词A) then https://b.example/y?q=词B; retry');
    final safe = sanitizeErrorForReport(e);
    expect(safe.contains('词A'), isFalse);
    expect(safe.contains('词B'), isFalse);
    expect(safe.contains('a.example'), isFalse);
    expect(safe.contains('retry'), isTrue, reason: '非 URL 描述骨架保留');
  });
}

// 与 dart:convert jsonDecode 同语义的最小复现（避免测试引 convert 只为抛错）。
Object? jsonDecodeLike(String raw) {
  throw FormatException('Unexpected character', raw, raw.length - 1);
}
