// 我的空间页：顶部导航 + 头像区 + 昵称 + 会员入口 + 卡片
// 已接入 SkinSystem 主题
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/message_badge_icon.dart';
import 'package:word_app/widgets/scare_coin_summary_cards.dart';
import 'package:word_app/features/account/application/account_profile_state.dart';

class MySpacePage extends StatelessWidget {
  const MySpacePage({super.key});

  static const routeName = RouteNames.mySpace;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    final profile = context.watch<AccountProfileState>();

    return Scaffold(
      body: Column(
        children: [
          // 金色渐变头部区域（头像 + 卡片）
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MistralColors.sunshine300.withValues(alpha: 0.35),
                  MistralColors.sunshine500.withValues(alpha: 0.08),
                  skin.pageBg,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 顶部导航栏
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                            color: skin.text1,
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          // 未读角标由 MessageStore 驱动（旧版为硬编码常显红点）。
                          const MessageBadgeIcon(),
                          IconButton(
                            icon: const Icon(Icons.settings, size: 22),
                            color: skin.text1,
                            onPressed: () => Navigator.pushNamed(context, RouteNames.settings),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 头像 + VIP 徽章 + 用户 ID + 会员状态
                  _buildProfileHeader(context, skin, profile),
                  SizedBox(height: 16),
                  // 尖叫币 + 装备卡片
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(child: ScareCoinCard(skin: skin)),
                        SizedBox(width: 12),
                        Expanded(child: EquipCard(skin: skin)),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // 菜单列表（普通背景）
          Expanded(child: _buildMenuList(context, skin)),
        ],
      ),
    );
  }

  /// 头像 + VIP 徽章 + 用户 ID + 会员状态条
  Widget _buildProfileHeader(BuildContext context, ThemeVars skin, AccountProfileState profile) {
    final resp = context.responsive;
    return resp.isDesktop
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 头像
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [MistralColors.sunshine300, MistralColors.sunshine500],
                        ),
                        border: Border.all(color: skin.cardBg, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: MistralColors.sunshine500.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.person, color: skin.cardBg, size: 40),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: MistralColors.sunshine500,
                          shape: BoxShape.circle,
                          border: Border.all(color: skin.cardBg, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            'V',
                            style: TextStyle(color: skin.cardBg, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              // 用户信息
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
                    style: MistralTypography.bodyMd.copyWith(color: skin.text2),
                  ),
                ],
              ),
            ],
          )
        : Column(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [MistralColors.sunshine300, MistralColors.sunshine500],
                        ),
                        border: Border.all(color: skin.cardBg, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: MistralColors.sunshine500.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.person, color: skin.cardBg, size: 40),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: MistralColors.sunshine500,
                          shape: BoxShape.circle,
                          border: Border.all(color: skin.cardBg, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            'V',
                            style: TextStyle(color: skin.cardBg, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Text(
                profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
                style: MistralTypography.bodyMd.copyWith(color: skin.text2),
              ),
            ],
          );
  }

  /// 菜单列表
  Widget _buildMenuList(BuildContext context, dynamic skin) {
    final resp = context.responsive;
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: resp.isWide ? 24 : 20),
      children: [
        _MenuItem(
          icon: Icons.palette_outlined,
          title: '外观 & 沉浸场景',
          subtitle: '主题、壁纸、字体',
          skin: skin,
          onTap: () => Navigator.pushNamed(context, RouteNames.appearance),
        ),
        _MenuItem(
          icon: Icons.school_outlined,
          title: '学习偏好',
          subtitle: '发音、节奏、题型',
          skin: skin,
          onTap: () => Navigator.pushNamed(context, RouteNames.settings),
        ),
        _MenuItem(
          icon: Icons.tune,
          title: '更多设置',
          subtitle: '账号、通知、关于',
          skin: skin,
          onTap: () => Navigator.pushNamed(context, RouteNames.moreSettings),
        ),
      ],
    );
  }
}

/// 菜单项
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeVars skin;
  final VoidCallback? onTap;
  const _MenuItem({required this.icon, required this.title, required this.subtitle, required this.skin, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: skin.text1.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: MistralColors.sunshine300.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: skin.accent, size: 20),
        ),
        title: Text(
          title,
          style: MistralTypography.bodyMd.copyWith(fontWeight: FontWeight.w500, color: skin.text1),
        ),
        subtitle: Text(subtitle, style: MistralTypography.caption.copyWith(color: skin.text3)),
        trailing: Icon(Icons.chevron_right, color: skin.text3, size: 20),
        onTap: onTap,
      ),
    );
  }
}
