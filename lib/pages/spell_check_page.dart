// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 spellcheck/SpellCheckFragment + SpellCheckPresenterImp
// 拼写检查：播放音频 → 用户拼写 → 正确/错误反馈
import 'package:flutter/material.dart';

import '../player/audio_players.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class SpellCheckPage extends StatefulWidget {
  final String word;
  final String? phonetic;

  const SpellCheckPage({
    super.key,
    required this.word,
    this.phonetic,
  });

  static const routeName = '/spell_check';

  @override
  State<SpellCheckPage> createState() => _SpellCheckPageState();
}

class _SpellCheckPageState extends State<SpellCheckPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  // 音频通过 playWordAudio 统一播放
  String _result = '';
  bool _isCorrect = false;
  bool _hasChecked = false;
  int _attemptCount = 0;

  @override
  void initState() {
    super.initState();
    // 自动播放单词音频
    WidgetsBinding.instance.addPostFrameCallback((_) => _playAudio());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (widget.word.isEmpty) return;
    try {
      await playWordAudio(widget.word);
    } catch (e) {
      debugPrint('Audio playback error: $e');
    }
  }

  void _check() {
    final input = _controller.text.trim();
    if (input.isEmpty || widget.word.isEmpty) return;

    setState(() {
      _attemptCount++;
      _hasChecked = true;
      if (input.toLowerCase() == widget.word.toLowerCase()) {
        _isCorrect = true;
        _result = '拼写正确！';
      } else {
        _isCorrect = false;
        _result = '拼写错误，正确答案：${widget.word}';
      }
    });
  }

  void _reset() {
    setState(() {
      _controller.clear();
      _result = '';
      _hasChecked = false;
      _isCorrect = false;
    });
    _focusNode.requestFocus();
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 单词提示（隐藏部分字母）
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: MistralColors.cream,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _buildHint(),
                            style: MistralTypography.heading2.copyWith(
                              color: MistralColors.ink,
                              letterSpacing: 4,
                            ),
                          ),
                          if (widget.phonetic != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '/${widget.phonetic}/',
                              style: MistralTypography.body.copyWith(color: MistralColors.slate),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // 播放音频按钮
                          GestureDetector(
                            onTap: _playAudio,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: MistralColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.volume_up, color: MistralColors.primary, size: 20),
                                  const SizedBox(width: 6),
                                  Text('播放发音',
                                    style: MistralTypography.caption.copyWith(
                                      color: MistralColors.primary,
                                      fontWeight: FontWeight.w500,
                                    )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('尝试次数: $_attemptCount',
                      style: MistralTypography.micro.copyWith(color: skin.colors.text3)),
                    const SizedBox(height: 32),
                    // 输入框
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textAlign: TextAlign.center,
                      style: MistralTypography.heading3.copyWith(color: skin.colors.text1),
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        hintText: '请输入完整单词',
                        hintStyle: MistralTypography.body.copyWith(color: skin.colors.text3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: skin.colors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: MistralColors.primary, width: 2),
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
                          color: _isCorrect
                              ? MistralColors.success.withValues(alpha: 0.1)
                              : MistralColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: _isCorrect ? MistralColors.success : MistralColors.danger,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isCorrect ? Icons.check_circle : Icons.error,
                              color: _isCorrect ? MistralColors.success : MistralColors.danger,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(_result,
                                style: MistralTypography.bodyBold.copyWith(
                                  color: _isCorrect ? MistralColors.success : MistralColors.danger,
                                )),
                            ),
                          ],
                        ),
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
                                _hasChecked = true;
                                _result = '答案：${widget.word}';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: skin.colors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('查看答案'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _hasChecked ? _reset : _check,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MistralColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(_hasChecked ? '再试一次' : '检查'),
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
    );
  }

  String _buildHint() {
    final word = widget.word;
    if (word.isEmpty) return '';
    if (word.length <= 2) return word;
    // 显示首尾字母，中间用下划线
    final middle = '_' * (word.length - 2);
    return '${word[0]}$middle${word[word.length - 1]}';
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
          Text('拼写检查', style: MistralTypography.heading5.copyWith(color: skin.colors.text1)),
        ],
      ),
    );
  }
}
