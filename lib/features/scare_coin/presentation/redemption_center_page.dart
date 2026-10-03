import 'dart:async';

import 'package:word_app/widgets/common/mw_feedback.dart';
import 'package:flutter/material.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/widgets/monster_icon.dart';
import 'package:word_app/widgets/redeem_swallow_sheet.dart';

/// 兑换中心页面。
///
/// 经济规则（用户确认，2026-08-31）：
/// - 不设 VIP、不做任何权益墙：全部功能对所有人无条件开放。
/// - 兑换为纯收集/纪念性质：真实扣币、真实入账，但不附带任何功能权益。
/// - 商品一经兑换永久持有（按 id 记录在本地，不提供退换）。
///
/// 修订（断签保护卡，需求方确认）：保护卡是唯一的耗材型功能商品——
/// 断签自动续命一张，不占装备架（owned/3 口径不变）、不计收藏章；
/// 其余徽章仍为纯收集。库存走 ScareCoinStore 账本，可重复兑换。
class RedemptionCenterPage extends StatefulWidget {
  static const String routeName = RouteNames.redemption;
  const RedemptionCenterPage({super.key});

  @override
  State<RedemptionCenterPage> createState() => _RedemptionCenterPageState();
}

class _RedemptionCenterPageState extends State<RedemptionCenterPage> {
  /// 已兑换收藏章键前缀（与 AppPreferences.redeemedBadgePrefix 同值；presentation 不 import infrastructure）。
  static const String _redeemedPrefix = 'scare_coin.redeemed.';

  int _coins = 0;
  int _todayEarned = 0;
  Set<String> _redeemedIds = <String>{};
  int _protectionStock = 0;
  bool _redeeming = false;

  /// 兑换弹层的怪兽进化阶段（MonsterIcon.stageFor，0/7/30/100 天口径）。
  /// 异步补齐：默认 0（奶泡形态），读到累计签到天数后换装；读取失败保持 0。
  int _monsterStage = 0;

