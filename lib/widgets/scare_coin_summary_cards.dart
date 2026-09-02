// Monster Word — 尖叫币/装备概要卡片（A5 单一事实来源，v2.7.41）
//
// 消费方：features/account/presentation/my_space_page.dart（我的空间）、
//         features/settings/presentation/profile_screen.dart（个人中心）。
// 两页此前各自私有实现 _CoinCard/_EquipCard，UI 与行为已漂移（裸 Container vs
// MwCard、字符串路由 vs RouteNames、装备数规则双写、装备徽章两套配色），
// 本文件收口为唯一实现。
//
// 依赖边界（由 ImportGuard R-widgets 规则锁定）：
// - 仅消费 feature 的 application 端口（ScareCoinStore / CheckinStatusReader）；
// - core 契约（RouteNames / AppPreferences）与共享 UI（MwCard / MonsterAvatar /
//   MistralTypography / FuncColors）。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/func_colors.dart';
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/widgets/mw_card.dart';

/// 尖叫币卡片：动态余额，点击进入历史记录页。
class ScareCoinCard extends StatelessWidget {
  const ScareCoinCard({super.key, required this.skin});

  /// 主题变量（SkinSystem.colors / context.skin.colors）。
  final ThemeVars skin;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '尖叫币是学习奖励货币，签到/学词可赚取，可用于兑换主题装备',
      child: MwCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        onTap: () => Navigator.pushNamed(context, RouteNames.scareCoinHistory),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '尖叫币',
                  style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(Icons.help_outline_rounded, color: skin.text3, size: 14),
                const Spacer(),
                Icon(Icons.chevron_right, color: skin.text3, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const MonsterAvatar(size: 32),
                const SizedBox(width: 8),
                FutureBuilder<int>(
                  future: context.read<ScareCoinStore>().balance(),
                  builder: (context, snap) {
                    return Text(
                      '${snap.data ?? 0}',
                      style: MistralTypography.heading4.copyWith(color: skin.text1, fontWeight: FontWeight.w700),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text('学习奖励', style: TextStyle(fontSize: 12, color: skin.text3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 装备卡片：标题 + 已拥有件数 + 4 组装备徽章，点击进入我的装备架。
class EquipCard extends StatelessWidget {
  const EquipCard({super.key, required this.skin});

  /// 主题变量（SkinSystem.colors / context.skin.colors）。
  final ThemeVars skin;

  @override
  Widget build(BuildContext context) {
    // 已拥有装备件数规则（⚠️ 全库唯一持有，勿在他处复制）：
    // 当前皮肤(恒 1) + 收藏章(已兑换≥1 计 1 件) + 连击徽章(连击>0 计 1 件)；
    // 总数取装备架条目数（单一事实来源 AppPreferences.equipRackCount，与我的装备页同源）。
    final streakFuture = context.read<CheckinStatusReader>().getStreakDays();
    final redeemedCount = AppPreferences().redeemedBadgeCount();
    return MwCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      onTap: () => Navigator.pushNamed(context, RouteNames.myEquip),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '装备',
                style: MistralTypography.bodyMd.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              FutureBuilder<int>(
                future: streakFuture,
                builder: (context, snap) {
                  final owned = 1 + (redeemedCount > 0 ? 1 : 0) + ((snap.data ?? 0) > 0 ? 1 : 0);
                  return Text(
                    '$owned/${AppPreferences.equipRackCount}',
                    style: MistralTypography.caption.copyWith(color: skin.text3),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 装备徽章（4 组功能色，使用 FuncColors token）
              _equipIcon(FuncColors.warningLight, FuncColors.warning, Icons.auto_stories),
              const SizedBox(width: 6),
              _equipIcon(FuncColors.infoLight, FuncColors.info, Icons.menu_book),
              const SizedBox(width: 6),
              _equipIcon(FuncColors.successLight, skin.success, Icons.headphones),
              const SizedBox(width: 6),
              _equipIcon(FuncColors.purpleLight, FuncColors.purple, Icons.edit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _equipIcon(Color bg, Color fg, IconData icon) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: 16),
    );
  }
}
