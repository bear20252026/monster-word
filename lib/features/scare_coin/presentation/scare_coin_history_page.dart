// 由 Claude 团队生成 | Monster Word App
//
// 尖叫币（Scare Coin）历史记录页 — 功能域内聚实现
//
// 本页面完整包含尖叫币历史页的 UI 与交互逻辑，遵循 R1-R6 分层：
// - 读：通过 ScareCoinStore 端口（application 层）
// - 写：通过 ScareCoinStore.checkIn() 端口
// - 不直接接触偏好存储或任何基础设施

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../hooks/responsive.dart';
import '../../../theme/skin_system.dart';
import '../../../tokens/design_tokens.dart';
import '../../../widgets/monster_icon.dart';
import '../../../core/scare_coin/scare_coin_store.dart';
import '../../../models/scare_coin_entry.dart';

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
    final store = context.read<ScareCoinStore>();
    final balance = await store.balance();
    final last = await store.lastCheckInDate();
    final entries = await store.history();
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _checkedToday = store.isSameDay(last, DateTime.now());
      _entries = entries;
    });
  }

  Future<void> _onCheckIn() async {
    final store = context.read<ScareCoinStore>();
    final newBalance = await store.checkIn();
    if (!mounted) return;
    if (newBalance == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('今天已经签到过啦，明天再来～')));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('签到成功！尖叫币 +${store.checkInReward} 👹')));
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
                  borderRadius: BorderRadius.circular(context.design.radius.xl),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('还没有记录，先去签到吧～', style: TextStyle(fontSize: 14, color: skin.text3)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('去签到'),
                          ),
                        ],
                      ),
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
                            borderRadius: BorderRadius.circular(context.design.radius.md),
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
              decoration: BoxDecoration(color: skin.cardBgAlt, borderRadius: BorderRadius.circular(context.design.radius.lg)),
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
