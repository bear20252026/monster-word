// 学习伴侣 AI 化 · 记忆沉淀器（core/application，中性，守 R-core）。
//
// 把学习快照沉淀为事实层记忆（幂等 upsert），供对话/主动陪伴注入上下文。
// 近期层提取本次留规则接口（recordRecent），真实 LLM 提取待接入后增强。
// 人格层读性格设置由调用方注入，curator 不感知业务端口。
import 'package:word_app/core/application/monster_memory_port.dart';

/// 中性学习快照（由 companion 装配从学习端口换算注入，curator 不 import features）。
class LearningSnapshot {
  const LearningSnapshot({
    required this.totalCheckinDays,
    required this.streakDays,
    required this.todayLearned,
    required this.dailyGoal,
    required this.dueCount,
    required this.coinBalance,
  });

  final int totalCheckinDays;
  final int streakDays;
  final int todayLearned;
  final int dailyGoal;
  final int dueCount;
  final int coinBalance;
}

class MonsterMemoryCurator {
  const MonsterMemoryCurator(this._memory);

  final MonsterMemoryPort _memory;

  /// 事实层键（单一来源）。
  static const String factCheckinDays = 'total_checkin_days';
  static const String factStreak = 'streak_days';
  static const String factTodayProgress = 'today_progress';
  static const String factDue = 'due_count';
  static const String factCoins = 'coin_balance';

  /// 沉淀学习快照到事实层（幂等：同键覆盖）。失败由 DAO 兜底，不阻断。
  Future<void> ingestLearningSnapshot(LearningSnapshot s) async {
    await _memory.put(MemoryKind.fact, factCheckinDays, '累计签到 ${s.totalCheckinDays} 天');
    await _memory.put(MemoryKind.fact, factStreak, '连续签到 ${s.streakDays} 天');
    await _memory.put(MemoryKind.fact, factTodayProgress, '今天学了 ${s.todayLearned}/${s.dailyGoal} 词');
    await _memory.put(MemoryKind.fact, factDue, '有 ${s.dueCount} 个词待复习');
    await _memory.put(MemoryKind.fact, factCoins, '攒了 ${s.coinBalance} 枚尖叫币');
  }

  /// 近期层：记录一条对话/事件记忆（规则提取入口；LLM 提取接入后由调用方先提炼再传入）。
  /// [key] 建议用时间戳或事件 id，保证幂等可覆盖。
  Future<void> recordRecent(String key, String content) async {
    await _memory.put(MemoryKind.recent, key, content);
  }

  /// 人格层：沉淀性格/相处模式（调用方读性格设置后注入）。
  Future<void> recordPersona(String key, String content) async {
    await _memory.put(MemoryKind.persona, key, content);
  }

  /// 近期层容量控制（委托端口）：只保留最新 [limit] 条。
  Future<void> trimRecent(int limit) => _memory.trimRecent(limit);

  /// 组装供 LLM 的记忆上下文（事实 + 近期 + 人格，中性文本）。
  Future<String> buildContext({int recentLimit = 5}) async {
    final facts = await _memory.read(MemoryKind.fact);
    final recent = await _memory.read(MemoryKind.recent);
    final persona = await _memory.read(MemoryKind.persona);
    final buf = StringBuffer();
    if (persona.isNotEmpty) {
      buf.writeln('【相处模式】${persona.map((e) => e.content).join('；')}');
    }
    if (facts.isNotEmpty) {
      buf.writeln('【学习近况】${facts.map((e) => e.content).join('；')}');
    }
    if (recent.isNotEmpty) {
      buf.writeln('【最近记忆】${recent.take(recentLimit).map((e) => e.content).join('；')}');
    }
    return buf.toString().trim();
  }
}
