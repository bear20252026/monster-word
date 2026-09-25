// part of profile_screen.dart — 怪兽小屋绘制件（家具 / 房主 / 币图标）。
// 几何与 deliverables/room-hub-settings-prototype.html 同源。
part of 'profile_screen.dart';

/// ① 装备架（我的装备）。
class _ShelfPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 128;
    Paint p(Color c) => Paint()..color = c;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(2 * s, 46 * s, 126 * s, 53 * s), Radius.circular(3.5 * s)),
      p(RoomPalette.wood),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(2 * s, 46 * s, 126 * s, 49 * s), Radius.circular(1.5 * s)),
      p(RoomPalette.rugBase),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(8 * s, 52 * s, 14 * s, 62 * s), Radius.circular(2 * s)),
      p(RoomPalette.woodDeep),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(114 * s, 52 * s, 120 * s, 62 * s), Radius.circular(2 * s)),
      p(RoomPalette.woodDeep),
    );
    // 徽章一：尖叫铃铛（珊瑚）
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(12 * s, 16 * s, 38 * s, 42 * s), Radius.circular(8 * s)),
      p(TreasurePalette.coinColors[2]),
    );
    final bell = Paint()
      ..color = TreasurePalette.cream
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(20 * s, 32 * s)
        ..quadraticBezierTo(25 * s, 20 * s, 30 * s, 32 * s),
      bell,
    );
    // 徽章二：青绿头像环
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(51 * s, 16 * s, 77 * s, 42 * s), Radius.circular(8 * s)),
      p(TreasurePalette.pigSkinTop),
    );
    canvas.drawCircle(Offset(64 * s, 29 * s), 7 * s, bell);
    canvas.drawLine(Offset(64 * s, 22 * s), Offset(64 * s, 18 * s), bell);
    // 空槽（虚线）
    final dash = Paint()
      ..color = RoomPalette.woodDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(90 * s, 16 * s, 116 * s, 42 * s), Radius.circular(8 * s)),
      dash..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ShelfPainter old) => false;
}

/// ② 窗（外观 & 沉浸场景；sceneIdx 0 日 / 1 暮 / 2 夜）。
class _WindowPainter extends CustomPainter {
  _WindowPainter({required this.sceneIdx});

  final int sceneIdx;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 118;
    Paint p(Color c) => Paint()..color = c;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(4 * s, 4 * s, 114 * s, 84 * s), Radius.circular(10 * s)),
      p(RoomPalette.woodFrame),
    );
    final sky = [RoomPalette.skyDay, RoomPalette.skyDusk, RoomPalette.skyNight][sceneIdx];
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(9 * s, 9 * s, 109 * s, 79 * s), Radius.circular(7 * s)),
      p(sky),
    );
    // 星（夜）
    if (sceneIdx == 2) {
      final star = p(RoomPalette.star);
      for (final c in [const Offset(30, 24), Offset(55, 40), Offset(82, 58), Offset(98, 30)]) {
        canvas.drawCircle(Offset(c.dx * s, c.dy * s), 1.3 * s, star);
      }
    }
    // 云（夜时淡出）
    final cloudAlpha = sceneIdx == 2 ? 0.12 : (sceneIdx == 1 ? 0.5 : 0.9);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(42 * s, 30 * s), width: 26 * s, height: 12 * s),
      p(RoomPalette.cloud.withValues(alpha: cloudAlpha)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(76 * s, 44 * s), width: 20 * s, height: 10 * s),
      p(RoomPalette.cloud.withValues(alpha: cloudAlpha * 0.8)),
    );
    // 日 / 暮阳 / 月
    final celestial = [RoomPalette.sunDay, RoomPalette.sunDusk, RoomPalette.moon][sceneIdx];
    final cPos = [const Offset(88, 24), Offset(30, 58), Offset(84, 22)][sceneIdx];
    canvas.drawCircle(Offset(cPos.dx * s, cPos.dy * s), 9 * s, p(celestial));
    // 十字窗棂
    canvas.drawRect(Rect.fromLTWH(56 * s, 9 * s, 5 * s, 70 * s), p(RoomPalette.woodFrame));
    canvas.drawRect(Rect.fromLTWH(9 * s, 41 * s, 100 * s, 5 * s), p(RoomPalette.woodFrame));
    // 窗台
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(0, 82 * s, 118 * s, 92 * s), Radius.circular(4 * s)),
      p(RoomPalette.woodSill),
    );
  }

  @override
  bool shouldRepaint(covariant _WindowPainter old) => old.sceneIdx != sceneIdx;
}

