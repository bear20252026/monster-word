import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/core/presentation/responsive.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';

/// 兑换中心页面。
///
/// 经济规则（用户确认，2026-08-31）：
/// - 不设 VIP、不做任何权益墙：全部功能对所有人无条件开放。
/// - 兑换为纯收集/纪念性质：真实扣币、真实入账，但不附带任何功能权益。
/// - 商品一经兑换永久持有（按 id 记录在本地，不提供退换）。
class RedemptionCenterPage extends StatefulWidget {
  static const String routeName = '/redemption';
  const RedemptionCenterPage({super.key});

  @override
  State<RedemptionCenterPage> createState() => _RedemptionCenterPageState();
}

class _RedemptionCenterPageState extends State<RedemptionCenterPage> {
  /// 已兑换收藏章键前缀（单一事实来源：AppPreferences.redeemedBadgePrefix）。
  static const String _redeemedPrefix = AppPreferences.redeemedBadgePrefix;

  int _coins = 0;
  int _todayEarned = 0;
  Set<String> _redeemedIds = <String>{};
  bool _redeeming = false;

  static const List<_RedeemItem> _items = [
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
    final results = await Future.wait([store.balance(), store.history()]);
    if (!mounted) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayEarned = (results[1] as List)
        .where((e) => e.delta > 0 && _isoDay(e.time) == today)
        .fold<int>(0, (sum, e) => sum + e.delta as int);
    setState(() {
      _coins = results[0] as int;
      _todayEarned = todayEarned;
      _redeemedIds = _items.map((i) => i.id).where((id) => prefs.getBool('$_redeemedPrefix$id') ?? false).toSet();
    });
  }

  static String _isoDay(DateTime t) => t.toIso8601String().substring(0, 10);

  Future<void> _redeem(_RedeemItem item) async {
    if (_redeeming || _redeemedIds.contains(item.id)) return;
    if (_coins < item.cost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('尖叫币不足（还差 ${item.cost - _coins} 枚），继续学习攒币吧！')));
      return;
    }
    setState(() => _redeeming = true);
    try {
      final store = context.read<ScareCoinStore>();
      await store.grant(delta: -item.cost, reason: '兑换 · ${item.title}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_redeemedPrefix${item.id}', true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('兑换成功！「${item.title}」已收入囊中 👹')));
      await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('兑换失败，请稍后重试')));
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
              padding: const EdgeInsets.all(12),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accent, colors.accent.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.design.radius.lg),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: const Text('👹', style: TextStyle(fontSize: 32))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('我的尖叫币', style: MwTypography.bodySm.copyWith(color: colors.onGlassAccent.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Text('$_coins', style: MwTypography.heading3.copyWith(color: colors.onGlassAccent)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('今日已获得', style: MwTypography.bodySm.copyWith(color: colors.onGlassAccent.withValues(alpha: 0.8))),
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
    final redeemed = _redeemedIds.contains(item.id);
    final affordable = _coins >= item.cost;
    return Container(
      margin: EdgeInsets.only(bottom: context.design.spacing.sm),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(context.design.radius.md),
        border: Border.all(color: redeemed ? colors.accent.withValues(alpha: 0.5) : colors.divider),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(context.design.spacing.md),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(item.color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(context.design.radius.sm),
          ),
          child: Icon(item.icon, color: Color(item.color)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(item.title, style: MwTypography.bodyBold.copyWith(color: colors.text1)),
            ),
            if (redeemed) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('已拥有', style: MwTypography.micro.copyWith(color: colors.accent)),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${item.description} · ${item.cost} 币',
            style: MwTypography.caption.copyWith(color: colors.text2),
          ),
        ),
        trailing: redeemed
            ? Icon(Icons.verified, color: colors.accent, semanticLabel: '已拥有')
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: affordable ? colors.accent : colors.text3.withValues(alpha: 0.3),
                  foregroundColor: affordable ? colors.onGlassAccent : colors.text2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.design.radius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 0,
                ),
                onPressed: _redeeming ? null : () => _redeem(item),
                child: _redeeming
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(item.cost.toString(), style: MwTypography.micro),
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

  const _RedeemItem({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.icon,
    required this.color,
  });
}
