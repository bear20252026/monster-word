// 对比度自动化守卫 — WCAG AA 回归测试
// 读取 ThemeVars 全部语义配对，断言对比度 ≥ 阈值
// 三套主题（明亮/深邃/极夜）各跑一遍
//
// 参考：docs/a11y_contrast_report.md、docs/a11y_dark_mode_report.md

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/theme/skin_system.dart';

void main() {
  // 遍历所有主题
  for (final entry in themes.entries) {
    final themeId = entry.key;
    final preset = entry.value;
    final vars = preset.vars;

    group('WCAG 对比度守卫 — ${preset.name}（$themeId）', () {
      // ── 正文级配对（阈值 4.5:1） ──
      _testPair('正文/画布', vars.text1, vars.pageBg, 4.5, themeId);
      _testPair('次要文字/画布', vars.text2, vars.pageBg, 4.5, themeId);
      _testPair('三级文字/画布', vars.text3, vars.pageBg, 4.5, themeId);
      _testPair('正文/卡片', vars.text1, vars.cardBg, 4.5, themeId);
      _testPair('次要文字/卡片', vars.text2, vars.cardBg, 4.5, themeId);
      _testPair('三级文字/卡片', vars.text3, vars.cardBg, 4.5, themeId);
      _testPair('强调色/画布', vars.accent, vars.pageBg, 4.5, themeId);
      _testPair('强调色/卡片', vars.accent, vars.cardBg, 4.5, themeId);
      _testPair('成功色/画布', vars.success, vars.pageBg, 4.5, themeId);
      _testPair('危险色/画布', vars.danger, vars.pageBg, 4.5, themeId);
      _testPair('链接色/画布', vars.teal, vars.pageBg, 4.5, themeId);
      _testPair('玻璃文字/玻璃底', vars.onGlassText1, vars.glassBg, 4.5, themeId);
      _testPair('玻璃次要/玻璃底', vars.onGlassText2, vars.glassBg, 4.5, themeId);
      _testPair('玻璃强调/玻璃底', vars.onGlassAccent, vars.glassBg, 4.5, themeId);
      _testPair('答对文字/答对底', vars.quizCorrectText, vars.quizCorrectBg, 4.5, themeId);
      _testPair('答错文字/答错底', vars.quizWrongText, vars.quizWrongBg, 4.5, themeId);
      _testPair('VIP文字/VIP底', vars.vipGoldText, vars.vipGoldBg, 4.5, themeId);
      _testPair('弹窗文字/弹窗底', vars.modalText1, vars.modalGlassBg, 4.5, themeId);
      _testPair('弹窗次要/弹窗底', vars.modalText2, vars.modalGlassBg, 4.5, themeId);

      // ── 大元素/图标级配对（阈值 3.0:1） ──
      _testPair('标签栏图标/画布', vars.tabBarIcon, vars.pageBg, 3.0, themeId);
    });
  }
}

/// 测试单个配对的对比度
void _testPair(String label, Color foreground, Color background, double threshold, String themeId) {
  test('$label — 对比度 ≥ ${threshold.toStringAsFixed(1)}:1', () {
    // 带 alpha 的前景色先与背景做 alpha 合成
    final effectiveFg = _alphaComposite(foreground, background);
    final ratio = contrastRatio(effectiveFg, background);
    expect(
      ratio >= threshold,
      true,
      reason: _failureMessage(label, foreground, background, effectiveFg, ratio, threshold),
    );
  });
}

/// Alpha 合成：将前景色叠加到背景色上，返回等效实色
/// 用于处理 rgba(r,g,b,α) 类型的半透明颜色
Color _alphaComposite(Color fg, Color bg) {
  if (fg.alpha == 255) return fg; // 不透明，无需合成
  final a = fg.alpha / 255.0;
  final r = (a * fg.red + (1 - a) * bg.red).round();
  final g = (a * fg.green + (1 - a) * bg.green).round();
  final b = (a * fg.blue + (1 - a) * bg.blue).round();
  return Color.fromARGB(255, r, g, b);
}

/// 失败时的详细输出
String _failureMessage(String label, Color originalFg, Color bg, Color effectiveFg, double actual, double required) {
  final fgHex = '#${originalFg.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  final bgHex = '#${bg.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  final effHex = '#${effectiveFg.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  // 判断是否经过了 alpha 合成
  final alphaNote = originalFg.alpha < 255 ? '  （α=${originalFg.alpha}，合成等效色：$effHex）\n' : '';

  return '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ WCAG 对比度不达标：$label
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  前景色：$fgHex  (r=${originalFg.red}, g=${originalFg.green}, b=${originalFg.blue}, a=${originalFg.alpha})
  背景色：$bgHex  (r=${bg.red}, g=${bg.green}, b=${bg.blue}, a=${bg.alpha})
$alphaNote  实测对比度：${actual.toStringAsFixed(2)}:1
  要求阈值：${required.toStringAsFixed(1)}:1
  差距：${(required - actual).toStringAsFixed(2)}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  修复建议：
  1. 调整前景色使其更深/更亮（增大与背景的明度差）
  2. 或调整背景色
  3. 参考 https://webaim.org/resources/contrastchecker/ 在线验证
  4. 若为大元素（≥18pt 或 ≥14pt bold），可将阈值从 4.5 降为 3.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
}

// ── WCAG 对比度计算函数 ──

/// 计算两个颜色的 WCAG 对比度
/// 返回值 ≥ 1.0（相同颜色 = 1.0:1）
/// 注意：传入的 Color 必须已做 alpha 合成（a=255）
double contrastRatio(Color a, Color b) {
  final l1 = relativeLuminance(a);
  final l2 = relativeLuminance(b);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// 计算颜色的 WCAG 相对亮度
/// 基于 sRGB → 线性转换（WCAG 2.1 定义）
/// 阈值 0.03928 与人工审查脚本一致
double relativeLuminance(Color c) {
  // sRGB 通道归一化到 [0, 1]
  final r = c.red / 255.0;
  final g = c.green / 255.0;
  final b = c.blue / 255.0;

  // sRGB → 线性（WCAG 2.1 精确公式）
  final rLin = _srgbToLinear(r);
  final gLin = _srgbToLinear(g);
  final bLin = _srgbToLinear(b);

  return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin;
}

/// sRGB → 线性转换
/// 值 ≤ 0.03928 时除以 12.92，否则 ((v+0.055)/1.055)^2.4
double _srgbToLinear(double v) {
  if (v <= 0.03928) {
    return v / 12.92;
  }
  return pow((v + 0.055) / 1.055, 2.4).toDouble();
}
