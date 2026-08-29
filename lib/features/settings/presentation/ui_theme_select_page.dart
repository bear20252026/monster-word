// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 UIThemeSelectActivity
// 主题选择：切换应用主题/皮肤
import 'package:flutter/material.dart';

import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';

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
                padding: EdgeInsets.all(16),
                children: [
                  // 跟随系统开关
                  _buildFollowSystemToggle(context, skin),
                  SizedBox(height: 16),
                  // 动态渲染所有可用主题
                  ...skin.availableThemes.map((theme) {
                    final isSelected = skin.themeId == theme.id && !skin.followSystem;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _buildThemeOption(
                        context: context,
                        skin: skin,
                        name: theme.name,
                        description: _themeDescription(theme.id),
                        colors: theme.previewColors,
                        isSelected: isSelected,
                        onTap: () => skin.setTheme(theme.id),
                      ),
                    );
                  }),
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
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4),
          Text('主题设置', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  /// 跟随系统开关
  Widget _buildFollowSystemToggle(BuildContext context, SkinSystem skin) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: skin.colors.cardBgAlt, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.brightness_6, color: skin.colors.accent),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('跟随系统', style: MistralTypography.body.copyWith(color: skin.colors.text1)),
                Text('根据系统深色/浅色自动切换', style: MistralTypography.caption.copyWith(color: skin.colors.text2)),
              ],
            ),
          ),
          Switch(
            value: skin.followSystem,
            onChanged: (v) => skin.setFollowSystem(v),
            activeThumbColor: skin.colors.accent,
          ),
        ],
      ),
    );
  }

  /// 主题描述文字
  String _themeDescription(String id) {
    switch (id) {
      case 'starbucks_cream':
        return '星巴克绿，奶油画布，温暖咖啡感';
      case 'starbucks_dark':
        return '深绿夜空，沉浸式学习';
      case 'bright':
        return 'Mistral AI 风格，清爽明亮';
      case 'dark':
        return '护眼深色，夜间友好';
      case 'pure_black':
        return '纯黑模式，OLED 省电';
      case 'warm_orange':
        return '暖阳橙，活力温暖，适合日间';
      default:
        return '';
    }
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
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: skin.colors.cardBgAlt,
          borderRadius: BorderRadius.circular(context.design.radius.lg),
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
                borderRadius: BorderRadius.circular(context.design.radius.md),
                gradient: LinearGradient(colors: colors),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
                  Text(description, style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: MistralColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
