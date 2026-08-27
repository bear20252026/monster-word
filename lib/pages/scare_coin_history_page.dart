// 由 Claude 团队生成 | Monster Word App

// 尖叫币（Scare Coin）历史记录页
// - 顶部：余额 + 每日签到（+10，一天一次）
// - 中部：可滑动的历史流水
// - 底部：《怪兽电力公司》电影渊源说明
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/di/service_locator.dart';
import '../hooks/responsive.dart';
import '../services/checkin_service.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';
import '../widgets/monster_icon.dart';

/// 尖叫币账本：余额、签到与流水的本地持久化（SharedPreferences JSON）
class ScareCoinLedger {
  ScareCoinLedger._();

  static const String _kBalance = 'scare_coin.balance';
  static const String _kHistory = 'scare_coin.history';
  static const String _kLastCheckIn = 'scare_coin.last_checkin';

  /// 全部签到日期（yyyy-MM-dd 集合），供弹性签到日历渲染
  static const String _kCheckinDates = 'scare_coin.checkin_dates';
  static const int checkInReward = 10;

  /// 当前余额
  static Future<int> balance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBalance) ?? 0;
  }

  /// 全部已签到日期（yyyy-MM-dd）
  static Future<Set<String>> checkinDates() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kCheckinDates) ?? const [];
    return list.toSet();
  }

  /// 连续签到天数：从今天（若今日已签）或昨天往回连续计数
  static Future<int> streak() async {
    final dates = await checkinDates();
    if (dates.isEmpty) return 0;
    var day = DateTime.now();
    bool has(DateTime d) => dates.contains(_iso(d));
    // 今天没签则从昨天起算（连击不断）
    if (!has(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (has(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 流水列表（新→旧）
  static Future<List<ScareCoinEntry>> history() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).map((e) => ScareCoinEntry.fromJson(e as Map<String, dynamic>)).toList();
      list.sort((a, b) => b.time.compareTo(a.time));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<String> lastCheckInDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastCheckIn) ?? '';
  }

  static bool isSameDay(String isoDate, DateTime time) =>
      isoDate == '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

  /// 今日签到；已签过返回 null，成功返回新余额
  static Future<int?> checkIn() async {
    final now = DateTime.now();
    final last = await lastCheckInDate();
    if (isSameDay(last, now)) return null;
    final iso = _iso(now);
    // 记入签到日历集合（弹性签到日历渲染用）
    try {
      final prefs = await SharedPreferences.getInstance();
      final dates = (prefs.getStringList(_kCheckinDates) ?? const <String>[]).toSet()..add(iso);
      await prefs.setStringList(_kCheckinDates, dates.toList()..sort());
    } catch (_) {
      // 日历集合写入失败不阻断主签到流程
    }
    return _apply(delta: checkInReward, reason: '每日签到', lastCheckInIso: iso);
  }

  /// 发放奖励（供学习/复习结算等场景调用）
  static Future<int> grant({required int delta, required String reason}) => _apply(delta: delta, reason: reason);

  static Future<int> _apply({required int delta, required String reason, String? lastCheckInIso}) async {
    final prefs = await SharedPreferences.getInstance();
    final newBalance = (prefs.getInt(_kBalance) ?? 0) + delta;
    await prefs.setInt(_kBalance, newBalance);
    if (lastCheckInIso != null) {
      await prefs.setString(_kLastCheckIn, lastCheckInIso);
    }
    final entries = await history();
    entries.insert(0, ScareCoinEntry(time: DateTime.now(), delta: delta, reason: reason));
    // 只保留最近 200 条，避免无限增长
    await prefs.setString(_kHistory, jsonEncode(entries.take(200).map((e) => e.toJson()).toList()));
    return newBalance;
  }
}

/// 一条流水
class ScareCoinEntry {
  final DateTime time;
  final int delta;
  final String reason;
  ScareCoinEntry({required this.time, required this.delta, required this.reason});

  Map<String, dynamic> toJson() => {'t': time.millisecondsSinceEpoch, 'd': delta, 'r': reason};
  factory ScareCoinEntry.fromJson(Map<String, dynamic> json) => ScareCoinEntry(
    time: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
    delta: json['d'] as int,
    reason: json['r'] as String,
  );
}

class ScareCoinHistoryPage extends StatefulWidget {
  const ScareCoinHistoryPage({super.key});

  @override
  State<ScareCoinHistoryPage> createState() => _ScareCoinHistoryPageState();
}

class _ScareCoinHistoryPageState extends State<ScareCoinHistoryPage> {
  int _balance = 0;
  bool _checkedToday = false;
  List<ScareCoinEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final balance = await ScareCoinLedger.balance();
    final last = await ScareCoinLedger.lastCheckInDate();
    final entries = await ScareCoinLedger.history();
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _checkedToday = ScareCoinLedger.isSameDay(last, DateTime.now());
      _entries = entries;
    });
  }

  Future<void> _onCheckIn() async {
    final newBalance = await ScareCoinLedger.checkIn();
    if (!mounted) return;
    if (newBalance == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('今天已经签到过啦，明天再来～')));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('签到成功！尖叫币 +${ScareCoinLedger.checkInReward} 👹')));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin.colors;
    return Scaffold(
      backgroundColor: skin.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: skin.text1),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '尖叫币',
          style: TextStyle(color: skin.text1, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ===== 余额卡 + 签到 =====
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.responsive.pageMargin),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: skin.cardBg,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: skin.divider),
                ),
                child: Row(
                  children: [
                    // 怪兽图标 + 余额
                    const MonsterAvatar(size: 52),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('我的尖叫币', style: TextStyle(fontSize: 13, color: skin.text3)),
                        Text(
                          '$_balance',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: skin.text1),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _checkedToday ? skin.divider : skin.accent,
                        foregroundColor: _checkedToday ? skin.text3 : AppColors.white100,
                      ),
                      onPressed: _checkedToday ? null : _onCheckIn,
                      icon: const Icon(Icons.redeem, size: 18),
                      label: const Text('签到 +10'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ===== 历史流水 =====
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.responsive.pageMargin),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '获取记录',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: skin.text1),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _entries.isEmpty
                  ? Center(
                      child: Text('还没有记录，先去签到吧～', style: TextStyle(fontSize: 14, color: skin.text3)),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(context.responsive.pageMargin, 0, context.responsive.pageMargin, 8),
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final e = _entries[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: skin.cardBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: skin.divider),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                e.delta >= 0 ? Icons.trending_up : Icons.trending_down,
                                size: 18,
                                color: e.delta >= 0 ? skin.success : MistralColors.danger,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.reason, style: TextStyle(fontSize: 14, color: skin.text1)),
                                    const SizedBox(height: 2),
                                    Text(_formatTime(e.time), style: TextStyle(fontSize: 12, color: skin.text3)),
                                  ],
                                ),
                              ),
                              Text(
                                '${e.delta >= 0 ? '+' : ''}${e.delta}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: e.delta >= 0 ? skin.success : MistralColors.danger,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // ===== 电影渊源说明 =====
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(context.responsive.pageMargin, 4, context.responsive.pageMargin, 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: skin.cardBgAlt, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Text(
                '🎬 关于「尖叫币」\n\n'
                '设定致敬皮克斯经典动画《怪兽电力公司》（Monsters, Inc., 2001）：'
                '在怪兽世界里，孩子们的尖叫声被收集起来转化为整座城市的电力——尖叫，就是硬通货。\n\n'
                '愿每一枚尖叫币都提醒你：背单词时发出的每一声"惊呼"，都在为你的大脑充电。',
                style: TextStyle(fontSize: 12, height: 1.7, color: skin.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} $hh:$mm';
  }
}
