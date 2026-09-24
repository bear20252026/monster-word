// CoinSwallowCelebration：签到成功庆祝 — “肚皮储蓄罐”
//
// 四幕 1800ms：①射（金币从签到按钮中心弹射而出，拖尾坠入口中，怪兽下蹲张嘴）；
// ②吞（squash＋咕咚波纹）；③存（光点沉入肚底、肚皮鼓胀、金库窗弹出并滚动到最新余额）；
// ④满足（星芒迸发、欢腾一跃、+N 上浮）。吞＝存一眼闭环。
// 播完经 onDone 自清，不常驻、不持有静态单例（MEM 无残留）。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/effect_palette.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/tokens/star_gold.dart';
import 'package:word_app/widgets/monster_icon.dart';

// ── 版式常量（widget 与粒子画笔同源，避免嘴／币错位） ──
const double _kBoxH = 220.0;
const double _kMonster = 128.0;
const double _kHalfMonster = _kMonster / 2; // 64
const double _kR = _kHalfMonster * 0.85; // 54.4，与 _MonsterPainter 同源
const double _kMonsterTop = _kBoxH - _kMonster; // 92
const double _kMouthY = _kMonsterTop + _kHalfMonster + _kR * 0.22; // ≈168
const double _kBellyY = _kMonsterTop + _kHalfMonster + _kR * 0.25; // ≈170
const double _kSinkY = _kBellyY + 18.0; // 光点沉底 ≈188
const double _kBurstY = _kMonsterTop + 70.0; // 星芒中心 ≈162
// 发射起点：签到按钮高 46 且紧贴庆祝盒上方，币心即按钮中心（相对盒顶 -23）。
const double _kLaunchCenterY = -23.0;
const double _kCoinStartTop = _kLaunchCenterY - 18.0; // ≈-41（盒外，需 Stack Clip.none）
const double _kCoinEndTop = _kMouthY - 18.0; // 币心落到嘴心 ≈150

class CoinSwallowCelebration extends StatefulWidget {
  /// 本次签到增量（== ScareCoinStore.checkInReward）。
  final int reward;

  /// 签到后最新余额（ScareCoinStore.checkIn() 返回值），金库窗滚动终点。
  final int balance;

  /// 续演起点：亲手投喂成功后从 0.32（币已到嘴）续演后三幕；点按自动为 0。
  final double startAt;

  /// 怪兽进化阶段（0 奶泡／1 尖角／2 飞翼／3 金冠），按累计签到换算。
  final int evoStage;

  /// 肚皮生长基线（1.0~1.25），与仪式鼓胀相乘，越养越大。
  final double growthBase;

  final VoidCallback? onDone;

  const CoinSwallowCelebration({
    super.key,
    required this.reward,
    required this.balance,
    this.onDone,
    this.startAt = 0.0,
    this.evoStage = 0,
    this.growthBase = 1.0,
  });

  @override
  State<CoinSwallowCelebration> createState() => _CoinSwallowCelebrationState();
}

