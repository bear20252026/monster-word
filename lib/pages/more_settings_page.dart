// 由 Claude 团队生成 | Monster Word App

// 更多设置页：账号信息 / 壁纸随动 / 帮助反馈 / 评价应用 / 检查更新 / 推荐好友 / 兑换中心 / 举报 / 协议
// 还原原版 v3.2 个人中心 → 更多设置入口
import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_modal.dart';
import '../widgets/scale_down_on_press.dart';

/// 更多设置页
class MoreSettingsPage extends StatefulWidget {
  const MoreSettingsPage({super.key});
  static const routeName = '/more_settings';

  @override
  State<MoreSettingsPage> createState() => _MoreSettingsPageState();
}

class _MoreSettingsPageState extends State<MoreSettingsPage> {
  bool _wallpaperParallax = true;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final resp = context.responsive;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNav(skin),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                    horizontal: resp.pageMargin, vertical: AppleSpacing.md),
                children: [
                  // 账号信息
                  _SettingGroup([
                    _Cell(
                      icon: Icons.person_outline,
                      iconColor: skin.colors.accent,
                      title: '账号信息',
                      subtitle: '点击设置',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: AppleSpacing.md),

                  // 主页壁纸随动
                  _SettingGroup([
                    _SwitchCell(
                      icon: Icons.wallpaper,
                      iconColor: MistralColors.link,
                      title: '主页壁纸随动',
                      subtitle: '壁纸随设备陀螺仪轻微移动',
                      value: _wallpaperParallax,
                      onChanged: (v) =>
                          setState(() => _wallpaperParallax = v),
                    ),
                  ]),
                  const SizedBox(height: AppleSpacing.md),

                  // 帮助与反馈 / 评价应用 / 检查更新 / 推荐给好友
                  _SettingGroup([
                    _Cell(
                      icon: Icons.help_outline,
                      iconColor: MistralColors.success,
                      title: '帮助与反馈',
                      onTap: () {},
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.star_outline,
                      iconColor: MistralColors.warning,
                      title: '评价应用',
                      subtitle: 'v5.11.1',
                      onTap: () {},
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.system_update_outlined,
                      iconColor: MistralColors.link,
                      title: '检查更新',
                      onTap: () {},
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.share_outlined,
                      iconColor: MistralColors.ink,
                      title: '推荐给好友',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: AppleSpacing.md),

                  // 兑换中心 / 举报
                  _SettingGroup([
                    _Cell(
                      icon: Icons.redeem_outlined,
                      iconColor: MistralColors.primary,
                      title: '兑换中心',
                      onTap: () {},
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.flag_outlined,
                      iconColor: MistralColors.danger,
                      title: '违法不良信息举报',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: AppleSpacing.md),

                  // 服务条款 / 隐私协议
                  _SettingGroup([
                    _Cell(
                      icon: Icons.description_outlined,
                      iconColor: skin.colors.text3,
                      title: '服务条款',
                      onTap: () {},
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: skin.colors.text3,
                      title: '隐私协议',
                      onTap: () {},
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.info_outline,
                      iconColor: skin.colors.text3,
                      title: '关于我们',
                      subtitle: 'v5.11.1',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: AppleSpacing.xxl),

                  // 退出登录
                  SizedBox(
                    width: double.infinity,
                    child: SbButton.outlined(
                      label: '退出登录',
                      onTap: () => _showLogoutSheet(context),
                      borderSide: BorderSide(color: skin.colors.danger, width: 1),
                      textColor: skin.colors.danger,
                    ),
                  ),
                  const SizedBox(height: AppleSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 退出登录确认弹窗（SbModal 底部弹出）
  void _showLogoutSheet(BuildContext context) {
    SbModal.show(
      context,
      mode: SbModalMode.bottom,
      title: '退出登录',
      child: Text(
        '确定要退出登录吗？退出后学习数据将保留在本地，但同步功能将不可用。',
        style: MistralTypography.bodyMd.copyWith(
          color: context.skin.colors.text2,
        ),
      ),
      actions: [
        SbButton.outlined(
          label: '取消',
          onTap: () => Navigator.pop(context),
        ),
        SbButton(
          label: '退出',
          onTap: () {
            Navigator.pop(context);
            // TODO: 执行退出登录逻辑
          },
          fillColor: context.skin.colors.danger,
        ),
      ],
    );
  }

  Widget _buildNav(SkinSystem skin) {
    return Container(
      height: AppSpacing.navH,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        border: Border(
            bottom: BorderSide(color: skin.colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('更多设置',
              style: MistralTypography.heading5
                  .copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}

// =============================================================================
// 通用组件
// =============================================================================

/// 设置项分组（ContentCard 风格：12px 圆角 + 双层低透明阴影）
class _SettingGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingGroup(this.children);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      decoration: BoxDecoration(
        color: skin.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(offset: Offset.zero, blurRadius: 0.5, color: Color(0x24000000)),
          BoxShadow(offset: Offset(0, 1), blurRadius: 1, color: Color(0x3D000000)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

/// 普通设置项（图标 + 标题 + 副标题 + 箭头）
class _Cell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _Cell({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return ScaleDownOnPress(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppleSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: AppleSpacing.sm),
            Expanded(
              child: Text(title,
                  style:
                      MistralTypography.bodyMd.copyWith(color: skin.text1)),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(right: AppleSpacing.xs),
                child: Text(subtitle!,
                    style: MistralTypography.bodySm
                        .copyWith(color: skin.text3)),
              ),
            Icon(Icons.chevron_right, size: 18, color: skin.text3),
          ],
        ),
      ),
    );
  }
}

/// 开关设置项（图标 + 标题 + 副标题 + Switch）
class _SwitchCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchCell({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppleSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: AppleSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: MistralTypography.bodyMd
                        .copyWith(color: skin.text1)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: MistralTypography.micro
                          .copyWith(color: skin.text3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.white100,
            activeTrackColor: skin.accent,
            inactiveThumbColor: AppColors.white100,
            inactiveTrackColor: skin.text3,
          ),
        ],
      ),
    );
  }
}
