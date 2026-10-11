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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/utils/haptics_gate.dart';
import 'package:word_app/core/utils/calendar_days.dart';
import 'package:word_app/core/utils/monster_bond_prefs.dart';
import 'package:word_app/core/utils/monster_identity_prefs.dart';
import 'package:word_app/core/utils/monster_rhythm.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/core/utils/sfx.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/account/application/account_profile_state.dart';
// 跨 feature 只依赖 application 端口（R4 通道）
import 'package:word_app/features/learning/application/learning_statistics_reader.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/features/learning/application/monster_mood.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/tokens/design_tokens.dart';
import 'package:word_app/tokens/room_palette.dart';
import 'package:word_app/tokens/treasure_palette.dart';
import 'package:word_app/widgets/message_badge_icon.dart';
import 'package:word_app/widgets/bond_level_up_overlay.dart';
import 'package:word_app/widgets/monster_icon.dart';

part 'monster_room_painters.dart';
part 'monster_room_life.dart';

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
      // 曾错接 scareCoinHistory（余额明细）：真实兑换中心路由已注册却从未被
      // 小屋使用，点「兑换中心」进的是明细页。
      _RoomRow('兑换中心', '断签保护卡等', TreasurePalette.pigAccent, RouteNames.redemption),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
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

  /// 怪兽名（蓝图 W4 命名仪式的回显；未破壳/未读到 → null → 门牌不出这一行）。
  String? _monsterName;

  /// 窗外天色：0 日 / 1 暮 / 2 夜（专利要点④「点窗循环 日/暮/夜」）。
  /// 未手动选过（_skyAuto）时跟随真实时钟自动流转；点窗循环并持久化选择。
  int _sceneIdx = 0;
  bool _skyAuto = true;
  static const String _skySceneKey = 'monster_room.sky_scene';

  /// 房间时钟：每分钟重估昼夜节律与自动天色（此前 _isNight 只在 initState
  /// 求值一次，21:55 进 App 23:00 切到本页仍见白天怪兽在蹦跶）。
  Timer? _roomClock;
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

  // ── W4.5 宠物化：昼夜节律 / 抚摸 / 羁绊 / 房间气泡（方法在 monster_room_life.dart）──
  bool _isNight = false;
  bool _petting = false;
  double _happy = 0.0; // 抚摸开心度 0~1（驱动 _RoomMonsterPainter.happy）
  int _petStrokes = 0;
  double _petStrokeDist = 0;
  Offset _petLastPos = Offset.zero;
  String? _roomBubble;
  Timer? _roomBubbleTimer;
  String? _bondLevelName;
  final MonsterSpeech _roomSpeech = MonsterSpeech();

  /// 上次读到的羁终等级阈值（null = 首次载入不办仪式；
  /// 跨阈值时触发 BondLevelUpOverlay）。
  int? _lastBondMin;

  /// 需求气泡是否还没弹过（首次「进屋」可见时才弹——IndexedStack 会在
  /// 启动时就构建全部 tab，不可见时弹掉等于永远看不见）。
  bool _needBubblePending = true;

  /// 心情解析是否已完成（需求气泡依赖 _lastDueCount；didChangeDependencies
  /// 触发时异步解析往往未就绪，两个入口都经 _tryFireNeedBubble 守门）。
  bool _moodReady = false;

  /// 最近一次解析心情时的到期数（供首次可见时的需求气泡复用）。
  int? _lastDueCount;

  /// 统计域监听（dueCount 变化 → 心情实时刷新；此前只在 initState 解析一次，
  /// 80 个到期词清零后小屋怪兽仍 worried 停跳踱步）。
  LearningStatisticsReader? _statsReader;

  /// 房主进化阶段（签到天数换算；签完到进化仪式回来重读）。
  int _evoStage = 0;

  /// life 扩展（part 文件）专用的 setState 转发：setState 是 @protected 成员，
  /// 扩展方法内直接调用会触发 invalid_use_of_protected_member。
  void _lifeSetState(VoidCallback fn) => setState(fn);

  // 蓝图 W4 五档心情机：默认 calm；由 resolver 按真实数据驱动（数据不可得不猜，降级 calm）。
  MonsterMood _mood = MonsterMood.calm;
  double get _hopAmplitude => switch (_mood) {
    MonsterMood.excited => 1.25,
    MonsterMood.calm => 1.0,
    MonsterMood.sleepy => 0.5,
    MonsterMood.worried => 0.0,
  };
  double get _idleSpeed => switch (_mood) {
    MonsterMood.excited => 0.7, // 周期缩短→呼吸更快
    MonsterMood.calm => 1.0,
    MonsterMood.sleepy => 1.6,
    MonsterMood.worried => 1.3,
  };

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
    _loadMonsterName();
    try {
      _statsReader = context.read<LearningStatisticsReader?>();
      _statsReader?.addListener(_onStatsChanged);
    } catch (_) {
      _statsReader = null; // 未装配统计域（如单独预览）
    }
    _resolveMood();
    _initRoomLife();
    if (!_reduceMotion) {
      // 夜息：睡着时呼吸放慢一倍多，不眨眼（闭眼由 painter blink=1 呈现）。
      _idleCtrl.duration = Duration(milliseconds: _isNight ? 7600 : 3200);
      _idleCtrl.repeat();
      if (!_isNight) _blinkTimer = Timer.periodic(const Duration(milliseconds: 3400), (_) => _runBlink());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // W4.5「它会找你」：本 tab 首次可见（TickerMode 翻 true）才弹需求气泡。
    // 主壳 IndexedStack 常驻构建全部 tab，以前不可见也会弹掉并超时消失。
    _tryFireNeedBubble();
  }

  /// 需求气泡双条件守门：可见 + 心情取数已就绪。didChangeDependencies 触发时
  /// _resolveMood 的异步往往未完成（dueCount 还是 null），由其完成后再补一发。
  void _tryFireNeedBubble() {
    if (!_needBubblePending || !_moodReady) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    _needBubblePending = false;
    unawaited(_maybeShowNeedBubble(dueCount: _lastDueCount));
  }

  void _onStatsChanged() {
    if (!mounted) return;
    _resolveMood();
  }

  /// 蓝图 W4：按真实学习数据解析心情（只读，零新持久层）。
  Future<void> _resolveMood() async {
    int? dueCount;
    try {
      // 走 application 层 Reader 端口（跨 feature 不直接依赖他域 presentation 类）。
      final stats = context.read<LearningStatisticsReader>();
      dueCount = stats.dueCount;
    } catch (_) {
      dueCount = null; // 未装配统计域（如单独预览）→ 不可得
    }
    // combo 为会话内部状态（learning presentation 私有），小屋不跨域读：v0 只用 dueCount + 回归两路数据。
    final int? combo = null;
    ScareCoinStore? store;
    try {
      store = context.read<ScareCoinStore>();
    } catch (_) {
      store = null;
    }
    final resolvedDue = dueCount;
    final resolvedCombo = combo;
    final mood = await resolveMonsterMood(
      dueCountReader: resolvedDue == null ? null : () => resolvedDue,
      todayComboReader: resolvedCombo == null ? null : () => resolvedCombo,
      store: store,
    );
    if (!mounted) return;
    setState(() => _mood = mood);
    _lastDueCount = dueCount;
    _moodReady = true;
    _tryFireNeedBubble();
    // 心情变化后重排呼吸节奏（repeat 周期变更需重启）。
    if (!_reduceMotion) {
      _idleCtrl.stop();
      _idleCtrl.duration = Duration(milliseconds: (3200 * _idleSpeed * (_isNight ? 2.4 : 1.0)).round());
      _idleCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _statsReader?.removeListener(_onStatsChanged);
    _roomClock?.cancel();
    _roomBubbleTimer?.cancel();
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
    var stage = 0;
    try {
      stage = MonsterIcon.stageFor((await store.checkinDates()).length);
    } catch (e, s) {
      reportSwallowedError('小屋房主形态读取失败（降级奶泡）', e, s);
    }
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _balanceLoaded = true;
      _evoStage = stage;
    });
  }

  /// 门牌回显怪兽名——蓝图 W4「开局命名仪式」闭环的最后一环（仪式页写，这里读）。
  /// 世界观红线：名字只进展示，绝不参与任何数值计算。
  Future<void> _loadMonsterName() async {
    try {
      if (!await MonsterIdentityPrefs.hatched) return;
      final name = await MonsterIdentityPrefs.name();
      if (!mounted) return;
      setState(() => _monsterName = name);
    } catch (e, s) {
      reportSwallowedError('小屋门牌怪兽名读取失败', e, s);
    }
  }

  // ── 交互 ──
  void _onPointerHover(PointerEvent e, Offset monsterCenter) {
    if (_reduceMotion || _isNight) return; // 睡着了瞳孔不跟人
    final dx = ((e.localPosition.dx - monsterCenter.dx) / 240).clamp(-1.0, 1.0);
    final dy = ((e.localPosition.dy - monsterCenter.dy) / 200).clamp(-1.0, 1.0);
    setState(() => _pupilOffset = Offset(dx * 4, dy * 3));
  }

  void _openObject(String key) {
    final reduced = _reduceMotion;
    setState(() => _activeKey = key);
    if (!reduced && !_isNight) _hopCtrl.forward(from: 0); // 睡着了不蹦
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
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: TreasurePalette.ink.withValues(alpha: AppAlphas.o18),
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
                    color: TreasurePalette.gold.withValues(alpha: AppAlphas.o20),
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
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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
      // 门牌只依赖头像与昵称两个字段：资料编辑/刷新的 notify 不再整页重建
      child: Selector<AccountProfileState, (String, String)>(
        selector: (_, profile) => (profile.avatar, profile.nickname),
        builder: (context, data, _) => _buildRoom(context, data.$1, data.$2),
      ),
    );
  }

  Widget _buildRoom(BuildContext context, String avatar, String nickname) {
    return Column(
      children: [
        // 门牌在宽屏下限宽居中，与舞台同轴
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildDoorplate(avatar, nickname),
          ),
        ),
        Expanded(child: _buildStage()),
      ],
    );
  }

  // ── 门牌身份区 ──
  Widget _buildDoorplate(String avatar, String nickname) {
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
                    image: avatar.isEmpty
                        ? null
                        : DecorationImage(
                            // 头像小窗（~64px 逻辑）：按 2x 解码即可，别把相机原图驻进内存。
                            image: ResizeImage(FileImage(File(avatar)), width: 192, height: 192),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: avatar.isEmpty ? Icon(Icons.menu_book_rounded, color: RoomPalette.woodDark, size: 28) : null,
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
                  nickname.isEmpty ? '未设置昵称' : nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MwTypography.bodyMd.copyWith(fontWeight: FontWeight.w800, color: TreasurePalette.ink),
                ),
                if (_monsterName != null) ...[
                  const SizedBox(height: 2),
                  // 纯 Text 回显（不做富文本/方向嵌入），名字来自开局命名仪式。
                  Text(
                    // 羁绊段（W4.5）：读到才显示，未读到不假装认识。
                    '怪兽 · $_monsterName${_bondLevelName == null ? '' : ' · 羁绊$_bondLevelName'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MwTypography.micro.copyWith(fontWeight: FontWeight.w600, color: TreasurePalette.dim),
                  ),
                ],
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
      // 专利要点④：窗是「点窗循环 日/暮/夜」的戏法位——点窗换天色，
      // 长按才展开外观抽屉（入口不丢，双手势都进 Semantics 说明）。
      final isWindow = key == 'scene';
      return Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        child: Semantics(
          label: isWindow ? '窗外天色，点按切换日暮夜，长按打开外观设置' : _RoomObjects.specs[key]!.label,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isWindow ? _cycleSky : () => _openObject(key),
            onLongPress: isWindow ? () => _openObject(key) : null,
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
                        color: active ? TreasurePalette.green.withValues(alpha: AppAlphas.o40) : TreasurePalette.line,
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
              // W4.5 夜幕：家具压暗一层，怪兽与 Zzz 画在其上保持清晰。
              ?_nightOverlay,
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
              // 房主（爪印地毯上）：跳跃 + 挤压拉伸 + 待机呼吸；长按抚摸（W4.5）
              Positioned(
                left: stageW / 2 - 58,
                bottom: stageH * 0.035,
                child: _monsterLifeWrap(
                  AnimatedBuilder(
                    animation: Listenable.merge([_hopCtrl, _blinkCtrl, _idleCtrl]),
                    builder: (context, child) {
                      // 蓝图 W4：心情驱动——hop 振幅分档；worried 不跳，改为呼吸相位驱动的小碎步左右微摆。
                      final air = _reduceMotion ? 0.0 : math.sin(math.pi * _hopCtrl.value) * _hopAmplitude;
                      final breathe = _reduceMotion ? 0.0 : math.sin(2 * math.pi * _idleCtrl.value);
                      final pace = !_isNight && _mood == MonsterMood.worried && !_reduceMotion
                          ? math.sin(2 * math.pi * _idleCtrl.value) * 2.0
                          : 0.0;
                      // 跳起拉伸（纵向拉长横向收窄），落地恢复；呼吸叠加微小起伏
                      final sy = (1 + 0.12 * air) * (1 + 0.015 * breathe);
                      final sx = (1 - 0.10 * air) * (1 - 0.01 * breathe);
                      return Transform.translate(
                        offset: Offset(pace, -16 * air),
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
                        blink: _isNight ? 1.0 : (_reduceMotion ? 0 : _blinkSeq.evaluate(_blinkCtrl)),
                        hop: _isNight || _reduceMotion ? 0.0 : math.sin(math.pi * _hopCtrl.value),
                        happy: _happy,
                        evoStage: _evoStage,
                      ),
                    ),
                  ),
                ),
              ),
              ?_sleepGlyph,
              ?_lifeBubble,
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
          color: TreasurePalette.card.withValues(alpha: AppAlphas.o90),
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
