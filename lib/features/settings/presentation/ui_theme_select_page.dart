// 由 Claude 团队生成 | Monster Word App

// 主题选择：精选风格 6 选 1（与其他换肤入口共用 MwStyleGrid，展示一致）
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_style_grid.dart';

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
                  // 精选风格网格（唯一风格事实来源）
                  const MwStyleGrid(),
                  SizedBox(height: 24),
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
          Text('主题设置', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
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
                Text('跟随系统', style: MwTypography.body.copyWith(color: skin.colors.text1)),
                Text('根据系统深色/浅色自动切换', style: MwTypography.caption.copyWith(color: skin.colors.text2)),
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
}
