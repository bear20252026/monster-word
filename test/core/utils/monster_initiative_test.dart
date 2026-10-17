// companion 域：怪兽的主动发起规则（借 N.E.K.O 的「主动」，不借它的模型）。
//
// 产品红线的可执行版本：
// - 久别重逢只欢迎、不催
// - 已经学过就不再催（陪伴 ≠ 监工）
// - 没有值得说的就闭嘴
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/monster_initiative.dart';

void main() {
  test('久别重逢压过一切催办（积压 999 + 签到断 30 天也只欢迎）', () {
    final d = pickInitiative(
      const MonsterInitiativeInput(dueCount: 999, daysSinceLastCheckin: 30, daysSinceLastVisit: 10),
    );
    expect(d?.initiative, MonsterInitiative.welcomeBack);
  });

  test('连续答错 → 提议三词小组（优先于催复习）', () {
    final d = pickInitiative(const MonsterInitiativeInput(dueCount: 50, consecutiveWrong: 3));
    expect(d?.initiative, MonsterInitiative.proposeThreeWordGroup);
  });

  test('连续答错未到阈值不提议（2 次太早）', () {
    final d = pickInitiative(const MonsterInitiativeInput(consecutiveWrong: 2));
    expect(d, isNull);
  });

  test('今天已经学过 → 不再催复习（陪伴与监工的分界线）', () {
    final d = pickInitiative(const MonsterInitiativeInput(dueCount: 50, studiedToday: true));
    expect(d, isNull, reason: '学过了还催，就是监工');
  });

  test('未学 + 到期达阈值 → 提议复习；差一个不提', () {
    expect(pickInitiative(const MonsterInitiativeInput(dueCount: 20))?.initiative, MonsterInitiative.proposeReview);
    expect(pickInitiative(const MonsterInitiativeInput(dueCount: 19)), isNull);
  });

  test('签到断 2 天 → 提议签到；断 1 天不提', () {
    expect(
      pickInitiative(const MonsterInitiativeInput(daysSinceLastCheckin: 2))?.initiative,
      MonsterInitiative.proposeCheckin,
    );
    expect(pickInitiative(const MonsterInitiativeInput(daysSinceLastCheckin: 1)), isNull);
  });

  test('没有任何值得说的事 → 返回 null（不硬凑）', () {
    expect(pickInitiative(const MonsterInitiativeInput()), isNull);
  });

  test('判定理由非空（进埋点/排障用）', () {
    final d = pickInitiative(const MonsterInitiativeInput(dueCount: 30));
    expect(d?.reason, isNotEmpty);
  });
}
