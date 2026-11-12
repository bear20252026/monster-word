// 肚皮储蓄罐离线计息口径：起计门槛、8 小时封顶、费率换算、文案红线。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/checkin/domain/belly_interest.dart';

void main() {
  // emoji_hygiene_test 对 lib 非注释行零 emoji（按 rune 判，同 boss_siege_test）。
  bool hasEmoji(String s) {
    for (final r in s.runes) {
      if ((r >= 0x1F000 && r <= 0x1FAFF) || (r >= 0x2600 && r <= 0x27BF) || (r >= 0xFE00 && r <= 0xFE0F)) {
        return true;
      }
    }
    return false;
  }

  group('bellyInterestFor 起计门槛', () {
    test('不足 1 小时不计息（含 0 与负数）', () {
      expect(bellyInterestFor(awayMinutes: 0, yesterdayWords: 50).isEmpty, isTrue);
      expect(bellyInterestFor(awayMinutes: 59, yesterdayWords: 50).isEmpty, isTrue);
      expect(bellyInterestFor(awayMinutes: -30, yesterdayWords: 50).isEmpty, isTrue);
    });

    test('恰好 1 小时起计', () {
      final r = bellyInterestFor(awayMinutes: 60, yesterdayWords: 0);
      expect(r.hours, 1);
      expect(r.coins, bellyInterestBasePerHour);
    });
  });

  group('bellyInterestFor 费率与封顶', () {
    test('昨日零学习也有保底费率（陪伴不嫌少）', () {
      final r = bellyInterestFor(awayMinutes: 3 * 60, yesterdayWords: 0);
      expect(r.coins, 3 * bellyInterestBasePerHour);
    });

    test('昨日学习量按步长抬费率', () {
      final r = bellyInterestFor(awayMinutes: 2 * 60, yesterdayWords: 5);
      expect(r.coins, 2 * (bellyInterestBasePerHour + 5));
    });

    test('离线上限 8 小时：多睡不加息', () {
      final eight = bellyInterestFor(awayMinutes: 8 * 60, yesterdayWords: 3);
      final overnight = bellyInterestFor(awayMinutes: 30 * 60, yesterdayWords: 3);
      expect(eight.hours, bellyInterestCapHours);
      expect(overnight.hours, bellyInterestCapHours);
      expect(overnight.coins, eight.coins);
    });

    test('高费率也不超过单次封顶', () {
      final r = bellyInterestFor(awayMinutes: 8 * 60, yesterdayWords: 500);
      expect(r.coins, bellyInterestMaxCoins);
    });

    test('负数学习量按 0 处理', () {
      final r = bellyInterestFor(awayMinutes: 60, yesterdayWords: -9);
      expect(r.coins, bellyInterestBasePerHour);
    });
  });

  group('文案红线（只陪伴，不制造焦虑）', () {
    test('零 emoji', () {
      for (final text in [bellyInterestHint(12), bellyInterestSettledLine, bellyInterestEmptyLine]) {
        expect(hasEmoji(text), isFalse, reason: '不得用 emoji 表达情绪');
      }
    });

    test('不出现羞辱/催促/亏损式措辞', () {
      final all = [bellyInterestHint(12), bellyInterestSettledLine, bellyInterestEmptyLine];
      for (final text in all) {
        for (final banned in ['你怎么', '退步', '又拖', '再不', '居然', '太差', '亏', '过期', '浪费', '赶紧']) {
          expect(text, isNot(contains(banned)), reason: '不得制造焦虑：$text');
        }
      }
    });

    test('提示只说攒了多少，不说离开了多久', () {
      expect(bellyInterestHint(12), contains('12'));
      expect(bellyInterestHint(12), isNot(contains('小时')));
      expect(bellyInterestHint(12), isNot(contains('天')));
    });
  });
}
