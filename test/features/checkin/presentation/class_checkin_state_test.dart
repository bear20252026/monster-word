import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/presentation/class_checkin_state.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/application/checkin_writer.dart';
import 'package:word_app/features/checkin/domain/checkin_status.dart';

/// 模拟 CheckinStatusReader
class FakeStatusReader implements CheckinStatusReader {
  CheckinStatus _status = const CheckinStatus.empty();
  Set<String> _dates = {};

  void setStatus(CheckinStatus status) => _status = status;
  void setDates(Set<String> dates) => _dates = dates;

  @override
  Future<CheckinStatus> getStatus() async => _status;

  @override
  Future<Set<String>> getCheckinDates() async => _dates;

  @override
  Future<int> getStreakDays() async => _status.streakDays;

  @override
  Future<bool> hasCheckedInToday() async => _status.todayChecked;
}

/// 模拟 CheckinWriter
class FakeWriter implements CheckinWriter {
  bool _result = true;
  int _streak = 0;
  bool _todayChecked = false;

  void setResult(bool result) => _result = result;
  void setTodayChecked(bool value) => _todayChecked = value;

  @override
  Future<bool> checkIn() async {
    if (_todayChecked) return false;
    if (_result) {
      _streak++;
      _todayChecked = true;
    }
    return _result;
  }

  @override
  Future<int> getStreak() async => _streak;
}

void main() {
  group('ClassCheckinState', () {
    late FakeStatusReader statusReader;
    late FakeWriter writer;
    late ClassCheckinState state;

    setUp(() {
      statusReader = FakeStatusReader();
      writer = FakeWriter();
      state = ClassCheckinState(statusReader: statusReader, writer: writer);
    });

    test('初始状态是空状态', () {
      expect(state.loading, isTrue);
      expect(state.checking, isFalse);
      expect(state.status.todayChecked, isFalse);
      expect(state.checkedDates, isEmpty);
    });

    test('load 加载签到状态和日期', () async {
      statusReader.setStatus(const CheckinStatus(todayChecked: true, streakDays: 7, totalDays: 20, reward: 10));
      statusReader.setDates({'2025-03-01', '2025-03-02', '2025-03-03'});

      await state.load();

      expect(state.loading, isFalse);
      expect(state.status.todayChecked, isTrue);
      expect(state.status.streakDays, 7);
      expect(state.checkedDates.length, 3);
    });

    test('checkIn 成功并刷新状态', () async {
      statusReader.setStatus(const CheckinStatus.empty());
      writer.setResult(true);

      await state.load();
      expect(state.status.todayChecked, isFalse);

      // 模拟签到成功后状态更新（writer 成功后底层 service 状态改变）
      writer.setResult(true);
      statusReader.setStatus(const CheckinStatus(todayChecked: true, streakDays: 1, totalDays: 1, reward: 10));
      statusReader.setDates({'2025-03-28'});

      final result = await state.checkIn();

      expect(result, isTrue);
      expect(state.status.todayChecked, isTrue);
    });

    test('checkIn 今天已签到时返回 false', () async {
      statusReader.setStatus(const CheckinStatus(todayChecked: true, streakDays: 3, totalDays: 3, reward: 10));
      writer.setTodayChecked(true);

      await state.load();
      final result = await state.checkIn();

      expect(result, isFalse);
    });
  });
}
