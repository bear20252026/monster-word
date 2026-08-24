// 由 Claude 团队生成 | Monster Word App
// 备考速刷：针对考试的快速复习模式
// 特点：高频词汇优先、限时模式、统计正确率
import 'dart:async';
import 'package:flutter/material.dart';

import '../data/wordbook_database.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

/// 考试类型
enum ExamType {
  cet4('四级高频', 30),
  cet6('六级高频', 25),
  gaokao('高考必备', 35),
  kaoyan('考研核心', 20),
  ielts('雅思核心', 20),
  toefl('托福核心', 20);

  final String label;
  final int timeLimit; // 秒/词
  const ExamType(this.label, this.timeLimit);
}

/// 速刷统计
class QuickReviewStats {
  int total = 0;
  int correct = 0;
  int wrong = 0;
  int skipped = 0;
  int totalTime = 0; // 秒

  double get accuracy => total == 0 ? 0 : correct / total;
  String get accuracyPercent => '${(accuracy * 100).toStringAsFixed(1)}%';
  String get timeFormatted {
    final min = totalTime ~/ 60;
    final sec = totalTime % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class ExamQuickReviewPage extends StatefulWidget {
  const ExamQuickReviewPage({super.key});
  static const routeName = '/exam_quick_review';

  @override
  State<ExamQuickReviewPage> createState() => _ExamQuickReviewPageState();
}

class _ExamQuickReviewPageState extends State<ExamQuickReviewPage> {
  ExamType _selectedExam = ExamType.cet4;
  bool _started = false;
  bool _finished = false;

  // 词库数据
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<String> _choices = [];
  int? _selectedChoice;
  bool _isLoading = true;

  // 计时器
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _wordStartTime = 0;

  // 统计
  final QuickReviewStats _stats = QuickReviewStats();

  // 选项背景色（装饰性，无全局 token，页面级常量）
  static const Color _optionGreen = Color(0xFFE8F5E9);
  static const Color _optionBlue = Color(0xFFE3F2FD);
  static const Color _optionOrange = Color(0xFFFFF3E0);
  static const Color _optionPurple = Color(0xFFF3E5F5);

  final List<Color> _optionColors = [
    _optionGreen,
    _optionBlue,
    _optionOrange,
    _optionPurple,
  ];

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    try {
      // 加载高频词汇（按词频排序）
      final words = await WordBookDatabase.instance.searchWords('', limit: 200);
      // 按词频排序（模拟高频词优先）
      words.sort((a, b) => b.id.compareTo(a.id)); // 用ID模拟词频
      setState(() {
        _words = words.take(50).toList(); // 速刷模式只取50个词
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _startReview() {
    setState(() {
      _started = true;
      _finished = false;
      _currentIndex = 0;
      _stats.total = _words.length;
      _stats.correct = 0;
      _stats.wrong = 0;
      _stats.skipped = 0;
      _stats.totalTime = 0;
      _elapsedSeconds = 0;
    });
    _generateChoices();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          _stats.totalTime = _elapsedSeconds;
        });
      }
    });
    _wordStartTime = _elapsedSeconds;
  }

  void _generateChoices() {
    if (_currentIndex >= _words.length) return;
    final current = _words[_currentIndex];
    final choices = <String>[current.interpret.split('\n').first];

    // 生成干扰项（从其他词的释义中随机选3个）
    final otherWords = _words.where((w) => w.id != current.id).toList();
    otherWords.shuffle();
    for (var i = 0; i < 3 && i < otherWords.length; i++) {
      choices.add(otherWords[i].interpret.split('\n').first);
    }
    choices.shuffle();

    setState(() {
      _choices = choices;
      _selectedChoice = null;
      _showAnswer = false;
    });
  }

