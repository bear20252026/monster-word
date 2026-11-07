import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/progress/application/xp_repository.dart';
import 'package:word_app/features/progress/domain/xp_curve.dart';

/// 一次 XP 结算的结果（结算页据此显示「+N 经验」与升级庆祝）。
class XpGrantResult {
  const XpGrantResult({required this.awarded, required this.previous, required this.snapshot});

  final int awarded;
  final XpSnapshot previous;
  final XpSnapshot snapshot;

  bool get leveledUp => snapshot.level > previous.level;

  int? get newLevel => leveledUp ? snapshot.level : null;
}

/// XP / 等级状态（M3）。
///
/// 只做两件事：把会话 XP 幂等地累加进 `xp_state`，以及把「升级庆祝只播一次」
/// 记在 SP。等级不参与商店/兑换，任何 UI 只读 [snapshot]。
class XpStore extends ChangeNotifier {
  XpStore({required this.repository});

  final XpRepository repository;

  static const String _celebratedLevelKey = 'xp.celebrated.level';

  XpSnapshot _snapshot = XpSnapshot.zero;
  bool _loaded = false;
  Future<void> _queue = Future<void>.value();

  bool get loaded => _loaded;

  XpSnapshot get snapshot => _snapshot;

  int get level => _snapshot.level;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _queue.then((_) => action());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> ensureLoaded() {
    return _serialized(() async {
      if (_loaded) return;
      final total = await repository.loadTotalXp();
      // 等级按曲线重算，不只信表里的缓存（曲线调整/旧库都能自洽）。
      _snapshot = XpSnapshot.fromTotal(total);
      _loaded = true;
      notifyListeners();
    });
  }

  /// 结算一局：答对 [correct] 词 + 完成奖励（只有 answered > 0 才算完成一局）。
  ///
  /// [eventKey] 是本局的幂等键（`xp:learn:<sessionId>` / `xp:review:<sessionId>`）：
  /// 同一局重复结算不会重复加经验，此时返回 awarded = 0。
  Future<XpGrantResult> grantSession({
    required String eventKey,
    required int answered,
    required int correct,
    required bool completed,
  }) {
    return _serialized(() async {
      if (!_loaded) {
        final total = await repository.loadTotalXp();
        _snapshot = XpSnapshot.fromTotal(total);
        _loaded = true;
      }
      final previous = _snapshot;
      final awarded = xpForSession(correct: correct, completed: completed && answered > 0);
      if (awarded <= 0) {
        return XpGrantResult(awarded: 0, previous: previous, snapshot: previous);
      }
      final newTotal = await repository.addXpOnce(eventKey: eventKey, delta: awarded);
      if (newTotal == null) {
        // 同一局已经结算过：静默跳过，不重复发经验、不重复庆祝。
        return XpGrantResult(awarded: 0, previous: previous, snapshot: previous);
      }
      _snapshot = XpSnapshot.fromTotal(newTotal);
      notifyListeners();
      return XpGrantResult(awarded: awarded, previous: previous, snapshot: _snapshot);
    });
  }

  /// 「升级只庆祝一次」：同一等级只返回一次 true；跨级也只在最高等级庆祝一次。
  Future<bool> claimLevelUpCelebration(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final celebrated = prefs.getInt(_celebratedLevelKey) ?? 0;
      if (celebrated >= level) return false;
      await prefs.setInt(_celebratedLevelKey, level);
      return true;
    } catch (e, s) {
      reportSwallowedError('升级庆祝标记写入失败（本次按庆祝处理）', e, s);
      return true;
    }
  }
}
