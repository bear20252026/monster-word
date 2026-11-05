part of '../home_screen.dart';

/// 今日路线（灰度开关 [kPathHome]）：数据复用 TodayProgressStore，点击节点弹小卡。
class _HomePathSection extends StatelessWidget {
  const _HomePathSection();

  @override
  Widget build(BuildContext context) {
    return Selector<TodayProgressStore, ({int goal, int learned, int due})>(
      selector: (_, s) => (goal: s.goal, learned: s.learned, due: s.due),
      builder: (context, p, _) {
        final nodes = buildHomePathNodes(goal: p.goal, learned: p.learned, due: p.due);
        return HomePathMap(nodes: nodes, onNodeTap: (index) => _openNodeSheet(context, nodes, index));
      },
    );
  }

  /// 节点小卡：一个主按钮「开始 · 约 N 分钟」+ 文字链「换个任务」，不做全屏遮罩。
  Future<void> _openNodeSheet(BuildContext context, List<HomePathNode> nodes, int index) {
    return showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PathNodeSheet(
        nodes: nodes,
        initialIndex: index,
        onStart: (nodeIndex) {
          Navigator.of(sheetContext).pop();
          final kind = nodes[nodeIndex].kind;
          if (kind == HomePathNodeKind.review) {
            showReviewDialog(context);
          } else {
            startHomeLearning(context);
          }
        },
      ),
    );
  }
}

/// 路线节点弹层（「换个任务」在 4 个节点间轮换，不强制顺序）。
class _PathNodeSheet extends StatefulWidget {
  const _PathNodeSheet({required this.nodes, required this.initialIndex, required this.onStart});

  final List<HomePathNode> nodes;
  final int initialIndex;
  final ValueChanged<int> onStart;

  @override
  State<_PathNodeSheet> createState() => _PathNodeSheetState();
}

class _PathNodeSheetState extends State<_PathNodeSheet> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.skin.colors;
    final node = widget.nodes[_index];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            border: Border.all(color: colors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '第 ${_index + 1} / ${widget.nodes.length} 步',
                style: MwTypography.micro.copyWith(color: colors.text3),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                node.label,
                style: MwTypography.titleLg.copyWith(fontWeight: FontWeight.bold, color: colors.text1),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('${node.detail} · 约 ${node.minutes} 分钟', style: MwTypography.bodySm.copyWith(color: colors.text2)),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onGlassAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  onPressed: () => widget.onStart(_index),
                  child: Text(
                    '开始 · 约 ${node.minutes} 分钟',
                    style: const TextStyle(fontSize: AppFontSizes.bodyMd, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => setState(() => _index = (_index + 1) % widget.nodes.length),
                style: TextButton.styleFrom(foregroundColor: colors.text3),
                child: const Text('换个任务', style: TextStyle(fontSize: AppFontSizes.caption)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
