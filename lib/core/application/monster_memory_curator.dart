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

  /// 审计 B5（2026-11-15）：用户原话沉淀前消毒——折叠换行/控制字符、中和
  /// 指令覆写与角色标记、截断长度，降低持久化 prompt 注入面（记忆会被注入 system prompt）。
  static String sanitizeMemory(String raw) {
    var s = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ').trim();
    // 审计 R15（2026-11-16）：零宽/双向控制字符替换为**空格**（不是删除）——
    // 它们能把敏感词拆开绕过下方正则（「act\u200Bas」），删成空串会粘成 actas
    // 反而漏检；替换为空格后词边界仍命中，正常文本只多一个无害空格。
    s = s.replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]'), ' ');
    // 第三轮 T8：截断**前置**——修饰词组 `(...|\s)*` 与前后 `\s*` 对空白段
    // 歧义切分存在多项式回溯，超长输入（无长度上限的用户原话）可卡顿。
    // 先截到 400（最终上限 200 的 2 倍，留过滤标记展开余量）再跑正则，
    // 回溯规模有界；截断语义与旧版一致（最终仍 200+省略号）。
    if (s.length > 400) s = s.substring(0, 400);
    // 审计 R15：英文关键词加词边界——旧实现子串匹配把「in fact as」里的 fact as
    // 误当 act as 过滤；修饰词组改可重复（ignore all previous instructions 旧版漏检）。
    s = s.replaceAll(
      RegExp(
        r'(忽略|无视|\bforget\b|\bignore\b)\s*(之前|上面|以上|previous|above|all|\s)*\s*(的)?\s*(指令|指示|规则|instructions?|rules?)',
        caseSensitive: false,
      ),
      '［已过滤］',
    );
    // 审计 R15：「你现在是」加否定 lookahead——「你现在是不是饿了」是正常疑问句，
    // 旧版子串命中误过滤；真正的角色覆写（你现在是海盗）仍命中。
    // 第三轮 T7：lookahead 扩「否」——「你现在是否饿了」同样正常疑问句，
    // 旧版只豁免「不」仍误杀；「是不是/是否」都放行。
    s = s.replaceAll(
      RegExp(r'(system\s*prompt|系统提示|你现在是(?!不|否)|\byou are now\b|\bact as\b|扮演)', caseSensitive: false),
      '［已过滤］',
    );
    if (s.length > 200) s = '${s.substring(0, 200)}…';
    return s;
  }

  /// 近期层：记录一条对话/事件记忆（规则提取入口；LLM 提取接入后由调用方先提炼再传入）。
  /// [key] 建议用时间戳或事件 id，保证幂等可覆盖。
  Future<void> recordRecent(String key, String content) async {
    await _memory.put(MemoryKind.recent, key, sanitizeMemory(content));
  }

  /// 人格层：沉淀性格/相处模式（调用方读性格设置后注入）。
  /// 审计 R15（2026-11-16）：与近期层同口径消毒——此前直写未过滤，接入 persona
  /// 调用方即成 prompt 注入绕过口（buildContext 对 persona 也不再补消毒）。
  Future<void> recordPersona(String key, String content) async {
    await _memory.put(MemoryKind.persona, key, sanitizeMemory(content));
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
      // 审计 R15：存量 persona 可能含未消毒内容（旧版直写），注入前再消毒一次。
      buf.writeln('【相处模式】${persona.map((e) => sanitizeMemory(e.content)).join('；')}');
    }
    if (facts.isNotEmpty) {
      buf.writeln('【学习近况】${facts.map((e) => e.content).join('；')}');
    }
    if (recent.isNotEmpty) {
      // 审计 B5：存量记忆可能含未消毒内容，注入前再消毒一次。
      buf.writeln('【最近记忆】${recent.take(recentLimit).map((e) => sanitizeMemory(e.content)).join('；')}');
    }
    return buf.toString().trim();
  }
}
