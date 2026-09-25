// 个人中心 · 怪兽小屋（「怪兽小屋」GUI 外观设计的产品落地版）
//
// 设计来源：
// - 设计文档 design/怪兽小屋个人中心-外观专利设计说明.md（设计要点 / 状态序列）
// - 交互原型 deliverables/room-hub-settings-prototype.html（几何与节奏参数同源搬运）
// - 色板 lib/tokens/room_palette.dart（木作+天色；暖纸/青绿/金复用 treasure_palette）
//
// 专利设计要点对应：
// ① 场景化物件入口布局：功能入口呈现场景内家具（装备架/窗/台灯书桌/唱片机/
//    书架/爪印地毯/工具箱/存钱罐），物件下常驻胶囊名牌，图形+文字双编码。
// ② 全景 ⇄ 抽屉展开 双构图：待机为房间全景；点选物件后抽屉面板自底部滑出，
//    全景蒙暖纸幕布。
// ③ 房主角色联动：小怪兽瞳孔跟随指针、周期眨眼；物件点选时跳跃响应。
// ④ 沉浸场景与窗外天色同源：窗为「外观&沉浸场景」入口，点窗循环 日/暮/夜。
//
// 无障碍：物件均有 Semantics 名牌；系统减弱动效时瞳孔不跟随、跳跃取消、抽屉改淡入。
// 架构：沿用 A5 收口——尖叫币/装备的规则与卡片唯一持有方仍是
// widgets/scare_coin_summary_cards.dart，本页零双写（装备数不在本页计算）。
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/features/account/application/account_profile_state.dart';
// 跨 feature 只依赖 application 端口（R4 通道）
import 'package:word_app/features/learning/application/learning_statistics_reader.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/room_palette.dart';
import 'package:word_app/tokens/treasure_palette.dart';
import 'package:word_app/widgets/message_badge_icon.dart';

part 'monster_room_painters.dart';

/// 房间物件规格：名牌 + 抽屉行（行可携带真实路由）。
class _RoomSpec {
  const _RoomSpec(this.label, this.rows);

  final String label;
  final List<_RoomRow> rows;
}

class _RoomRow {
  const _RoomRow(this.label, this.sub, this.dotColor, this.route);

  final String label;
  final String sub;
  final Color dotColor;
  final String? route;
}

class _RoomObjects {
  // 全部二级入口沿用现有路由（业务零改动）。
  static final specs = <String, _RoomSpec>{
    'equip': _RoomSpec('我的装备', [_RoomRow('装备架', '皮肤 / 徽章 / 摆件的存放处', TreasurePalette.gold, RouteNames.myEquip)]),
    'scene': _RoomSpec('外观 & 沉浸场景', [
      _RoomRow('主题与沉浸场景', '窗外天色即氛围预览', TreasurePalette.pigSkinTop, RouteNames.appearance),
      _RoomRow('设计语言', '卡片与字体的质感', TreasurePalette.pigSkinBottom, RouteNames.appearance),
    ]),
    'learn': _RoomSpec('学习偏好', [_RoomRow('每日目标 / 提醒 / 发音', '台灯下拧你的节奏', RoomPalette.lampGlow, RouteNames.settings)]),
    'stereo': _RoomSpec('随身听', [_RoomRow('单词电台与录音', '黑胶转起来', TreasurePalette.pigDark, RouteNames.personalStereo)]),
    'content': _RoomSpec('我的内容', [_RoomRow('生词本 / 收藏 / 笔记', '书架上的私藏', TreasurePalette.gold, RouteNames.myContent)]),
    'tracks': _RoomSpec('学习足迹', [_RoomRow('打卡历史与统计', '地毯爪印 = 每一天', TreasurePalette.goldDeep, RouteNames.footMark)]),
    'more': _RoomSpec('更多设置', [
      _RoomRow('系统与关于', '提醒 / 诊断 / 版本', TreasurePalette.pigAccent, MoreSettingsPage.routeName),
      _RoomRow('我的空间', '个人主页与档案', TreasurePalette.pigSkinBottom, RouteNames.mySpace),
    ]),
    'coin': _RoomSpec('尖叫币', [
      _RoomRow('余额与明细', '存钱罐肚皮 = 学习奖励', TreasurePalette.gold, RouteNames.scareCoinHistory),
      _RoomRow('兑换中心', '断签保护卡等', TreasurePalette.pigAccent, RouteNames.scareCoinHistory),
    ]),
  };
}

