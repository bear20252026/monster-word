// 由 Claude 团队生成 | Monster Word App

// 外观 & 沉浸场景页：主题切换 + 风格字体 + 沉浸场景入口
// （原「壁纸/阅读模式静态预览卡」为纯装饰假卡片，且壁纸系统已随主页方案C移除，于 v2.7.36 删除）
import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_style_grid.dart';

/// 外观 & 沉浸场景页
class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});
  static const routeName = '/appearance';

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: resp.contentWidth),
            child: Column(
              children: [
                // 顶部导航
                _buildNav(skin),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: resp.pageMargin),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: context.design.spacing.lg),
                        // 精选风格（6 选 1：颜色主题 + 设计语言一次绑定）
                        Text(
                          '风格',
                          style: MwTypography.captionBold.copyWith(
                            fontWeight: FontWeight.w600,
                            color: skin.colors.text3,
                          ),
                        ),
                        SizedBox(height: context.design.spacing.sm),
                        const MwStyleGrid(),
                        SizedBox(height: context.design.spacing.md),
                        // 跟随系统开关
                        _buildFollowSystemRow(skin),
                        SizedBox(height: context.design.spacing.md),
                        // 风格字体（可切换，全局生效）
                        _buildFontRow(skin),
                        SizedBox(height: context.design.spacing.md),
                        // 沉浸场景（点击查看使用方法并前往体验）
                        _buildImmersiveRow(skin),
                        SizedBox(height: context.design.spacing.xxl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildNav(SkinSystem skin) {
    return Container(
      height: context.design.spacing.navH,
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                '外观 & 沉浸场景',
                style: MwTypography.bodyBold.copyWith(fontWeight: FontWeight.w600, color: skin.colors.text1),
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  /// 跟随系统开关
  Widget _buildFollowSystemRow(SkinSystem skin) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('跟随系统', style: MwTypography.bodyMd.copyWith(color: skin.colors.text1)),
          ),
          Switch(
            value: skin.followSystem,
            onChanged: (v) => skin.setFollowSystem(v),
            activeThumbColor: AppColors.white100,
            activeTrackColor: skin.colors.accent,
            inactiveThumbColor: AppColors.white100,
            inactiveTrackColor: context.skin.colors.divider,
          ),
        ],
      ),
    );
  }

  static const Map<String, String?> _fontChoices = {
    '现代简约（默认）': null, // Inter
    '经典衬线': 'Charter', // 衬线阅读体
    '系统字体': 'system', // 跟随平台
  };

  /// 风格字体行：点击弹出选择对话框，全局生效并持久化
  Widget _buildFontRow(SkinSystem skin) {
    final current = skin.fontFamilyOverride;
    final currentLabel = _fontChoices.entries
        .firstWhere((e) => e.value == current, orElse: () => _fontChoices.entries.first)
        .key;
    return InkWell(
      borderRadius: BorderRadius.circular(context.design.radius.xl),
      onTap: () => _showFontDialog(context, skin),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.xl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('风格字体', style: MwTypography.bodyMd.copyWith(color: skin.colors.text1)),
            ),
            Text(currentLabel, style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
            SizedBox(width: context.design.spacing.xxs),
            Icon(Icons.chevron_right, size: 20, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }

  void _showFontDialog(BuildContext context, SkinSystem skin) {
    final current = skin.fontFamilyOverride;
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择风格字体'),
        children: [
          RadioGroup<String?>(
            groupValue: current,
            onChanged: (value) {
              if (value != null) skin.setFontFamily(value);
              Navigator.pop(ctx);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _fontChoices.entries.map((entry) {
                return RadioListTile<String?>(
                  value: entry.value,
                  title: Text(entry.key),
                  activeColor: skin.colors.accent,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 沉浸场景行：点击弹窗说明使用方法，可直接前往体验
  Widget _buildImmersiveRow(SkinSystem skin) {
    return InkWell(
      borderRadius: BorderRadius.circular(context.design.radius.xl),
      onTap: () => _showImmersiveSheet(skin),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: skin.colors.cardBg,
          borderRadius: BorderRadius.circular(context.design.radius.xl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('沉浸场景', style: MwTypography.bodyMd.copyWith(color: skin.colors.text1)),
            ),
            Text('点击体验', style: MwTypography.bodySm.copyWith(color: skin.colors.text3)),
            SizedBox(width: context.design.spacing.xxs),
            Icon(Icons.chevron_right, size: 20, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }

  void _showImmersiveSheet(SkinSystem skin) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: skin.colors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '沉浸场景',
                style: MwTypography.heading5.copyWith(fontWeight: FontWeight.bold, color: skin.colors.text1),
              ),
              SizedBox(height: 12),
              Text(
                '全屏滑动式背单词模式：整词卡片左右滑动作答，无界面干扰，'
                '适合快速过词。\n\n入口：课程页 → 「沉浸背单词」，或点击下方按钮直接体验。',
                style: TextStyle(fontSize: 14, height: 1.6, color: skin.colors.text2),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: skin.colors.accent),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, RouteNames.immersiveSwipe);
                  },
                  icon: const Icon(Icons.swipe_up_alt),
                  label: const Text('立即体验'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
