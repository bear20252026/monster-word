// 由 Claude 团队生成 | Monster Word App

// 更多设置页：账号信息 / 壁纸随动 / 帮助反馈 / 评价应用 / 检查更新 / 推荐好友 / 兑换中心 / 举报 / 协议
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/auth/app_session_controller.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/core/application/wordbook_maintenance_service.dart';
import 'package:word_app/features/settings/application/update_check_service.dart';
import 'package:word_app/features/settings/data/github_update_check_service.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/mw_button.dart';
import 'package:word_app/widgets/mw_modal.dart';
import 'package:word_app/widgets/scale_down_on_press.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:word_app/tokens/func_colors.dart';

/// 更多设置页
class MoreSettingsPage extends StatefulWidget {
  const MoreSettingsPage({super.key, this.updateServiceOverride});

  final UpdateCheckService? updateServiceOverride;

  static const routeName = '/more_settings';

  @override
  State<MoreSettingsPage> createState() => _MoreSettingsPageState();
}

class _MoreSettingsPageState extends State<MoreSettingsPage> {
  bool _isCheckingUpdate = false;

  /// 真实应用版本号（package_info_plus；替换原硬编码 v5.11.1）。
  String _appVersion = '';

  UpdateCheckService get _updateService => widget.updateServiceOverride ?? GithubUpdateCheckService();

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _appVersion = info.version);
        })
        .catchError((e) => debugPrint('读取应用版本失败: $e'));
  }

  /// 违法不良信息举报：展示官方举报渠道（中央网信办 12377 / 公安 110 / 应用内反馈）。
  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.skin.colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Text('🚩', style: TextStyle(fontSize: 36)),
            SizedBox(height: 8),
            Text('举报渠道', style: MwTypography.heading5.copyWith(color: context.skin.colors.text1)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('如发现违法和不良信息，可通过以下官方渠道举报：', style: MwTypography.bodySm.copyWith(color: context.skin.colors.text2)),
            SizedBox(height: 12),
            _reportChannel('中央网信办举报中心', '电话 12377 · 官网 www.12377.cn'),
            SizedBox(height: 8),
            _reportChannel('公安报警', '电话 110'),
            SizedBox(height: 8),
            _reportChannel('应用内问题反馈', '帮助与反馈入口'),
          ],
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

  Widget _reportChannel(String title, String detail) {
    final skin = context.skin.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('· ', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MwTypography.bodySm.copyWith(color: skin.text1, fontWeight: FontWeight.w600),
              ),
              Text(detail, style: MwTypography.caption.copyWith(color: skin.text3)),
            ],
          ),
        ),
      ],
    );
  }

  /// 关于我们弹窗（真实版本号 + 官网信息）。
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.skin.colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Text('🧸', style: TextStyle(fontSize: 36)),
            SizedBox(height: 8),
            Text('Monster Word', style: MwTypography.heading5.copyWith(color: context.skin.colors.text1)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _appVersion.isEmpty ? '正在读取版本…' : '版本 $_appVersion',
              style: MwTypography.body.copyWith(color: context.skin.colors.text2),
            ),
            SizedBox(height: 8),
            Text('Monster Word · 科学背单词', style: MwTypography.bodySm.copyWith(color: context.skin.colors.text3)),
          ],
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
              Text('给个好评吧！', style: MwTypography.heading5.copyWith(color: context.skin.colors.text1)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('您的支持是我们前进的动力', style: MwTypography.body.copyWith(color: context.skin.colors.text2)),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => rating = i + 1),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(i < rating ? Icons.star : Icons.star_border, color: FuncColors.ratingStar, size: 36),
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
                  : () async {
                      Navigator.pop(ctx);
                      // 评分走真实动作：好评跳仓库页（可 Star），低分引导到应用内反馈。
                      if (rating >= 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('感谢您的 $rating 星好评！欢迎去 GitHub 给我们一个 ⭐'),
                            backgroundColor: context.skin.colors.success,
                          ),
                        );
                        await launchUrl(
                          Uri.parse(GithubUpdateCheckService.repoUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('感谢反馈！已为您打开意见反馈页，帮我们做得更好'),
                            backgroundColor: context.skin.colors.success,
                          ),
                        );
                        Navigator.pushNamed(context, RouteNames.feedback);
                      }
                    },
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  /// 检查更新：真实请求 GitHub Releases 最新 tag 与当前版本比较。
  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('正在检查更新…'), duration: Duration(seconds: 2)));

    final result = await _updateService.check(currentVersion: _appVersion);
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (result.failed) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.skin.colors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              const Text('📡', style: TextStyle(fontSize: 36)),
              SizedBox(height: 8),
              Text('检查失败', style: MwTypography.heading5.copyWith(color: context.skin.colors.text1)),
            ],
          ),
          content: Text(
            '无法连接更新服务器，请检查网络后重试',
            style: MwTypography.body.copyWith(color: context.skin.colors.text2),
            textAlign: TextAlign.center,
          ),
          actions: [_okButton(ctx)],
        ),
      );
      return;
    }

    if (result.hasUpdate) {
      final notesPreview = result.notes == null ? '' : _firstLines(result.notes!, 6);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.skin.colors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 36)),
              SizedBox(height: 8),
              Text(
                '发现新版本 v${result.latestVersion}',
                style: MwTypography.heading5.copyWith(color: context.skin.colors.text1),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前版本 v${result.currentVersion}，可前往下载页更新',
                style: MwTypography.body.copyWith(color: context.skin.colors.text2),
              ),
              if (notesPreview.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(notesPreview, style: MwTypography.bodySm.copyWith(color: context.skin.colors.text3)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('下次再说', style: TextStyle(color: context.skin.colors.text3)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.skin.colors.accent,
                foregroundColor: context.skin.colors.onGlassAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await launchUrl(Uri.parse(result.releaseUrl), mode: LaunchMode.externalApplication);
              },
              child: const Text('前往下载'),
            ),
          ],
        ),
      );
      return;
    }

    // 真实对比后确认已是最新。
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.skin.colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Text('✅', style: TextStyle(fontSize: 36)),
            SizedBox(height: 8),
            Text('已是最新版本', style: MwTypography.heading5.copyWith(color: context.skin.colors.text1)),
          ],
        ),
        content: Text(
          _appVersion.isEmpty ? '当前已是最新版本' : '当前版本 v$_appVersion 已是最新（远端 v${result.latestVersion}）',
          style: MwTypography.body.copyWith(color: context.skin.colors.text2),
          textAlign: TextAlign.center,
        ),
        actions: [_okButton(ctx)],
      ),
    );
  }

  Widget _okButton(BuildContext ctx) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: context.skin.colors.accent,
        foregroundColor: context.skin.colors.onGlassAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () => Navigator.pop(ctx),
      child: const Text('知道了'),
    );
  }

  /// 更新日志摘要：取前 [maxLines] 行，压掉空行与图片标记。
  String _firstLines(String notes, int maxLines) {
    final lines = notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('!['))
        .toList();
    final picked = lines.take(maxLines).join('\n');
    return lines.length > maxLines ? '$picked\n…' : picked;
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
      result = await context.read<WordBookMaintenanceService>().forceRebuild();
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
                  Text('Monster Word', style: MwTypography.heading5.copyWith(color: context.skin.colors.onGlassAccent)),
                  SizedBox(height: 4),
                  Text(
                    '背单词，so easy！',
                    style: MwTypography.bodySm.copyWith(
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
                    child: Text('扫码下载', style: MwTypography.micro.copyWith(color: context.skin.colors.accent)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text('扫码下载 Monster Word', style: MwTypography.body.copyWith(color: context.skin.colors.text2)),
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
                  _buildAccountGroup(skin),
                  SizedBox(height: context.design.spacing.md),
                  _buildFeedbackGroup(skin),
                  SizedBox(height: context.design.spacing.md),
                  _buildRedeemReportGroup(skin),
                  SizedBox(height: context.design.spacing.md),
                  _buildLegalGroup(skin),
                  SizedBox(height: context.design.spacing.xxl),
                  _buildLogoutButton(skin),
                  SizedBox(height: context.design.spacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 账号信息组
  Widget _buildAccountGroup(SkinSystem skin) {
    return _SettingGroup([
      _Cell(
        icon: Icons.person_outline,
        iconColor: skin.colors.accent,
        title: '账号信息',
        subtitle: '点击设置',
        onTap: () => Navigator.pushNamed(context, RouteNames.accountInfo),
      ),
    ]);
  }

  /// 帮助与反馈 / 评价应用 / 检查更新 / 更新词库 / 推荐给好友组
  Widget _buildFeedbackGroup(SkinSystem skin) {
    return _SettingGroup([
      _Cell(
        icon: Icons.help_outline,
        iconColor: MwColors.success,
        title: '帮助与反馈',
        onTap: () => Navigator.pushNamed(context, RouteNames.feedback),
      ),
      Divider(height: 1, color: skin.colors.divider, indent: 52),
      _Cell(
        icon: Icons.star_outline,
        iconColor: MwColors.warning,
        title: '评价应用',
        subtitle: _appVersion.isEmpty ? null : 'v$_appVersion',
        onTap: () => _showRatingDialog(context),
      ),
      Divider(height: 1, color: skin.colors.divider, indent: 52),
      _Cell(
        icon: Icons.system_update_outlined,
        iconColor: MwColors.link,
        title: '检查更新',
        onTap: () => _checkForUpdate(),
      ),
      Divider(height: 1, color: skin.colors.divider, indent: 52),
      _Cell(
        icon: Icons.storage_outlined,
        iconColor: MwColors.link,
        title: '更新词库数据',
        subtitle: '全量覆盖重建本地词库（含全部词条与索引）',
        onTap: () => _showRebuildWordbookDialog(context),
      ),
      Divider(height: 1, color: skin.colors.divider, indent: 52),
      _Cell(
        icon: Icons.share_outlined,
        iconColor: MwColors.ink,
        title: '推荐给好友',
        onTap: () => _showShareDialog(context),
      ),
    ]);
  }

  /// 兑换中心 / 举报组
  Widget _buildRedeemReportGroup(SkinSystem skin) {
    return _SettingGroup([
      _Cell(
        icon: Icons.redeem_outlined,
        iconColor: MwColors.primary,
        title: '兑换中心',
        onTap: () => Navigator.pushNamed(context, RouteNames.redemption),
      ),
      Divider(height: 1, color: skin.colors.divider, indent: 52),
      _Cell(
        icon: Icons.flag_outlined,
        iconColor: MwColors.danger,
        title: '违法不良信息举报',
        onTap: () => _showReportDialog(context),
      ),
    ]);
  }

  /// 服务条款 / 隐私协议 / 关于我们组
  Widget _buildLegalGroup(SkinSystem skin) {
    return _SettingGroup([
      _Cell(
        icon: Icons.description_outlined,
        iconColor: skin.colors.text3,
        title: '服务条款',
        onTap: () => _showLegalDialog(context, '服务条款'),
      ),
      Divider(height: 1, color: skin.colors.divider, indent: 52),
      _Cell(
        icon: Icons.privacy_tip_outlined,
        iconColor: skin.colors.text3,
        title: '隐私协议',
        onTap: () => _showLegalDialog(context, '隐私协议'),
      ),
      Divider(height: 1, color: skin.colors.divider, indent: 52),
      _Cell(
        icon: Icons.info_outline,
        iconColor: skin.colors.text3,
        title: '关于我们',
        subtitle: _appVersion.isEmpty ? null : 'v$_appVersion',
        onTap: () => _showAboutDialog(context),
      ),
    ]);
  }

  /// 服务条款 / 隐私协议说明弹窗（本地展示，正式文本随后续版本发布）
  void _showLegalDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.skin.colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: MwTypography.heading5.copyWith(color: context.skin.colors.text1)),
        content: Text(
          'Monster Word 正在完善独立的$title文本，将随后续版本发布。\n\n'
          '在此之前如有任何疑问，欢迎通过「帮助与反馈」联系我们。',
          style: MwTypography.body.copyWith(color: context.skin.colors.text2),
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

  /// 退出登录按钮
  Widget _buildLogoutButton(SkinSystem skin) {
    return SizedBox(
      width: double.infinity,
      child: MwButton.outlined(
        label: '退出登录',
        onTap: () => _showLogoutSheet(context),
        borderSide: BorderSide(color: skin.colors.danger, width: 1),
        textColor: skin.colors.danger,
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
        style: MwTypography.bodyMd.copyWith(color: context.skin.colors.text2),
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
          Text('更多设置', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
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
          BoxShadow(offset: Offset.zero, blurRadius: 0.5, color: MwShadows.softShadow),
          BoxShadow(offset: Offset(0, 1), blurRadius: 1, color: MwShadows.liftShadow),
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
              child: Text(title, style: MwTypography.bodyMd.copyWith(color: skin.text1)),
            ),
            if (subtitle != null)
              Padding(
                padding: EdgeInsets.only(right: context.design.spacing.xs),
                child: Text(subtitle!, style: MwTypography.bodySm.copyWith(color: skin.text3)),
              ),
            Icon(Icons.chevron_right, size: 18, color: skin.text3),
          ],
        ),
      ),
    );
  }
}
