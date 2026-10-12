// P1-01 余项：SQLite 降级日志通用设施。
//
// 背景：user_data.db 运行中可能因锁竞争 / IO 故障 / 库损坏导致单次写失败。
// 此前各写路径的统一处理是「回滚内存 + 上报」——用户这一次的收藏 / 例句收藏 /
// 加生词就此丢失（内存回滚保证了不出现「界面说成功、重启后消失」的分叉，但
// 代价是把一次真实用户意图直接丢弃）。
//
// FSRS 评分已用 `fsrs6_degraded_journal_v1` 证明另一条路可行：把「用户意图」
// 落 SP StringList（逐条 JSON），SQLite 恢复后按序幂等回放。本文件把该模式
// 抽为通用实现，供收藏 / 例句收藏 / 生词本复用（MW-22 同口径外推）。
//
// 设计要点：
// - 幂等键由各领域自行给出（单词文本 / word_id:sentence_id / word_id），回放侧
//   用 INSERT OR IGNORE / REPLACE 去重，重复回放不产生额外副作用。
// - 容量上限保护 SP 体积；超限丢最旧并**上报**（可观测，不静默丢数据）。
// - 单条 JSON 损坏 → 跳过并上报（不可读数据不能永久阻塞整条回放链）；
//   单条 apply 失败 → 整体保留，下次启动重试（与 FSRS 口径一致）。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';

class DegradedJournal {
  const DegradedJournal({required this.key, required this.domain, this.cap = 2000});

  /// SP 键名（每个领域独占，互不干扰）。
  final String key;

  /// 上报与日志中的领域标识（如「单词收藏」）。
  final String domain;

  /// 容量上限：极端积压时丢最旧，保护 SP 体积。
  final int cap;

  /// 追加一条用户意图。返回 false 表示**连日志都写不进**（磁盘满 / SP 不可用），
  /// 调用方必须按硬失败处理（回滚内存 + 如实提示），不得假装成功。
  Future<bool> append(Map<String, Object?> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final journal = prefs.getStringList(key) ?? <String>[];
      journal.add(jsonEncode({...entry, 'savedAt': DateTime.now().toIso8601String()}));
      var kept = journal;
      if (kept.length > cap) {
        kept = kept.sublist(kept.length - cap);
        reportSwallowedError(
          '$domain 降级日志超上限($cap)，丢弃最旧 ${journal.length - kept.length} 条',
          StateError('degraded journal overflow: $key'),
          StackTrace.current,
        );
      }
      return await prefs.setStringList(key, kept);
    } catch (error, stack) {
      reportSwallowedError('$domain 降级日志写入失败（本次操作硬失败）', error, stack);
      return false;
    }
  }

  /// 读取全部待回放条目（按写入顺序）。损坏条目跳过并上报。
  Future<List<Map<String, dynamic>>> entries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(key);
      if (raw == null || raw.isEmpty) return const [];
      final result = <Map<String, dynamic>>[];
      for (final line in raw) {
        try {
          result.add(jsonDecode(line) as Map<String, dynamic>);
        } catch (error, stack) {
          reportSwallowedError('$domain 降级日志单条解析失败（跳过该条）', error, stack);
        }
      }
      return result;
    } catch (error, stack) {
      reportSwallowedError('$domain 降级日志读取失败（保留待下次）', error, stack);
      return const [];
    }
  }

  /// 按序回放。全部成功才清空日志；任一条 [apply] 抛错则整体保留，下次启动重试。
  ///
  /// [apply] 必须幂等（同一条重复执行结果相同），因为回放可能因中途失败而整体重来。
  /// 返回成功应用的条数。
  Future<int> replay(Future<void> Function(Map<String, dynamic> entry) apply) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(key);
      if (raw == null || raw.isEmpty) return 0;
      var applied = 0;
      for (final line in raw) {
        Map<String, dynamic> entry;
        try {
          entry = jsonDecode(line) as Map<String, dynamic>;
        } catch (error, stack) {
          reportSwallowedError('$domain 降级日志单条解析失败（跳过该条）', error, stack);
          applied++;
          continue;
        }
        try {
          await apply(entry);
          applied++;
        } catch (error, stack) {
          reportSwallowedError('$domain 降级日志回放中断（已应用 $applied 条，日志整体保留待下次重试）', error, stack);
          return applied;
        }
      }
      await prefs.remove(key);
      if (applied > 0) {
        reportSwallowedError(
          '$domain 降级日志回放完成（applied=$applied）',
          StateError('degraded journal replayed: $key'),
          StackTrace.current,
        );
      }
      return applied;
    } catch (error, stack) {
      reportSwallowedError('$domain 降级日志回放读取失败（保留日志下次重试）', error, stack);
      return 0;
    }
  }

  /// 待回放条数（诊断 / 测试用）。
  Future<int> pendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(key)?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
