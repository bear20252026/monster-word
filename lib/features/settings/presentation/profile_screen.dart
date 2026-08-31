// 个人中心页：星巴克风格 — 奶油画布 + 头像 + 尖叫币/装备 + 菜单
// batch4a 改造：金色渐变→奶油纯色，硬编码→token，卡片→MwCard
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/features/account/application/account_profile_state.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/func_colors.dart';
import 'package:word_app/widgets/mw_card.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';
import 'package:word_app/widgets/monster_icon.dart';

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
            // 顶部导航栏（仅消息图标）
            Container(
              height: AppSpacing.navH,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.mail_outline, color: skin.colors.text1, size: 22),
                    tooltip: '消息',
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('消息功能开发中...'), duration: Duration(seconds: 1)));
                    },
                  ),
                ],
              ),
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
                          Expanded(child: _CoinCard(skin: skin)),
                          const SizedBox(width: 12),
                          Expanded(child: _EquipCard(skin: skin)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 菜单列表
                    _buildMenu(skin, resp, context),
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
      color: MistralColors.cream, // 奶油画布纯色（token：#F2F0EB）
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resp.contentWidth),
          child: resp.isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 头像 + VIP 徽章
                    _buildAvatar(skin),
                    const SizedBox(width: 20),
                    // 用户信息
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
                          style: MistralTypography.heading4.copyWith(color: skin.colors.text1),
                        ),
                        const SizedBox(height: 4),
                        Text('VIP 会员', style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                      ],
                    ),
                  ],
                )
              : Column(
                  children: [
                    // 头像 + VIP 徽章
                    _buildAvatar(skin),
                    const SizedBox(height: 12),
                    // 用户 ID（用户可自定义）
                    Text(
                      profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
                      style: MistralTypography.heading4.copyWith(color: skin.colors.text1),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAvatar(SkinSystem skin) {
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
            ),
            child: Icon(Icons.menu_book_rounded, color: skin.colors.accent, size: 40),
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
            _menuRow(Icons.tune, FuncColors.purple, '学习偏好', skin),
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
                child: Text(label, style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
              ),
              if (onTap != null) Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 尖叫币卡片：动态余额，点击进入历史记录页
class _CoinCard extends StatelessWidget {
  final SkinSystem skin;
  const _CoinCard({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '尖叫币是学习奖励货币，签到/学词可赚取，可用于兑换主题装备',
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/scare_coin_history'),
        child: MwCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '尖叫币',
                    style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.help_outline_rounded, color: skin.colors.text3, size: 14),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: skin.colors.text3, size: 16),
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
                        style: MistralTypography.heading4.copyWith(
                          color: skin.colors.text1,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text('学习奖励', style: TextStyle(fontSize: 12, color: skin.colors.text3)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 装备卡片
class _EquipCard extends StatelessWidget {
  final SkinSystem skin;
  const _EquipCard({required this.skin});

  @override
  Widget build(BuildContext context) {
    return MwCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '装备',
                style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Text('9/9', style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 装备徽章（4组功能色，使用 FuncColors token）
              _equipIcon(FuncColors.warningLight, FuncColors.warning, Icons.auto_stories),
              const SizedBox(width: 6),
              _equipIcon(FuncColors.infoLight, FuncColors.info, Icons.menu_book),
              const SizedBox(width: 6),
              _equipIcon(FuncColors.successLight, skin.colors.success, Icons.headphones),
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
