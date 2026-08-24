// 由 Claude 团队生成 | Monster Word App

// 外观 & 沉浸场景页：壁纸选择 + 主题切换 + 实时预览
// 还原原版 v3.2 个人中心 → 外观&沉浸场景入口
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                    const SizedBox(height: 20),
                    // 两个大预览卡片（壁纸 + 阅读模式）
                    _buildPreviewCards(skin),
                    const SizedBox(height: 24),
                    // 主题选择圆圈（明亮/深邃/极夜）
                    _buildThemeCircles(skin),
                    const SizedBox(height: 16),
                    // 跟随系统开关
                    _buildFollowSystemRow(skin),
                    const SizedBox(height: 16),
                    // 风格字体
                    _buildSettingRow(skin, '风格字体', '现代简约'),
                    const SizedBox(height: 16),
                    // 沉浸场景
                    _buildSettingRow(skin, '沉浸场景', '未开启'),
                    const SizedBox(height: 32),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
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
              borderRadius: BorderRadius.circular(16),
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
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30, left: 16, right: 16,
                  child: Row(
                    children: [
                      Expanded(child: Container(
                        height: 24, decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: Container(
                        height: 24, decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
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
                        color: Colors.white.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock, size: 18, color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 阅读模式预览卡
        Expanded(
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFD6E6F2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 60, height: 10, decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(4),
                  )),
                  const SizedBox(height: 12),
                  ...List.generate(4, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: themes.values.map((preset) {
          final isSelected = skin.themeId == preset.id;
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
                      color: isSelected ? const Color(0xFFFF6800) : preset.vars.divider,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(Icons.check, color: Color(0xFFFF6800), size: 20),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('跟随系统', style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A))),
          ),
          Switch(
            value: true,
            onChanged: (v) {},
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFE8913A),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE0E0E0),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A))),
          ),
          Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20, color: Color(0xFF999999)),
        ],
      ),
    );
  }
}
