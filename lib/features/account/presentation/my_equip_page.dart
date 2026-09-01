// 由 Claude 团队生成 | Monster Word App

// 我的装备：真实装备架（当前皮肤/已兑换收藏章/连续签到徽章）
// batch5：原"暂无装备"空壳页改造为可用的装备展示与入口页。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/func_colors.dart';

class MyEquipPage extends StatelessWidget {
  const MyEquipPage({super.key});

  static const routeName = '/my_equip';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    assert(AppPreferences.equipRackCount == 3, '装备架条目数与 AppPreferences.equipRackCount 不同步（profile 装备卡片共用该值）');

    final equips = [
      _EquipItem(
        icon: Icons.palette_outlined,
        color: FuncColors.warning,
        title: '当前皮肤',
        subtitle: '主题外观与沉浸场景',
        value: skin.currentTheme.name,
        route: RouteNames.appearance,
      ),
      _EquipItem(
        icon: Icons.stars_rounded,
        color: FuncColors.purple,
        title: '收藏章',
        subtitle: '在兑换中心用尖叫币兑换',
        value: '${AppPreferences().redeemedBadgeCount()} 枚',
        route: RouteNames.redemption,
      ),
      _EquipItem(
        icon: Icons.local_fire_department_rounded,
        color: FuncColors.success,
        title: '连击徽章',
        subtitle: '每日签到累积连击天数',
        value: null, // 异步加载，见 _EquipRow
        future: context.read<CheckinStatusReader>().getStreakDays(),
        route: RouteNames.checkInHistory,
      ),
    ];

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, context),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: equips.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _EquipRow(skin: skin, item: equips[index]),
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
          Text('我的装备', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}

/// 装备条目定义（数据 + 跳转目标）。
class _EquipItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? value; // 同步值（如皮肤名/收藏章数）
  final Future<int>? future; // 异步值（连击天数）
  final String route;

  const _EquipItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    this.future,
    required this.route,
  });
}

/// 单个装备行：图标 + 标题/说明 + 徽章值 + 箭头，整行可点进入对应页面。
class _EquipRow extends StatelessWidget {
  final SkinSystem skin;
  final _EquipItem item;

  const _EquipRow({required this.skin, required this.item});

  @override
  Widget build(BuildContext context) {
    final badge = item.value ?? '—';
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: skin.colors.cardBg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
                ],
              ),
            ),
            // 异步值（连击天数）用 FutureBuilder，同步值直接显示。
            if (item.future != null)
              FutureBuilder<int>(
                future: item.future,
                builder: (context, snap) => Text(
                  snap.data == null ? '—' : '连击 ${snap.data} 天',
                  style: MistralTypography.bodySm.copyWith(color: skin.colors.text2),
                ),
              )
            else
              Text(badge, style: MistralTypography.bodySm.copyWith(color: skin.colors.text2)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}