  static const List<_RedeemItem> _items = [
    _RedeemItem(
      id: 'protection_card',
      title: '断签保护卡',
      description: '断签自动续命一张 · 耗材不占装备架',
      cost: 200,
      icon: Icons.shield_rounded,
      color: 0xFFD9A62E,
      isConsumable: true,
    ),
    _RedeemItem(
      id: 'badge_warm',
      title: '暖橙收藏章',
      description: '纯收藏纪念 · 全部功能本就人人可用',
      cost: 300,
      icon: Icons.palette,
      color: 0xFFFF8C42,
    ),
    _RedeemItem(
      id: 'badge_midnight',
      title: '深蓝收藏章',
      description: '纯收藏纪念 · 全部功能本就人人可用',
      cost: 400,
      icon: Icons.nightlight_round,
      color: 0xFF4A90E2,
    ),
    _RedeemItem(
      id: 'badge_green',
      title: '翠绿纪念章',
      description: '纯收藏纪念 · 全部功能本就人人可用',
      cost: 500,
      icon: Icons.emoji_events,
      color: 0xFF008550,
    ),
    _RedeemItem(
      id: 'badge_cute',
      title: '萌系徽章',
      description: '纯收藏纪念 · 全部功能本就人人可用',
      cost: 800,
      icon: Icons.auto_awesome,
      color: 0xFFE91E63,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final store = context.read<ScareCoinStore>();
    final prefs = await SharedPreferences.getInstance();
    final results = await Future.wait([store.balance(), store.history(), store.protectionCount()]);
    if (!mounted) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayEarned = (results[1] as List)
        .where((e) => e.delta > 0 && _isoDay(e.time) == today)
        .fold<int>(0, (sum, e) => sum + e.delta as int);
    setState(() {
      _coins = results[0] as int;
      _todayEarned = todayEarned;
      _protectionStock = results[2] as int;
      _redeemedIds = _items.map((i) => i.id).where((id) => prefs.getBool('$_redeemedPrefix$id') ?? false).toSet();
    });
    // 弹层展示用进化阶段异步补齐（与怪兽探头同口径）：独立读取、失败降级，不牵连页面主数据。
    unawaited(_loadMonsterStage(store));
  }

  /// 累计签到天数 → 进化阶段（MonsterIcon.stageFor，与怪兽探头/小屋同口径）。
  /// 纯展示数据：失败上报后降级默认形态（0 奶泡），不上抛、不阻断兑换主流程。
  Future<void> _loadMonsterStage(ScareCoinStore store) async {
    try {
      final totalDays = (await store.checkinDates()).length;
      if (!mounted) return;
      setState(() => _monsterStage = MonsterIcon.stageFor(totalDays));
    } catch (e, s) {
      reportSwallowedError('兑换弹层怪兽形态读取失败', e, s);
    }
  }

  static String _isoDay(DateTime t) => t.toIso8601String().substring(0, 10);

  /// 耗材兑换：扣币＋账本入账，满额拒收（上限见 ScareCoinStore.protectionCap）。
  Future<void> _redeemConsumable(_RedeemItem item, ScareCoinStore store) async {
    if (_coins < item.cost) {
      showMwSnackBar(context, SnackBar(content: Text('尖叫币不足（还差 ${item.cost - _coins} 枚），继续学习攒币吧！')));
      return;
    }
    if (_protectionStock >= store.protectionCap) {
      showMwSnackBar(context, SnackBar(content: Text('保护卡已满（${store.protectionCap} 张），用掉再来兑换吧！')));
      return;
    }
    setState(() => _redeeming = true);
    try {
      await store.grant(delta: -item.cost, reason: '兑换 · ${item.title}');
      try {
        final stock = await store.addProtection(count: 1, reason: '兑换 · ${item.title}');
        if (!mounted) return;
        showMwSnackBar(context, SnackBar(content: Text('兑换成功！断签保护卡×1（当前库存 $stock 张）')));
        await _reload();
      } catch (e, s) {
        // 数据完整性审计 P2：扣币后落账失败需补偿退款，否则币丢奖励没到手。
        reportSwallowedError('兑换耗材落账失败，补偿回滚', e, s);
        await store.grant(delta: item.cost, reason: '兑换失败退款 · ${item.title}');
        rethrow;
      }
    } catch (_) {
      if (mounted) {
        showMwSnackBar(context, const SnackBar(content: Text('兑换失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _redeem(_RedeemItem item) async {
    if (_redeeming) return;
    final store = context.read<ScareCoinStore>();
    // 耗材分支：可重复兑换，走库存口径（不进 redeemedIds、不占装备架）。
    if (item.isConsumable) return _redeemConsumable(item, store);
    if (_redeemedIds.contains(item.id)) return;
    if (_coins < item.cost) {
      showMwSnackBar(context, SnackBar(content: Text('尖叫币不足（还差 ${item.cost - _coins} 枚），继续学习攒币吧！')));
      return;
    }
    setState(() => _redeeming = true);
    try {
      final store = context.read<ScareCoinStore>();
      await store.grant(delta: -item.cost, reason: '兑换 · ${item.title}');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('$_redeemedPrefix${item.id}', true);
      } catch (e, s) {
        // 数据完整性审计 P2：扣币后标记失败需补偿退款，否则币丢奖励没落账。
        reportSwallowedError('兑换标记写入失败，补偿回滚', e, s);
        await store.grant(delta: item.cost, reason: '兑换失败退款 · ${item.title}');
        rethrow;
      }
      if (!mounted) return;
      // 兑换成交仪式弹层（纯展示；扣币已在上方 grant 完成）。不 await：
      // 弹层挂起期间 _reload 照常刷新余额与「已拥有」态。
      unawaited(
        showRedeemSwallowSheet(context, itemName: item.title, coinCost: item.cost, monsterStage: _monsterStage),
      );
      await _reload();
    } catch (_) {
      if (mounted) {
        showMwSnackBar(context, const SnackBar(content: Text('兑换失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = SkinProvider.of(context);
    final resp = context.responsive;
    final colors = skin.colors;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: colors.pageBg,
        appBar: AppBar(
          backgroundColor: colors.pageBg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: colors.text1),
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('兑换中心', style: MwTypography.heading5.copyWith(color: colors.text1)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: colors.divider),
          ),
        ),
        body: Column(
          children: [
            _buildBalanceCard(skin, resp),
            // 公平声明：无权益墙，兑换纯收集
            Container(
              margin: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, resp.pageMargin),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.cardBgAlt,
                borderRadius: BorderRadius.circular(context.design.radius.md),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.favorite_outline, size: 18, color: colors.text2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '所有功能对所有人开放；兑换为纯收集纪念，不附带任何权益',
                      style: MwTypography.caption.copyWith(color: colors.text2),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(resp.pageMargin, 0, resp.pageMargin, resp.pageMargin),
                itemCount: _items.length,
                itemBuilder: (ctx, i) => _buildItem(_items[i], skin, resp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(SkinSystem skin, AppResponsive resp) {
    final colors = skin.colors;
    return Container(
      margin: EdgeInsets.all(resp.pageMargin),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.accent,
            colors.accent.withValues(alpha: AppAlphas.o80),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.design.radius.lg),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: const MonsterAvatar(size: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的尖叫币',
                  style: MwTypography.bodySm.copyWith(color: colors.onGlassAccent.withValues(alpha: AppAlphas.o80)),
                ),
                const SizedBox(height: 4),
                Text('$_coins', style: MwTypography.heading3.copyWith(color: colors.onGlassAccent)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '今日已获得',
                style: MwTypography.bodySm.copyWith(color: colors.onGlassAccent.withValues(alpha: AppAlphas.o80)),
              ),
              const SizedBox(height: 4),
              Text('+$_todayEarned', style: MwTypography.heading4.copyWith(color: colors.onGlassAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_RedeemItem item, SkinSystem skin, AppResponsive resp) {
    final colors = skin.colors;
    // 耗材永不进“已拥有”态，走库存口径。
    final redeemed = !item.isConsumable && _redeemedIds.contains(item.id);
    final affordable = _coins >= item.cost;
    return Container(
      margin: EdgeInsets.only(bottom: context.design.spacing.sm),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: redeemed ? colors.accent.withValues(alpha: AppAlphas.o50) : colors.divider),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(context.design.spacing.md),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(item.color).withValues(alpha: AppAlphas.o10),
            borderRadius: BorderRadius.circular(context.design.radius.sm),
          ),
          child: Icon(item.icon, color: Color(item.color)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(item.title, style: MwTypography.bodyBold.copyWith(color: colors.text1)),
            ),
            if (item.isConsumable) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(item.color).withValues(alpha: AppAlphas.o12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text('库存 ×$_protectionStock', style: MwTypography.micro.copyWith(color: Color(item.color))),
              ),
            ] else if (redeemed) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: AppAlphas.o12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text('已拥有', style: MwTypography.micro.copyWith(color: colors.accent)),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Text(
            '${item.description} · ${item.cost} 币',
            style: MwTypography.caption.copyWith(color: colors.text2),
          ),
        ),
        trailing: redeemed
            ? Icon(Icons.verified, color: colors.accent, semanticLabel: '已拥有')
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: affordable ? colors.accent : colors.text3.withValues(alpha: AppAlphas.o30),
                  foregroundColor: affordable ? colors.onGlassAccent : colors.text2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  elevation: 0,
                ),
                onPressed: _redeeming ? null : () => _redeem(item),
                child: _redeeming
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(item.cost.toString(), style: MwTypography.micro.copyWith(color: context.skin.colors.text1)),
              ),
      ),
    );
  }
}

class _RedeemItem {
  final String id;
  final String title;
  final String description;
  final int cost;
  final IconData icon;
  final int color;

  /// 耗材（如保护卡）：可重复兑换，走库存口径，不进 redeemedIds。
  final bool isConsumable;

  const _RedeemItem({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.icon,
    required this.color,
    this.isConsumable = false,
  });
}