class _CoinSwallowCelebrationState extends State<CoinSwallowCelebration> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1800);
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone?.call();
      })
      // 亲手投喂续演：从币到嘴处开始，forward() 从当前值播到终点。
      ..value = widget.startAt.clamp(0.0, 0.9)
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static double _seg(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);
  static double _easeOutCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();
  // 徽标出现一律走公司标准弹性曲线 MotionCurves.springPop（星巴克复选框弹性同族）。

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final accent = skin.accent;
    final oldBalance = math.max(0, widget.balance - widget.reward);
    return SizedBox(
      height: _kBoxH,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final fallT = _seg(t, 0.0, 0.30);
          final gulpT = _seg(t, 0.30, 0.44);
          final sinkT = _seg(t, 0.44, 0.58);
          final storeT = _seg(t, 0.46, 0.70);
          // 金库窗／+N 出场均用标准 springPop（选中/确认家族），上限钳制防过冲穿帮。
          final vaultScale = MotionCurves.springPop.transform(_seg(t, 0.52, 0.72)).clamp(0.0, 1.15);
          final countP = _easeOutCubic(_seg(t, 0.55, 0.88));
          final burstT = _seg(t, 0.70, 1.0);
          final plusT = _seg(t, 0.72, 1.0);

          final fallEase = fallT * fallT * fallT; // easeInCubic：加速下坠
          final mouthOpen = fallT < 1 ? fallT : 1 - gulpT;
          final crouch = math.sin(fallT * math.pi); // 下坠前摇：微微下蹲蓄势
          final gulpPulse = math.sin(gulpT * math.pi);
          final bellyScale = 1 + 0.38 * _easeOutCubic(storeT); // 肚皮鼓胀即存款
          final hopY = -9 * math.sin(_seg(t, 0.70, 0.95) * math.pi); // 欢腾一跃

          final sx = (1 + 0.03 * crouch) * (1 + 0.07 * gulpPulse);
          final sy = (1 - 0.04 * crouch) * (1 - 0.07 * gulpPulse);

          final coinTop = _kCoinStartTop + (_kCoinEndTop - _kCoinStartTop) * fallEase;
          // 发射 pop：从按钮中心弹出时先由小变大，再随入嘴缩小（被吞感）。
          final pop = 0.5 + 0.5 * (fallT * 4).clamp(0.0, 1.0);
          final coinScale = pop * (1 - 0.75 * fallT);
          final coinOpacity = t < 0.42 ? 1.0 : (1 - (t - 0.42) / 0.06).clamp(0.0, 1.0);

          final shown = (oldBalance + (widget.balance - oldBalance) * countP).round();
          final rise = plusT * plusT * (3 - 2 * plusT); // smoothstep 上升
          final plusScale = (0.6 + 0.5 * MotionCurves.springPop.transform(plusT)).clamp(0.7, 1.15);

          return GestureDetector(
            // 点按跳过：1800ms 仪式过长时用户可一触收尾（动效时长合规缓释）。
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_ctrl.status == AnimationStatus.forward) _ctrl.value = 1.0;
            },
            child: Stack(
              // 币从盒顶上方（按钮中心）射入，需溢出绘制。
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // 舞台柔光：签到时刻的追光
                Positioned(
                  top: _kMonsterTop - 46,
                  child: Container(
                    width: 216,
                    height: 216,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [accent.withValues(alpha: 0.14), accent.withValues(alpha: 0.0)]),
                    ),
                  ),
                ),
                // 粒子层：尾迹／咕咚波纹／沉底光点／星芒／肚皮辉光
                Positioned.fill(
                  child: CustomPaint(
                    painter: _VaultFxPainter(
                      fallEase: fallEase,
                      fallT: fallT,
                      gulpT: gulpT,
                      sinkT: sinkT,
                      burstT: burstT,
                      storeGlow:
                          _easeOutCubic(storeT) *
                          (1 - burstT * 0.4) *
                          // 心跳：辉光在存款段起伏一次
                          (0.8 + 0.2 * math.sin(_seg(t, 0.46, 0.70) * math.pi * 2).abs()),
                      gold: MwColors.sunshine300,
                      accent: accent,
                      white: AppColors.white100,
                    ),
                  ),
                ),
                // 怪兽（置底居中，欢腾时上跃；进化形态＋生长基线来自累计签到）
                Positioned(
                  bottom: hopY,
                  child: Transform.scale(
                    scaleX: sx,
                    scaleY: sy,
                    child: MonsterIcon(
                      size: _kMonster,
                      mouthOpen: mouthOpen,
                      bellyScale: (bellyScale * widget.growthBase).clamp(0.6, 1.8),
                      evoStage: widget.evoStage,
                    ),
                  ),
                ),
                // 下坠金币（从按钮中心射出）
                if (coinOpacity > 0)
                  Positioned(
                    top: coinTop,
                    child: Opacity(
                      opacity: coinOpacity,
                      child: Transform.scale(
                        scale: coinScale,
                        child: Transform.rotate(angle: fallEase * 0.5, child: const CoinBadge()),
                      ),
                    ),
                  ),
                // 肚皮金库窗：余额滚动到最新（弹出同时上浮 10px，防贴肚）
                if (vaultScale > 0.01)
                  Positioned(
                    bottom: 12 + 10 * (1 - vaultScale.clamp(0.0, 1.0)),
                    child: Transform.scale(
                      scale: vaultScale.clamp(0.0, 1.15),
                      child: _VaultBadge(amountText: _fmt(shown)),
                    ),
                  ),
                // +N 上浮（兽头顶，避免与金库窗重叠）
                if (plusT > 0 && plusT < 1)
                  Positioned(
                    bottom: 128 - 40 * rise,
                    child: Opacity(
                      opacity: 1 - plusT,
                      child: Transform.scale(
                        scale: plusScale,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+${widget.reward}',
                              style: MwTypography.heading4.copyWith(fontWeight: FontWeight.w900, color: skin.success),
                            ),
                            const SizedBox(width: 4),
                            MonsterIcon(size: 24, bodyColor: skin.success),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 金币徽章：品牌金圆＋星形矢量标（emoji 守卫禁 ★ 字符，一律用 Icons）。
/// 公开给签到按钮复用同一视觉物（idle 态即此币，发射后币“离家”飞入兽嘴）。
class CoinBadge extends StatelessWidget {
  final double size;

  const CoinBadge({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [MwColors.sunshine300, MwColors.mutedGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: MwColors.mutedGold, width: size >= 28 ? 2 : 1.5),
        boxShadow: [
          BoxShadow(
            color: MwColors.sunshine300.withValues(alpha: 0.55),
            blurRadius: 12 * size / 36,
            offset: Offset(0, 3 * size / 36),
          ),
        ],
      ),
      child: Icon(Icons.star_rounded, size: size * 0.56, color: AppColors.white100),
    );
  }
}

/// 肚皮金库窗：奶油底＋金边＋辉光＋顶部投币口（存钱罐铭牌），余额等宽滚动。
/// 投币口＋余额窗的组合是本仪式的外观专利设计点，勿拆散改版。
/// 小字用 StarGold.bronzeDark（白底 WCAG AA），星标/边框用品牌金。
class _VaultBadge extends StatelessWidget {
  final String amountText;

  const _VaultBadge({required this.amountText});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 122,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white100.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(context.design.radius.lg),
            border: Border.all(color: MwColors.sunshine300, width: 2),
            boxShadow: [
              BoxShadow(color: MwColors.sunshine300.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: MwColors.mutedGold),
                      const SizedBox(width: 3),
                      Text(
                        '肚皮金库',
                        style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: StarGold.bronzeDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amountText,
                      style: MwTypography.heading4.copyWith(
                        fontWeight: FontWeight.w800,
                        color: skin.text1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              // 静态对角 sheen：奶油窗上的贵价反光，零动画成本（禁裸色值，走 token）。
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(context.design.radius.control),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.center,
                        colors: [AppColors.white100.withValues(alpha: 0.35), AppColors.white100.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 投币口：压住金边上沿的存钱罐窄缝。
        Positioned(
          top: -5,
          child: Container(
            width: 30,
            height: 9,
            decoration: BoxDecoration(
              color: MonsterPalette.mouthInner,
              borderRadius: BorderRadius.circular(4.5),
              border: Border.all(color: MwColors.sunshine300, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// 金库粒子画笔：尾迹／咕咚波纹／沉底光点／星芒／肚皮辉光，一笔绘完。
class _VaultFxPainter extends CustomPainter {
  final double fallEase;
  final double fallT;
  final double gulpT;
  final double sinkT;
  final double burstT;
  final double storeGlow;
  final Color gold;
  final Color accent;
  final Color white;

  _VaultFxPainter({
    required this.fallEase,
    required this.fallT,
    required this.gulpT,
    required this.sinkT,
    required this.burstT,
    required this.storeGlow,
    required this.gold,
    required this.accent,
    required this.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final coinCy = (_kCoinStartTop + 18) + ((_kCoinEndTop + 18) - (_kCoinStartTop + 18)) * fallEase;
    // 金币流光：随下坠环绕币面的高光点，金属贵价感。
    if (fallT > 0 && fallT < 1) {
      final glintA = fallEase * 5;
      canvas.drawCircle(
        Offset(cx + math.cos(glintA) * 7, coinCy + math.sin(glintA) * 5),
        3.2,
        Paint()..color = white.withValues(alpha: 0.85 * (1 - fallEase * 0.5)),
      );
    }
    // 金币尾迹：从按钮中心起算，4 点渐隐
    if (fallT > 0 && fallT < 1) {
      for (var i = 0; i < 4; i++) {
        final p = fallEase - (i + 1) * 0.055;
        if (p <= 0 || p >= 1) continue;
        final y = _kLaunchCenterY + (_kMouthY - _kLaunchCenterY) * p;
        canvas.drawCircle(
          Offset(cx + (i.isEven ? 2.5 : -2.5) * i, y),
          3.4 - i * 0.6,
          Paint()..color = gold.withValues(alpha: (1 - p) * 0.45),
        );
      }
    }
    // 肚皮辉光：存款时的金色暖意，带一次心跳起伏（精美感来自二次节奏）。
    if (storeGlow > 0.01) {
      const r = 64.0;
      final rect = Rect.fromCircle(center: Offset(cx, _kBellyY), radius: r);
      canvas.drawCircle(
        Offset(cx, _kBellyY),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              gold.withValues(alpha: 0.30 * storeGlow),
              gold.withValues(alpha: 0.0),
            ],
          ).createShader(rect),
      );
    }
    // 咕咚波纹：从嘴心扩散
    if (gulpT > 0 && gulpT < 1) {
      canvas.drawCircle(
        Offset(cx, _kMouthY),
        12 + 36 * gulpT,
        Paint()
          ..color = gold.withValues(alpha: 0.55 * (1 - gulpT))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + 3 * (1 - gulpT),
      );
    }
    // 沉底光点：金币化作暖光沉入肚底
    if (sinkT > 0 && sinkT < 1) {
      final y = _kMouthY + (_kSinkY - _kMouthY) * sinkT * sinkT;
      final a = 1 - sinkT;
      canvas.drawCircle(Offset(cx, y), 10 * a + 3, Paint()..color = gold.withValues(alpha: 0.35 * a));
      canvas.drawCircle(Offset(cx, y), 5 * a + 1.5, Paint()..color = white.withValues(alpha: 0.9 * a));
    }
    // 星芒迸发：10 枚四角星，椭圆轨道向外
    if (burstT > 0 && burstT < 1) {
      final ease = 1 - math.pow(1 - burstT, 2).toDouble();
      for (var i = 0; i < 10; i++) {
        final ang = i * math.pi / 5 + 0.3;
        final dist = 66 + 52 * ease;
        final pos = Offset(cx + math.cos(ang) * dist, _kBurstY + math.sin(ang) * dist * 0.82);
        final s = (i.isEven ? 7.0 : 5.0) * (1 - burstT * 0.4);
        _sparkle(canvas, pos, s, (i.isEven ? gold : white).withValues(alpha: (1 - burstT) * 0.95));
      }
    }
  }

  void _sparkle(Canvas canvas, Offset c, double s, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _VaultFxPainter old) =>
      old.fallEase != fallEase ||
      old.fallT != fallT ||
      old.gulpT != gulpT ||
      old.sinkT != sinkT ||
      old.burstT != burstT ||
      old.storeGlow != storeGlow ||
      old.gold != gold ||
      old.accent != accent;
}
