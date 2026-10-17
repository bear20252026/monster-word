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
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/monster_rhythm.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
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
  const BondRecordResult({
    required this.awarded,
    required this.todayCount,
    required this.pointsBefore,
    required this.pointsAfter,
  });

  /// 本次是否 +1（同源同日只记一次）。
  final bool awarded;

  /// 今日该来源已记次数（含本次；抚摸侧用于「摸太多会不耐烦」的性格判定）。
  final int todayCount;

  /// 本次记账前后的羁绊点数。
  ///
  /// 带上它们是为了让调用方**不必再额外读两次 SP**：完成页原先写的是
  /// `points() → recordFeed() → points()`，三次独立读写（2026-10-17 审计 P2）。
  final int pointsBefore;
  final int pointsAfter;
}

class MonsterBondPrefs {
  MonsterBondPrefs._();

  // 并发说明（2026-10-17 审计 P2 更新）：状态已收进**单个**键（[stateKey]），
  // 一次记账只做一次 setString ⇒ 原先「points 写了但日期没写」的半截窗口消失。
  // 仍然存在的是**读-改-写竞态**：pet/feed 同毫秒并发时两者都读到同一份旧值，
  // 后写者覆盖前者，最坏丢 1 点（与审计前同级，未变差）。
  // 曾试过静态 future 链串行化，但静态链在 testWidgets 的 FakeAsync zone 跨用例
  // 会非确定性悬挂，得不偿失——撤销。真正的互斥留待 zone 安全方案。

  static const String pointsKey = 'monster_bond.points';
  static const String petDayKey = 'monster_bond.pet_day';
  static const String petCountKey = 'monster_bond.pet_count';
  static const String feedDayKey = 'monster_bond.feed_day';
  static const String feedCountKey = 'monster_bond.feed_count';

  /// 单一状态键（2026-10-17 审计 P2 新增）。
  ///
  /// 此前羁绊状态分散在 5 个 SP 键里，一次记账要写 3 次（points / dayKey / countKey），
  /// 三写非原子 ⇒ 崩溃在中间会把当日羁绊点永久吞掉（源码注释里承认过这个窗口）。
  /// 现在整份状态序列化进**一个**键，一次 `setString` 落盘，窗口消失。
  ///
  /// 兼容：本键不存在时从上面 5 个旧键读一次（迁移），此后只写本键；
  /// **旧键保留不删** —— 万一回退旧版本，它能读到迁移前的值（冻结但完整），
  /// 比「读不到 = 归零」安全。
  static const String stateKey = 'monster_bond.state_v1';

  /// 同日抚摸次数达到该值 → 摸烦了（性格：不耐烦台词，羁绊不再增长自然成立）。
  static const int annoyedAfterSessions = 4;

  /// 当前羁绊点数（读取失败按 0 降级——羁绊丢了体验比崩了差）。
  static Future<int> points() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _readState(prefs)['points'] as int? ?? 0;
    } catch (e, s) {
      reportSwallowedError('羁终点读取失败（0 降级）', e, s);
      return 0;
    }
  }

  /// 读整份羁绊状态；`stateKey` 不存在时从 5 个旧键迁移（只读，不写回）。
  static Map<String, dynamic> _readState(SharedPreferences prefs) {
    final raw = prefs.getString(stateKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (e, s) {
        // 损坏就按旧键重建 —— 宁可丢当日计数，也不要把点数丢掉。
        reportSwallowedError('羁绊状态解析失败（回退旧键重建）', e, s);
      }
    }
    return <String, dynamic>{
      'points': prefs.getInt(pointsKey) ?? 0,
      'petDay': prefs.getString(petDayKey),
      'petCount': prefs.getInt(petCountKey) ?? 0,
      'feedDay': prefs.getString(feedDayKey),
      'feedCount': prefs.getInt(feedCountKey) ?? 0,
    };
  }

  /// 记一次抚摸：同日首个会话 +1 羁绊；[todayCount] 为今日抚摸会话总数
  /// （含本次），调用方据此决定是「开心」还是「摸烦了」。
  static Future<BondRecordResult> recordPet({DateTime? at}) => _record('petDay', 'petCount', at: at);

  /// 记一次喂食（完成页结算发币成功即算喂到）：同日 +1。
  static Future<BondRecordResult> recordFeed({DateTime? at}) => _record('feedDay', 'feedCount', at: at);

  static Future<BondRecordResult> _record(String dayField, String countField, {DateTime? at}) =>
      _doRecord(dayField, countField, at: at);

  static Future<BondRecordResult> _doRecord(String dayField, String countField, {DateTime? at}) async {
    final now = at ?? MonsterRhythm.now();
    final today = MonsterSpeech.dayKeyOf(now);
    final prefs = await SharedPreferences.getInstance();
    final state = _readState(prefs);
    final before = state['points'] as int? ?? 0;
    final isSameDay = state[dayField] == today;
    final count = isSameDay ? ((state[countField] as int?) ?? 0) + 1 : 1;
    final awarded = !isSameDay;
    final after = awarded ? before + 1 : before;

    // **一次写入**（2026-10-17 审计 P2）：整份状态一次 setString 落盘，
    // 不再有「points 写了、日期没写」这种半截状态。写失败时抛给调用方，
    // 内存/展示层不前进（不假装记上了）。
    final next = <String, dynamic>{'points': after, dayField: today, countField: count};
    if (!await prefs.setString(stateKey, jsonEncode(next))) {
      throw StateError('羁绊状态写入失败（$dayField/$today）');
    }
    return BondRecordResult(awarded: awarded, todayCount: count, pointsBefore: before, pointsAfter: after);
  }
}
