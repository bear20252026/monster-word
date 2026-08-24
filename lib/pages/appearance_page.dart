// 由 Claude 团队生成 | Monster Word App

// 外观 & 沉浸场景页：壁纸选择 + 主题切换 + 实时预览
// 还原原版 v3.2 个人中心 → 外观&沉浸场景入口
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

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
                    const SizedBox(height: AppleSpacing.lg),
                    // 两个大预览卡片（壁纸 + 阅读模式）
                    _buildPreviewCards(skin),
                    const SizedBox(height: AppleSpacing.xl),
                    // 主题选择圆圈（明亮/深邃/极夜）
                    _buildThemeCircles(skin),
                    const SizedBox(height: AppleSpacing.md),
                    // 跟随系统开关
                    _buildFollowSystemRow(skin),
                    const SizedBox(height: AppleSpacing.md),
                    // 风格字体
                    _buildSettingRow(skin, '风格字体', '现代简约'),
                    const SizedBox(height: AppleSpacing.md),
                    // 沉浸场景
                    _buildSettingRow(skin, '沉浸场景', '未开启'),
                    const SizedBox(height: AppleSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildNav(SkinSystem skin) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text('外观 & 沉浸场景',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: skin.colors.text1)),
            ),
          ),
          const SizedBox(width: 48),
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
              borderRadius: BorderRadius.circular(AppRadius.xl),
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
                  top: 40, left: 20, right: 20,
                  child: Container(
                    height: 30, decoration: BoxDecoration(
                      color: AppColors.white100.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30, left: 16, right: 16,
                  child: Row(
                    children: [
                      Expanded(child: Container(
                        height: 24, decoration: BoxDecoration(
                          color: AppColors.white100.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      )),
                      const SizedBox(width: AppleSpacing.xs),
                      Expanded(child: Container(
                        height: 24, decoration: BoxDecoration(
                          color: AppColors.white100.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      )),
                    ],
                  ),
                ),
                // 锁图标
                Positioned(
                  top: 80, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      width: 36, height: 36,
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
        const SizedBox(width: AppleSpacing.sm),
        // 阅读模式预览卡
        Expanded(
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              color: skin.colors.cardBgAlt,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 60, height: 10, decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(AppRadius.xs),
                  )),
                  const SizedBox(height: AppleSpacing.sm),
                  ...List.generate(4, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                  )),
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
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
                  child: isSelected
                      ? Center(
                          child: Icon(Icons.check, color: skin.colors.accent, size: 20),
                        )
                      : null,
                ),
                const SizedBox(height: AppleSpacing.xs),
                Text(preset.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? skin.colors.text1 : skin.colors.text3,
                  )),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
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

  /// 设置行
  Widget _buildSettingRow(SkinSystem skin, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 16, color: skin.colors.text1)),
          ),
          Text(value, style: TextStyle(fontSize: 14, color: skin.colors.text3)),
          const SizedBox(width: AppleSpacing.xxs),
          Icon(Icons.chevron_right, size: 20, color: skin.colors.text3),
        ],
      ),
    );
  }
}