/// 个人中心页（底部导航「设置」tab 的内容页）。
///
/// 顶部保留消息入口；主体为怪兽小屋房间场景。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      color: skin.colors.pageBg,
      child: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏（仅消息图标，未读角标由 MessageStore 驱动）
            Container(
              height: AppSpacing.navH,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [const Spacer(), const MessageBadgeIcon()]),
            ),
            const Expanded(child: MonsterRoomView()),
          ],
        ),
      ),
    );
  }
}

/// 怪兽小屋房间视图（门牌身份区 + 家具物件 + 房主 + 抽屉面板）。
class MonsterRoomView extends StatefulWidget {
  const MonsterRoomView({super.key});

  @override
  State<MonsterRoomView> createState() => _MonsterRoomViewState();
}

class _MonsterRoomViewState extends State<MonsterRoomView> with TickerProviderStateMixin {
  // ── 数据 ──
  int _balance = 0;
  bool _balanceLoaded = false;
  final int _sceneIdx = 0; // 窗外天色：0 日 / 1 暮 / 2 夜（进入外观页编辑）
  String? _activeKey;
  Offset _pupilOffset = Offset.zero;
  final bool _reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  late final AnimationController _hopCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final AnimationController _blinkCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  // 待机呼吸相位（3.2s 一循环，repeat 驱动胸腔起伏）
  late final AnimationController _idleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  Timer? _blinkTimer;
  int _blinkRound = 0;

