// 个人中心页：星巴克风格 — 奶油画布 + 头像 + 尖叫币/装备 + 菜单
// batch4a 改造：金色渐变→奶油纯色，硬编码→token，卡片→MwCard
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/account/application/account_profile_state.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
// 跨 feature 只依赖 application 端口（R4 通道）：经 LearningStatisticsReader 读取统计
import 'package:word_app/features/learning/application/learning_statistics_reader.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/func_colors.dart';
import 'package:word_app/widgets/message_badge_icon.dart';
import 'package:word_app/widgets/mw_card.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';
import 'package:word_app/widgets/scare_coin_summary_cards.dart';

// 功能图标色（使用 FuncColors token）
// _iconPurple → FuncColors.purple
// _iconBlue → FuncColors.info

// 装备徽章色（使用 FuncColors token）
// _equipGoldBg → FuncColors.warningLight
// _equipGoldFg → FuncColors.warning (深色)
// _equipBlueBg → FuncColors.infoLight
// _equipBlueFg → FuncColors.info
// _equipGreenBg → FuncColors.successLight (新增)
// _equipGreenFg → skin.colors.success
// _equipPurpleBg → FuncColors.purpleLight
// _equipPurpleFg → FuncColors.purple

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;
    final profile = context.watch<AccountProfileState>();

    return Container(
      color: skin.colors.pageBg,
      child: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏（仅消息图标，未读角标由 MessageStore 驱动）
            Container(
              height: AppSpacing.navH,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [const Spacer(), const MessageBadgeIcon()]),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 金色渐变头部区
                    _buildProfileHeader(context, skin, profile),
                    const SizedBox(height: 20),
                    // 尖叫币 + 装备卡片
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                      child: Row(
                        children: [
                          Expanded(child: ScareCoinCard(skin: skin.colors)),
                          const SizedBox(width: 12),
                          Expanded(child: EquipCard(skin: skin.colors)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 菜单列表
                    _buildMenu(skin, resp, context),
                    const SizedBox(height: 16),
                    // 我的学习菜单组（足迹/内容/随身听/装备）
                    _buildMyLearningMenu(skin, resp, context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, SkinSystem skin, AccountProfileState profile) {
    final resp = context.responsive;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      color: skin.colors.pageBg, // 跟随主题画布（勿硬编码奶油色，深色主题下会断裂）
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resp.contentWidth),
          child: resp.isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 头像（点击进入资料编辑）
                    _buildAvatar(context, skin, profile),
                    const SizedBox(width: 20),
                    // 用户信息
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
                          style: MwTypography.heading4.copyWith(color: skin.colors.text1),
                        ),
                        const SizedBox(height: 6),
                        const _ProfileStatsRow(),
                      ],
                    ),
                  ],
                )
              : Column(
                  children: [
                    // 头像（点击进入资料编辑）
                    _buildAvatar(context, skin, profile),
                    const SizedBox(height: 12),
                    // 用户 ID（用户可自定义）
                    Text(
                      profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
                      style: MwTypography.heading4.copyWith(color: skin.colors.text1),
                    ),
                    const SizedBox(height: 6),
                    const _ProfileStatsRow(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, SkinSystem skin, AccountProfileState profile) {
    return ScaleDownOnPress(
      onTap: () => Navigator.pushNamed(context, RouteNames.accountInfo),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white100,
                border: Border.all(color: skin.colors.divider, width: 1),
                boxShadow: const [
                  BoxShadow(color: MwShadows.hairlineShadow, blurRadius: 0.5),
                  BoxShadow(color: MwShadows.liftShadow, blurRadius: 1.0, offset: Offset(0, 1)),
                ],
                image: profile.avatar.isEmpty
                    ? null
                    : DecorationImage(image: FileImage(File(profile.avatar)), fit: BoxFit.cover),
              ),
              child: profile.avatar.isEmpty ? Icon(Icons.menu_book_rounded, color: skin.colors.accent, size: 40) : null,
            ),
            // 编辑角标（点击头像进入资料编辑）
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: skin.colors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: skin.colors.cardBg, width: 2),
                ),
                child: const Center(child: Icon(Icons.edit_rounded, color: Colors.white, size: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(SkinSystem skin, AppResponsive resp, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: MwCard(
        child: Column(
          children: [
            _menuRow(
              Icons.palette_outlined,
              FuncColors.success, // #4CAF50 → token
              '外观 & 沉浸场景',
              skin,
              onTap: () => Navigator.pushNamed(context, RouteNames.appearance),
            ),
            Divider(height: 1, color: skin.colors.divider),
            _menuRow(
              Icons.tune,
              FuncColors.purple,
              '学习偏好',
              skin,
              onTap: () => Navigator.pushNamed(context, RouteNames.settings),
            ),
            Divider(height: 1, color: skin.colors.divider),
            _menuRow(
              Icons.settings_outlined,
              FuncColors.info,
              '更多设置',
              skin,
              onTap: () => Navigator.pushNamed(context, MoreSettingsPage.routeName),
            ),
          ],
        ),
      ),
    );
  }

  /// "我的学习"菜单组：足迹/我的内容/随身听/我的装备（batch5 接通四个孤儿页入口）。
  Widget _buildMyLearningMenu(SkinSystem skin, AppResponsive resp, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: MwCard(
        child: Column(
          children: [
            _menuRow(
              Icons.timeline,
              FuncColors.success,
              '学习足迹',
              skin,
              onTap: () => Navigator.pushNamed(context, RouteNames.footMark),
            ),
            Divider(height: 1, color: skin.colors.divider),
            _menuRow(
              Icons.grid_view_outlined,
              FuncColors.info,
              '我的内容',
              skin,
              onTap: () => Navigator.pushNamed(context, RouteNames.myContent),
            ),
            Divider(height: 1, color: skin.colors.divider),
            _menuRow(
              Icons.headphones_outlined,
              FuncColors.purple,
              '随身听',
              skin,
              onTap: () => Navigator.pushNamed(context, RouteNames.personalStereo),
            ),
            Divider(height: 1, color: skin.colors.divider),
            _menuRow(
              Icons.inventory_2_outlined,
              FuncColors.warning,
              '我的装备',
              skin,
              onTap: () => Navigator.pushNamed(context, RouteNames.myEquip),
            ),
            Divider(height: 1, color: skin.colors.divider),
            _menuRow(
              Icons.person_outline,
              FuncColors.info,
              '我的空间',
              skin,
              onTap: () => Navigator.pushNamed(context, RouteNames.mySpace),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, Color iconColor, String label, SkinSystem skin, {VoidCallback? onTap}) {
    return ScaleDownOnPress(
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: AppSpacing.rowH,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: MwTypography.bodyMd.copyWith(color: skin.colors.text1)),
              ),
              if (onTap != null) Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 头像下方真实学习数据行（替代此前的硬编码「VIP 会员」假标签）。
class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Selector<LearningStatisticsReader, (int, int)>(
      selector: (_, s) => (s.totalLearnedDays, s.learnedCount),
      builder: (context, stats, _) {
        final (days, words) = stats;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              days > 0 ? '已坚持 $days 天' : '开始你的第一天',
              style: MwTypography.bodySm.copyWith(color: skin.colors.text3),
            ),
            const SizedBox(width: 8),
            Container(width: 3, height: 3, decoration: BoxDecoration(color: skin.colors.text3, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('掌握 $words 词', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
          ],
        );
      },
    );
  }
}