/// ③ 书桌台灯（学习偏好）。
class _DeskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 150;
    Paint p(Color c) => Paint()..color = c;
    final stroke = Paint()
      ..color = RoomPalette.woodDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round;
    // 光锥
    canvas.drawPath(
      Path()
        ..moveTo(96 * s, 40 * s)
        ..lineTo(64 * s, 96 * s)
        ..lineTo(128 * s, 96 * s)
        ..close(),
      p(RoomPalette.lampGlow.withValues(alpha: 0.55)),
    );
    // 灯臂 + 灯罩
    canvas.drawLine(Offset(96 * s, 88 * s), Offset(96 * s, 52 * s), stroke);
    canvas.drawLine(Offset(96 * s, 52 * s), Offset(82 * s, 34 * s), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(70 * s, 34 * s)
        ..quadraticBezierTo(82 * s, 18 * s, 94 * s, 34 * s)
        ..lineTo(88 * s, 42 * s)
        ..quadraticBezierTo(82 * s, 34 * s, 76 * s, 42 * s)
        ..close(),
      p(TreasurePalette.pigAccent),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(82 * s, 41 * s), width: 18 * s, height: 7 * s),
      p(RoomPalette.lampGlow),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(96 * s, 90 * s), width: 24 * s, height: 8 * s),
      p(RoomPalette.woodDark),
    );
    // 桌面 + 桌腿
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(6 * s, 94 * s, 144 * s, 103 * s), Radius.circular(4.5 * s)),
      p(RoomPalette.wood),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(18 * s, 103 * s, 25 * s, 117 * s), Radius.circular(2.5 * s)),
      p(RoomPalette.woodDeep),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(124 * s, 103 * s, 131 * s, 117 * s), Radius.circular(2.5 * s)),
      p(RoomPalette.woodDeep),
    );
    // 桌上小书两本 + 旋钮
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(28 * s, 80 * s, 54 * s, 87 * s), Radius.circular(2 * s)),
      p(TreasurePalette.coinColors[3]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(31 * s, 73 * s, 53 * s, 80 * s), Radius.circular(2 * s)),
      p(TreasurePalette.greenLight),
    );
    canvas.drawCircle(Offset(118 * s, 82 * s), 8 * s, p(TreasurePalette.card));
    canvas.drawCircle(
      Offset(118 * s, 82 * s),
      8 * s,
      Paint()
        ..color = RoomPalette.woodDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s,
    );
    canvas.drawLine(Offset(118 * s, 77 * s), Offset(118 * s, 81 * s), stroke..strokeWidth = 2.5 * s);
  }

  @override
  bool shouldRepaint(covariant _DeskPainter old) => false;
}

/// ④ 唱片机（随身听）。
class _PlayerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 118;
    Paint p(Color c) => Paint()..color = c;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(6 * s, 12 * s, 112 * s, 78 * s), Radius.circular(12 * s)),
      p(RoomPalette.woodDark),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(12 * s, 18 * s, 106 * s, 72 * s), Radius.circular(8 * s)),
      p(TreasurePalette.card),
    );
    final disc = p(TreasurePalette.ink);
    canvas.drawCircle(Offset(59 * s, 40 * s), 22 * s, disc);
    final groove = Paint()
      ..color = RoomPalette.groove.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s;
    canvas.drawCircle(Offset(59 * s, 40 * s), 15 * s, groove);
    canvas.drawCircle(Offset(59 * s, 40 * s), 10 * s, groove);
    canvas.drawCircle(Offset(59 * s, 40 * s), 5.5 * s, p(TreasurePalette.coral));
    canvas.drawCircle(Offset(59 * s, 40 * s), 1.8 * s, p(TreasurePalette.cream));
    // 唱臂
    final arm = Paint()
      ..color = TreasurePalette.goldDeep
      ..strokeWidth = 3.4 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(92 * s, 24 * s), Offset(84 * s, 46 * s), arm);
    canvas.drawCircle(Offset(92 * s, 24 * s), 4 * s, p(TreasurePalette.goldDeep));
    // 底座 + 指示灯
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(6 * s, 80 * s, 112 * s, 88 * s), Radius.circular(4 * s)),
      p(RoomPalette.woodBase),
    );
    canvas.drawCircle(Offset(26 * s, 88 * s), 2.6 * s, p(RoomPalette.lampGlow));
    canvas.drawCircle(Offset(38 * s, 88 * s), 2.6 * s, p(RoomPalette.lampGlow.withValues(alpha: 0.5)));
  }

  @override
  bool shouldRepaint(covariant _PlayerPainter old) => false;
}

