// 我的空间页：顶部导航 + 头像区 + 昵称 + 会员入口 + 卡片
// 已接入 SkinSystem 主题
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/route_names.dart';
import '../../../core/scare_coin/scare_coin_store.dart';
import 'package:word_app/core/presentation/responsive.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import '../../../widgets/monster_icon.dart';
import '../../account/presentation/account_profile_state.dart';

class MySpacePage extends StatelessWidget {
  const MySpacePage({super.key});

  static const routeName = '/my_space';

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
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.mail_outline, size: 22),
                                color: skin.text1,
                                onPressed: () => Navigator.pushNamed(context, RouteNames.messages),
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: skin.danger,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: skin.pageBg, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                        Expanded(child: _CoinCard(skin: skin)),
                        SizedBox(width: 12),
                        Expanded(child: _EquipCard(skin: skin)),
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

/// 尖叫币卡片：动态余额，点击进入历史记录页
class _CoinCard extends StatelessWidget {
  final ThemeVars skin;
  const _CoinCard({required this.skin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, RouteNames.scareCoinHistory),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: skin.text1.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const MonsterAvatar(size: 34),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('尖叫币', style: MistralTypography.micro.copyWith(color: skin.text3)),
                  SizedBox(height: 2),
                  FutureBuilder<int>(
                    future: context.read<ScareCoinStore>().balance(),
                    builder: (context, snap) {
                      return Text(
                        '${snap.data ?? 0}',
                        style: MistralTypography.heading4.copyWith(color: skin.text1, fontWeight: FontWeight.w700),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: skin.text3, size: 14),
          ],
        ),
      ),
    );
  }
}

/// 装备卡片：标题 + 4个装备图标 + 箭头
class _EquipCard extends StatelessWidget {
  final ThemeVars skin;
  const _EquipCard({required this.skin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: skin.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: skin.text1.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text('装备', style: MistralTypography.micro.copyWith(color: skin.text3)),
                      SizedBox(width: 4),
                      Text(
                        '9/9',
                        style: MistralTypography.micro.copyWith(color: skin.accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _equipIcon(Icons.auto_awesome, skin),
                      SizedBox(width: 6),
                      _equipIcon(Icons.menu_book, skin),
                      SizedBox(width: 6),
                      _equipIcon(Icons.headphones, skin),
                      SizedBox(width: 6),
                      _equipIcon(Icons.translate, skin),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: skin.text3, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _equipIcon(IconData icon, ThemeVars skin) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: skin.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, color: skin.accent, size: 15),
    );
  }
}
