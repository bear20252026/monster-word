// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 PersonalStereoActivity
// 随身听：碎片时间听记单词
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class PersonalStereoPage extends StatelessWidget {
  const PersonalStereoPage({super.key});

  static const routeName = '/personal_stereo';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    void showDevToast() {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('随身听功能开发中...'), duration: Duration(seconds: 1)));
    }

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, context),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPlayerCard(skin, showDevToast),
                    const SizedBox(height: 24),
                    _buildMenuCard(
                      skin: skin,
                      icon: Icons.play_circle_outline,
                      title: '今日已学单词',
                      subtitle: '巩固今天学习的单词',
                      onTap: () {
                        // TODO: 播放今日已学单词
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      skin: skin,
                      icon: Icons.replay,
                      title: '复习中单词',
                      subtitle: '播放正在复习的单词',
                      onTap: () {
                        // TODO: 播放复习中单词
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      skin: skin,
                      icon: Icons.fiber_new,
                      title: '生词本',
                      subtitle: '播放生词本中的单词',
                      onTap: () {
                        // TODO: 播放生词本
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      skin: skin,
                      icon: Icons.shuffle,
                      title: '播放顺序',
                      subtitle: '设置单词播放顺序',
                      onTap: () => Navigator.pushNamed(context, '/play_order'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('随身听', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(SkinSystem skin, VoidCallback onDevTap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [MistralColors.cream, MistralColors.creamDeeper]),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          Icon(Icons.headphones, size: 64, color: MistralColors.primary),
          const SizedBox(height: 16),
          Text('随身听模式', style: MistralTypography.heading4.copyWith(color: MistralColors.ink)),
          const SizedBox(height: 8),
          Text('碎片时间也能听记单词', style: MistralTypography.body.copyWith(color: MistralColors.slate)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous, color: MistralColors.ink, size: 32),
                tooltip: '上一首',
                onPressed: onDevTap,
              ),
              const SizedBox(width: 16),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle, color: MistralColors.primary),
                child: IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                  tooltip: '播放',
                  onPressed: onDevTap,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.skip_next, color: MistralColors.ink, size: 32),
                tooltip: '下一首',
                onPressed: onDevTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required SkinSystem skin,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: skin.colors.cardBgAlt,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: skin.colors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: MistralColors.cream, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(icon, color: MistralColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
                  Text(subtitle, style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}
