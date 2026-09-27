// 由 Claude 团队生成 | Monster Word App

// 释义文本单一真相（审计提升点 I2）：此前 Word.cleanInterpret /
// WordChoicePair.cleanInterpret / MwWordProcess 各持一份逐字相同的
// "interpret JSON → 可读文本" 提取逻辑，改格式必须改多处（架构规范 §4
// 双轨禁令）。本文件是唯一的提取与回退实现。
import 'dart:convert';

/// 从 interpret JSON 提取可读释义文本（词性 + 中英释义拼接，`；`分隔）。
///
/// 提取成功返回拼接文本；interpret 非 JSON、解析失败或无有效释义时返回
/// null（调用方回退到 [cleanDefinitionHtml]）。
/// def 为整数 ID 引用（如 22285）时跳过不显示。
String? extractReadableInterpretText(String interpret) {
  try {
    final decoded = jsonDecode(interpret);
    if (decoded is List && decoded.isNotEmpty) {
      final texts = <String>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final pos = (item['t'] ?? item['pos'] ?? '') as String;
        if (pos.isNotEmpty) texts.add(pos);
        final defList = item['def'];
        if (defList is List) {
          for (final d in defList) {
            if (d is Map) {
              final en = (d['en'] ?? d['endef'] ?? '') as String;
              final cn = (d['cn'] ?? d['cndef'] ?? '') as String;
              if (cn.isNotEmpty) texts.add(cn);
              if (en.isNotEmpty) texts.add(en);
            }
            // 跳过整数 ID 引用（如 22285），不显示
          }
        }
      }
      if (texts.isNotEmpty) return texts.join('；');
    }
  } catch (_) {
    // C 级豁免：解析失败由调用方回退原文（REG-OBS-001，内容降级非数据丢失）
  }
  return null;
}

/// 释义回退清理：去 HTML 标签/实体/多余空白。
/// 统一走 Word.cleanHtml 的同源语义（此前 WordChoicePair 用 `&[a-zA-Z]+;`
/// 泛匹配、MwWordProcess 另有一份六实体版本——收敛到这一份）。
String cleanDefinitionHtml(String text) {
  if (text.isEmpty) return '';
  var result = text.replaceAll(RegExp(r'<[^>]*>'), '');
  result = result.replaceAll(RegExp(r'&[a-zA-Z]+;|&#\d+;'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return result;
}