/// ⑤ 书架（我的内容）。
class _BookshelfPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 104;
    Paint p(Color c) => Paint()..color = c;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(4 * s, 4 * s, 100 * s, 80 * s), Radius.circular(8 * s)),
      p(RoomPalette.woodDeep),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(10 * s, 10 * s, 94 * s, 74 * s), Radius.circular(5 * s)),
      p(RoomPalette.woodDark),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(14 * s, 16 * s, 24 * s, 42 * s), Radius.circular(2 * s)),
      p(TreasurePalette.coinColors[2]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(26 * s, 20 * s, 35 * s, 42 * s), Radius.circular(2 * s)),
      p(TreasurePalette.pigSkinTop),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(37 * s, 14 * s, 48 * s, 42 * s), Radius.circular(2 * s)),
      p(TreasurePalette.gold),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(52 * s, 18 * s, 61 * s, 42 * s), Radius.circular(2 * s)),
      p(TreasurePalette.coinColors[3]),
    );
    // 斜靠的书
    canvas.save();
    canvas.translate(74 * s, 30 * s);
    canvas.rotate(-0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(-6 * s, -12 * s, 6 * s, 12 * s), Radius.circular(2 * s)),
      p(TreasurePalette.card.withValues(alpha: 0.9)),
    );
    canvas.restore();
    // 隔板
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(14 * s, 48 * s, 94 * s, 53 * s), Radius.circular(2.5 * s)),
      p(RoomPalette.woodDeep),
    );
    // 下层：竖书 + 圆徽章 + 虚线空位
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(20 * s, 56 * s, 32 * s, 74 * s), Radius.circular(2 * s)),
      p(RoomPalette.bookBlush),
    );
    canvas.drawCircle(Offset(46 * s, 65 * s), 9 * s, p(TreasurePalette.card));
    final cross = Paint()
      ..color = RoomPalette.woodDark
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(46 * s, 58 * s), Offset(46 * s, 72 * s), cross);
    canvas.drawLine(Offset(40 * s, 62 * s), Offset(52 * s, 62 * s), cross);
    final dash = Paint()
      ..color = RoomPalette.wood
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(64 * s, 56 * s, 88 * s, 74 * s), Radius.circular(3 * s)),
      dash,
    );
  }

  @override
  bool shouldRepaint(covariant _BookshelfPainter old) => false;
}

/// ⑥ 爪印地毯（学习足迹）。
class _RugPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 148;
    Paint p(Color c) => Paint()..color = c;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(74 * s, 28 * s), width: 144 * s, height: 52 * s),
      p(RoomPalette.rugBase),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(74 * s, 28 * s), width: 144 * s, height: 52 * s),
      Paint()
        ..color = RoomPalette.woodDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s,
    );
    final paw = p(TreasurePalette.goldDeep.withValues(alpha: 0.85));
    for (final c in [const Offset(40, 22), Offset(74, 34), Offset(108, 22)]) {
      final cx = c.dx * s, cy = c.dy * s;
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + 2 * s), width: 9.2 * s, height: 7.6 * s), paw);
      canvas.drawCircle(Offset(cx - 4.5 * s, cy - 3.5 * s), 1.7 * s, paw);
      canvas.drawCircle(Offset(cx, cy - 5 * s), 1.7 * s, paw);
      canvas.drawCircle(Offset(cx + 4.5 * s, cy - 3.5 * s), 1.7 * s, paw);
    }
  }

  @override
  bool shouldRepaint(covariant _RugPainter old) => false;
}

