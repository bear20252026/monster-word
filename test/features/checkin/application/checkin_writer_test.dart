import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/application/checkin_writer.dart';

/// 模拟 CheckinWriter
class MockCheckinWriter implements CheckinWriter {
  bool _canCheckIn = true;
  int _streak = 0;

  void setCanCheckIn(bool value) => _canCheckIn = value;
  void setStreak(int value) => _streak = value;

  @override
  Future<bool> checkIn() async {
    if (!_canCheckIn) return false;
    _streak++;
    return true;
  }

  @override
  Future<int> getStreak() async => _streak;
}

void main() {
  group('CheckinWriter port contract', () {
    late MockCheckinWriter writer;

    setUp(() {
      writer = MockCheckinWriter();
    });

    test('checkIn 成功并增加连续天数', () async {
      writer.setCanCheckIn(true);
      writer.setStreak(3);

      final success = await writer.checkIn();
      expect(success, isTrue);
      expect(await writer.getStreak(), 4);
    });

    test('checkIn 失败时返回 false', () async {
      writer.setCanCheckIn(false);

      final success = await writer.checkIn();
      expect(success, isFalse);
    });
  });
}
