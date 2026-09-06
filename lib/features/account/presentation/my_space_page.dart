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
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/widgets/mw_list_row.dart';
import 'package:word_app/widgets/mw_section_header.dart';
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
                  MwColors.sunshine300.withValues(alpha: 0.35),
                  MwColors.sunshine500.withValues(alpha: 0.08),
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

  /// 品牌头像与用户信息：手机/桌面共用同一套组件，避免两套布局漂移。
  Widget _buildProfileHeader(BuildContext context, ThemeVars skin, AccountProfileState profile) {
    final resp = context.responsive;
    final identity = Column(
      crossAxisAlignment: resp.isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
          style: TextStyle(
            fontFamily: 'Charter',
            fontSize: 22,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.3,
            color: skin.text1,
          ),
        ),
        const SizedBox(height: 5),
        Text('在词海里，持续成为更好的自己', style: MwTypography.caption.copyWith(color: skin.text3)),
      ],
    );

    final avatar = Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: skin.accent.withValues(alpha: 0.10),
        border: Border.all(color: skin.accent.withValues(alpha: 0.22), width: 1),
      ),
      child: const MonsterAvatar(size: 62),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: resp.isDesktop
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [avatar, const SizedBox(width: 18), identity])
          : Column(children: [avatar, const SizedBox(height: 12), identity]),
    );
  }

  /// 菜单列表：统一使用共享列表行，视觉与设置页/我的内容页一致。
  Widget _buildMenuList(BuildContext context, dynamic skin) {
    final resp = context.responsive;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(resp.isWide ? 24 : 20, 8, resp.isWide ? 24 : 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MwSectionHeader(title: '空间设置'),
          const SizedBox(height: 12),
          MwListGroup(
            children: [
              MwListRow(
                icon: Icons.palette_outlined,
                iconColor: skin.accent,
                title: '外观 & 沉浸场景',
                subtitle: '主题、字体与沉浸学习',
                onTap: () => Navigator.pushNamed(context, RouteNames.appearance),
              ),
              MwListRow(
                icon: Icons.school_outlined,
                iconColor: skin.success,
                title: '学习偏好',
                subtitle: '发音、节奏与题型',
                onTap: () => Navigator.pushNamed(context, RouteNames.settings),
              ),
              MwListRow(
                icon: Icons.tune_rounded,
                iconColor: skin.teal,
                title: '更多设置',
                subtitle: '账号、通知与关于',
                onTap: () => Navigator.pushNamed(context, RouteNames.moreSettings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
