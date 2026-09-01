// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 ListWordListenActivity
// 单词听写：播放单词语音，用户拼写练习
// 词源与发音均走既有端口（单一事实来源）：队列取自 LearningSessionState.queue
// （与听写会话页同源），发音走 AudioPlaybackState.playWord。
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/features/learning/presentation/learning_session_state.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

class ListWordListenPage extends StatefulWidget {
  const ListWordListenPage({super.key});

  static const routeName = '/word_listen';

  @override
  State<ListWordListenPage> createState() => _ListWordListenPageState();
}

class _ListWordListenPageState extends State<ListWordListenPage> {
  final _inputController = TextEditingController();
  List<Word> _words = [];
  int _currentIndex = -1;
  bool _loading = true;
  String _feedback = '';
  bool _showAnswer = false;
  int _correctCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    // 延迟到首帧后读 provider，避免 initState 中直接读 provider 的副作用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadWords();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _loadWords() {
    final words = context.read<LearningSessionState>().queue.toList();
    setState(() {
      _words = words;
      _loading = false;
      _currentIndex = words.isNotEmpty ? 0 : -1;
    });
    if (words.isNotEmpty) _playWord();
  }

  Word? get _current => (_currentIndex >= 0 && _currentIndex < _words.length) ? _words[_currentIndex] : null;

  bool get _hasNext => _currentIndex < _words.length - 1;

  void _playWord() {
    final word = _current;
    if (word == null || word.word.isEmpty) return;
    context.read<AudioPlaybackState>().playWord(word.word);
  }

  void _loadNextWord() {
    if (!_hasNext) return;
    setState(() {
      _currentIndex++;
      _feedback = '';
      _showAnswer = false;
      _inputController.clear();
    });
    _playWord();
  }

  void _checkSpelling() {
    final word = _current;
    if (word == null) return;
    final input = _inputController.text.trim().toLowerCase();
    setState(() {
      _totalCount++;
      if (input == word.word.toLowerCase()) {
        _correctCount++;
        _feedback = '✓ 正确！';
      } else {
        _feedback = '✗ 正确答案：${word.word}';
      }
      _showAnswer = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            Container(height: 1, color: skin.colors.divider),
            Expanded(child: _buildBody(skin)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SkinSystem skin) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_current == null) {
      return Center(
        child: Text('暂无学习队列，请先选择词书开始学习', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 进度：答题统计 + 队列位置
          Text(
            '$_correctCount / $_totalCount',
            style: MistralTypography.heading4.copyWith(color: MistralColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            '第 ${_currentIndex + 1} / ${_words.length} 词',
            style: MistralTypography.caption.copyWith(color: skin.colors.text3),
          ),
          const SizedBox(height: 24),
          // 播放按钮
          GestureDetector(
            onTap: _playWord,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MistralColors.cream,
                border: Border.all(color: MistralColors.primary, width: 2),
              ),
              child: Icon(Icons.volume_up, size: 40, color: MistralColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _playWord,
            child: Text('点击播放', style: TextStyle(color: MistralColors.primary)),
          ),
          const SizedBox(height: 32),
          // 输入框
          TextField(
            controller: _inputController,
            textAlign: TextAlign.center,
            style: MistralTypography.heading3.copyWith(color: skin.colors.text1),
            decoration: InputDecoration(
              hintText: '请输入单词',
              hintStyle: MistralTypography.body.copyWith(color: skin.colors.text3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.design.radius.lg),
                borderSide: BorderSide(color: skin.colors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.design.radius.lg),
                borderSide: BorderSide(color: MistralColors.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _checkSpelling(),
          ),
          const SizedBox(height: 16),
          // 反馈
          if (_showAnswer) ...[
            Text(
              _feedback,
              style: MistralTypography.heading5.copyWith(
                color: _feedback.startsWith('✓') ? MistralColors.success : MistralColors.danger,
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Spacer(),
          // 按钮组
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showAnswer = true;
                      _feedback = '答案：${_current!.word}';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: skin.colors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('查看答案'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: !_showAnswer
                      ? _checkSpelling
                      : (_hasNext
                            ? _loadNextWord
                            : () =>
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已是最后一个词')))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MistralColors.primary,
                    foregroundColor: AppColors.white100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(!_showAnswer ? '确认' : (_hasNext ? '下一个' : '完成')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(SkinSystem skin) {
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
          Text('单词听写', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}
