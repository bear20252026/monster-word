// 由 Claude 团队生成 | Monster Word App

// 外观 & 沉浸场景页：壁纸选择 + 主题切换 + 实时预览
// 还原原版 v3.2 个人中心 → 外观&沉浸场景入口
import 'package:flutter/material.dart';

import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

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
                        // 两个大预览卡片（壁纸 + 阅读模式）
                        _buildPreviewCards(skin),
                        SizedBox(height: context.design.spacing.xl),
                        // 主题选择圆圈（明亮/深邃/极夜）
                        _buildThemeCircles(skin),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.colors.text1),
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  /// 两个大预览卡片
  Widget _buildPreviewCards(SkinSystem skin) {
    return Row(
      children: [
        // 壁纸预览卡
        Expanded(
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.design.radius.xl),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF87CEEB), Color(0xFFB0C4DE), Color(0xFFF5F5F5)],
              ),
            ),
            child: Stack(
              children: [
                // 模拟壁纸内容
                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.white100.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(context.design.radius.md),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.white100.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(context.design.radius.sm),
                          ),
                        ),
                      ),
                      SizedBox(width: context.design.spacing.xs),
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.white100.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(context.design.radius.sm),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 锁图标
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.white100.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock, size: 18, color: skin.colors.text3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: context.design.spacing.sm),
        // 阅读模式预览卡
        Expanded(
          child: Container(
            height: 220,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(context.design.radius.xl), color: skin.colors.cardBgAlt),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(context.design.radius.xs),
                    ),
                  ),
                  SizedBox(height: context.design.spacing.sm),
                  ...List.generate(
                    4,
                    (i) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.white100.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(context.design.radius.xs),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 主题选择圆圈
  Widget _buildThemeCircles(SkinSystem skin) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: skin.colors.cardBg, borderRadius: BorderRadius.circular(context.design.radius.xl)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: themes.values.map((preset) {
          final isSelected = skin.effectiveThemeId == preset.id;
          return GestureDetector(
            onTap: () => skin.setTheme(preset.id),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: preset.vars.pageBg,
                    border: Border.all(
                      color: isSelected ? skin.colors.accent : preset.vars.divider,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected ? Center(child: Icon(Icons.check, color: skin.colors.accent, size: 20)) : null,
                ),
                SizedBox(height: context.design.spacing.xs),
                Text(
                  preset.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? skin.colors.text1 : skin.colors.text3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 跟随系统开关
  Widget _buildFollowSystemRow(SkinSystem skin) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: skin.colors.cardBg, borderRadius: BorderRadius.circular(context.design.radius.xl)),
      child: Row(
        children: [
          Expanded(
            child: Text('跟随系统', style: TextStyle(fontSize: 16, color: skin.colors.text1)),
          ),
          Switch(
            value: skin.followSystem,
            onChanged: (v) => skin.setFollowSystem(v),
            activeThumbColor: AppColors.white100,
            activeTrackColor: skin.colors.accent,
            inactiveThumbColor: AppColors.white100,
            inactiveTrackColor: MistralColors.hairline,
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
        decoration: BoxDecoration(color: skin.colors.cardBg, borderRadius: BorderRadius.circular(context.design.radius.xl)),
        child: Row(
          children: [
            Expanded(
              child: Text('风格字体', style: TextStyle(fontSize: 16, color: skin.colors.text1)),
            ),
            Text(currentLabel, style: TextStyle(fontSize: 14, color: skin.colors.text3)),
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
        decoration: BoxDecoration(color: skin.colors.cardBg, borderRadius: BorderRadius.circular(context.design.radius.xl)),
        child: Row(
          children: [
            Expanded(
              child: Text('沉浸场景', style: TextStyle(fontSize: 16, color: skin.colors.text1)),
            ),
            Text('点击体验', style: TextStyle(fontSize: 14, color: skin.colors.text3)),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: skin.colors.text1),
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