  void _selectChoice(int index) {
    if (_showAnswer) return;

    final current = _words[_currentIndex];
    final isCorrect = _choices[index] == current.interpret.split('\n').first;

    setState(() {
      _selectedChoice = index;
      _showAnswer = true;
      if (isCorrect) {
        _stats.correct++;
      } else {
        _stats.wrong++;
      }
    });
  }

  void _nextWord() {
    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _generateChoices();
      _wordStartTime = _elapsedSeconds;
    } else {
      _finishReview();
    }
  }

  void _skipWord() {
    _stats.skipped++;
    _nextWord();
  }

  void _finishReview() {
    _timer?.cancel();
    setState(() {
      _finished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: skin.colors.pageBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_started) {
      return _buildExamSelection(skin);
    }

    if (_finished) {
      return _buildResultPage(skin);
    }

    return _buildReviewPage(skin);
  }

  /// 考试类型选择页面
  Widget _buildExamSelection(SkinSystem skin) {
    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 导航栏
            Container(
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
                  Text(
                    '备考速刷',
                    style: MistralTypography.heading5.copyWith(color: skin.colors.text1),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: skin.colors.divider),
            // 说明
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.speed, size: 64, color: MistralColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    '快速复习高频词汇',
                    style: MistralTypography.heading4.copyWith(color: skin.colors.text1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '限时答题，统计正确率，高效备考',
                    style: MistralTypography.body.copyWith(color: skin.colors.text3),
                  ),
                ],
              ),
            ),
            // 考试类型选择
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: ExamType.values.map((exam) {
                  final selected = _selectedExam == exam;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedExam = exam),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selected
                            ? MistralColors.primary.withValues(alpha: 0.1)
                            : skin.colors.cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: selected ? MistralColors.primary : skin.colors.divider,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getExamIcon(exam),
                            color: selected ? MistralColors.primary : skin.colors.text3,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exam.label,
                                  style: MistralTypography.body.copyWith(
                                    color: skin.colors.text1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '每词 ${exam.timeLimit} 秒',
                                  style: MistralTypography.micro.copyWith(color: skin.colors.text3),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle, color: MistralColors.primary),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // 开始按钮
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _startReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MistralColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Text(
                    '开始速刷',
                    style: MistralTypography.buttonMd.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 速刷页面
  Widget _buildReviewPage(SkinSystem skin) {
    final current = _words[_currentIndex];
    final wordTime = _elapsedSeconds - _wordStartTime;
    final timeLimit = _selectedExam.timeLimit;
    final isOvertime = wordTime > timeLimit;

    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // 导航栏
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: skin.colors.text1,
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.pop(context);
                    },
                  ),
                  // 进度条
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / _words.length,
                      backgroundColor: skin.colors.divider,
                      valueColor: AlwaysStoppedAnimation(MistralColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 计时器
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOvertime ? skin.colors.danger.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _stats.timeFormatted,
                      style: MistralTypography.body.copyWith(
                        color: isOvertime ? skin.colors.danger : skin.colors.text1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            // 统计栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('正确', '${_stats.correct}', skin.colors.success),
                  _buildStatItem('错误', '${_stats.wrong}', skin.colors.danger),
                  _buildStatItem('跳过', '${_stats.skipped}', MistralColors.warning),
                  _buildStatItem('正确率', _stats.accuracyPercent, MistralColors.primary),
                ],
              ),
            ),
            Container(height: 1, color: skin.colors.divider),
            // 单词展示
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // 单词
                    Text(
                      current.word,
                      style: MistralTypography.heading1.copyWith(
                        color: skin.colors.text1,
                        fontSize: 40,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 音标
                    if (current.usPron.isNotEmpty)
                      Text(
                        '美 /${current.usPron}/',
                        style: MistralTypography.body.copyWith(color: skin.colors.text3),
                      ),
                    const SizedBox(height: 32),
                    // 选项
                    ...List.generate(_choices.length, (index) {
                      return _buildChoiceItem(index, skin);
                    }),
                  ],
                ),
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: skin.colors.cardBg,
                border: Border(top: BorderSide(color: skin.colors.divider)),
              ),
              child: Row(
                children: [
                  // 跳过按钮
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _showAnswer ? null : _skipWord,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('跳过'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 下一词按钮
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _showAnswer ? _nextWord : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MistralColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(_currentIndex < _words.length - 1 ? '下一词' : '完成'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceItem(int index, SkinSystem skin) {
    final current = _words[_currentIndex];
    final isCorrect = _choices[index] == current.interpret.split('\n').first;
    final isSelected = _selectedChoice == index;
    final showResult = _showAnswer;

    Color bgColor;
    Color borderColor;
    if (showResult) {
      if (isCorrect) {
        bgColor = skin.colors.success.withValues(alpha: 0.1);
        borderColor = skin.colors.success;
      } else if (isSelected && !isCorrect) {
        bgColor = skin.colors.danger.withValues(alpha: 0.1);
        borderColor = skin.colors.danger;
      } else {
        bgColor = _optionColors[index % _optionColors.length];
        borderColor = skin.colors.divider;
      }
    } else {
      bgColor = _optionColors[index % _optionColors.length];
      borderColor = skin.colors.divider;
    }

    return GestureDetector(
      onTap: () => _selectChoice(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? borderColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                    color: isSelected ? Colors.white : skin.colors.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _choices[index],
                style: MistralTypography.body.copyWith(color: skin.colors.text1),
              ),
            ),
            if (showResult && isCorrect)
              Icon(Icons.check_circle, color: skin.colors.success, size: 20),
            if (showResult && isSelected && !isCorrect)
              Icon(Icons.cancel, color: skin.colors.danger, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: MistralTypography.heading5.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: MistralTypography.micro.copyWith(color: MistralColors.muted),
        ),
      ],
    );
  }

  /// 结果页面
  Widget _buildResultPage(SkinSystem skin) {
    return Scaffold(
      backgroundColor: skin.colors.pageBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 图标
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: MistralColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _stats.accuracy >= 0.8 ? Icons.emoji_events : Icons.speed,
                    size: 48,
                    color: MistralColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '速刷完成！',
                  style: MistralTypography.heading3.copyWith(color: skin.colors.text1),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedExam.label,
                  style: MistralTypography.body.copyWith(color: skin.colors.text3),
                ),
                const SizedBox(height: 32),
                // 统计卡片
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: skin.colors.cardBg,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: skin.colors.divider),
                  ),
                  child: Column(
                    children: [
                      _buildResultRow('总词数', '${_stats.total}', skin),
                      _buildResultRow('正确', '${_stats.correct}', skin),
                      _buildResultRow('错误', '${_stats.wrong}', skin),
                      _buildResultRow('跳过', '${_stats.skipped}', skin),
                      const Divider(),
                      _buildResultRow('正确率', _stats.accuracyPercent, skin,
                          valueColor: _stats.accuracy >= 0.8 ? skin.colors.success : skin.colors.danger),
                      _buildResultRow('用时', _stats.timeFormatted, skin),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // 按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _started = false;
                            _finished = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: const Text('重新选择'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MistralColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: const Text('再来一轮'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '返回首页',
                    style: MistralTypography.body.copyWith(color: skin.colors.text3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, SkinSystem skin,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: MistralTypography.body.copyWith(color: skin.colors.text2)),
          Text(
            value,
            style: MistralTypography.body.copyWith(
              color: valueColor ?? skin.colors.text1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getExamIcon(ExamType type) {
    switch (type) {
      case ExamType.cet4:
        return Icons.school;
      case ExamType.cet6:
        return Icons.school;
      case ExamType.gaokao:
        return Icons.menu_book;
      case ExamType.kaoyan:
        return Icons.science;
      case ExamType.ielts:
        return Icons.language;
      case ExamType.toefl:
        return Icons.language;
    }
  }
}
