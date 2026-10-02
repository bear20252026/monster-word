import 'package:word_app/tokens/motion_tokens.dart';

import 'dart:async';

/// 正式复习选择候选项的结果。
enum ReviewChoiceSelection { correct, wrong }

/// 正式复习答题交互状态。
///
/// 此类维护“看答案”、错误候选的短暂反馈与正确选择的反馈驻留；当前题目、
/// 候选项、引擎推进和 FSRS 评分仍由 [ReviewSessionState] 编排——正确选择
/// 先展示对勾/彩带驻留窗口（体验对齐学习页），驻留结束经
/// [onCorrectFeedbackElapsed] 交还宿主推进，驻留期间重复选择被忽略。
/// 反馈发生变化或计时器结束时，[onChanged] 通知宿主刷新展示快照。
class ReviewSessionAnswerState {
  ReviewSessionAnswerState({
    required this._onChanged,
    this.onCorrectFeedbackElapsed,
    this._wrongChoiceFeedback = MotionDurations.slow,
    this._correctFeedback = const Duration(milliseconds: 600),
  });

  final void Function() _onChanged;

  /// 正确反馈驻留结束时通知宿主推进评分（对齐学习页的答对反馈时刻）。
  final void Function()? onCorrectFeedbackElapsed;
  final Duration _wrongChoiceFeedback;
  final Duration _correctFeedback;
  Timer? _wrongChoiceTimer;
  Timer? _correctTimer;
  bool _showAnswer = false;
  String? _selectedWrongChoice;
  bool _correctRevealed = false;

  bool get showAnswer => _showAnswer;
  String? get selectedWrongChoice => _selectedWrongChoice;

  /// 本题已答对并处于反馈驻留窗口（卡片变绿 + 对勾 + 彩带）。
  bool get correctRevealed => _correctRevealed;
  bool isWrongChoiceSelected(String word) => _selectedWrongChoice == word;

  /// 返回正确或错误选择；正确选择的评分推进经反馈驻留后由宿主继续处理。
  ReviewChoiceSelection selectChoice({required String selectedWord, required String correctWord}) {
    // 本题已答对：驻留期内任何后续选择都被忽略（防连点/误触他项）
    if (_correctRevealed) return ReviewChoiceSelection.correct;

    if (selectedWord == correctWord) {
      _correctRevealed = true;
      _correctTimer?.cancel();
      _correctTimer = Timer(_correctFeedback, _finishCorrectFeedback);
      _onChanged();
      return ReviewChoiceSelection.correct;
    }

    _wrongChoiceTimer?.cancel();
    _selectedWrongChoice = selectedWord;
    _wrongChoiceTimer = Timer(_wrongChoiceFeedback, _clearWrongChoice);
    _onChanged();
    return ReviewChoiceSelection.wrong;
  }

  /// 只在首次揭示答案时通知宿主，避免重复点击造成无意义重建。
  bool revealAnswer() {
    if (_showAnswer) return false;
    _showAnswer = true;
    _onChanged();
    return true;
  }

  /// 在题目推进、手动掌握或重新初始化时清理上一题的交互快照。
  void reset() {
    _wrongChoiceTimer?.cancel();
    _wrongChoiceTimer = null;
    _correctTimer?.cancel();
    _correctTimer = null;
    _showAnswer = false;
    _selectedWrongChoice = null;
    _correctRevealed = false;
  }

  void dispose() {
    _wrongChoiceTimer?.cancel();
    _wrongChoiceTimer = null;
    _correctTimer?.cancel();
    _correctTimer = null;
  }

  void _clearWrongChoice() {
    _wrongChoiceTimer = null;
    if (_selectedWrongChoice == null) return;
    _selectedWrongChoice = null;
    _onChanged();
  }

  void _finishCorrectFeedback() {
    _correctTimer = null;
    onCorrectFeedbackElapsed?.call();
  }
}