/// ⑦ 工具箱（更多设置）。
class _ToolboxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 86;
    Paint p(Color c) => Paint()..color = c;
    final handle = Paint()
      ..color = RoomPalette.woodDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(28 * s, 20 * s)
        ..lineTo(28 * s, 14 * s)
        ..quadraticBezierTo(43 * s, 2 * s, 58 * s, 14 * s)
        ..lineTo(58 * s, 20 * s),
      handle,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(8 * s, 20 * s, 78 * s, 54 * s), Radius.circular(9 * s)),
      p(TreasurePalette.pigAccent),
    );
    canvas.drawRect(Rect.fromLTWH(8 * s, 33 * s, 70 * s, 8 * s), p(RoomPalette.toolboxLid));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(36 * s, 29 * s, 50 * s, 45 * s), Radius.circular(3.5 * s)),
      p(TreasurePalette.card),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(41 * s, 25 * s, 45 * s, 31 * s), Radius.circular(2 * s)),
      p(TreasurePalette.card),
    );
  }

  @override
  bool shouldRepaint(covariant _ToolboxPainter old) => false;
}

/// ⑧ 迷你存钱罐（尖叫币；与聚宝日历储蓄罐同源的小号版）。
class _RoomPiggyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 76;
    Paint p(Color c) => Paint()..color = c;
    final body = Rect.fromCenter(center: Offset(38 * s, 26 * s), width: 64 * s, height: 38 * s);
    final skinShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [TreasurePalette.pigSkinTop, TreasurePalette.pigSkinBottom],
    ).createShader(body);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(24 * s, 42 * s), width: 16 * s, height: 8 * s),
      p(TreasurePalette.pigAccent),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(52 * s, 42 * s), width: 16 * s, height: 8 * s),
      p(TreasurePalette.pigAccent),
    );
    canvas.drawOval(body, Paint()..shader = skinShader);
    // 橙角
    canvas.drawPath(
      Path()
        ..moveTo(28 * s, 10 * s)
        ..quadraticBezierTo(26 * s, 2 * s, 32 * s, 1 * s)
        ..quadraticBezierTo(36 * s, 0.5 * s, 36 * s, 7 * s)
        ..close(),
      p(TreasurePalette.pigAccent),
    );
    canvas.drawPath(
      Path()
        ..moveTo(48 * s, 10 * s)
        ..quadraticBezierTo(50 * s, 2 * s, 44 * s, 1 * s)
        ..quadraticBezierTo(40 * s, 0.5 * s, 40 * s, 7 * s)
        ..close(),
      p(TreasurePalette.pigAccent),
    );
    // 投币口
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(34 * s, 6 * s, 43 * s, 9 * s), Radius.circular(1.5 * s)),
      p(TreasurePalette.pigBellyBack),
    );
    // 眼 + 微笑
    canvas.drawCircle(Offset(29 * s, 22 * s), 2.2 * s, p(TreasurePalette.pigDark));
    canvas.drawCircle(Offset(47 * s, 22 * s), 2.2 * s, p(TreasurePalette.pigDark));
    canvas.drawPath(
      Path()
        ..moveTo(35 * s, 27 * s)
        ..quadraticBezierTo(38 * s, 29.6 * s, 41 * s, 27 * s),
      Paint()
        ..color = TreasurePalette.pigDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * s
        ..strokeCap = StrokeCap.round,
    );
    // 肚皮窗（金位半满）
    final belly = Rect.fromCenter(center: Offset(38 * s, 33 * s), width: 28 * s, height: 14 * s);
    canvas.drawOval(belly, p(TreasurePalette.pigBellyBack));
    canvas.save();
    canvas.clipPath(Path()..addOval(belly));
    canvas.drawRect(Rect.fromLTRB(24 * s, 33 * s, 52 * s, 40 * s), p(TreasurePalette.gold));
    canvas.restore();
    canvas.drawOval(
      belly,
      Paint()
        ..color = TreasurePalette.cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s,
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPiggyPainter old) => false;
}

