// 个人中心页：星巴克风格 — 奶油画布 + 头像 + 尖叫币/装备 + 菜单
// batch4a 改造：金色渐变→奶油纯色，硬编码→token，卡片→MwCard
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/account/application/account_profile_state.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
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
      color: MwColors.cream, // 奶油画布纯色（token：#F2F0EB）
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resp.contentWidth),
          child: resp.isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 头像 + VIP 徽章
                    _buildAvatar(skin, profile),
                    const SizedBox(width: 20),
                    // 用户信息
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
                          style: MwTypography.heading4.copyWith(color: skin.colors.text1),
                        ),
                        const SizedBox(height: 4),
                        Text('VIP 会员', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
                      ],
                    ),
                  ],
                )
              : Column(
                  children: [
                    // 头像 + VIP 徽章
                    _buildAvatar(skin, profile),
                    const SizedBox(height: 12),
                    // 用户 ID（用户可自定义）
                    Text(
                      profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
                      style: MwTypography.heading4.copyWith(color: skin.colors.text1),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAvatar(SkinSystem skin, AccountProfileState profile) {
    return SizedBox(
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
              border: Border.all(color: AppColors.white100, width: 3),
              image: profile.avatar.isEmpty
                  ? null
                  : DecorationImage(image: FileImage(File(profile.avatar)), fit: BoxFit.cover),
            ),
            child: profile.avatar.isEmpty ? Icon(Icons.menu_book_rounded, color: skin.colors.accent, size: 40) : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: skin.colors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white100, width: 2),
              ),
              child: const Center(
                child: Text(
                  'VIP',
                  style: TextStyle(color: AppColors.white100, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
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
