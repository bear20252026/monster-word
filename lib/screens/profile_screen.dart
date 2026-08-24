// 个人中心页：还原原版个人中心 — 金色渐变头部 + 头像 + 酷币/装备 + 菜单
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../pages/appearance_page.dart';
import '../pages/more_settings_page.dart';
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
            // 顶部导航栏（仅消息图标）
            Container(
              height: AppSpacing.navH,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.mail_outline, color: skin.colors.text1, size: 22),
                  onPressed: () {},
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 金色渐变头部区
                    _buildProfileHeader(skin),
                    const SizedBox(height: 20),
                    // 酷币 + 装备卡片
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

  Widget _buildProfileHeader(SkinSystem skin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF3CD),
            Color(0xFFFFF8E1),
            Color(0xFFF5F5F5),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        children: [
          // 头像 + VIP 徽章
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFF3CD), Color(0xFFFFE0B2)],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFCC80).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF8B6914), size: 40),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A6741),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Text('VIP', style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 用户 ID
          Text('44459754',
            style: MistralTypography.heading4.copyWith(color: skin.colors.text1)),
          const SizedBox(height: 10),
          // 会员状态
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8CC).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('成为终身大会员 1379 天',
                  style: MistralTypography.caption.copyWith(
                    color: const Color(0xFFCC8800),
                    fontWeight: FontWeight.w500,
                  )),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCC8800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(SkinSystem skin, AppResponsive resp, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: Container(
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          _menuRow(
            Icons.palette_outlined,
            const Color(0xFF4CAF50),
            '外观 & 沉浸场景',
            skin,
            onTap: () => Navigator.pushNamed(context, AppearancePage.routeName),
          ),
          Divider(height: 1, color: skin.colors.divider),
          _menuRow(Icons.tune, const Color(0xFF9C27B0), '学习偏好', skin),
          Divider(height: 1, color: skin.colors.divider),
          _menuRow(Icons.settings_outlined, const Color(0xFF2196F3), '更多设置', skin,
            onTap: () => Navigator.pushNamed(context, MoreSettingsPage.routeName)),
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
          Expanded(child: Text(label,
            style: MistralTypography.bodyMd.copyWith(color: skin.colors.text1))),
          Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
        ]),
      ),
    );
  }
}

/// 酷币卡片
class _CoinCard extends StatelessWidget {
  final SkinSystem skin;
  const _CoinCard({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('酷币', style: MistralTypography.bodyMd.copyWith(
                color: skin.colors.text1, fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(Icons.chevron_right, color: skin.colors.text3, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFCC80),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monetization_on, color: Color(0xFFCC8800), size: 18),
              ),
              const SizedBox(width: 8),
              Text('6,821', style: MistralTypography.heading4.copyWith(
                color: skin.colors.text1, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('装备', style: MistralTypography.bodyMd.copyWith(
                color: skin.colors.text1, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text('9/9', style: MistralTypography.caption.copyWith(
                color: skin.colors.text3)),
              const Spacer(),
              Icon(Icons.chevron_right, color: skin.colors.text3, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _equipIcon(const Color(0xFFFFE0B2), const Color(0xFFCC8800), Icons.auto_stories),
              const SizedBox(width: 6),
              _equipIcon(const Color(0xFFBBDEFB), const Color(0xFF1976D2), Icons.menu_book),
              const SizedBox(width: 6),
              _equipIcon(const Color(0xFFE8F5E9), const Color(0xFF388E3C), Icons.headphones),
              const SizedBox(width: 6),
              _equipIcon(const Color(0xFFF3E5F5), const Color(0xFF7B1FA2), Icons.edit),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: fg, size: 16),
    );
  }
}
