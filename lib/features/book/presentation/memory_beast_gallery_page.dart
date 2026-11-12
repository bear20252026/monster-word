// 词书图鉴 demo（蓝图 T3 第一步）：当前词书前 20 词，一词一只程序化记忆兽。
// 先验证「可爱不恐怖」，再谈整册生态域——本页不接 FSRS 成熟度、不做收集进度，
// 只展示生成器观感。路由：/memory_beast_gallery。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/utils/memory_beast.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';
import 'package:word_app/features/book/presentation/book_state.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/memory_beast_icon.dart';

/// demo 展示词数（蓝图口径：20 词生成器）。
const int memoryBeastDemoCount = 20;

class MemoryBeastGalleryPage extends StatefulWidget {
  const MemoryBeastGalleryPage({super.key});

  static const routeName = RouteNames.memoryBeastGallery;

  @override
  State<MemoryBeastGalleryPage> createState() => _MemoryBeastGalleryPageState();
}

class _MemoryBeastGalleryPageState extends State<MemoryBeastGalleryPage> {
  List<MemoryBeastSpec> _beasts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bookState = context.read<BookState>();
      final bookId = bookState.currentBookId;
      if (bookId <= 0) {
        setState(() {
          _loading = false;
          _error = '先去选一册词书，记忆兽才有栖息地。';
        });
        return;
      }
      final reader = context.read<BookWordListReader>();
      final words = await reader.loadWordPage(bookId, offset: 0, limit: memoryBeastDemoCount);
      if (!mounted) return;
      setState(() {
        _beasts = words.map(memoryBeastFor).toList();
        _loading = false;
      });
    } catch (e, s) {
      reportSwallowedError('图鉴 demo 加载失败', e, s);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '记忆兽们还没醒，稍后再来看看。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      appBar: AppBar(title: const Text('词书图鉴 · demo'), backgroundColor: skin.colors.pageBg),
      body: _buildBody(skin),
    );
  }

  Widget _buildBody(SkinSystem skin) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: MwTypography.bodySm.copyWith(color: skin.colors.text2),
          ),
        ),
      );
    }
    if (_beasts.isEmpty) {
      return Center(
        child: Text('这册词书还没有词。', style: MwTypography.bodySm.copyWith(color: skin.colors.text2)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          '每个词都有自己的小记忆兽：词长定体型，词性定耳朵，难词配稀有色。稀有不是抽奖，是你啃下了难词。',
          style: MwTypography.caption.copyWith(color: skin.colors.text2, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildLegend(skin),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 0.82,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          children: [for (final spec in _beasts) _BeastCard(spec: spec)],
        ),
      ],
    );
  }

  /// 稀有度图例：三档只是颜色不同，无数值高低。
  Widget _buildLegend(SkinSystem skin) {
    return Row(
      children: [
        for (final rarity in BeastRarity.values) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: MemoryBeastIcon.colorFor(rarity), shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(beastRarityLabels[rarity]!, style: MwTypography.micro.copyWith(color: skin.colors.text2)),
          const SizedBox(width: AppSpacing.md),
        ],
      ],
    );
  }
}

/// 单张图鉴卡：记忆兽 + 词 + 属性签（体型/耳朵/稀有度，只陈述不评价）。
class _BeastCard extends StatelessWidget {
  const _BeastCard({required this.spec});

  final MemoryBeastSpec spec;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: skin.colors.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: skin.colors.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MemoryBeastIcon(spec: spec, size: 72),
          const SizedBox(height: AppSpacing.sm),
          Text(
            spec.word,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MwTypography.bodyBold.copyWith(color: skin.colors.text1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${beastBuildLabels[spec.build]} · ${beastEarsLabels[spec.ears]} · ${beastRarityLabels[spec.rarity]}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MwTypography.micro.copyWith(color: skin.colors.text3),
          ),
        ],
      ),
    );
  }
}
