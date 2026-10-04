// MonsterBondPrefs：怪兽亲密度（羁绊）的单一读写出口（W4.5 宠物化）。
//
// 宠物感的第二根支柱：关系会升温。抚摸（小屋撸怪）与喂食（完成页喂币
// 结算）各 +1/日——多摸多得的是当下反应，升羁绊的是每天来看它这件事
// （防刷：同源同日只记一次）。羁绊与尖叫币经济完全解耦：不产出、不消耗
// 任何货币，只解锁台词/动作层（世界观红线：进化绝不与金币挂钩同理）。
//
// 放 core/utils 的原因：写入方跨 account（完成页喂食）与 settings（小屋
// 抚摸），同族怪兽原语（monster_speech / monster_mood / monster_identity）
// 都收在 core/utils。
// 世界观红线：羁绊等级只进展示与台词选择，绝不参与任何数值计算。
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/monster_rhythm.dart';
import 'package:word_app/core/utils/monster_speech.dart';

/// 羁绊等级（阈值 [min] 含：points >= min 即达该级）。
class BondLevel {
  const BondLevel(this.min, this.name);

  /// 达到该级所需的最低羁绊点数。
  final int min;

  /// 等级名（门牌/台词用，温暖不评判）。
  final String name;

  /// 等级阶梯（升序；points 落在哪一档取「min ≤ points 的最高档」）。
  static const List<BondLevel> catalog = [
    BondLevel(0, '初识'),
    BondLevel(7, '熟络'),
    BondLevel(30, '亲密'),
    BondLevel(90, '形影不离'),
    BondLevel(180, '灵魂共振'),
  ];

  /// 纯函数：点数 → 当前等级。
  static BondLevel levelOf(int points) {
    var level = catalog.first;
    for (final l in catalog) {
      if (points >= l.min) level = l;
    }
    return level;
  }

  /// 下一级所需点数；已满级返回 null（供 UI 显示「还差 N 点」或不显示）。
  static int? nextMin(int points) {
    for (final l in catalog) {
      if (points < l.min) return l.min;
    }
    return null;
  }
}

/// 一次抚摸/喂食的记账结果。
class BondRecordResult {
  const BondRecordResult({required this.awarded, required this.todayCount});

  /// 本次是否 +1（同源同日只记一次）。
  final bool awarded;

  /// 今日该来源已记次数（含本次；抚摸侧用于「摸太多会不耐烦」的性格判定）。
  final int todayCount;
}

class MonsterBondPrefs {
  MonsterBondPrefs._();

  static const String pointsKey = 'monster_bond.points';
  static const String petDayKey = 'monster_bond.pet_day';
  static const String petCountKey = 'monster_bond.pet_count';
  static const String feedDayKey = 'monster_bond.feed_day';
  static const String feedCountKey = 'monster_bond.feed_count';

  /// 同日抚摸次数达到该值 → 摸烦了（性格：不耐烦台词，羁绊不再增长自然成立）。
  static const int annoyedAfterSessions = 4;

  /// 当前羁绊点数（读取失败按 0 降级——羁绊丢了体验比崩了差）。
  static Future<int> points() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(pointsKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 记一次抚摸：同日首个会话 +1 羁绊；[todayCount] 为今日抚摸会话总数
  /// （含本次），调用方据此决定是「开心」还是「摸烦了」。
  static Future<BondRecordResult> recordPet({DateTime? at}) => _record(petDayKey, petCountKey, at: at);

  /// 记一次喂食（完成页结算发币成功即算喂到）：同日 +1。
  static Future<BondRecordResult> recordFeed({DateTime? at}) => _record(feedDayKey, feedCountKey, at: at);

  static Future<BondRecordResult> _record(String dayKey, String countKey, {DateTime? at}) async {
    final now = at ?? MonsterRhythm.now();
    final today = MonsterSpeech.dayKeyOf(now);
    final prefs = await SharedPreferences.getInstance();
    final isSameDay = prefs.getString(dayKey) == today;
    final count = isSameDay ? (prefs.getInt(countKey) ?? 0) + 1 : 1;
    await prefs.setString(dayKey, today);
    await prefs.setInt(countKey, count);
    var awarded = false;
    if (!isSameDay) {
      await prefs.setInt(pointsKey, (prefs.getInt(pointsKey) ?? 0) + 1);
      awarded = true;
    }
    return BondRecordResult(awarded: awarded, todayCount: count);
  }
}
