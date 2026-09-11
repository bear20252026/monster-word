// Monster Word — 品牌开场动画「记忆生长」
//
// 分镜（总长 2.8s，配合 SplashPage 的点按跳过）：
//   落 0.00–0.32  三颗记忆之点（金=新词 / 绿=学习中 / 墨=已掌握）自上落下，
//                 easeOutBack 落定回弹，错峰 0.05
//   生 0.30–0.62  发丝线自中心生长；Charter 衬线词标自左向右显影；
//                 词尾小怪兽头像弹入（它是活的）
//   收 0.68–1.00  整体深呼吸一次（scale 1→1.02→1）后视差上飘淡出，
//                 点比词标飘得快（纵深）；画布保持 pageBg 不翻色
//
// 全部由单个 AnimationController 驱动（纯 Transform/Opacity/ClipRect），
// 无贴图无逐帧，Windows/Android 满帧一致。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/tokens/design_tokens.dart';

class BrandIntro extends StatelessWidget {
  const BrandIntro({super.key, required this.animation});

  /// 0→1 的主时间线（由 SplashPage 持有控制器，便于点按快进跳过）。
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    // 记忆三态用色：金（新词）→ 品牌绿（学习中）→ 墨（已掌握）
    final dots = [skin.vipGoldBg, skin.accent, skin.text1];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;

        // ── 收：视差上飘 + 淡出 ──
        final exitT = _interval(t, 0.80, 1.0, curve: Curves.easeInCubic);
        final groupOpacity = 1.0 - exitT;
        final wordExit = exitT * -46.0; // 词标飘得慢
        final dotsExit = exitT * -110.0; // 点飘得快（视差）

        // ── 收：深呼吸 ──
        final breatheUp = _interval(t, 0.68, 0.77, curve: Curves.easeInOut);
        final breatheDown = _interval(t, 0.77, 0.86, curve: Curves.easeInOut);
        final breathe = 1.0 + 0.02 * breatheUp - 0.02 * breatheDown;

        return Opacity(
          opacity: groupOpacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: breathe,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 词标 + 小怪兽 ──
                Transform.translate(
                  offset: Offset(0, wordExit),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 衬线词标：左→右裁切显影
                      ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: _interval(t, 0.32, 0.62, curve: Curves.easeOutCubic),
                          child: Text(
                            'Monster Word',
                            style: TextStyle(
                              fontFamily: 'Charter',
                              fontSize: MwTypography.stat.fontSize,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.5,
                              color: skin.text1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 小怪兽：词标显影尾部弹入
                      Transform.scale(
                        scale: (_interval(t, 0.55, 0.68, curve: Curves.easeOutBack)).clamp(0.0, 1.3),
                        child: const MonsterAvatar(size: 44),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // ── 发丝线：自中心生长 ──
                SizedBox(
                  width: 220,
                  child: Transform.scale(
                    scaleX: _interval(t, 0.30, 0.44, curve: Curves.easeOutCubic),
                    child: Container(height: 1, color: skin.divider),
                  ),
                ),
                const SizedBox(height: 26),
                // ── 记忆三点的田垄 ──
                Transform.translate(
                  offset: Offset(0, dotsExit),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < dots.length; i++) ...[
                        if (i > 0) const SizedBox(width: 44),
                        _FallingDot(t: t, start: 0.0 + i * 0.05, color: dots[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 区间归一：t 在 [begin,end) 内线性映射到 0→1 并施加曲线，区间外钳到 0/1。
  static double _interval(double t, double begin, double end, {Curve curve = Curves.linear}) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return curve.transform((t - begin) / (end - begin));
  }
}

/// 单颗记忆之点：自上落下 + easeOutBack 落定回弹。
class _FallingDot extends StatelessWidget {
  const _FallingDot({required this.t, required this.start, required this.color});

  final double t;
  final double start;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const duration = 0.22; // 占总时间线的比例（≈620ms）
    final local = BrandIntro._interval(t, start, start + duration, curve: Curves.easeOutBack);
    final opacity = BrandIntro._interval(t, start, start + duration * 0.5).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, (1 - local) * -140),
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
