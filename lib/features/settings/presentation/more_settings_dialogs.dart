// part of 'more_settings_page.dart' —— 更多设置页的展示类弹窗
// （举报渠道 / 关于我们 / 评价应用）。
//
// 拆出理由：more_settings_page.dart 一度逼近 900 行上限，加 R3-A05 的登出跳转后
// 越界（919 行），触发 test/architecture/code_style_guard_test.dart。
// 这三个弹窗是自包含的展示逻辑，按本仓既有的 part 约定
// （见 profile_screen.dart + monster_room_*.dart）外移。
//
// 注意：part 共享宿主 library 的作用域，因此 `appGitHubRepoUrl`、`MwTypography`、
// `RouteNames` 等均在作用域内，**不需要**再当作参数往里传。
part of 'more_settings_page.dart';

/// 违法不良信息举报：展示官方举报渠道（中央网信办 12377 / 公安 110 / 应用内反馈）。
void _showReportDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.skin.colors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.control)),
      title: Column(
        children: [
          Icon(Icons.flag_rounded, size: 40, color: context.skin.colors.danger),
          const SizedBox(height: 8),
          Text('举报渠道', style: MwTypography.heading5.copyWith(color: context.skin.colors.text1)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('如发现违法和不良信息，可通过以下官方渠道举报：', style: MwTypography.bodySm.copyWith(color: context.skin.colors.text2)),
          const SizedBox(height: 12),
          _reportChannel(context, '中央网信办举报中心', '电话 12377 · 官网 www.12377.cn'),
          const SizedBox(height: 8),
          _reportChannel(context, '公安报警', '电话 110'),
          const SizedBox(height: 8),
          _reportChannel(context, '应用内问题反馈', '帮助与反馈入口'),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: context.skin.colors.accent,
            foregroundColor: context.skin.colors.onGlassAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// 单条举报渠道行。
///
/// ⚠️ 原先它是 State 的方法，可直接用 `this.context`；外移为顶层函数后
/// **没有隐式 context**，必须显式传入（本文件唯一需要 context 的顶层辅助函数）。
Widget _reportChannel(BuildContext context, String title, String detail) {
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
void _showAboutDialog(BuildContext context, String appVersion) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.skin.colors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.control)),
      title: Column(
        children: [
          const MonsterIcon(size: 40, showCircle: true),
          const SizedBox(height: 8),
          Text('Monster Word', style: MwTypography.heading5.copyWith(color: context.skin.colors.text1)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            appVersion.isEmpty ? '正在读取版本…' : '版本 $appVersion',
            style: MwTypography.body.copyWith(color: context.skin.colors.text2),
          ),
          const SizedBox(height: 8),
          Text('Monster Word · 科学背单词', style: MwTypography.bodySm.copyWith(color: context.skin.colors.text3)),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: context.skin.colors.accent,
            foregroundColor: context.skin.colors.onGlassAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// 评价应用弹窗（5 星评分）。
///
/// 评分走真实动作：好评跳仓库页（可 Star），低分引导到应用内反馈。
Future<void> _showRatingDialog(BuildContext context) async {
  var rating = 0;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: context.skin.colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.control)),
        title: Column(
          children: [
            Icon(Icons.star_rounded, size: 44, color: context.skin.colors.accent),
            const SizedBox(height: 8),
            Text('给个好评吧！', style: MwTypography.heading5.copyWith(color: context.skin.colors.text1)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('您的支持是我们前进的动力', style: MwTypography.body.copyWith(color: context.skin.colors.text2)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setDialogState(() => rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.lg)),
            ),
            onPressed: rating == 0
                ? null
                : () async {
                    Navigator.pop(ctx);
                    // 评分走真实动作：好评跳仓库页（可 Star），低分引导到应用内反馈。
                    if (rating >= 4) {
                      showMwSnackBar(
                        context,
                        SnackBar(
                          content: Text('感谢您的 $rating 星好评！欢迎去 GitHub 给我们点一个 Star'),
                          backgroundColor: context.skin.colors.success,
                        ),
                      );
                      await launchUrl(Uri.parse(appGitHubRepoUrl), mode: LaunchMode.externalApplication);
                    } else {
                      showMwSnackBar(
                        context,
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
