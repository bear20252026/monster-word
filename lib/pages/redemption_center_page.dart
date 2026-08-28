import 'package:flutter/material.dart';

import '../hooks/responsive.dart';
import '../theme/skin_system.dart';
import '../tokens/design_tokens.dart';

/// 兑换中心页面（遵循星巴克设计规范）
/// 用户可以使用尖叫币兑换主题、壁纸、会员等
class RedemptionCenterPage extends StatefulWidget {
  static const String routeName = '/redemption';
  const RedemptionCenterPage({super.key});

  @override
  State<RedemptionCenterPage> createState() => _RedemptionCenterPageState();
}

class _RedemptionCenterPageState extends State<RedemptionCenterPage> {
  int _coins = 1280; // 示例尖叫币余额

  final _items = const [
    _RedeemItem(
      id: 'theme_warm',
      title: '暖橙主题',
      description: '解锁温暖橙色主题',
      cost: 500,
      icon: Icons.palette,
      color: 0xFFFF8C42,
    ),
    _RedeemItem(
      id: 'theme_midnight',
      title: '深蓝主题',
      description: '解锁深邃蓝色主题',
      cost: 500,
      icon: Icons.nightlight_round,
      color: 0xFF4A90E2,
    ),
    _RedeemItem(
      id: 'vip_7',
      title: '7天VIP',
      description: '解锁全部高级功能',
      cost: 800,
      icon: Icons.workspace_premium,
      color: 0xFFCBA258,
    ),
    _RedeemItem(
      id: 'vip_30',
      title: '30天VIP',
      description: '解锁全部高级功能',
      cost: 2800,
      icon: Icons.workspace_premium,
      color: 0xFFCBA258,
    ),
    _RedeemItem(
      id: 'wallpaper_1',
      title: '星巴克壁纸包',
      description: '5张精选星巴克壁纸',
      cost: 300,
      icon: Icons.wallpaper,
      color: 0xFF008550,
    ),
    _RedeemItem(
      id: 'font_cute',
      title: '可爱字体',
      description: '解锁萌系手写字体',
      cost: 400,
      icon: Icons.font_download,
      color: 0xFFE91E63,
    ),
  ];

  void _redeem(_RedeemItem item) {
    if (_coins < item.cost) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('尖叫币不足，快去签到赚取吧！')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SkinProvider.of(context).colors.cardBg,
        title: Text('确认兑换', style: TextStyle(color: SkinProvider.of(context).colors.text1)),
        content: Text(
          '确定花费 ${item.cost} 兑换「${item.title}」吗？',
          style: TextStyle(color: SkinProvider.of(context).colors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: SkinProvider.of(context).colors.text3)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SkinProvider.of(context).colors.accent,
              foregroundColor: SkinProvider.of(context).colors.onGlassAccent,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _coins -= item.cost);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('兑换成功！${item.title} 已到账')));
            },
            child: const Text('确认兑换'),
          ),
        ],
      ),
    );
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
            icon: Icon(Icons.arrow_back, color: colors.text1),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('兑换中心', style: MistralTypography.heading5.copyWith(color: colors.text1)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: colors.divider),
          ),
        ),
        body: Column(
          children: [
            // 余额卡片
            _buildBalanceCard(skin, resp),
            // 兑换列表
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(resp.pageMargin),
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
        borderRadius: BorderRadius.circular(AppleRadius.lg),
      ),
      child: Row(
        children: [
          const Text('👹', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('我的尖叫币', style: MistralTypography.bodySm.copyWith(color: colors.onGlassAccent.withValues(alpha: 0.8))),
              const SizedBox(height: 4),
              Text('$_coins', style: MistralTypography.heading3.copyWith(color: colors.onGlassAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_RedeemItem item, SkinSystem skin, AppResponsive resp) {
    final colors = skin.colors;
    final canAfford = _coins >= item.cost;
    return Container(
      margin: const EdgeInsets.only(bottom: AppleSpacing.sm),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(AppleRadius.md),
        border: Border.all(color: colors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppleSpacing.md),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(item.color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppleRadius.sm),
          ),
          child: Icon(item.icon, color: Color(item.color)),
        ),
        title: Text(item.title, style: MistralTypography.bodyBold.copyWith(color: colors.text1)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(item.description, style: MistralTypography.caption.copyWith(color: colors.text2)),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canAfford ? colors.accent : colors.text3,
            foregroundColor: colors.onGlassAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppleRadius.pill)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
          ),
          onPressed: () => _redeem(item),
          child: Text('${item.cost}币', style: MistralTypography.micro.copyWith(color: colors.onGlassAccent)),
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
