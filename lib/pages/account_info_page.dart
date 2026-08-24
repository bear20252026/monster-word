// 账号信息页：还原 v3.2 原版账号信息页布局
// 包含：头像 + 相机图标、账号、昵称、手机号、绑定平台
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class AccountInfoPage extends StatelessWidget {
  const AccountInfoPage({super.key});

  static const routeName = '/account_info';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;

    return Scaffold(
      backgroundColor: skin.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildNavBar(context, skin),
            // 内容区
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // 头像区
                    _buildAvatarSection(skin),
                    const SizedBox(height: 32),
                    // 信息卡片
                    _buildInfoCard(context, skin),
                    const SizedBox(height: 16),
                    // 绑定平台卡片
                    _buildBindCard(context, skin),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildNavBar(BuildContext context, ThemeVars skin) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            '账号信息',
            style: MistralTypography.heading5.copyWith(color: skin.text1),
          ),
          const Spacer(),
          const SizedBox(width: 48), // 占位，保持标题居中
        ],
      ),
    );
  }

  /// 头像区（圆形头像 + 相机图标）
  Widget _buildAvatarSection(ThemeVars skin) {
    return Center(
      child: Stack(
        children: [
          // 头像
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [skin.cardBg, skin.cardBgAlt],
              ),
              border: Border.all(color: skin.divider, width: 2),
            ),
            child: Icon(Icons.person, color: skin.text3, size: 44),
          ),
          // 相机图标（右下角）
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: skin.accent,
                border: Border.all(color: skin.cardBg, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// 信息卡片（账号、昵称、手机号）
  Widget _buildInfoCard(BuildContext context, ThemeVars skin) {
    return Container(
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            skin,
            label: '账号',
            value: '微信：幸福',
            onTap: () {},
          ),
          _buildDivider(skin),
          _buildInfoRow(
            skin,
            label: '昵称',
            value: '幸福',
            onTap: () {
              // TODO: 跳转修改昵称页
            },
          ),
          _buildDivider(skin),
          _buildInfoRow(
            skin,
            label: '手机号',
            value: '136****0067',
            onTap: () {
              // TODO: 跳转绑定/修改手机号页
            },
          ),
        ],
      ),
    );
  }

  /// 绑定平台卡片（QQ / 微博 / Apple ID）
  Widget _buildBindCard(BuildContext context, ThemeVars skin) {
    return Container(
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '绑定平台',
              style: MistralTypography.body.copyWith(
                color: skin.text2,
                fontSize: 13,
              ),
            ),
          ),
          _buildBindRow(
            skin,
            icon: Icons.chat_bubble,
            iconColor: const Color(0xFF07C160), // 微信绿
            platform: '微信',
            isBound: true,
            boundName: '幸福',
            onTap: () {},
          ),
          _buildDivider(skin),
          _buildBindRow(
            skin,
            icon: Icons.circle,
            iconColor: const Color(0xFF12B7F5), // QQ蓝
            platform: 'QQ',
            isBound: false,
            onTap: () {
              // TODO: 绑定 QQ
            },
          ),
          _buildDivider(skin),
          _buildBindRow(
            skin,
            icon: Icons.language,
            iconColor: const Color(0xFFE6162D), // 微博红
            platform: '微博',
            isBound: false,
            onTap: () {
              // TODO: 绑定微博
            },
          ),
          _buildDivider(skin),
          _buildBindRow(
            skin,
            icon: Icons.apple,
            iconColor: skin.text1, // Apple 黑
            platform: 'Apple ID',
            isBound: false,
            onTap: () {
              // TODO: 绑定 Apple ID
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// 信息行（左侧标签 + 右侧值 + 箭头）
  Widget _buildInfoRow(
    ThemeVars skin, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        height: AppSpacing.rowH,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              label,
              style: MistralTypography.body.copyWith(color: skin.text1),
            ),
            const Spacer(),
            Text(
              value,
              style: MistralTypography.body.copyWith(color: skin.text2),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: skin.text3),
          ],
        ),
      ),
    );
  }

  /// 绑定平台行
  Widget _buildBindRow(
    ThemeVars skin, {
    required IconData icon,
    required Color iconColor,
    required String platform,
    required bool isBound,
    String? boundName,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        height: AppSpacing.rowH,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 平台图标
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            // 平台名
            Text(
              platform,
              style: MistralTypography.body.copyWith(color: skin.text1),
            ),
            const Spacer(),
            // 绑定状态
            if (isBound && boundName != null)
              Text(
                boundName,
                style: MistralTypography.body.copyWith(color: skin.text2),
              )
            else
              Text(
                '未绑定',
                style: MistralTypography.body.copyWith(color: skin.text3),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: skin.text3),
          ],
        ),
      ),
    );
  }

  /// 分割线
  Widget _buildDivider(ThemeVars skin) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: skin.divider,
    );
  }
}
