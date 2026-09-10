// 由 Claude 团队生成 | Monster Word App

// 我的装备：陈列式装备架 —— 当前皮肤以主题色板 hero 呈现，
// 收藏章/连击徽章进「收藏陈列」分组（MwListRow 统一列表语言）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/func_colors.dart';
import 'package:word_app/widgets/mw_list_row.dart';
import 'package:word_app/widgets/mw_section_header.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

class MyEquipPage extends StatelessWidget {
  const MyEquipPage({super.key});

  static const routeName = '/my_equip';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // 装备总数 = hero（当前皮肤）+ 收藏陈列 2 行，与 profile 装备卡片共用该值。
    assert(AppPreferences.equipRackCount == 3, '装备架条目数与 AppPreferences.equipRackCount 不同步（profile 装备卡片共用该值）');

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, context),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SkinHeroCard(skin: skin),
                  const SizedBox(height: 24),
                  const MwSectionHeader(title: '收藏陈列'),
                  const SizedBox(height: 12),
                  MwListGroup(
                    children: [
                      MwListRow(
                        icon: Icons.stars_rounded,
                        iconColor: FuncColors.purple,
                        title: '收藏章',
                        subtitle: '在兑换中心用尖叫币兑换',
                        value: '${AppPreferences().redeemedBadgeCount()} 枚',
                        onTap: () => Navigator.pushNamed(context, RouteNames.redemption),
                      ),
                      MwListRow(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: FuncColors.success,
                        title: '连击徽章',
                        subtitle: '每日签到累积连击天数',
                        trailing: _StreakValue(reader: context.read<CheckinStatusReader>()),
                        onTap: () => Navigator.pushNamed(context, RouteNames.checkInHistory),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('我的装备', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}

/// 当前皮肤陈列卡：主题 2×2 色板芯片 + Charter 衬线主题名。
class _SkinHeroCard extends StatelessWidget {
  const _SkinHeroCard({required this.skin});

  final SkinSystem skin;

  @override
  Widget build(BuildContext context) {
    final vars = skin.colors;
    return ScaleDownOnPress(
      onTap: () => Navigator.pushNamed(context, RouteNames.appearance),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: vars.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.xl),
          border: Border.all(color: vars.divider),
        ),
        child: Row(
          children: [
            _ThemePaletteChip(vars: vars),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前装备 · 主题外观', style: MwTypography.caption.copyWith(color: vars.text3, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(
                    skin.currentTheme.name,
                    style: MwTypography.heading3.copyWith(color: vars.text1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('全局配色与沉浸场景', style: MwTypography.caption.copyWith(color: vars.text3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 22, color: vars.text3),
          ],
        ),
      ),
    );
  }
}

/// 主题色板芯片：像颜料陈列一样展示当前主题的四个代表色。
class _ThemePaletteChip extends StatelessWidget {
  const _ThemePaletteChip({required this.vars});

  static const double _dotSize = 14;

  final ThemeVars vars;

  @override
  Widget build(BuildContext context) {
    final dots = [vars.accent, vars.teal, vars.success, vars.text3];
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: vars.pageBg,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: vars.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: dots.take(2).map(_dot).toList()),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: dots.skip(2).map(_dot).toList()),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: _dotSize,
    height: _dotSize,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// 连击天数（异步读取）。
class _StreakValue extends StatelessWidget {
  const _StreakValue({required this.reader});

  final CheckinStatusReader reader;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: reader.getStreakDays(),
      builder: (context, snap) => Text(
        snap.data == null ? '—' : '连击 ${snap.data} 天',
        style: MwTypography.bodySm.copyWith(color: context.skin.colors.text2),
      ),
    );
  }
}
