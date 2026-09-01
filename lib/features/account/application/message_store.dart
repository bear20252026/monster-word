// 由 Claude 团队生成 | Monster Word App

// 消息中心本地仓库：消息的唯一事实来源。
// 持久化走 SharedPreferences；学习类消息（打卡提醒/连续打卡里程碑）
// 通过 CheckinStatusReader 端口刷新（跨 feature 仅依赖 application 端口，符合 R4）。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/domain/message_item.dart';
import 'package:word_app/features/checkin/application/checkin_status_reader.dart';

/// 连续打卡里程碑天数：达成时各生成一条祝贺消息（永久去重）。
const List<int> kWelcomedStreakMilestones = <int>[3, 7, 21, 60, 100, 365];

class MessageStore extends ChangeNotifier {
  MessageStore({this.checkinReader});

  static const String _storageKey = 'mw.messages.v1';

  /// 测试注入 SharedPreferences 背板；为 null 时走 getInstance()。
  @visibleForTesting
  SharedPreferences? prefsOverride;

  /// 签到状态读取端口（跨 feature application 端口，R4 通道）；null 时不刷新学习消息。
  final CheckinStatusReader? checkinReader;

  List<MessageItem> _messages = <MessageItem>[];
  bool _loaded = false;

  Future<SharedPreferences> _prefs() async => prefsOverride ?? await SharedPreferences.getInstance();

  /// 当前消息列表（新消息在前）。
  List<MessageItem> get messages => List<MessageItem>.unmodifiable(_messages);

  /// 未读数量。
  int get unreadCount => _messages.where((MessageItem m) => !m.isRead).length;

  /// 是否已完成首次加载。
  bool get loaded => _loaded;

  /// 加载消息：读持久化 → 刷新学习类消息 → 持久化 → 通知。
  Future<void> load() async {
    final prefs = await _prefs();
    _messages = _decode(prefs.getString(_storageKey));

    final fresh = await _refreshLearningMessages();
    if (fresh) {
      await _persist(prefs);
    }
    _loaded = true;
    notifyListeners();
  }

  /// 全部标记已读。
  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    _messages = _messages.map((MessageItem m) => m.markRead()).toList();
    final prefs = await _prefs();
    await _persist(prefs);
    notifyListeners();
  }

  /// 单条标记已读。
  Future<void> markRead(String id) async {
    final index = _messages.indexWhere((MessageItem m) => m.id == id);
    if (index < 0 || _messages[index].isRead) return;
    _messages = List<MessageItem>.of(_messages)..[index] = _messages[index].markRead();
    final prefs = await _prefs();
    await _persist(prefs);
    notifyListeners();
  }

  /// 追加本地消息（去重键相同则跳过），供后续事件源扩展。
  Future<void> append(MessageItem item) async {
    if (item.dedupeKey != null && _messages.any((MessageItem m) => m.dedupeKey == item.dedupeKey)) {
      return;
    }
    _messages = <MessageItem>[item, ..._messages];
    final prefs = await _prefs();
    await _persist(prefs);
    notifyListeners();
  }

  /// 刷新消息（欢迎 + 学习类）。返回 true 表示列表有变化需要持久化。
  Future<bool> _refreshLearningMessages() async {
    var changed = false;

    // 首次使用欢迎消息（无条件，不依赖签到端口）。
    if (_messages.isEmpty) {
      _messages = <MessageItem>[
        MessageItem(
          id: 'welcome',
          title: '欢迎来到 Monster Word',
          content: '从今天开始，每天打卡背单词，小怪兽会陪你一起进步！',
          time: _formatTime(DateTime.now()),
          dedupeKey: 'welcome',
        ),
      ];
      changed = true;
    }

    final reader = checkinReader;
    if (reader == null) return changed;

    final status = await reader.getStatus();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // 打卡提醒：今天未打卡且尚无当日提醒时生成；打卡后移除当日提醒。
    final remindKey = 'remind:$today';
    final hasRemind = _hasDedupeKey(remindKey);
    if (status.todayChecked) {
      if (hasRemind) {
        _messages = _messages.where((MessageItem m) => m.dedupeKey != remindKey).toList();
        changed = true;
      }
    } else if (!hasRemind) {
      _messages.insert(
        0,
        MessageItem(
          id: 'remind-$today',
          title: '今日打卡提醒',
          content: '今天的单词还没背哦，坚持第 ${status.streakDays + 1} 天！',
          time: _formatTime(DateTime.now()),
          dedupeKey: remindKey,
        ),
      );
      changed = true;
    }

    // 连续打卡里程碑祝贺（永久去重）。
    for (final int milestone in kWelcomedStreakMilestones) {
      if (status.streakDays < milestone) continue;
      final key = 'streak:$milestone';
      if (_hasDedupeKey(key)) continue;
      _messages.insert(
        0,
        MessageItem(
          id: 'streak-$milestone',
          title: '连续打卡 $milestone 天！',
          content: '太棒了，你已经连续学习 $milestone 天，小怪兽为你欢呼！继续保持！',
          time: _formatTime(DateTime.now()),
          dedupeKey: key,
        ),
      );
      changed = true;
    }

    // 移除历史遗留的"已过期"打卡提醒（非今天的 remind: 消息）。
    final expiredRemoved = _removeExpiredReminds(today);
    if (expiredRemoved) changed = true;

    return changed;
  }

  /// 按 dedupeKey 判断消息是否存在。
  bool _hasDedupeKey(String key) => _messages.any((MessageItem m) => m.dedupeKey == key);

  /// 移除非今天的打卡提醒（阅读噪声清理）。
  bool _removeExpiredReminds(String today) {
    final expired = _messages
        .where(
          (MessageItem m) =>
              m.dedupeKey != null && m.dedupeKey!.startsWith('remind:') && m.dedupeKey != 'remind:$today',
        )
        .toList();
    if (expired.isEmpty) return false;
    final expiredKeys = expired.map((MessageItem m) => m.dedupeKey).toSet();
    _messages = _messages.where((MessageItem m) => !expiredKeys.contains(m.dedupeKey)).toList();
    return true;
  }

  Future<void> _persist(SharedPreferences prefs) async {
    await prefs.setString(_storageKey, jsonEncode(_messages.map((MessageItem m) => m.toJson()).toList()));
  }

  static List<MessageItem> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <MessageItem>[];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.map((dynamic e) => MessageItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // 数据损坏时静默重置，不阻塞消息中心可用性。
      return <MessageItem>[];
    }
  }

  static String _formatTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }
}