/// 房主小怪兽：瞳孔跟随 + 眨眼。
class _RoomMonsterPainter extends CustomPainter {
  _RoomMonsterPainter({required this.pupilOffset, required this.blink});

  final Offset pupilOffset;
  final double blink; // 0 睁眼 → 1 闭合

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 116;
    Paint p(Color c) => Paint()..color = c;
    final body = Rect.fromCenter(center: Offset(58 * s, 62 * s), width: 104 * s, height: 92 * s);
    final skinShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [TreasurePalette.pigSkinTop, TreasurePalette.pigSkinBottom],
    ).createShader(body);
    // 脚
    canvas.drawOval(
      Rect.fromCenter(center: Offset(38 * s, 108 * s), width: 24 * s, height: 12 * s),
      p(TreasurePalette.pigAccent),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(78 * s, 108 * s), width: 24 * s, height: 12 * s),
      p(TreasurePalette.pigAccent),
    );
    // 身体
    canvas.drawOval(body, Paint()..shader = skinShader);
    // 白角
    for (final dx in [44.0, 72.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(dx * s, 22 * s)
          ..quadraticBezierTo((dx - 3) * s, 6 * s, (dx + 9) * s, 5 * s)
          ..quadraticBezierTo((dx + 18) * s, 4 * s, (dx + 18) * s, 17 * s),
        p(TreasurePalette.card),
      );
    }
    // 眼睛（眨眼 scaleY）
    final eyeOpenY = 1 - 0.88 * blink;
    for (final cx in [41.0, 75.0]) {
      canvas.save();
      canvas.translate(cx * s, 52 * s);
      canvas.scale(1, eyeOpenY);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 23 * s, height: 26 * s), p(TreasurePalette.card));
      canvas.drawCircle(pupilOffset * s, 5.2 * s, p(TreasurePalette.pigDark));
      canvas.drawCircle(pupilOffset * s + Offset(2 * s, -2.4 * s), 1.8 * s, p(TreasurePalette.card));
      canvas.restore();
    }
    // 微笑 + 腮红 + 胸前 W
    canvas.drawPath(
      Path()
        ..moveTo(50 * s, 70 * s)
        ..quadraticBezierTo(58 * s, 77 * s, 66 * s, 70 * s),
      Paint()
        ..color = TreasurePalette.pigDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(26 * s, 64 * s), 5.5 * s, p(TreasurePalette.pigBlush));
    canvas.drawCircle(Offset(90 * s, 64 * s), 5.5 * s, p(TreasurePalette.pigBlush));
    canvas.drawPath(
      Path()
        ..moveTo(42 * s, 80 * s)
        ..lineTo(50 * s, 94 * s)
        ..lineTo(56 * s, 84 * s)
        ..lineTo(58 * s, 90 * s)
        ..lineTo(60 * s, 84 * s)
        ..lineTo(66 * s, 94 * s)
        ..lineTo(74 * s, 80 * s),
      Paint()
        ..color = TreasurePalette.cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RoomMonsterPainter old) => old.pupilOffset != pupilOffset || old.blink != blink;
}

/// 金币小图标（门牌余额胶囊；与聚宝日历同款）。
class _RoomCoinGlyph extends StatelessWidget {
  const _RoomCoinGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RoomCoinGlyphPainter()),
    );
  }
}

class _RoomCoinGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final center = Offset(12 * s, 12 * s);
    canvas.drawCircle(center, 9 * s, Paint()..color = TreasurePalette.gold);
    canvas.drawCircle(
      center,
      6.2 * s,
      Paint()
        ..color = TreasurePalette.goldDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * s,
    );
    final paint = Paint()
      ..color = TreasurePalette.goldDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(12 * s, 8.4 * s), Offset(12 * s, 15.6 * s), paint);
    canvas.drawLine(Offset(9.6 * s, 10 * s), Offset(14.4 * s, 10 * s), paint);
    canvas.drawLine(Offset(9.6 * s, 14 * s), Offset(14.4 * s, 14 * s), paint);
  }

  @override
  bool shouldRepaint(covariant _RoomCoinGlyphPainter old) => false;
}
