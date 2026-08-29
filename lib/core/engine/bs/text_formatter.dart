// 移植自 v3.2 bs/TextFormatter.java
// 文本格式化工具：数字高亮着色

import 'package:flutter/material.dart';

/// 文本格式化工具（翻译自 TextFormatter.java）
///
/// 将文本中的数字部分用指定颜色高亮显示。
/// 原版返回 Android Spanned，Flutter 版返回 Widget 或 TextSpan。
class TextFormatter {
  /// 将文本中的数字着色（原版 numColored）
  ///
  /// 返回 [TextSpan] 列表，数字部分使用指定颜色。
  /// 可直接用于 [RichText] 的 [TextSpan] 树。
  static TextSpan numColored(String text, Color numberColor) {
    if (text.isEmpty) {
      return TextSpan(text: text);
    }

    // 替换换行符
    text = text.replaceAll('\n', '');

    final spans = <InlineSpan>[];
    final regex = RegExp(r'[0-9]+');
    var lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // 匹配前的普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      // 数字部分着色
      spans.add(
        TextSpan(
          text: ' ${match.group(0)} ',
          style: TextStyle(color: numberColor),
        ),
      );

      lastEnd = match.end;
    }

    // 匹配后的普通文本
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return TextSpan(children: spans.cast<InlineSpan>());
  }

  /// 将文本中的数字着色（Widget 版本，直接返回 RichText）
  static Widget numColoredWidget(String text, Color numberColor, {TextStyle? style}) {
    return RichText(text: numColored(text, numberColor));
  }

  /// 从 Color int 值创建颜色（原版 #AARRGGBB 格式）
  static Color colorFromInt(int colorInt) {
    return Color(colorInt);
  }

  /// 从十六进制字符串创建颜色（原版 "#rrggbb" 格式）
  static Color colorFromHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}
