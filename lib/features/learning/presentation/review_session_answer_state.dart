import 'dart:async';

/// 正式复习选择候选项的结果。
enum ReviewChoiceSelection { correct, wrong }

/// 正式复习答题交互状态。
///
/// 此类仅维护“看答案”和错误候选的短暂反馈；当前题目、候选项、引擎推进和
/// FSRS 评分仍由 [ReviewSessionState] 编排。反馈发生变化或计时器结束时，
/// [onChanged] 通知宿主状态刷新展示快照。
class ReviewSessionAnswerState {
  ReviewSessionAnswerState({required this._onChanged, this._wrongChoiceFeedback = const Duration(milliseconds: 300)});

  final void Function() _onChanged;
  final Duration _wrongChoiceFeedback;
  Timer? _wrongChoiceTimer;
  bool _showAnswer = false;
  String? _selectedWrongChoice;

  bool get showAnswer => _showAnswer;
  String? get selectedWrongChoice => _selectedWrongChoice;
  bool isWrongChoiceSelected(String word) => _selectedWrongChoice == word;

  /// 返回正确或错误选择；正确选择的评分推进由宿主继续处理。
  ReviewChoiceSelection selectChoice({required String selectedWord, required String correctWord}) {
    if (selectedWord == correctWord) return ReviewChoiceSelection.correct;

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
    _showAnswer = false;
    _selectedWrongChoice = null;
  }

  void dispose() {
    _wrongChoiceTimer?.cancel();
    _wrongChoiceTimer = null;
  }

  void _clearWrongChoice() {
    _wrongChoiceTimer = null;
    if (_selectedWrongChoice == null) return;
    _selectedWrongChoice = null;
    _onChanged();
  }
}
