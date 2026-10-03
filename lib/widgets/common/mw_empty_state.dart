// Monster Word — 空状态组件（无数据/无结果/无网络 一等公民）
//
// 商业产品惯例：空态不是白屏，而是「图标 + 一句话 + 行动指引」。
// 颜色/圆角/间距全部走 A 档 + B 档，跟随品牌换肤。
import 'package:flutter/material.dart';

import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';

/// 预置空态场景，避免各页图标/文案各写各的。
enum MwEmptyKind {
  /// 无数据（列表为空）
  empty,

  /// 搜索无结果
  search,

  /// 无网络
  offline,

  /// 加载失败
  error,
}

extension _MwEmptyKindX on MwEmptyKind {
  IconData get icon => switch (this) {
    MwEmptyKind.empty => Icons.inbox_outlined,
    MwEmptyKind.search => Icons.search_off_rounded,
    MwEmptyKind.offline => Icons.wifi_off_rounded,
    MwEmptyKind.error => Icons.error_outline_rounded,
  };

  String get defaultTitle => switch (this) {
    MwEmptyKind.empty => '这里还空空如也',
    MwEmptyKind.search => '没有找到相关内容',
    MwEmptyKind.offline => '网络连接不可用',
    MwEmptyKind.error => '加载失败了',
  };

  String get defaultSubtitle => switch (this) {
    MwEmptyKind.empty => '从下面开始，添加第一批内容吧',
    MwEmptyKind.search => '换个关键词，或检查一下拼写',
    MwEmptyKind.offline => '检查网络后重试',
    MwEmptyKind.error => '稍后再试一次',
  };
}

class MwEmptyState extends StatelessWidget {
  final MwEmptyKind kind;
  final String? title;
  final String? subtitle;

  /// 空态怪兽气泡（G6 空态家族）：非 null 时渲染「小怪兽 + 气泡文案」替代静态 icon 区；
  /// null（默认）时完全走原图标路径，渲染与历史版本一致。
  final String? monsterPhrase;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MwEmptyState({
    super.key,
    this.kind = MwEmptyKind.empty,
    this.title,
    this.subtitle,
    this.monsterPhrase,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final design = context.design;
    final c = skin.colors;
    final monsterPhrase = this.monsterPhrase;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(design.spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标：低饱和描边圆底，避免大红大绿；monsterPhrase 非空时由「怪兽 + 气泡」替代
            if (monsterPhrase != null)
              _MonsterBubble(
                phrase: monsterPhrase,
                bgColor: c.cardBgAlt,
                borderColor: c.divider,
                textColor: c.text2,
                radius: design.radius.lg,
                padH: design.spacing.lg,
                padV: design.spacing.sm,
                gap: design.spacing.sm,
              )
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.cardBgAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.divider),
                ),
                child: Icon(kind.icon, size: 30, color: c.text3),
              ),
            SizedBox(height: design.spacing.lg),
            Text(
              title ?? kind.defaultTitle,
              style: MwTypography.bodyBold.copyWith(fontWeight: FontWeight.w600, color: c.text1),
            ),
            SizedBox(height: design.spacing.xs),
            Text(
              subtitle ?? kind.defaultSubtitle,
              textAlign: TextAlign.center,
              style: MwTypography.caption.copyWith(color: c.text2),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: design.spacing.lg),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「怪兽 + 气泡」头部：小尺寸怪兽 + 圆角气泡话痨文案，替代静态 icon 区。
/// 颜色/圆角/间距由宿主按 token 传入，自身不做主题查找。
class _MonsterBubble extends StatelessWidget {
  final String phrase;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  /// 圆角 / 横向留白 / 纵向留白 / 怪兽与气泡间距（design token 值）。
  final double radius;
  final double padH;
  final double padV;
  final double gap;

  const _MonsterBubble({
    required this.phrase,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.radius,
    required this.padH,
    required this.padV,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MonsterIcon(size: 48),
        SizedBox(height: gap),
        // maxWidth 260：长句换行，防止气泡在宽屏被拉成一条横幅
        Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            phrase,
            textAlign: TextAlign.center,
            style: MwTypography.caption.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}
