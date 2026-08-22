// 由账号4生成
// L3 个人中心：米色渐变背景 + 头像 + VIP胶囊 + 酷币/装备卡 + 三行菜单
// 翻译自 Figma 03c-screens-profile.json profile
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../pages/settings_page.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    return Container(
      // 米色渐变背景（原版 profileDecor）
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: skin.colors.profileDecor,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏（原版 NavBar：空标题 + 消息图标）
            _buildNav(skin),
            // 头像区
            _buildIdentity(skin),
            const SizedBox(height: 24),
            // 酷币/装备双卡
            _buildStatsCards(skin, resp),
            const SizedBox(height: 16),
            // 三行菜单
            _buildMenu(skin, resp, context),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(SkinSystem skin) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            icon: Icon(Icons.mail_outline, color: skin.colors.text1, size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// 头像区（80dp 圆形 + VIP 盾牌角标 + 昵称 + 会员胶囊）
  Widget _buildIdentity(SkinSystem skin) {
    return Column(
      children: [
        // 头像（80dp 圆形）
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: skin.colors.profileDecor,
            ),
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 12),
        // 昵称
        Text(
          '未登录',
          style: AppTypography.titlePage.copyWith(color: skin.colors.text1),
        ),
        const SizedBox(height: 12),
        // 会员胶囊（原版 gold_gradient）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [skin.colors.vipGoldBg, skin.colors.vipGoldBg.withValues(alpha: 0.5)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, size: 18, color: skin.colors.vipGoldText),
              const SizedBox(width: 4),
              Text(
                '开通终身大会员',
                style: AppTypography.caption.copyWith(color: skin.colors.vipGoldText),
              ),
              Icon(Icons.chevron_right, size: 16, color: skin.colors.vipGoldText),
            ],
          ),
        ),
      ],
    );
  }

  /// 酷币/装备双卡
  Widget _buildStatsCards(SkinSystem skin, AppResponsive resp) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: skin.colors.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: skin.colors.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.monetization_on_outlined, color: AppleColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('酷币  0', style: AppTypography.body.copyWith(color: skin.colors.text1)),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: skin.colors.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: skin.colors.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.card_giftcard, color: AppleColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('装备', style: AppTypography.body.copyWith(color: skin.colors.text1)),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 三行菜单（外观&沉浸 / 学习偏好 / 更多设置）
  Widget _buildMenu(SkinSystem skin, AppResponsive resp, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: Container(
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: skin.colors.divider),
        ),
        child: Column(
          children: [
            _menuRow(Icons.palette_outlined, AppleColors.primary, '外观 & 沉浸场景', skin),
            Divider(height: 1, color: skin.colors.divider),
            _menuRow(Icons.tune, AppleColors.primary, '学习偏好', skin),
            Divider(height: 1, color: skin.colors.divider),
            _menuRow(Icons.settings_outlined, AppleColors.primary, '更多设置', skin,
                onTap: () => Navigator.pushNamed(context, SettingsPage.routeName)),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, Color iconColor, String label, SkinSystem skin, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: AppSpacing.rowH,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppTypography.body.copyWith(color: skin.colors.text1)),
            ),
            Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}
