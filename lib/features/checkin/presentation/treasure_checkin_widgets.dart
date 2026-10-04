// part of treasure_checkin_page.dart — 聚宝日历 UI 区块构建方法（I58 拆分）。
// extension 承载 State 的纯构建方法：同 library 私有可见。
part of 'treasure_checkin_page.dart';

extension _TreasureCheckInUi on _TreasureCheckInPageState {
  // ── 顶部胶囊：连击 / 余额 ──
  Widget _buildTopBar() {
    const popDur = 0.5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Builder(
        builder: (context) {
          final pt = _now - _pillPopAt;
          final pop = pt >= 0 && pt < popDur ? math.sin(math.pi * pt / popDur) : 0.0;
          final flameScale = 1.0 + 0.35 * pop;
          final numScale = 1.0 + 0.45 * pop;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _pill(
                children: [
                  Transform.rotate(
                    angle: -0.14 * pop,
                    child: Transform.scale(
                      scale: flameScale,
                      child: const Icon(Icons.local_fire_department_rounded, size: 17, color: TreasurePalette.coral),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text('连续 ', style: _pillStyle()),
                  Transform.scale(
                    scale: numScale,
                    child: Text('$_streak', style: _pillStyle(color: pop > 0.4 ? TreasurePalette.goldDeep : null)),
                  ),
                  Text(' 天', style: _pillStyle()),
                ],
              ),
              _pill(
                children: [
                  const _CoinGlyph(size: 16),
                  const SizedBox(width: 7),
                  Transform.scale(
                    scale: numScale,
                    child: Text('$_balance', style: _pillStyle(color: pop > 0.4 ? TreasurePalette.goldDeep : null)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _pillStyle({Color? color}) => MwTypography.caption.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 0.02,
    color: color ?? TreasurePalette.ink,
  );

  Widget _pill({required List<Widget> children}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: TreasurePalette.card,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: TreasurePalette.line),
      boxShadow: [BoxShadow(color: TreasurePalette.pillShadow, blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );

  // ── 月份栏 ──
  Widget _buildMonthBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navBtn(Icons.chevron_left, () => _shiftMonth(-1)),
          const SizedBox(width: 18),
          Column(
            children: [
              Text(
                '${_month.year} 年 ${_month.month} 月',
                style: MwTypography.titleLg.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.04,
                  color: TreasurePalette.ink,
                ),
              ),
              Text(
                '聚宝日历',
                style: MwTypography.micro.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.12,
                  color: TreasurePalette.dim,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          _navBtn(Icons.chevron_right, () => _shiftMonth(1)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: TreasurePalette.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: TreasurePalette.line),
      ),
      child: Icon(icon, size: 16, color: TreasurePalette.ink),
    ),
  );

  // ── 日历舞台 ──
  Widget _buildStage() {
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
    return LayoutBuilder(
      builder: (context, constraints) {
        // 回调内先查存活：同帧内 element 被卸载时 findRenderObject 会打在
        // defunct element 上（热重载/测试可见的真实窗口）。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _computeGeometry();
        });
        return Stack(
          key: _stageKey,
          children: [
            // 星期行（聚合后淡入）。
            Positioned(
              top: 4,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _mode == 'grid' ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Text(
                            weekLabels[i],
                            textAlign: TextAlign.center,
                            style: MwTypography.micro.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                              color: i == 6 ? TreasurePalette.coral : TreasurePalette.dim,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // 日期徽章（绝对定位 + 弹簧变换）。
            for (var i = 0; i < _days.length; i++)
              Builder(
                builder: (context) {
                  final d = _days[i];
                  return Positioned(
                    left: d.x - 22,
                    top: d.y - 22,
                    width: 44,
                    height: 44,
                    child: Transform.rotate(
                      angle: d.rot * math.pi / 180,
                      child: Transform.scale(
                        scale: d.scale,
                        child: GestureDetector(
                          onTap: d.isToday ? _doCheckIn : null,
                          child: _SealBadge(
                            kind: _kindOf(d),
                            num: d.dnum,
                            squareness: d.square,
                            glowAlpha: i == _justIndex ? _glowValue(_now - _justAt) : 0,
                            reduceMotion: _reduceMotion,
                            frame: _fxSignal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  /// 盖章光晕强度（同原型 stampIn：0→35% 升到 0.9 → 消散）。
  double _glowValue(double t) {
    if (t < 0 || t > 0.55) return 0;
    return t < 0.2 ? (t / 0.2) * 0.9 : 0.9 * (1 - (t - 0.2) / 0.35);
  }

  // ── 底部：储蓄罐 + CTA ──
  Widget _buildBottom() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 128,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Builder(
                  builder: (context) {
                    // bump：scale(1)→(1.14,.9)@35% →(.96,1.1)@65% →(1)，节流由金币到达触发。
                    double sx = 1, sy = 1;
                    if (_bumpT < 0.55) {
                      final t = _bumpT / 0.55;
                      if (t < 0.35) {
                        sx = 1 + 0.14 * (t / 0.35);
                        sy = 1 - 0.10 * (t / 0.35);
                      } else if (t < 0.65) {
                        final u = (t - 0.35) / 0.3;
                        sx = 1.14 - 0.18 * u;
                        sy = 0.9 + 0.20 * u;
                      } else {
                        final u = (t - 0.65) / 0.35;
                        sx = 0.96 + 0.04 * u;
                        sy = 1.10 - 0.10 * u;
                      }
                    }
                    return Transform.scale(
                      scale: sx,
                      alignment: const Alignment(0, 0.5), // 原点 (110,96)
                      child: Transform.scale(
                        scale: sy,
                        alignment: const Alignment(0, 0.5),
                        child: CustomPaint(
                          key: _piggyKey,
                          size: const Size(220, 128),
                          painter: _PiggyPainter(bellyPct: _bellyPct),
                        ),
                      ),
                    );
                  },
                ),
                // +N 浮字（0.9s 上浮淡出）。
                Positioned(
                  left: 0,
                  right: 0,
                  top: 6,
                  child: IgnorePointer(
                    child: Builder(
                      builder: (context) {
                        final t = _now - _gainAt;
                        if (t < 0 || t > 0.9) return const SizedBox.shrink();
                        final u = t / 0.9;
                        final opacity = u < 0.25 ? u / 0.25 : 1 - (u - 0.25) / 0.75;
                        final scale = u < 0.25 ? 0.7 + 0.45 * (u / 0.25) : 1.15 - 0.15 * ((u - 0.25) / 0.75);
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: scale,
                            child: Text(
                              '+$_gainValue',
                              textAlign: TextAlign.center,
                              style: MwTypography.bodyMd.copyWith(
                                fontWeight: FontWeight.w900,
                                color: TreasurePalette.gainText,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildCta(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCta() {
    final checked = _todayChecked;
    final busy = _busy;
    return GestureDetector(
      onTap: (checked || busy) ? null : _doCheckIn,
      child: AnimatedContainer(
        duration: MotionDurations.slow,
        padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 15),
        decoration: BoxDecoration(
          gradient: checked
              ? const LinearGradient(colors: [TreasurePalette.ctaDisabledTop, TreasurePalette.ctaDisabledBottom])
              : const LinearGradient(
                  colors: [TreasurePalette.greenLight, TreasurePalette.green, TreasurePalette.greenDark],
                  stops: [0, 0.55, 1],
                ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: checked
              ? null
              : [BoxShadow(color: TreasurePalette.ctaShadow, blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!checked) ...[const _CoinGlyph(size: 18, creamStyle: true), const SizedBox(width: 10)],
            Text(
              checked ? '今日已签到 · 明天再来' : '立即签到 · +$_reward',
              style: MwTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
                color: TreasurePalette.cream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
