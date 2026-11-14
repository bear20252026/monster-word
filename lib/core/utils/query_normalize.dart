/// 查询输入归一（用户反馈修复 2026-11-14）。
///
/// 词库 word 列以 ASCII 小写为主存储；旧查词/搜索只做 trim，导致：
/// - 深链/查词携带大写（`Apple`）时 BINARY 点查不中（搜索页却能搜到）；
/// - 中文输入法全角（`ａｐｐｌｅ`/`１００`）静默搜不到。
/// 这里统一：全角→半角、trim、ASCII 折小写。中文不受 toLowerCase 影响。
library;

/// 全角 ASCII（U+FF01..U+FF5E）→ 半角（0x21..0x7E）；全角空格 U+3000 → 空格。
String foldFullWidth(String input) {
  final sb = StringBuffer();
  for (final code in input.codeUnits) {
    if (code >= 0xFF01 && code <= 0xFF5E) {
      sb.writeCharCode(code - 0xFEE0);
    } else if (code == 0x3000) {
      sb.write(' ');
    } else {
      sb.writeCharCode(code);
    }
  }
  return sb.toString();
}

/// 查词/搜索入口归一：全角→半角 + trim + 折小写。
String normalizeQuery(String input) => foldFullWidth(input).trim().toLowerCase();
