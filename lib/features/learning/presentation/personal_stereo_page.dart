// 由 Claude 团队 生成 | Monster Word App

// 随身听：磁带机隐喻的碎片时间听记（词源四选 + 顺序连播 + 播放控制）。
// hero 是一台「正在转卷轴的盒式磁带」——播放中双卷轴持续旋转，
// 暂停即停转，把播放状态变成看得见的机械隐喻。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/features/learning/application/learning_favorites_store.dart';
import 'package:word_app/features/learning/application/learning_session_reader.dart';
import 'package:word_app/features/learning/application/new_words_reader.dart';
import 'package:word_app/features/learning/application/stereo_player_state.dart';
import 'package:word_app/features/learning/presentation/learning_queue_word_lists_state.dart';
import 'package:word_app/features/learning/presentation/play_order_page.dart';
import 'package:word_app/features/learning/presentation/review_queue_state.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/func_colors.dart';
import 'package:word_app/widgets/mw_list_row.dart';
import 'package:word_app/widgets/mw_section_header.dart';

class PersonalStereoPage extends StatefulWidget {
  const PersonalStereoPage({super.key});

  static const routeName = '/personal_stereo';

  @override
  State<PersonalStereoPage> createState() => _PersonalStereoPageState();
}

class _PersonalStereoPageState extends State<PersonalStereoPage> {
  late final StereoPlayerState _player;

  @override
  void initState() {
    super.initState();
    _player = StereoPlayerState(audioService: context.read<AudioService>());
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _startSource(StereoSource source) async {
    final words = await _loadWords(source);
    if (!mounted) return;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('该词源暂无可播放的单词'), duration: Duration(seconds: 1)));
      return;
    }
    _player.start(source: source, words: words);
  }

  Future<List<Word>> _loadWords(StereoSource source) async {
    switch (source) {
      case StereoSource.todayLearned:
        return context.read<LearningQueueWordListsState>().learnedWords;
      case StereoSource.reviewing:
        return context.read<ReviewQueueState>().snapshot.dueWords;
      case StereoSource.newWords:
        return context.read<NewWordsReader>().loadWords();
      case StereoSource.favorites:
        final favorites = context.read<LearningFavoritesStore>();
        final queue = context.read<LearningSessionReader>().queue;
        return favorites.loadFavoriteWords(currentQueue: queue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin, context),
            Container(height: 1, color: skin.colors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlayerCard(skin),
                    const SizedBox(height: 24),
                    const MwSectionHeader(title: '选择词源'),
                    const SizedBox(height: 12),
                    MwListGroup(children: _buildSourceRows()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin, BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: skin.colors.text1,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('随身听', style: MwTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  List<Widget> _buildSourceRows() {
    return [
      MwListRow(
        icon: Icons.play_circle_outline,
        iconColor: context.skin.colors.accent,
        title: '今日已学单词',
        subtitle: '巩固今天学习的单词',
        onTap: () => unawaited(_startSource(StereoSource.todayLearned)),
      ),
      MwListRow(
        icon: Icons.replay,
        iconColor: FuncColors.warning,
        title: '复习中单词',
        subtitle: '播放正在复习的单词',
        onTap: () => unawaited(_startSource(StereoSource.reviewing)),
      ),
      MwListRow(
        icon: Icons.fiber_new,
        iconColor: FuncColors.purple,
        title: '生词本',
        subtitle: '播放生词本中的单词',
        onTap: () => unawaited(_startSource(StereoSource.newWords)),
      ),
      MwListRow(
        icon: Icons.favorite_border,
        iconColor: context.skin.colors.danger,
        title: '收藏单词',
        subtitle: '播放收藏的单词',
        onTap: () => unawaited(_startSource(StereoSource.favorites)),
      ),
      MwListRow(
        icon: Icons.shuffle,
        iconColor: FuncColors.success,
        title: '播放顺序',
        subtitle: '设置单词播放顺序',
        onTap: () => Navigator.pushNamed(context, PlayOrderPage.routeName),
      ),
    ];
  }

  Widget _buildPlayerCard(SkinSystem skin) {
    return ListenableBuilder(
      listenable: _player,
      builder: (context, _) {
        final word = _player.currentWord;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [context.skin.colors.cardBgAlt, context.skin.colors.cardBg]),
            borderRadius: BorderRadius.circular(skin.design.radius.xl),
          ),
          child: Column(
            children: [
              CassetteTape(spinning: _player.isPlaying),
              const SizedBox(height: 16),
              if (word == null) ...[
                Text('随身听模式', style: MwTypography.heading4.copyWith(color: context.skin.colors.text1)),
                const SizedBox(height: 8),
                Text('选择下方词源开始播放', style: MwTypography.body.copyWith(color: context.skin.colors.text2)),
              ] else ...[
                Text(
                  word.word,
                  style: MwTypography.heading3.copyWith(color: context.skin.colors.text1, fontFamily: 'Charter'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  word.interpret,
                  style: MwTypography.bodySm.copyWith(color: context.skin.colors.text2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_sourceLabel(_player.source)} · ${_player.progressPosition} / ${_player.playlist.length}',
                  style: MwTypography.bodySm.copyWith(color: context.skin.colors.accent),
                ),
                const SizedBox(height: 8),
                _buildProgressBar(),
              ],
              const SizedBox(height: 16),
              _buildControls(word == null),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    final total = _player.playlist.length;
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.design.radius.pill),
      child: SizedBox(
        height: 4,
        child: LinearProgressIndicator(
          value: _player.progressPosition / total,
          backgroundColor: AppColors.white100.withValues(alpha: 0.6),
          valueColor: AlwaysStoppedAnimation(context.skin.colors.accent),
          minHeight: 4,
        ),
      ),
    );
  }

  Widget _buildControls(bool disabled) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous, color: context.skin.colors.text1, size: 32),
          tooltip: '上一首',
          onPressed: disabled ? null : () => unawaited(_player.previous()),
        ),
        const SizedBox(width: 16),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.skin.colors.accent),
          child: IconButton(
            icon: Icon(_player.isPlaying ? Icons.pause : Icons.play_arrow, color: AppColors.white100, size: 32),
            tooltip: _player.isPlaying ? '暂停' : '播放',
            onPressed: disabled ? null : () => _player.isPlaying ? unawaited(_player.pause()) : _player.resume(),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: Icon(Icons.skip_next, color: context.skin.colors.text1, size: 32),
          tooltip: '下一首',
          onPressed: disabled ? null : () => unawaited(_player.next()),
        ),
      ],
    );
  }

  String _sourceLabel(StereoSource? source) {
    switch (source) {
      case StereoSource.todayLearned:
        return '今日已学';
      case StereoSource.reviewing:
        return '复习中';
      case StereoSource.newWords:
        return '生词本';
      case StereoSource.favorites:
        return '收藏';
      case null:
        return '随身听';
    }
  }
}

