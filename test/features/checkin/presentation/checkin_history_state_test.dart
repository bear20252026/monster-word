import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/presentation/checkin_history_state.dart';
import 'package:word_app/features/checkin/application/check_in_history_reader.dart';

/// 模拟 CheckInHistoryReader
class FakeCheckInHistoryReader implements CheckInHistoryReader {
  Set<String> _dates = {};
  int _streak = 0;
  final int _reward = 10;

  void setDates(Set<String> dates) => _dates = dates;
  void setStreak(int streak) => _streak = streak;

  @override
  Future<Set<String>> getCheckedDates() async => _dates;

  @override
  Future<int> getStreak() async => _streak;

  @override
  int get checkInReward => _reward;
}

void main() {
  group('CheckinHistoryState', () {
    late FakeCheckInHistoryReader fakeReader;
    late CheckinHistoryState state;

    setUp(() {
      fakeReader = FakeCheckInHistoryReader();
      state = CheckinHistoryState(reader: fakeReader);
    });

    test('初始状态', () {
      expect(state.loading, isTrue);
      expect(state.checkedDates, isEmpty);
      expect(state.streak, 0);
      expect(state.reward, 0);
    });

    test('load 加载数据', () async {
      fakeReader.setDates({'2025-03-01', '2025-03-02'});
      fakeReader.setStreak(5);

      await state.load();

      expect(state.loading, isFalse);
      expect(state.checkedDates.length, 2);
      expect(state.streak, 5);
      expect(state.reward, 10);
    });

    test('load 通知监听器', () async {
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      fakeReader.setDates({});
      await state.load();

      // 至少通知 2 次（loading=true, loading=false）
      expect(notifyCount, greaterThanOrEqualTo(2));
    });
  });
}