  /// 眨眼序列：快闭 → 缓开并轻微睁大回弹（旧版线性闭合后会停在闭眼 3.2s，观感差）。
  static final Animatable<double> _blinkSeq = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 34),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: -0.06).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 44),
    TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 22),
  ]);

  @override
  void initState() {
    super.initState();
    _loadBalance();
    if (!_reduceMotion) {
      _idleCtrl.repeat();
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 3400), (_) => _runBlink());
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _hopCtrl.dispose();
    _blinkCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  void _runBlink() {
    _blinkRound++;
    _blinkCtrl.forward(from: 0).whenComplete(() {
      // 每第 4 轮补一次快速双眨，更像活物。
      if (mounted && _blinkRound % 4 == 0) _blinkCtrl.forward(from: 0);
    });
  }

  Future<void> _loadBalance() async {
    final store = context.read<ScareCoinStore>();
    final balance = await store.balance();
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _balanceLoaded = true;
    });
  }

  // ── 交互 ──
  void _onPointerHover(PointerEvent e, Offset monsterCenter) {
    if (_reduceMotion) return;
    final dx = ((e.localPosition.dx - monsterCenter.dx) / 240).clamp(-1.0, 1.0);
    final dy = ((e.localPosition.dy - monsterCenter.dy) / 200).clamp(-1.0, 1.0);
    setState(() => _pupilOffset = Offset(dx * 4, dy * 3));
  }

  void _openObject(String key) {
    final reduced = _reduceMotion;
    setState(() => _activeKey = key);
    if (!reduced) _hopCtrl.forward(from: 0);
    _showDrawer(key);
  }

  void _showDrawer(String key) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _buildDrawerSheet(sheetCtx, key),
    ).then((_) {
      if (mounted) setState(() => _activeKey = null);
    });
  }

  // ── 门牌抽屉内容 ──
  Widget _buildDrawerSheet(BuildContext sheetCtx, String key) {
    final spec = _RoomObjects.specs[key]!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TreasurePalette.card, TreasurePalette.paper],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: TreasurePalette.line),
          boxShadow: const [BoxShadow(color: TreasurePalette.pillShadow, blurRadius: 34, offset: Offset(0, -14))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 6,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: TreasurePalette.ink.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: TreasurePalette.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.place_rounded, size: 18, color: TreasurePalette.goldDeep),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.label,
                        style: MwTypography.bodyMd.copyWith(fontWeight: FontWeight.w800, color: TreasurePalette.ink),
                      ),
                      if (key == 'coin' && _balanceLoaded)
                        Text(
                          '当前余额 $_balance 币',
                          style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: TreasurePalette.dim),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in spec.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DrawerRow(row: row, onTap: () => _navigate(sheetCtx, row.route)),
              ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext sheetCtx, String? route) {
    if (route == null) return;
    Navigator.of(sheetCtx).pop();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AccountProfileState>();
    return Container(
      // 暖纸固定底（与小屋家族同源，不随明暗主题切换）
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TreasurePalette.paperTop, TreasurePalette.paper, TreasurePalette.paperBottom],
          stops: [0, 0.55, 1],
        ),
      ),
      child: _buildRoom(context, profile),
    );
  }

  Widget _buildRoom(BuildContext context, AccountProfileState profile) {
    return Column(
      children: [
        // 门牌在宽屏下限宽居中，与舞台同轴
        Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _buildDoorplate(profile)),
        ),
        Expanded(child: _buildStage()),
      ],
    );
  }

  // ── 门牌身份区 ──
  Widget _buildDoorplate(AccountProfileState profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          // 相框头像（点击进入资料编辑）
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(RouteNames.accountInfo),
            child: Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: TreasurePalette.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: TreasurePalette.line),
                    boxShadow: const [
                      BoxShadow(color: TreasurePalette.pillShadow, blurRadius: 10, offset: Offset(0, 3)),
                    ],
                    image: profile.avatar.isEmpty
                        ? null
                        : DecorationImage(image: FileImage(File(profile.avatar)), fit: BoxFit.cover),
                  ),
                  child: profile.avatar.isEmpty
                      ? Icon(Icons.menu_book_rounded, color: RoomPalette.woodDark, size: 28)
                      : null,
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: TreasurePalette.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: TreasurePalette.card, width: 2),
                    ),
                    child: Icon(Icons.edit_rounded, color: TreasurePalette.checkedNum, size: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.nickname.isEmpty ? '未设置昵称' : profile.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MwTypography.bodyMd.copyWith(fontWeight: FontWeight.w800, color: TreasurePalette.ink),
                ),
                const SizedBox(height: 3),
                const _RoomStatsRow(),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 尖叫币胶囊（余额真实；点击 = 存钱罐抽屉）
          GestureDetector(
            onTap: () => _openObject('coin'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: TreasurePalette.card,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: TreasurePalette.line),
                boxShadow: const [BoxShadow(color: TreasurePalette.pillShadow, blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _RoomCoinGlyph(size: 16),
                  const SizedBox(width: 7),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_balance',
                        style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w900, color: TreasurePalette.ink),
                      ),
                      Text(
                        '学习奖励',
                        style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: TreasurePalette.dim),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 房间舞台 ──
  //
  // 自适应策略：舞台使用固定逻辑尺寸（460×560）设计构图，通过 FittedBox
  // 等比缩放居中适配任意屏幕——手机窄屏整幅缩放铺满，桌面宽屏呈现为
  // 居中的「立体小盒子」相框，物件比例与构图在所有设备保持一致，永不溢出。
  Widget _buildStage() {
    const stageW = 460.0, stageH = 560.0;
    Widget obj(String key, {double? left, double? top, double? right, double? bottom, required Widget child}) {
      final active = _activeKey == key;
      return Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        child: Semantics(
          label: _RoomObjects.specs[key]!.label,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openObject(key),
            child: AnimatedScale(
              scale: active ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  child,
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: TreasurePalette.card,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: active ? TreasurePalette.green.withValues(alpha: 0.4) : TreasurePalette.line,
                      ),
                    ),
                    child: Text(
                      _RoomObjects.specs[key]!.label,
                      style: MwTypography.micro.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: active ? TreasurePalette.green : TreasurePalette.dim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final stage = MouseRegion(
      // 瞳孔跟随：localPosition 已映射到舞台逻辑坐标
      onHover: (e) => _onPointerHover(e, Offset(stageW / 2, stageH - stageH * 0.035 - 59)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: TreasurePalette.line),
          boxShadow: const [BoxShadow(color: TreasurePalette.pillShadow, blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 墙 + 地板（舞台内满铺）
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: stageH * 0.66,
                child: ColoredBox(color: TreasurePalette.paperTop),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: stageH * 0.34,
                child: ColoredBox(color: TreasurePalette.paperBottom),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: stageH * 0.34,
                child: Container(height: 2, color: TreasurePalette.line),
              ),
              // 家具物件
              obj(
                'equip',
                left: stageW * 0.05,
                top: stageH * 0.03,
                child: CustomPaint(size: const Size(128, 64), painter: _ShelfPainter()),
              ),
              obj(
                'scene',
                right: stageW * 0.05,
                top: stageH * 0.025,
                child: CustomPaint(
                  size: const Size(118, 92),
                  painter: _WindowPainter(sceneIdx: _sceneIdx),
                ),
              ),
              obj(
                'learn',
                left: stageW * 0.06,
                top: stageH * 0.30,
                child: CustomPaint(size: const Size(150, 118), painter: _DeskPainter()),
              ),
              obj(
                'stereo',
                right: stageW * 0.06,
                top: stageH * 0.32,
                child: CustomPaint(size: const Size(118, 100), painter: _PlayerPainter()),
              ),
              obj(
                'content',
                left: stageW * 0.06,
                bottom: stageH * 0.21,
                child: CustomPaint(size: const Size(104, 84), painter: _BookshelfPainter()),
              ),
              obj(
                'tracks',
                left: stageW / 2 - 74,
                bottom: stageH * 0.05,
                child: CustomPaint(size: const Size(148, 56), painter: _RugPainter()),
              ),
              obj(
                'more',
                right: stageW * 0.05,
                bottom: stageH * 0.075,
                child: CustomPaint(size: const Size(86, 62), painter: _ToolboxPainter()),
              ),
              obj(
                'coin',
                right: stageW * 0.09,
                bottom: stageH * 0.26,
                child: CustomPaint(size: const Size(76, 46), painter: _RoomPiggyPainter()),
              ),
              // 房主（爪印地毯上）：跳跃 + 挤压拉伸 + 待机呼吸
              Positioned(
                left: stageW / 2 - 58,
                bottom: stageH * 0.035,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_hopCtrl, _blinkCtrl, _idleCtrl]),
                  builder: (context, child) {
                    final air = _reduceMotion ? 0.0 : math.sin(math.pi * _hopCtrl.value);
                    final breathe = _reduceMotion ? 0.0 : math.sin(2 * math.pi * _idleCtrl.value);
                    // 跳起拉伸（纵向拉长横向收窄），落地恢复；呼吸叠加微小起伏
                    final sy = (1 + 0.12 * air) * (1 + 0.015 * breathe);
                    final sx = (1 - 0.10 * air) * (1 - 0.01 * breathe);
                    return Transform.translate(
                      offset: Offset(0, -16 * air),
                      child: Transform(
                        transform: Matrix4.diagonal3Values(sx.toDouble(), sy.toDouble(), 1),
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    );
                  },
                  child: CustomPaint(
                    size: const Size(116, 118),
                    painter: _RoomMonsterPainter(
                      pupilOffset: _pupilOffset,
                      blink: _reduceMotion ? 0 : _blinkSeq.evaluate(_blinkCtrl),
                      hop: _reduceMotion ? 0.0 : math.sin(math.pi * _hopCtrl.value),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 等比缩放居中：上限 1.18 倍防超大屏过度放大，其余按可用空间 contain
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: stageW * 1.18, maxHeight: stageH * 1.18),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(width: stageW, height: stageH, child: stage),
          ),
        ),
      ),
    );
  }
}

/// 门牌下的真实学习数据行（沿用原 profile 口径）。
class _RoomStatsRow extends StatelessWidget {
  const _RoomStatsRow();

  @override
  Widget build(BuildContext context) {
    return Selector<LearningStatisticsReader, (int, int)>(
      selector: (_, s) => (s.totalLearnedDays, s.learnedCount),
      builder: (context, stats, _) {
        final (days, words) = stats;
        return Text(
          '${days > 0 ? '已坚持 $days 天' : '开始你的第一天'} · 掌握 $words 词',
          style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: TreasurePalette.dim),
        );
      },
    );
  }
}

/// 抽屉面板行（可携带真实路由）。
class _DrawerRow extends StatelessWidget {
  const _DrawerRow({required this.row, required this.onTap});

  final _RoomRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: TreasurePalette.card.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: TreasurePalette.line),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: row.dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                row.label,
                style: MwTypography.caption.copyWith(fontWeight: FontWeight.w700, color: TreasurePalette.ink),
              ),
            ),
            Flexible(
              child: Text(
                row.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: TreasurePalette.dim),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 15, color: TreasurePalette.dim),
          ],
        ),
      ),
    );
  }
}
