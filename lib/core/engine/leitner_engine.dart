// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// Leitner 学习引擎
// 学习分组：按等级 0-4 分层（listLevel0..4），每组 GROUP_SIZE 个单词
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/core/engine/core_engine.dart';
import 'package:word_app/core/engine/distractor_generator.dart';

/// 学习策略（LearnUtils.LearnStrategy）
class LearnStrategy {
  final int groupSize; // 每组单词数（GROUP_SIZE）
  final int newWordCount; // 新词数量

  const LearnStrategy({this.groupSize = 10, this.newWordCount = 10});
}

/// Leitner 学习引擎
class LeitnerCardEngine extends MwCoreEngine {
  /// 当前学习单词的等级列表（listLevel0..4）
  final List<MwWordProcess> level0 = []; // 新词/未学
  final List<MwWordProcess> level1 = []; // 第1层
  final List<MwWordProcess> level2 = []; // 第2层
  final List<MwWordProcess> level3 = []; // 第3层
  final List<MwWordProcess> level4 = []; // 第4层（最熟）

  final List<MwWordProcess> _finishedLearned = []; // 已完成学习的单词
  final LearnStrategy strategy;
  int _learnedNumber = 0; // 已学数量
  int _currentIndexInGroup = 0;
  List<MwWordProcess> _currentGroup = [];
  List<WordChoicePair> _choicesRandom = [];

  /// 当前选中等级列表（按优先级：先新词 level0，再低层）
  List<MwWordProcess> get _activeList {
    if (level0.isNotEmpty) return level0;
    if (level1.isNotEmpty) return level1;
    if (level2.isNotEmpty) return level2;
    if (level3.isNotEmpty) return level3;
    return level4;
  }

  LeitnerCardEngine({super.eventLabel = 'learn', LearnStrategy? strategy})
    : strategy = strategy ?? const LearnStrategy();

  /// 初始化：填充等级列表（fillTheArray）+ 随机打乱
  void init(List<MwWordProcess> allWords) {
    level0.clear();
    level1.clear();
    level2.clear();
    level3.clear();
    level4.clear();
    _finishedLearned.clear();
    for (final w in allWords) {
      switch (w.level) {
        case 1:
          level1.add(w);
          break;
        case 2:
          level2.add(w);
          break;
        case 3:
          level3.add(w);
          break;
        case 4:
          level4.add(w);
          break;
        default:
          level0.add(w);
      }
    }
    // 每个等级内部随机打乱，确保学习顺序不总是 A→Z
    level0.shuffle();
    level1.shuffle();
    level2.shuffle();
    level3.shuffle();
    level4.shuffle();
    _buildNextGroup();
  }

  /// 构建下一组（逻辑：取 activeList 前 GROUP_SIZE 个）+ 组内打乱
  void _buildNextGroup() {
    final active = _activeList;
    _currentGroup = active.length <= strategy.groupSize
        ? List.from(active)
        : List.from(active.sublist(0, strategy.groupSize));
    // 组内随机打乱，避免每次都是 A→Z 顺序
    _currentGroup.shuffle();
    _currentIndexInGroup = 0;
    updateListChoicesRandom();
  }

  @override
  MwWordProcess? currentWord() {
    if (_currentGroup.isEmpty) return null;
    if (_currentIndexInGroup >= _currentGroup.length) return null;
    final w = _currentGroup[_currentIndexInGroup];
    currentWordProcess = w;
    return w;
  }

  @override
  int finishedNum() => _learnedNumber;

  @override
  DataPreparedState getDataPreparedState() {
    if (_activeList.isEmpty && _finishedLearned.isEmpty) return DataPreparedState.none;
    if (_activeList.isEmpty) return DataPreparedState.finished;
    return DataPreparedState.part;
  }

  @override
  List<WordChoicePair> getListChoicesRandom() => _choicesRandom;

  /// 更新随机选项池（单一真相见 distractor_generator.dart，审计 I3）
  @override
  void updateListChoicesRandom() {
    _choicesRandom = buildRandomFourChoices(currentWord(), [..._currentGroup, ..._finishedLearned]);
  }

  @override
  int getWordMaxLevel() => 4;

  /// 不认识：词降级/标记失败（iDontKnow）
  @override
  void iDontKnow() {
    final w = currentWord();
    if (w == null) return;
    w.fail++;
    w.state = 1;
    w.level = 0;
    _afterRating(w, remember: false);
  }

  /// 模糊（iMayKnow）
  @override
  void iMayKnow() {
    final w = currentWord();
    if (w == null) return;
    w.fail++;
    w.level = max(0, w.level - 1);
    _afterRating(w, remember: false);
  }

  /// 认识（iReallyKnow）
  @override
  void iReallyKnow() {
    final w = currentWord();
    if (w == null) return;
    w.success++;
    w.level = min(4, w.level + 1);
    _afterRating(w, remember: true);
  }

  /// 太简单（tooEasy）
  @override
  void tooEasy() {
    final w = currentWord();
    if (w == null) return;
    w.success++;
    w.level = 4;
    _afterRating(w, remember: true, tooEasy: true);
  }

  /// 评分后处理：移动到下一单词/完成本组
  void _afterRating(MwWordProcess w, {required bool remember, bool tooEasy = false}) {
    _learnedNumber++;
    _finishedLearned.add(w);
    // 从 activeList 移除
    _activeList.remove(w);
    if (tooEasy || _currentIndexInGroup >= _currentGroup.length - 1) {
      // 本组完成，构建下一组
      if (_activeList.isNotEmpty) {
        _buildNextGroup();
      }
    } else {
      _currentIndexInGroup++;
    }
  }

  /// 本组是否结束
  @override
  bool lessonIsOver() => _activeList.isEmpty && _currentGroup.isEmpty;

  /// 是否全部太简单
  @override
  bool isAllTooEasy() => _activeList.every((w) => w.level >= 4);

  @override
  void nextGroup() {
    if (_activeList.isNotEmpty) _buildNextGroup();
  }

  @override
  MwWordProcess? nextWord() {
    _currentIndexInGroup++;
    return currentWord();
  }

  @override
  int remainWordsNum() => _activeList.length;

  @override
  int unFinishedNum() => _currentGroup.length - _currentIndexInGroup;

  int get totalWords => level0.length + level1.length + level2.length + level3.length + level4.length;

  int get learnedNumber => _learnedNumber;

  /// 最大值
  int max(int a, int b) => a > b ? a : b;
  int min(int a, int b) => a < b ? a : b;
}
