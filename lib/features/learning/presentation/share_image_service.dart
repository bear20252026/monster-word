// 分享图片生成服务
// 使用 CustomPaint 手绘宣传图，保存到本地并分享
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:word_app/tokens/starbucks_tokens.dart';

/// 分享图片生成器
class ShareImageService {
  /// 生成 Monster Word 宣传图
  static Future<Uint8List> generateShareImage({
    required int totalWords,
    required int streakDays,
    required int totalDays,
  }) async {
    const double width = 1080;
    const double height = 1920;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // === 背景渐变 ===
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [StarbucksCreamColors.greenHouse, StarbucksCreamColors.greenBanner],
    );
    final bgPaint = Paint()..shader = bgGradient.createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // === 装饰圆 ===
    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(width * 0.8, height * 0.15), 200, circlePaint);
    canvas.drawCircle(Offset(width * 0.2, height * 0.7), 300, circlePaint);
    canvas.drawCircle(Offset(width * 0.9, height * 0.85), 250, circlePaint);

    // === 金色分割线 ===
    final linePaint = Paint()
      ..color = StarbucksCreamColors.vipGoldBg
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(width * 0.1, height * 0.25), Offset(width * 0.9, height * 0.25), linePaint);

    // === 标题文字 ===
    _drawText(
      canvas,
      'Monster Word',
      width / 2,
      height * 0.12,
      fontSize: 72,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );

    _drawText(canvas, '背单词 · 有态度', width / 2, height * 0.18, fontSize: 36, color: StarbucksCreamColors.vipGoldBg);

    // === 数据统计卡片 ===
    final cardTop = height * 0.32;
    final cardHeight = 280.0;
    _drawStatCard(canvas, width * 0.1, cardTop, width * 0.8, cardHeight, '累计学习', '$totalDays 天', Icons.calendar_today);
    _drawStatCard(
      canvas,
      width * 0.1,
      cardTop + cardHeight + 30,
      width * 0.8,
      cardHeight,
      '掌握单词',
      '$totalWords 个',
      Icons.menu_book,
    );
    _drawStatCard(
      canvas,
      width * 0.1,
      cardTop + (cardHeight + 30) * 2,
      width * 0.8,
      cardHeight,
      '连续签到',
      '$streakDays 天 🔥',
      Icons.local_fire_department,
    );

    // === 底部装饰 ===
    final bottomY = height * 0.88;
    _drawText(canvas, '每一天，都在进步', width / 2, bottomY, fontSize: 32, color: Colors.white.withValues(alpha: 0.7));

    _drawText(canvas, '— Monster Word —', width / 2, bottomY + 60, fontSize: 24, color: StarbucksCreamColors.vipGoldBg);

    // === 二维码占位区域 ===
    final qrSize = 160.0;
    final qrLeft = (width - qrSize) / 2;
    final qrTop = height * 0.72;
    final qrPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(qrLeft, qrTop, qrSize, qrSize), const Radius.circular(16)),
      qrPaint,
    );

    // 二维码内部网格
    final qrInnerPaint = Paint()
      ..color = StarbucksCreamColors.greenBanner
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        if ((i + j) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(qrLeft + 20 + i * 15.0, qrTop + 20 + j * 15.0, 12, 12), qrInnerPaint);
        }
      }
    }

    _drawText(
      canvas,
      '扫码下载 Monster Word',
      width / 2,
      qrTop + qrSize + 30,
      fontSize: 20,
      color: Colors.white.withValues(alpha: 0.6),
    );

    // === 渲染 ===
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y, {
    double fontSize = 32,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color, fontWeight: fontWeight, fontFamily: 'sans-serif'),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y));
  }

  static void _drawStatCard(
    Canvas canvas,
    double left,
    double top,
    double w,
    double h,
    String label,
    String value,
    IconData icon,
  ) {
    // 卡片背景
    final cardPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(20)), cardPaint);

    // 卡片边框
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(20)), borderPaint);

    // 图标
    _drawText(
      canvas,
      String.fromCharCode(icon.codePoint),
      left + 60,
      top + h / 2 - 20,
      fontSize: 48,
      color: StarbucksCreamColors.vipGoldBg,
    );

    // 标签
    _drawText(canvas, label, left + 130, top + h / 2 - 30, fontSize: 28, color: Colors.white.withValues(alpha: 0.7));

    // 数值
    _drawText(
      canvas,
      value,
      left + 130,
      top + h / 2 + 30,
      fontSize: 42,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );
  }

  /// 生成并保存图片到临时目录，返回文件路径
  static Future<String> generateAndSave({
    required int totalWords,
    required int streakDays,
    required int totalDays,
  }) async {
    final bytes = await generateShareImage(totalWords: totalWords, streakDays: streakDays, totalDays: totalDays);
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/monster_word_share_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  /// 生成并直接分享
  static Future<void> generateAndShare({
    required int totalWords,
    required int streakDays,
    required int totalDays,
  }) async {
    final filePath = await generateAndSave(totalWords: totalWords, streakDays: streakDays, totalDays: totalDays);
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Monster Word 学习打卡',
      text: '我在 Monster Word 已学习 $totalDays 天，掌握 $totalWords 个单词，连续签到 $streakDays 天！一起来背单词吧！',
    );
  }
}