/// 盒式磁带：奶油机身 + 双卷轴 + 磁带窗；[spinning] 为真时卷轴持续旋转。
class CassetteTape extends StatefulWidget {
  const CassetteTape({super.key, this.spinning = false, this.size = const Size(176, 92)});

  final bool spinning;

  /// 磁带整体尺寸（宽 × 高）。
  final Size size;

  @override
  State<CassetteTape> createState() => _CassetteTapeState();
}

class _CassetteTapeState extends State<CassetteTape> with SingleTickerProviderStateMixin {
  late final AnimationController _reel = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _reel.repeat();
  }

  @override
  void didUpdateWidget(CassetteTape old) {
    super.didUpdateWidget(old);
    if (widget.spinning == old.spinning) return;
    widget.spinning ? _reel.repeat() : _reel.stop();
  }

  @override
  void dispose() {
    _reel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reelSize = widget.size.height * 0.44;
    return Container(
      width: widget.size.width,
      height: widget.size.height,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white100,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: context.skin.colors.text2.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: context.skin.colors.text1.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _spinningReel(reelSize),
          Container(
            width: reelSize * 0.72,
            height: reelSize * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.design.radius.xs),
              border: Border.all(color: context.skin.colors.text2.withValues(alpha: 0.5), width: 2),
            ),
          ),
          _spinningReel(reelSize),
        ],
      ),
    );
  }

  Widget _spinningReel(double size) {
    return AnimatedBuilder(
      animation: _reel,
      builder: (context, child) => Transform.rotate(angle: _reel.value * 2 * math.pi, child: child),
      child: CustomPaint(
        size: Size(size, size),
        painter: _ReelPainter(color: context.skin.colors.text1),
      ),
    );
  }
}

/// 卷轴：外圈 + 三辐条 + 轴心。
class _ReelPainter extends CustomPainter {
  _ReelPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;

    canvas.drawCircle(center, radius, paint);
    for (var i = 0; i < 3; i++) {
      final angle = i * 2 * math.pi / 3;
      canvas.drawLine(
        center + Offset(math.cos(angle) * radius * 0.25, math.sin(angle) * radius * 0.25),
        center + Offset(math.cos(angle) * radius * 0.92, math.sin(angle) * radius * 0.92),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.2, paint);
  }

  @override
  bool shouldRepaint(_ReelPainter oldDelegate) => color != oldDelegate.color;
}
