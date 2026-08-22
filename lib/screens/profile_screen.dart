// 由账号4生成
// 个人中心：Mistral AI 设计风格 — 奶油黄背景 + 橙色 CTA + Charter 标题
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
      color: skin.colors.pageBg,
      child: SafeArea(
        child: Column(
          children: [
            _buildNav(skin),
            _buildIdentity(skin),
            const SizedBox(height: 20),
            _buildStatsCards(skin, resp),
            const SizedBox(height: 16),
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
      child: Row(children: [
        const Spacer(),
        IconButton(
          icon: Icon(Icons.mail_outline, color: skin.colors.text1, size: 22),
          onPressed: () {},
        ),
      ]),
    );
  }

  Widget _buildIdentity(SkinSystem skin) {
    return Column(children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [MistralColors.cream, MistralColors.creamDeeper]),
          border: Border.all(color: MistralColors.hairline, width: 2),
        ),
        child: Icon(Icons.person, color: MistralColors.stone, size: 40),
      ),
      const SizedBox(height: 12),
      Text('Monster Word',
        style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MistralColors.sunshine300, MistralColors.sunshine500]),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.workspace_premium, size: 18, color: MistralColors.ink),
          const SizedBox(width: 4),
          Text('开通终身大会员',
            style: MistralTypography.micro.copyWith(color: MistralColors.ink)),
          const Icon(Icons.chevron_right, size: 16, color: MistralColors.ink),
        ]),
      ),
    ]);
  }

  Widget _buildStatsCards(SkinSystem skin, AppResponsive resp) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: Row(children: [
        Expanded(child: Container(
          height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: skin.colors.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: skin.colors.divider)),
          child: Row(children: [
            Icon(Icons.monetization_on_outlined, color: MistralColors.primary, size: 24),
            const SizedBox(width: 10),
            Text('酷币  0', style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
            const Spacer(),
            Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
          ]),
        )),
        const SizedBox(width: 12),
        Expanded(child: Container(
          height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: skin.colors.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: skin.colors.divider)),
          child: Row(children: [
            Icon(Icons.card_giftcard, color: MistralColors.sunshine700, size: 24),
            const SizedBox(width: 10),
            Text('装备', style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1)),
            const Spacer(),
            Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
          ]),
        )),
      ]),
    );
  }

  Widget _buildMenu(SkinSystem skin, AppResponsive resp, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: Container(
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: skin.colors.divider)),
        child: Column(children: [
          _menuRow(Icons.palette_outlined, MistralColors.primary, '外观 & 沉浸场景', skin),
          Divider(height: 1, color: skin.colors.divider),
          _menuRow(Icons.tune, MistralColors.sunshine700, '学习偏好', skin),
          Divider(height: 1, color: skin.colors.divider),
          _menuRow(Icons.settings_outlined, MistralColors.ink, '更多设置', skin,
            onTap: () => Navigator.pushNamed(context, SettingsPage.routeName)),
        ]),
      ),
    );
  }

  Widget _menuRow(IconData icon, Color iconColor, String label, SkinSystem skin, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: AppSpacing.rowH,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Text(label,
            style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1))),
          Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
        ]),
      ),
    );
  }
}
