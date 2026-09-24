// CoinFlyOverlay：答对金币从选项 tile 抛物线飞入顶栏余额
//
// 起点＝答对选项中心（全局坐标），终点＝顶栏金币 pill 中心；二次贝塞尔
// 高抛（控制点在中点上方 110px），easeIn 加速＋28→15 缩小＋尾段淡出。
// 完成或宿主销毁时必回调 onArrive 一次（entry 精确移除一次，无泄漏）；
// 落袋后父级刷新余额（AnimatedSwitcher 数字 pop）。
import 'package:flutter/material.dart';

import 'package:word_app/widgets/coin_swallow_celebration.dart' show CoinBadge;

class CoinFlyOverlay {
  /// 播放一次飞行（650ms）。from/to 均为全局坐标。
  static void play(
    BuildContext context, {
    required Offset from,
    required Offset to,
    required VoidCallback onArrive,
  }) {
    final overlay = Overlay.of(context);
    var done = false;
    late OverlayEntry entry;
    void finish() {
      if (done) return;
      done = true;
      entry.remove();
      onArrive();
    }

    entry = OverlayEntry(
      builder: (_) => _FlyCoin(from: from, to: to, onDone: finish),
    );
    overlay.insert(entry);
  }
}

/// 飞行金币（二次贝塞尔＋缩小＋尾 fade；销毁兜底回调防 entry 泄漏）。
class _FlyCoin extends StatefulWidget {
  final Offset from;
  final Offset to;
  final VoidCallback onDone;

  const _FlyCoin({required this.from, required this.to, required this.onDone});

  @override
  State<_FlyCoin> createState() => _FlyCoinState();
}

class _FlyCoinState extends State<_FlyCoin> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ease;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_notified) {
          _notified = true;
          widget.onDone();
        }
      })
      ..forward();
    _ease = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    // 路由提前弹出等未播完即销毁：仍走 onDone，保证 entry 移除＋余额刷新。
    if (!_notified) {
      _notified = true;
      widget.onDone();
    }
    _ctrl.dispose();
    super.dispose();
  }

  static Offset _bezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final control = Offset(
      (widget.from.dx + widget.to.dx) / 2,
      (widget.from.dy < widget.to.dy ? widget.from.dy : widget.to.dy) - 110,
    );
    return AnimatedBuilder(
      animation: _ease,
      builder: (context, _) {
        final t = _ease.value;
        final pos = _bezier(widget.from, control, widget.to, t);
        final scale = 1.0 - 0.45 * t;
        final opacity = t > 0.85 ? (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0) : 1.0;
        return Positioned(
          left: pos.dx - 14,
          top: pos.dy - 14,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: const CoinBadge(size: 28)),
          ),
        );
      },
    );
  }
}
