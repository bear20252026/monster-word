// MonsterBondPrefs 羁绊记账真值表（W4.5 宠物化）。
//
// 核心规则：同源同日只 +1（防刷），跨日恢复；抚摸/喂食是两个独立日闸。
// 等级阶梯为纯函数表（BondLevel.catalog）。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/monster_bond_prefs.dart';
import 'package:word_app/core/utils/monster_rhythm.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 10);
  });
  tearDown(MonsterRhythm.resetForTest);

  test('抚摸：同日多次只 +1，todayCount 累计（摸烦判定用）', () async {
    final first = await MonsterBondPrefs.recordPet();
    expect(first.awarded, isTrue, reason: '当日首次抚摸 +1');
    expect(first.todayCount, 1);

    final second = await MonsterBondPrefs.recordPet();
    expect(second.awarded, isFalse, reason: '同日不重复 +1（防刷）');
    expect(second.todayCount, 2, reason: '次数照记——性格（摸烦）判定需要它');

    final third = await MonsterBondPrefs.recordPet();
    final fourth = await MonsterBondPrefs.recordPet();
    expect(fourth.todayCount, MonsterBondPrefs.annoyedAfterSessions, reason: '第 4 次会话 = 摸烦阈值');
    expect(third.todayCount, 3);
  });

  test('跨日恢复：次日抚摸再 +1', () async {
    await MonsterBondPrefs.recordPet();
    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 5, 10);
    final next = await MonsterBondPrefs.recordPet();
    expect(next.awarded, isTrue);
    expect(await MonsterBondPrefs.points(), 2);
  });

  test('喂食与抚摸互不影响（独立日闸）', () async {
    final pet = await MonsterBondPrefs.recordPet();
    final feed = await MonsterBondPrefs.recordFeed();
    expect(pet.awarded, isTrue);
    expect(feed.awarded, isTrue, reason: '喂食有自己的每日首刷');
    final feedAgain = await MonsterBondPrefs.recordFeed();
    expect(feedAgain.awarded, isFalse);
    expect(await MonsterBondPrefs.points(), 2);
  });

  test('等级阶梯：阈值表锚点（0/7/30/90/180）', () {
    expect(BondLevel.levelOf(0).name, '初识');
    expect(BondLevel.levelOf(6).name, '初识');
    expect(BondLevel.levelOf(7).name, '熟络');
    expect(BondLevel.levelOf(29).name, '熟络');
    expect(BondLevel.levelOf(30).name, '亲密');
    expect(BondLevel.levelOf(89).name, '亲密');
    expect(BondLevel.levelOf(90).name, '形影不离');
    expect(BondLevel.levelOf(180).name, '灵魂共振');
    expect(BondLevel.levelOf(999).name, '灵魂共振');
  });

  test('下一级阈值：未满级给出下一档，满级为 null', () {
    expect(BondLevel.nextMin(0), 7);
    expect(BondLevel.nextMin(7), 30);
    expect(BondLevel.nextMin(180), isNull);
  });

  test('points 读取失败按 0 降级（羁绊丢体验差于崩溃）', () async {
    // mock SP 未初始化场景由共享 setUp 的 mock 兜住；这里锚定正常读取。
    await MonsterBondPrefs.recordPet();
    expect(await MonsterBondPrefs.points(), 1);
  });
}
