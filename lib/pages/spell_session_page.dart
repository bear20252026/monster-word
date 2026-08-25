// 听写单元测模式：多词连续听写
// 播放音频 → 用户拼写 → 正确/错误反馈 → 下一词
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../player/audio_players.dart';
import '../state/learning_state.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/session_exit_guard.dart';

class SpellSessionPage extends StatefulWidget {
  const SpellSessionPage({super.key});
  static const routeName = '/spell_session';

  @override
  State<SpellSessionPage> createState() => _SpellSessionPageState();
}

class _SpellSessionPageState extends State<SpellSessionPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  // 音频通过 playWordAudio 统一播放

  int _currentIndex = 0;
  String _result = '';
  bool _isCorrect = false;
  bool _hasChecked = false;
  int _correctCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playCurrentWord();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _currentWord {
    final state = context.read<LearningState>();
    if (state.queue.isEmpty) return '';
    return state.queue[_currentIndex.clamp(0, state.queue.length - 1)].word;
  }

  String? get _currentPhonetic {
    final state = context.read<LearningState>();
    if (state.queue.isEmpty) return null;
    final w = state.queue[_currentIndex.clamp(0, state.queue.length - 1)];
    return w.usPron.isNotEmpty ? w.usPron : (w.ukPron.isNotEmpty ? w.ukPron : null);
  }

  int get _totalWords {
    final state = context.read<LearningState>();
    return state.queue.length;
  }

  Future<void> _playCurrentWord() async {
    if (_currentWord.isEmpty) return;
    try {
      await playWordAudio(_currentWord);
    } catch (e) {
      debugPrint('Audio playback error: $e');
    }
  }

  void _check() {
    final input = _controller.text.trim();
    if (input.isEmpty || _currentWord.isEmpty) return;

    setState(() {
      _totalCount++;
      _hasChecked = true;
      if (input.toLowerCase() == _currentWord.toLowerCase()) {
        _isCorrect = true;
        _correctCount++;
        _result = '✓ 正确！';
      } else {
        _isCorrect = false;
        _result = '✗ 正确拼写：$_currentWord';
      }
    });
  }

  void _nextWord() {
    if (_currentIndex < _totalWords - 1) {
      setState(() {
        _currentIndex++;
        _controller.clear();
        _result = '';
        _hasChecked = false;
        _isCorrect = false;
      });
      _focusNode.requestFocus();
      _playCurrentWord();
    } else {
      // 测试完成
      _showResult();
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('听写完成'),
        content: Text('正确率：$_correctCount / $_totalCount\n'
            '${_totalCount > 0 ? (_correctCount / _totalCount * 100).toStringAsFixed(0) : 0}%'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentIndex = 0;
                _correctCount = 0;
                _totalCount = 0;
                _controller.clear();
                _result = '';
                _hasChecked = false;
              });
              _playCurrentWord();
            },
            child: const Text('重新开始'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    if (_totalWords == 0) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildNavBar(skin),
              Expanded(
                child: Center(
                  child: Text('暂无单词', style: MistralTypography.body.copyWith(color: skin.colors.text3)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 返回保护：系统返回需确认，防止误触丢失拼写进度
    return SessionExitGuard(
      subject: '拼写练习',
      child: Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(skin),
            // 进度条
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _totalWords,
              backgroundColor: skin.colors.divider,
              valueColor: AlwaysStoppedAnimation(skin.colors.accent),
              minHeight: 3,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 进度文字
                    Text('${_currentIndex + 1} / $_totalWords',
                        style: MistralTypography.caption.copyWith(color: skin.colors.text3)),
                    const SizedBox(height: 16),
                    // 播放按钮
                    GestureDetector(
                      onTap: _playCurrentWord,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: skin.colors.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.volume_up, color: skin.colors.accent, size: 40),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_currentPhonetic != null)
                      Text('/$_currentPhonetic/',
                          style: MistralTypography.body.copyWith(color: skin.colors.text3)),
                    const SizedBox(height: 32),
                    // 输入框
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textAlign: TextAlign.center,
                      style: MistralTypography.heading3.copyWith(color: skin.colors.text1),
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        hintText: '输入听到的单词',
                        hintStyle: MistralTypography.body.copyWith(color: skin.colors.text3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: skin.colors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: skin.colors.accent, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _check(),
                    ),
                    const SizedBox(height: 16),
                    // 反馈
                    if (_hasChecked) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (_isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: _isCorrect ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Text(_result,
                            textAlign: TextAlign.center,
                            style: MistralTypography.bodyBold.copyWith(
                              color: _isCorrect ? Colors.green : Colors.red,
                            )),
                      ),
                    ],
                    const Spacer(),
                    // 按钮组
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _totalCount++;
                                _hasChecked = true;
                                _result = '答案：$_currentWord';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: skin.colors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('跳过'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _hasChecked ? _nextWord : _check,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: skin.colors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(_hasChecked ? '下一词' : '检查'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
          Text('听写测试', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
          const Spacer(),
          Text('正确 $_correctCount',
              style: MistralTypography.caption.copyWith(color: Colors.green)),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
