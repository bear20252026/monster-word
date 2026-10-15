// 埋点记录替身：断言「业务侧到底报了什么」。
//
// 放在 test_helpers 下供 learning / book / checkin 的测试复用——各 feature 的埋点
// 断言关心的是同一组调用，重复写四份替身只会让口径悄悄漂移。
//
// 全部方法都是「记录后返回」，不抛异常：真实实现（UsageStatsCollector）在开关关闭时
// 空转、失败时也只记日志，替身保持同样的「调用方无需 try」语义。
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';

class SpyUsageStatsRecorder implements UsageStatsRecorder {
  int studySessions = 0;

  /// 累计上报的答题词次与其中答对数（多次 recordAnswers 累加）。
  int reviewed = 0;
  int correct = 0;

  int newWordsLearned = 0;

  /// 最近一次同步的词书进度（状态量，覆盖写）。
  int? bookWordCount;
  int? bookLearnedCount;

  /// 最近一次同步的连续签到天数。
  int? streakDays;

  int coinsEarned = 0;

  final List<String> moduleOpens = [];

  @override
  Future<void> recordStudySession() async {
    studySessions++;
  }

  @override
  Future<void> recordAnswers({required int reviewed, required int correct}) async {
    this.reviewed += reviewed;
    this.correct += correct;
  }

  @override
  Future<void> recordNewWordsLearned(int count) async {
    newWordsLearned += count;
  }

  @override
  Future<void> syncBookProgress({required int wordCount, required int learned}) async {
    bookWordCount = wordCount;
    bookLearnedCount = learned;
  }

  @override
  Future<void> syncStreak(int days) async {
    streakDays = days;
  }

  @override
  Future<void> recordCoinsEarned(int count) async {
    coinsEarned += count;
  }

  @override
  Future<void> recordModuleOpen(String module) async {
    moduleOpens.add(module);
  }
}
