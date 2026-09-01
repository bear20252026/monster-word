// 由 Claude 团队生成 | Monster Word App

// MessageStore 单元测试：本地消息持久化、打卡提醒生命周期、里程碑去重、已读语义。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/application/message_store.dart';
import 'package:word_app/features/account/domain/message_item.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';
import 'package:word_app/features/checkin/domain/checkin_status.dart';

class _FakeCheckinReader implements CheckinStatusReader {
  _FakeCheckinReader({this.todayChecked = false, this.streakDays = 0});

  bool todayChecked;
  int streakDays;

  @override
  Future<CheckinStatus> getStatus() async =>
      CheckinStatus(todayChecked: todayChecked, streakDays: streakDays, totalDays: 10, reward: 5);

  @override
  Future<Set<String>> getCheckinDates() async => <String>{};

  @override
  Future<int> getStreakDays() async => streakDays;

  @override
  Future<bool> hasCheckedInToday() async => todayChecked;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('MessageStore', () {
    test('首次加载（无签到端口）生成欢迎消息且已 loaded', () async {
      final store = MessageStore()..prefsOverride = prefs;

      await store.load();

      expect(store.loaded, isTrue);
      expect(store.messages, hasLength(1));
      expect(store.messages.first.dedupeKey, 'welcome');
      expect(store.unreadCount, 1);
    });

    test('未打卡时生成当日提醒；二次加载保持已读状态不被重置', () async {
      final store = MessageStore(checkinReader: _FakeCheckinReader())..prefsOverride = prefs;

      await store.load();
      final remind = store.messages.firstWhere((m) => m.dedupeKey!.startsWith('remind:'));
      expect(remind.isRead, isFalse);

      await store.markRead(remind.id);
      // 第二次 load（仍未打卡）：提醒不应被重建为未读。
      await store.load();
      final remindAgain = store.messages.firstWhere((m) => m.dedupeKey!.startsWith('remind:'));
      expect(remindAgain.isRead, isTrue);
    });

    test('打卡后当日提醒被移除且不再生成', () async {
      final reader = _FakeCheckinReader(todayChecked: true, streakDays: 5);
      final store = MessageStore(checkinReader: reader)..prefsOverride = prefs;

      await store.load();

      expect(store.messages.any((m) => m.dedupeKey!.startsWith('remind:')), isFalse);
      // 欢迎消息仍在。
      expect(store.messages.any((m) => m.dedupeKey == 'welcome'), isTrue);
    });

    test('连续打卡里程碑生成祝贺且永久去重（断签重刷不重复）', () async {
      final reader = _FakeCheckinReader(todayChecked: true, streakDays: 7);
      final store = MessageStore(checkinReader: reader)..prefsOverride = prefs;

      await store.load();
      final streakMsgs = store.messages.where((m) => m.dedupeKey!.startsWith('streak:')).toList();
      // streak=7 应达成 3 天与 7 天两个里程碑。
      expect(streakMsgs.map((m) => m.dedupeKey), containsAll(<String>['streak:3', 'streak:7']));
      expect(streakMsgs, hasLength(2));

      // 断签后重新刷到 7 天：不重复生成。
      reader.streakDays = 1;
      await store.load();
      reader.streakDays = 7;
      await store.load();
      expect(store.messages.where((m) => m.dedupeKey!.startsWith('streak:')), hasLength(2));
    });

    test('markAllRead 清零未读并持久化（新实例重载仍保持已读）', () async {
      final store = MessageStore()..prefsOverride = prefs;
      await store.load();
      expect(store.unreadCount, greaterThan(0));

      await store.markAllRead();
      expect(store.unreadCount, 0);

      final reloaded = MessageStore()..prefsOverride = prefs;
      await reloaded.load();
      expect(reloaded.unreadCount, 0);
      expect(reloaded.messages, isNotEmpty);
    });

    test('markRead 单条已读且未读数递减', () async {
      final store = MessageStore()..prefsOverride = prefs;
      await store.load();
      final target = store.messages.first;
      final before = store.unreadCount;

      await store.markRead(target.id);

      expect(store.messages.firstWhere((m) => m.id == target.id).isRead, isTrue);
      expect(store.unreadCount, before - 1);
    });

    test('append 按 dedupeKey 去重', () async {
      final store = MessageStore()..prefsOverride = prefs;
      await store.load();

      await store.append(
        const MessageItem(id: 'custom-1', title: '自定义', content: '内容', time: '2026-01-01 08:00', dedupeKey: 'welcome'),
      );

      // welcome 已存在，custom-1 被跳过。
      expect(store.messages.any((m) => m.id == 'custom-1'), isFalse);
    });
  });
}
