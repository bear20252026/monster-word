// MonsterHatchingPage：开局命名仪式（蓝图 W4「命名的仪式」）。
//
// 首次引导完成后一次性进入：台灯下的蛋 → 输入名字（可空→默认「咕噜」）
// → 「敲三下」破壳（每敲一下蛋壳裂纹加深 + 抖动，第三下白闪 + 怪兽 pop）
// → 「开始冒险！」保存 monster_name / monster_birthday / monster_hatched。
// 世界观红线：名字与生日只进小屋展示，绝不参与任何数值计算。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:word_app/core/utils/monster_identity_prefs.dart';
import 'package:word_app/core/utils/monster_voice.dart';
import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/tokens/treasure_palette.dart';
import 'package:word_app/widgets/common/mw_feedback.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 怪兽名输入闸：拒绝控制字符 / 零宽 / RTL 覆写字符（名字将在小屋门牌以纯 Text 回显）。
final RegExp _nameForbiddenChars = RegExp(r'[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u2028-\u202E\u2060-\u2064\uFEFF]');

class MonsterHatchingPage extends StatefulWidget {
  const MonsterHatchingPage({super.key, this.onFinished});

  /// 破壳完成回调（接线方决定后续路由；null 则由页面内按钮自行 pop/push）。
  final VoidCallback? onFinished;

  @override
  State<MonsterHatchingPage> createState() => _MonsterHatchingPageState();
}

class _MonsterHatchingPageState extends State<MonsterHatchingPage> with TickerProviderStateMixin {
  final TextEditingController _nameCtrl = TextEditingController();

  /// 敲蛋次数（0-3；3 = 已破壳）。
  int _taps = 0;

  /// 保存进行中（防重复点击与重复落库）。
  bool _saving = false;

  late final AnimationController _shakeCtrl = AnimationController(vsync: this, duration: MotionDurations.base);
  late final AnimationController _popCtrl = AnimationController(vsync: this, duration: MotionDurations.expressive);
  late final Animation<double> _pop = CurvedAnimation(parent: _popCtrl, curve: MotionCurves.springPop);

  bool get _hatched => _taps >= 3;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shakeCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  void _knock() {
    if (_hatched) return;
    _taps += 1;
    if (_taps >= 3) {
      // 第三下：白闪 + 怪兽破壳 pop。
      SfxPlayer.fire(Sfx.hatchFlash);
      _popCtrl.forward(from: 0);
    } else {
      SfxPlayer.fire(Sfx.eggKnock);
      _shakeCtrl.forward(from: 0);
    }
    setState(() {});
  }

  Future<void> _startAdventure() async {
    if (_saving) return;
    setState(() => _saving = true);
    String stored;
    try {
      stored = await MonsterIdentityPrefs.save(name: _nameCtrl.text);
    } catch (e, s) {
      // 三段 SP 写失败：不静默、不假装成功——留原态让用户再敲一次即可（save 可重入）。
      reportSwallowedError('命名仪式保存失败', e, s);
      if (!mounted) return;
      setState(() => _saving = false);
      showMwSnackBar(context, const SnackBar(content: Text('名字没记上，再点一次「开始冒险」试试')));
      return;
    }
    // 「怪兽开口」第一刻：破壳后自报家门（一生一次，最该出声的一句）。
    // 不等本页——发声走进程级 TTS 单例，页面换路由后照样说完；闸门拦下则静默。
    unawaited(MonsterVoice.system.say('我叫$stored！以后单词就交给我们俩啦~'));
    if (!mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    return Scaffold(
      backgroundColor: colors.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _hatched ? '破壳了！它认识你了。' : '台灯下，有一颗蛋在等你。',
                textAlign: TextAlign.center,
                style: MwTypography.heading3.copyWith(fontWeight: FontWeight.w700, color: colors.text1),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _buildEggStage(colors),
              const SizedBox(height: AppSpacing.xl),
              ..._buildControls(colors),
            ],
          ),
        ),
      ),
    );
  }

  /// 蛋/破壳舞台（点击敲蛋 + 裂纹递进 + 破壳 pop）。
  Widget _buildEggStage(ThemeVars colors) {
    return GestureDetector(
      onTap: _hatched ? null : _knock,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 160,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_shakeCtrl, _popCtrl]),
            builder: (context, child) {
              // 每敲一下水平抖动一格（裂纹感的位移近似）。
              final shake = _taps < 3 ? math.sin(2 * math.pi * _shakeCtrl.value) * (2.0 * _taps) : 0.0;
              final pop = _hatched ? _pop.value : 0.0;
              return Transform.translate(
                offset: Offset(shake, 0),
                child: Transform.scale(scale: 1 + 0.18 * pop, child: child),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 手绘蛋（台灯下的暖色渐变 + 呼吸光斑 + 随敲击递进的锯齿裂纹），
                // 替代旧 Icons.egg + 竖线裂纹（与全项目 CustomPainter 手绘质感断裂）。
                if (!_hatched)
                  Semantics(
                    label: '怪兽蛋，点按敲击（$_taps/3）',
                    button: true,
                    child: CustomPaint(
                      size: const Size(132, 156),
                      painter: _HatchEggPainter(taps: _taps),
                    ),
                  ),
                // 破壳后：怪兽破光而出。
                if (_hatched)
                  FadeTransition(opacity: _pop, child: const MonsterIcon(size: 120, mouthOpen: 1.0, evoStage: 0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 名字输入与主按钮（破壳前后两套）。
  List<Widget> _buildControls(ThemeVars colors) {
    final field = TextField(
      controller: _nameCtrl,
      textAlign: TextAlign.center,
      maxLength: 12,
      inputFormatters: [FilteringTextInputFormatter.deny(_nameForbiddenChars)],
      decoration: InputDecoration(
        hintText: _hatched ? '它的名字（可改，默认「咕噜」）' : '给它起个名字吧（可跳过，默认「咕噜」）',
        counterText: '',
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.accent)),
      ),
    );
    final button = SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _hatched ? (_saving ? null : _startAdventure) : _knock,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onGlassAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
          elevation: 0,
        ),
        child: Text(
          _hatched ? (_saving ? '保存中…' : '开始冒险！') : '敲三下（$_taps/3）',
          style: MwTypography.bodyBold.copyWith(color: colors.onGlassAccent),
        ),
      ),
    );
    return [field, const SizedBox(height: AppSpacing.lg), button];
  }
}

