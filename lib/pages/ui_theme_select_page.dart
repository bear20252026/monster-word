// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 UIThemeSelectActivity
// 主题选择：切换应用主题/皮肤
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class UIThemeSelectPage extends StatelessWidget {
  const UIThemeSelectPage({super.key});

  static const routeName = '/theme_select';

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, context),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildThemeOption(
                    context: context,
                    skin: skin,
                    name: '明亮',
                    description: 'Mistral AI 风格，奶油暖色调',
                    colors: [MistralColors.cream, MistralColors.primary],
                    isSelected: skin.themeId == 'bright',
                    onTap: () => skin.setTheme('bright'),
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    context: context,
                    skin: skin,
                    name: '深邃',
                    description: '护眼深色主题',
                    colors: [MistralColors.charcoal, const Color(0xFF3A3A3A)],
                    isSelected: skin.themeId == 'dark',
                    onTap: () => skin.setTheme('dark'),
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    context: context,
                    skin: skin,
                    name: '极夜',
                    description: '纯黑模式，OLED 友好',
                    colors: [MistralColors.surfaceCode, const Color(0xFF2C2C2E)],
                    isSelected: skin.themeId == 'pure_black',
                    onTap: () => skin.setTheme('pure_black'),
                  ),
                ],
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
          Text('主题设置', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required SkinSystem skin,
    required String name,
    required String description,
    required List<Color> colors,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: skin.colors.cardBgAlt,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? MistralColors.primary : skin.colors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 预览色块
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                gradient: LinearGradient(colors: colors),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
                  Text(description, style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: MistralColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
