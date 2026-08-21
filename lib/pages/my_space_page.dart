// 由账号4生成
// 我的空间页：1:1 复刻原版 activity_my_space.xml
// 结构：顶部导航 + 头像区(88dp) + 昵称 + 会员入口 + 消息中心/装备/酷币/Coolab 卡片
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'settings_page.dart';

class MySpacePage extends StatelessWidget {
  const MySpacePage({super.key});

  static const routeName = '/my_space';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 顶部导航栏（原版 CustomHeadView：左箭头 + 设置按钮）=====
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.black87,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 22),
                    color: AppColors.black87,
                    onPressed: () =>
                        Navigator.pushNamed(context, SettingsPage.routeName),
                  ),
                ],
              ),
            ),
            // ===== 头像区（原版 user_info_container：88dp 头像 + 昵称）=====
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.mainBgTop, AppColors.mainBgBottom],
                      ),
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '未登录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 会员入口（原版 super_member_container）
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 18, color: Color(0xFFF9A825)),
                        SizedBox(width: 4),
                        Text(
                          '开通终身大会员',
                          style: TextStyle(fontSize: 12, color: Color(0xFFF9A825)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // ===== 卡片区（原版 top_cell_container：消息中心/装备/酷币/Coolab）=====
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.pageCommonMargin),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppDimens.pageCommonMargin,
                  crossAxisSpacing: AppDimens.pageCommonMargin,
                  childAspectRatio: 2.4,
                  children: const [
                    _LableCard(icon: Icons.mail_outline, title: '消息中心'),
                    _LableCard(icon: Icons.card_giftcard, title: '装备'),
                    _LableCard(icon: Icons.monetization_on_outlined, title: '酷币'),
                    _LableCard(icon: Icons.science_outlined, title: 'Coolab'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片（复刻原版 LableCardStyle1View）
class _LableCard extends StatelessWidget {
  final IconData icon;
  final String title;
  const _LableCard({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppDimens.radiusNormal),
        border: Border.all(color: AppColors.dividerGrey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.successGreen, size: 28),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
