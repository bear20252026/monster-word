// 由 Claude 团队生成 | Monster Word App

// 移植自 v3.2 ListWordListenActivity
// 单词听写：播放单词语音，用户拼写练习
import 'package:flutter/material.dart';

import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

class ListWordListenPage extends StatefulWidget {
  const ListWordListenPage({super.key});

  static const routeName = '/word_listen';

  @override
  State<ListWordListenPage> createState() => _ListWordListenPageState();
}

class _ListWordListenPageState extends State<ListWordListenPage> {
  final _inputController = TextEditingController();
  String _currentWord = '';
  String _feedback = '';
  bool _showAnswer = false;
  int _correctCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNextWord();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _loadNextWord() {
    // TODO: 从学习状态获取下一个待听写单词
    setState(() {
      _currentWord = 'example'; // placeholder
      _feedback = '';
      _showAnswer = false;
      _inputController.clear();
    });
  }

  void _checkSpelling() {
    final input = _inputController.text.trim().toLowerCase();
    setState(() {
      _totalCount++;
      if (input == _currentWord.toLowerCase()) {
        _correctCount++;
        _feedback = '✓ 正确！';
      } else {
        _feedback = '✗ 正确答案：$_currentWord';
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 进度
                    Text('$_correctCount / $_totalCount',
                      style: MistralTypography.heading4.copyWith(color: MistralColors.primary)),
                    const SizedBox(height: 32),
                    // 播放按钮
                    GestureDetector(
                      onTap: () {
                        // TODO: 播放单词语音
                      },
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
                      onPressed: () {
                        // TODO: 再次播放
                      },
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
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: skin.colors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: MistralColors.primary, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _checkSpelling(),
                    ),
                    const SizedBox(height: 16),
                    // 反馈
                    if (_showAnswer) ...[
                      Text(_feedback,
                        style: MistralTypography.heading5.copyWith(
                          color: _feedback.startsWith('✓')
                              ? MistralColors.success
                              : MistralColors.danger,
                        )),
                      const SizedBox(height: 16),
                    ],
                    const Spacer(),
                    // 按钮组
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() => _showAnswer = true);
                              setState(() => _feedback = '答案：$_currentWord');
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
                            onPressed: _showAnswer ? _loadNextWord : _checkSpelling,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MistralColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(_showAnswer ? '下一个' : '确认'),
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