/// 手绘怪兽蛋：暖色渐变壳 + 恒定斑点 + 随敲击次数递进的锯齿裂纹。
/// 颜色取 TreasurePalette 的暖纸/金族（与小屋同一美术语言）。
class _HatchEggPainter extends CustomPainter {
  _HatchEggPainter({required this.taps});

  /// 已敲次数（0-2 破壳前；3 时舞台已切怪兽，本 painter 不再绘制）。
  final int taps;

  static final Paint _shellPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _shellLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _specklePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // 台灯下的暖光晕（蛋后一层柔光，说明它「在等你」）。
    _glowPaint.color = TreasurePalette.gold.withValues(alpha: AppAlphas.o18);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, h * 0.52), width: w * 1.25, height: h * 1.2), _glowPaint);

    // 蛋壳：上窄下宽的卵形（贝塞尔近似），暖纸→奶油渐变。
    final shell = Path()
      ..moveTo(cx, h * 0.04)
      ..quadraticBezierTo(w * 0.96, h * 0.42, w * 0.80, h * 0.74)
      ..quadraticBezierTo(w * 0.60, h * 1.02, cx, h * 1.02)
      ..quadraticBezierTo(w * 0.40, h * 1.02, w * 0.20, h * 0.74)
      ..quadraticBezierTo(w * 0.04, h * 0.42, cx, h * 0.04)
      ..close();
    _shellPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.white100.withValues(alpha: 0.97), TreasurePalette.paperTop, TreasurePalette.paperBottom],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shell, _shellPaint);

    // 恒定斑点（固定伪随机，同蛋同一张脸）。
    _specklePaint.color = TreasurePalette.pigSkinBottom.withValues(alpha: AppAlphas.o35);
    const speckles = [(-0.22, 0.30, 4.2), (0.18, 0.38, 3.4), (-0.05, 0.55, 5.0), (0.26, 0.62, 3.8), (-0.28, 0.68, 3.0)];
    for (final (dx, dy, r) in speckles) {
      canvas.drawCircle(Offset(cx + dx * w, h * dy), r, _specklePaint);
    }

    // 裂纹：随敲击递进的锯齿折线（第 1 敲顶部细纹；第 2 敲中部蔓延分叉）。
    _shellLinePaint.color = TreasurePalette.ink.withValues(alpha: 0.45);
    if (taps >= 1) {
      _shellLinePaint.strokeWidth = 1.8;
      final c1 = Path()
        ..moveTo(cx - 8, h * 0.22)
        ..lineTo(cx - 3, h * 0.28)
        ..lineTo(cx - 10, h * 0.34)
        ..lineTo(cx - 2, h * 0.40);
      canvas.drawPath(c1, _shellLinePaint);
    }
    if (taps >= 2) {
      _shellLinePaint.strokeWidth = 2.4;
      final c2 = Path()
        ..moveTo(cx + 6, h * 0.16)
        ..lineTo(cx + 12, h * 0.24)
        ..lineTo(cx + 4, h * 0.30)
        ..lineTo(cx + 14, h * 0.38)
        ..lineTo(cx + 6, h * 0.44)
        ..lineTo(cx + 16, h * 0.52);
      canvas.drawPath(c2, _shellLinePaint);
      // 第三敲前的预兆：中缝开始透光（金色细缝）。
      _shellLinePaint.color = TreasurePalette.goldDeep.withValues(alpha: AppAlphas.o80);
      _shellLinePaint.strokeWidth = 2.0;
      final c3 = Path()
        ..moveTo(cx - 2, h * 0.30)
        ..lineTo(cx + 2, h * 0.42)
        ..lineTo(cx - 1, h * 0.54)
        ..lineTo(cx + 3, h * 0.66);
      canvas.drawPath(c3, _shellLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HatchEggPainter oldDelegate) => oldDelegate.taps != taps;
}
