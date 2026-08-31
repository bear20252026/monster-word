// 由 Claude 团队生成 | Monster Word App

// 更多设置页：账号信息 / 壁纸随动 / 帮助反馈 / 评价应用 / 检查更新 / 推荐好友 / 兑换中心 / 举报 / 协议
// 还原原版 v3.2 个人中心 → 更多设置入口
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/auth/app_session_controller.dart';
import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/core/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_button.dart';
import 'package:word_app/widgets/mw_modal.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';

/// 更多设置页
class MoreSettingsPage extends StatefulWidget {
  const MoreSettingsPage({super.key});
  static const routeName = '/more_settings';

  @override
  State<MoreSettingsPage> createState() => _MoreSettingsPageState();
}

class _MoreSettingsPageState extends State<MoreSettingsPage> {
  bool _wallpaperParallax = true;

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature 功能即将上线'), duration: const Duration(seconds: 1)));
  }

  /// 评价应用弹窗（5星评分）
  void _showRatingDialog(BuildContext context) {
    int rating = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.skin.colors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 36)),
              SizedBox(height: 8),
              Text('给个好评吧！', style: MistralTypography.heading5.copyWith(color: context.skin.colors.text1)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('您的支持是我们前进的动力', style: MistralTypography.body.copyWith(color: context.skin.colors.text2)),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => rating = i + 1),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFC107),
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: context.skin.colors.text3)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.skin.colors.accent,
                foregroundColor: context.skin.colors.onGlassAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: rating == 0
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('感谢您的 $rating 星好评！⭐'), backgroundColor: context.skin.colors.success),
                      );
                    },
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  /// 检查更新弹窗
  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.skin.colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 36)),
            SizedBox(height: 8),
            Text('已是最新版本', style: MistralTypography.heading5.copyWith(color: context.skin.colors.text1)),
          ],
        ),
        content: Text(
          '当前版本 v5.11.1 已是最新，无需更新',
          style: MistralTypography.body.copyWith(color: context.skin.colors.text2),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.skin.colors.accent,
              foregroundColor: context.skin.colors.onGlassAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 词库全量覆盖重建：确认 → 执行（不可取消的进度弹窗）→ 完整性结果
  Future<void> _showRebuildWordbookDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更新词库数据'),
        content: const Text(
          '将以最新词库完整覆盖本地数据（约 133MB，需数秒），'
          '本地旧词库数据将被全部替换，且不影响学习进度。确定继续吗？',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('立即重建')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // 不可取消的进度弹窗
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
      ),
    );

    DbRebuildResult result;
    try {
      result = await WordBookDatabase.instance.forceRebuild();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('词库重建失败: $e')));
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      unawaited(
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              result.success ? Icons.check_circle_outline : Icons.error_outline,
              color: result.success ? Colors.green : Colors.red,
              size: 48,
            ),
            title: Text(result.success ? '更新成功' : '更新失败'),
            content: Text('${result.books} 本词书 / ${result.words} 词条 / ${result.links} 条关联\n\n${result.message}'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('好的'))],
          ),
        ),
      );
    }
  }

  /// 分享给好友弹窗（宣传海报）
  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.skin.colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 宣传海报
            Container(
              width: 200,
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.skin.colors.accent, context.skin.colors.accent.withValues(alpha: 0.7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('👹', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    'Monster Word',
                    style: MistralTypography.heading5.copyWith(color: context.skin.colors.onGlassAccent),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '背单词，so easy！',
                    style: MistralTypography.bodySm.copyWith(
                      color: context.skin.colors.onGlassAccent.withValues(alpha: 0.9),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.skin.colors.onGlassAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('扫码下载', style: MistralTypography.micro.copyWith(color: context.skin.colors.accent)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text('扫码下载 Monster Word', style: MistralTypography.body.copyWith(color: context.skin.colors.text2)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('关闭', style: TextStyle(color: context.skin.colors.text3)),
          ),
        ],
      ),
    );
  }

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
                padding: EdgeInsets.symmetric(horizontal: resp.pageMargin, vertical: context.design.spacing.md),
                children: [
                  // 账号信息
                  _SettingGroup([
                    _Cell(
                      icon: Icons.person_outline,
                      iconColor: skin.colors.accent,
                      title: '账号信息',
                      subtitle: '点击设置',
                      onTap: () => Navigator.pushNamed(context, RouteNames.accountInfo),
                    ),
                  ]),
                  SizedBox(height: context.design.spacing.md),

                  // 主页壁纸随动
                  _SettingGroup([
                    _SwitchCell(
                      icon: Icons.wallpaper,
                      iconColor: MistralColors.link,
                      title: '主页壁纸随动',
                      subtitle: '壁纸随设备陀螺仪轻微移动',
                      value: _wallpaperParallax,
                      onChanged: (v) => setState(() => _wallpaperParallax = v),
                    ),
                  ]),
                  SizedBox(height: context.design.spacing.md),

                  // 帮助与反馈 / 评价应用 / 检查更新 / 推荐给好友
                  _SettingGroup([
                    _Cell(
                      icon: Icons.help_outline,
                      iconColor: MistralColors.success,
                      title: '帮助与反馈',
                      onTap: () => Navigator.pushNamed(context, RouteNames.feedback),
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.star_outline,
                      iconColor: MistralColors.warning,
                      title: '评价应用',
                      subtitle: 'v5.11.1',
                      onTap: () => _showRatingDialog(context),
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.system_update_outlined,
                      iconColor: MistralColors.link,
                      title: '检查更新',
                      onTap: () => _showUpdateDialog(context),
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.storage_outlined,
                      iconColor: MistralColors.link,
                      title: '更新词库数据',
                      subtitle: '全量覆盖重建本地词库（含全部词条与索引）',
                      onTap: () => _showRebuildWordbookDialog(context),
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.share_outlined,
                      iconColor: MistralColors.ink,
                      title: '推荐给好友',
                      onTap: () => _showShareDialog(context),
                    ),
                  ]),
                  SizedBox(height: context.design.spacing.md),

                  // 兑换中心 / 举报
                  _SettingGroup([
                    _Cell(
                      icon: Icons.redeem_outlined,
                      iconColor: MistralColors.primary,
                      title: '兑换中心',
                      onTap: () => Navigator.pushNamed(context, RouteNames.redemption),
                    ),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.flag_outlined,
                      iconColor: MistralColors.danger,
                      title: '违法不良信息举报',
                      onTap: () => _showComingSoon('举报'),
                    ),
                  ]),
                  SizedBox(height: context.design.spacing.md),

                  // 服务条款 / 隐私协议
                  _SettingGroup([
                    _Cell(icon: Icons.description_outlined, iconColor: skin.colors.text3, title: '服务条款', onTap: () {}),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(icon: Icons.privacy_tip_outlined, iconColor: skin.colors.text3, title: '隐私协议', onTap: () {}),
                    Divider(height: 1, color: skin.colors.divider, indent: 52),
                    _Cell(
                      icon: Icons.info_outline,
                      iconColor: skin.colors.text3,
                      title: '关于我们',
                      subtitle: 'v5.11.1',
                      onTap: () {},
                    ),
                  ]),
                  SizedBox(height: context.design.spacing.xxl),

                  // 退出登录
                  SizedBox(
                    width: double.infinity,
                    child: MwButton.outlined(
                      label: '退出登录',
                      onTap: () => _showLogoutSheet(context),
                      borderSide: BorderSide(color: skin.colors.danger, width: 1),
                      textColor: skin.colors.danger,
                    ),
                  ),
                  SizedBox(height: context.design.spacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 退出登录确认弹窗（MwModal 底部弹出）
  void _showLogoutSheet(BuildContext context) {
    MwModal.show(
      context,
      mode: MwModalMode.bottom,
      title: '退出登录',
      child: Text(
        '确定要退出登录吗？退出后学习数据将保留在本地，但同步功能将不可用。',
        style: MistralTypography.bodyMd.copyWith(color: context.skin.colors.text2),
      ),
      actions: [
        MwButton.outlined(label: '取消', onTap: () => Navigator.pop(context)),
        MwButton(
          label: '退出',
          onTap: () {
            Navigator.pop(context);
            context.read<AppSessionController>().logout();
          },
          fillColor: context.skin.colors.danger,
        ),
      ],
    );
  }

  Widget _buildNav(SkinSystem skin) {
    return Container(
      height: context.design.spacing.navH,
      padding: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        border: Border(bottom: BorderSide(color: skin.colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => NavUtils.safePop(context),
          ),
          SizedBox(width: 4),
          Text('更多设置', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
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
        borderRadius: BorderRadius.circular(context.design.radius.lg),
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

  const _Cell({required this.icon, required this.iconColor, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return ScaleDownOnPress(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: context.design.spacing.md),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            SizedBox(width: context.design.spacing.sm),
            Expanded(
              child: Text(title, style: MistralTypography.bodyMd.copyWith(color: skin.text1)),
            ),
            if (subtitle != null)
              Padding(
                padding: EdgeInsets.only(right: context.design.spacing.xs),
                child: Text(subtitle!, style: MistralTypography.bodySm.copyWith(color: skin.text3)),
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
      padding: EdgeInsets.symmetric(horizontal: context.design.spacing.md),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          SizedBox(width: context.design.spacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MistralTypography.bodyMd.copyWith(color: skin.text1)),
                if (subtitle != null) Text(subtitle!, style: MistralTypography.micro.copyWith(color: skin.text3)),
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
