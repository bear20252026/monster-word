// MonsterHatchingPage：开局命名仪式（蓝图 W4「命名的仪式」）。
//
// 首次引导完成后一次性进入：台灯下的蛋 → 输入名字（可空→默认「咕噜」）
// → 「敲三下」破壳（每敲一下蛋壳裂纹加深 + 抖动，第三下白闪 + 怪兽 pop）
// → 「开始冒险！」保存 monster_name / monster_birthday / monster_hatched。
// 世界观红线：名字与生日只进小屋展示，绝不参与任何数值计算。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/motion_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// SP 键清单（与 app.dart 回家仪式、profile 门牌共用）。
class MonsterIdentityPrefs {
  MonsterIdentityPrefs._();

  static const String nameKey = 'monster_name';
  static const String birthdayKey = 'monster_birthday';
  static const String hatchedKey = 'monster_hatched';

  /// 怪兽名（未命名返回默认「咕噜」）。
  static Future<String> name() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(nameKey) ?? '咕噜';
  }

  static Future<void> save({required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(nameKey, name.trim().isEmpty ? '咕噜' : name.trim());
    await prefs.setString(
      birthdayKey,
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
    await prefs.setInt(hatchedKey, 1);
  }

  static Future<bool> get hatched async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(hatchedKey) == 1;
  }
}

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
      _popCtrl.forward(from: 0);
    } else {
      _shakeCtrl.forward(from: 0);
    }
    setState(() {});
  }

  Future<void> _startAdventure() async {
    await MonsterIdentityPrefs.save(name: _nameCtrl.text);
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
                // 蛋壳：裂纹随敲击次数加深（透明度渐显的裂缝线近似）。
                if (!_hatched) Icon(Icons.egg_rounded, size: 120, color: colors.text2.withValues(alpha: AppAlphas.o90)),
                // 裂纹（1-3 档，纯视觉近似：竖向细线渐显）。
                if (!_hatched)
                  for (var i = 0; i < _taps; i++)
                    Transform.translate(
                      offset: Offset(-14.0 + 14.0 * i, -4.0 + 6.0 * i),
                      child: Container(
                        width: 2,
                        height: 46 + 8.0 * i,
                        color: colors.text1.withValues(alpha: AppAlphas.o40),
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
        onPressed: _hatched ? _startAdventure : _knock,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onGlassAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
          elevation: 0,
        ),
        child: Text(
          _hatched ? '开始冒险！' : '敲三下（$_taps/3）',
          style: MwTypography.bodyBold.copyWith(color: colors.onGlassAccent),
        ),
      ),
    );
    return [field, const SizedBox(height: AppSpacing.lg), button];
  }
}
