// 个人中心页：星巴克风格 — 奶油画布 + 头像 + 酷币/装备 + 菜单
// batch4a 改造：金色渐变→奶油纯色，硬编码→token，卡片→SbCard
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../pages/appearance_page.dart';
import '../pages/more_settings_page.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/sb_badge.dart';
import '../widgets/sb_card.dart';

// 金色系 token（待提取为全局 StarGold 组，docs/starbucks_tokens_draft.md §4）
const Color _goldCream = Color(0xFFF2F0EB);   // 奶油画布（头部底色）
const Color _goldAccent = Color(0xFFCBA258);   // 品牌金（仅成就）
const Color _goldCoin = Color(0xFFCC8800);     // 酷币图标金

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
      color: _goldCream, // 奶油画布纯色（移除金色渐变）
      child: Column(
        children: [
          // 头像 + VIP 徽章（白框 + 绿色 VIP）
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
                    color: Colors.white, // 纯白底（移除金色渐变）
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: skin.colors.accent, size: 40), // 品牌绿图标
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: skin.colors.accent, // 绿色 VIP 徽章（原 #4A6741 → accent）
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
          // 会员状态（SbBadge 金色胶囊）
          SbBadge(
            text: '成为终身大会员 1379 天',
            icon: Icons.chevron_right,
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(SkinSystem skin, AppResponsive resp, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
      child: SbCard(
        child: Column(children: [
          _menuRow(
            Icons.palette_outlined,
            MistralColors.success, // #4CAF50 → token
            '外观 & 沉浸场景',
            skin,
            onTap: () => Navigator.pushNamed(context, AppearancePage.routeName),
          ),
          Divider(height: 1, color: skin.colors.divider),
          _menuRow(Icons.tune, const Color(0xFF9C27B0), '学习偏好', skin), // 紫色保留（功能色）
          Divider(height: 1, color: skin.colors.divider),
          _menuRow(Icons.settings_outlined, const Color(0xFF2196F3), '更多设置', skin, // 蓝色保留（功能色）
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
    return SbCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                  color: _goldAccent, // 品牌金 #CBA258（仅成就场景）
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monetization_on, color: _goldCoin, size: 18), // 酷币图标金
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
    return SbCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
              // 装备徽章（4组功能色，docs/live_pages_hardcode_map.md §4 装备图标）
              _equipIcon(const Color(0xFFFFE0B2), _goldCoin, Icons.auto_stories),   // 金系
              const SizedBox(width: 6),
              _equipIcon(const Color(0xFFBBDEFB), const Color(0xFF1976D2), Icons.menu_book), // 蓝系
              const SizedBox(width: 6),
              _equipIcon(const Color(0xFFE8F5E9), const Color(0xFF388E3C), Icons.headphones), // 绿系
              const SizedBox(width: 6),
              _equipIcon(const Color(0xFFF3E5F5), const Color(0xFF7B1FA2), Icons.edit), // 紫系
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
