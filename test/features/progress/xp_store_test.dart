import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/progress/application/xp_repository.dart';
import 'package:word_app/features/progress/application/xp_store.dart';
import 'package:word_app/features/progress/domain/xp_curve.dart';

/// 内存仓库：按事件键去重，模拟真实库的幂等语义。
class _MemoryXpRepository implements XpRepository {
  _MemoryXpRepository([this.total = 0]);

  int total;
  final Set<String> appliedKeys = <String>{};
  int addCalls = 0;

  @override
  Future<int> loadTotalXp() async => total;

  @override
  Future<int?> addXpOnce({required String eventKey, required int delta}) async {
    addCalls++;
    if (!appliedKeys.add(eventKey)) return null;
    total += delta;
    return total;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('首次加载：老用户 0 XP 从 Lv1 起算', () async {
    final store = XpStore(repository: _MemoryXpRepository());
    await store.ensureLoaded();
    expect(store.loaded, isTrue);
    expect(store.snapshot.totalXp, 0);
    expect(store.level, 1);
  });

  test('结算一局：答对 ×2 + 完成 10，并返回新快照', () async {
    final store = XpStore(repository: _MemoryXpRepository());
    final result = await store.grantSession(eventKey: 'xp:learn:a', answered: 6, correct: 5, completed: true);
    expect(result.awarded, 20);
    expect(result.snapshot.totalXp, 20);
    expect(result.snapshot.xpToNextLevel, 80);
    expect(result.leveledUp, isFalse);
    expect(result.newLevel, isNull);
  });

  test('一题未答：不给完成奖励，也不写库', () async {
    final repo = _MemoryXpRepository();
    final store = XpStore(repository: repo);
    final result = await store.grantSession(eventKey: 'xp:learn:b', answered: 0, correct: 0, completed: true);
    expect(result.awarded, 0);
    expect(repo.addCalls, 0);
    expect(result.snapshot.totalXp, 0);
  });

  test('同一局重复结算：事件键幂等，不重复加经验', () async {
    final repo = _MemoryXpRepository();
    final store = XpStore(repository: repo);
    final first = await store.grantSession(eventKey: 'xp:learn:c', answered: 6, correct: 5, completed: true);
    final again = await store.grantSession(eventKey: 'xp:learn:c', answered: 6, correct: 5, completed: true);
    expect(first.awarded, 20);
    expect(again.awarded, 0);
    expect(repo.total, 20);
    expect(store.snapshot.totalXp, 20);
  });

  test('不同局各自结算，经验累加', () async {
    final repo = _MemoryXpRepository();
    final store = XpStore(repository: repo);
    await store.grantSession(eventKey: 'xp:learn:d1', answered: 5, correct: 5, completed: true);
    await store.grantSession(eventKey: 'xp:learn:d2', answered: 5, correct: 5, completed: true);
    expect(repo.total, 40);
  });

  test('跨过阈值即升级，只升到最高等级', () async {
    final repo = _MemoryXpRepository(90);
    final store = XpStore(repository: repo);
    final result = await store.grantSession(eventKey: 'xp:learn:e', answered: 6, correct: 5, completed: true);
    expect(result.snapshot.totalXp, 110);
    expect(result.leveledUp, isTrue);
    expect(result.newLevel, 2);
    expect(result.snapshot.xpToNextLevel, 190);
  });

  test('升级庆祝同一等级只给一次，更高等级才会再庆祝', () async {
    final store = XpStore(repository: _MemoryXpRepository());
    expect(await store.claimLevelUpCelebration(2), isTrue);
    expect(await store.claimLevelUpCelebration(2), isFalse);
    expect(await store.claimLevelUpCelebration(1), isFalse);
    expect(await store.claimLevelUpCelebration(3), isTrue);
    expect(await store.claimLevelUpCelebration(3), isFalse);
  });

  test('复习结算与学习同口径：答对 10、完成一局 = 30 XP', () async {
    final store = XpStore(repository: _MemoryXpRepository());
    final result = await store.grantSession(eventKey: 'xp:review:r1', answered: 10, correct: 10, completed: true);
    expect(result.awarded, 10 * xpPerCorrectAnswer + xpPerCompletedSession);
  });
}
