// 由 Claude 团队生成 | Monster Word App

// 随身听：碎片时间听记单词（词源四选 + 顺序连播 + 播放控制）
import 'dart:async';

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
                  children: [
                    _buildPlayerCard(skin),
                    const SizedBox(height: 24),
                    _buildSourceCard(
                      skin: skin,
                      icon: Icons.play_circle_outline,
                      title: '今日已学单词',
                      subtitle: '巩固今天学习的单词',
                      source: StereoSource.todayLearned,
                    ),
                    const SizedBox(height: 12),
                    _buildSourceCard(
                      skin: skin,
                      icon: Icons.replay,
                      title: '复习中单词',
                      subtitle: '播放正在复习的单词',
                      source: StereoSource.reviewing,
                    ),
                    const SizedBox(height: 12),
                    _buildSourceCard(
                      skin: skin,
                      icon: Icons.fiber_new,
                      title: '生词本',
                      subtitle: '播放生词本中的单词',
                      source: StereoSource.newWords,
                    ),
                    const SizedBox(height: 12),
                    _buildSourceCard(
                      skin: skin,
                      icon: Icons.favorite_border,
                      title: '收藏单词',
                      subtitle: '播放收藏的单词',
                      source: StereoSource.favorites,
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      skin: skin,
                      icon: Icons.shuffle,
                      title: '播放顺序',
                      subtitle: '设置单词播放顺序',
                      onTap: () => Navigator.pushNamed(context, PlayOrderPage.routeName),
                    ),
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
          Text('随身听', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(SkinSystem skin) {
    return ListenableBuilder(
      listenable: _player,
      builder: (context, _) {
        final word = _player.currentWord;
        final source = _player.source;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [MistralColors.cream, MistralColors.creamDeeper]),
            borderRadius: BorderRadius.circular(skin.design.radius.xl),
          ),
          child: Column(
            children: [
              Icon(Icons.headphones, size: 48, color: MistralColors.primary),
              const SizedBox(height: 12),
              if (word == null) ...[
                Text('随身听模式', style: MistralTypography.heading4.copyWith(color: MistralColors.ink)),
                const SizedBox(height: 8),
                Text('选择下方词源开始播放', style: MistralTypography.body.copyWith(color: MistralColors.slate)),
              ] else ...[
                Text(
                  word.word,
                  style: MistralTypography.heading3.copyWith(color: MistralColors.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  word.interpret,
                  style: MistralTypography.bodySm.copyWith(color: MistralColors.slate),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_sourceLabel(source)} · ${_player.progressPosition} / ${_player.playlist.length}',
                  style: MistralTypography.bodySm.copyWith(color: MistralColors.primary),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: MistralColors.ink, size: 32),
                    tooltip: '上一首',
                    onPressed: word == null ? null : () => unawaited(_player.previous()),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: MistralColors.primary),
                    child: IconButton(
                      icon: Icon(_player.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                      tooltip: _player.isPlaying ? '暂停' : '播放',
                      onPressed: word == null
                          ? null
                          : () => _player.isPlaying ? unawaited(_player.pause()) : _player.resume(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: MistralColors.ink, size: 32),
                    tooltip: '下一首',
                    onPressed: word == null ? null : () => unawaited(_player.next()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

  Widget _buildSourceCard({
    required SkinSystem skin,
    required IconData icon,
    required String title,
    required String subtitle,
    required StereoSource source,
  }) {
    return _buildMenuCard(
      skin: skin,
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => unawaited(_startSource(source)),
    );
  }

  Widget _buildMenuCard({
    required SkinSystem skin,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: skin.colors.cardBgAlt,
          borderRadius: BorderRadius.circular(skin.design.radius.lg),
          border: Border.all(color: skin.colors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MistralColors.cream,
                borderRadius: BorderRadius.circular(skin.design.radius.md),
              ),
              child: Icon(icon, color: MistralColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: MistralTypography.bodyBold.copyWith(color: skin.colors.text1)),
                  Text(subtitle, style: MistralTypography.bodySm.copyWith(color: skin.colors.text3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: skin.colors.text3),
          ],
        ),
      ),
    );
  }
}
