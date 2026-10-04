// 怪兽小屋「生活层」（W4.5 宠物化）——profile_screen 的 part 文件。
//
// 职责：抚摸交互（撸怪）、房间气泡（需求/抚摸/睡话）、羁绊门牌。
// 与心情机（monster_mood）的分工：心情机管「它今天状态如何」（数据驱动
// 待机动作），本层管「你对它做什么、它如何回应」（交互驱动反馈）。
// 昼夜节律（MonsterRhythm）是两层的总闸：夜里它在睡觉，抚摸只会被摸醒
// 说句睡话，不弹开心、不涨羁绊。
part of 'profile_screen.dart';

extension _MonsterRoomLife on _MonsterRoomViewState {
  /// initState 接线：判定昼夜并调整待机节奏（夜间呼吸放慢一倍多）。
  void _initRoomLife() {
    _isNight = MonsterRhythm.isSleepTime();
    _loadBondState();
  }

  /// 门牌羁绊（读失败保持 null → 门牌不出羁绊段，不假装认识）。
  Future<void> _loadBondState() async {
    final points = await MonsterBondPrefs.points();
    if (!mounted) return;
    _lifeSetState(() => _bondLevelName = BondLevel.levelOf(points).name);
  }

  /// 房间气泡：显示 [text]，4.2s 后自动收敛（单一气泡位，后到覆盖）。
  void _showRoomBubble(String text) {
    _roomBubbleTimer?.cancel();
    _lifeSetState(() => _roomBubble = text);
    _roomBubbleTimer = Timer(const Duration(milliseconds: 4200), () {
      if (mounted) _lifeSetState(() => _roomBubble = null);
    });
  }

  /// 进屋需求气泡（每日事实驱动，非台词预算系统）：复习 > 签到。
  /// 只在小屋白天进屋时查一次；抽屉开着不打扰。
  Future<void> _maybeShowNeedBubble({required int? dueCount}) async {
    if (_isNight) return;
    try {
      var daysSince = -1; // -1 = 从未签到/读取失败：不催新用户（先让关系发生）
      final store = context.read<ScareCoinStore>();
      final lastIso = await store.lastCheckInDate();
      if (lastIso.isNotEmpty) {
        final last = DateTime.tryParse(lastIso);
        final now = MonsterRhythm.now();
        if (last != null) {
          daysSince = DateTime(
            now.year,
            now.month,
            now.day,
          ).difference(DateTime(last.year, last.month, last.day)).inDays;
        }
      }
      final need = pickMonsterNeed(dueCount: dueCount ?? 0, daysSinceLastCheckin: daysSince);
      if (!mounted || need == null || _activeKey != null) return;
      _showRoomBubble(_roomSpeech.pick(need.slot, vars: need.vars));
    } catch (e, s) {
      reportSwallowedError('小屋需求气泡读取失败', e, s);
    }
  }

  // ── 抚摸（撸怪）：长按开始，横向划动 = 一下一下摸 ──

  Future<void> _onPetStart(LongPressStartDetails details) async {
    if (_activeKey != null) return; // 抽屉展开时不响应（蒙幕语义优先）
    _petting = true;
    _petStrokes = 0;
    _petStrokeDist = 0;
    _petLastPos = details.localPosition;
    if (_isNight) {
      // 夜里被摸醒：睁眼代价太大，迷迷糊糊说句睡话继续睡。
      _showRoomBubble(_roomSpeech.pick(SpeechSlot.sleepyGreeting, vars: {'name': _monsterName}));
      return;
    }
    HapticsGate.play(HapticCue.light);
    _lifeSetState(() => _happy = 0.15);
  }

  void _onPetMove(LongPressMoveUpdateDetails details) {
    if (!_petting || _isNight) return;
    // LongPressMoveUpdateDetails 没有 delta：用相邻两次 localPosition 自算。
    _petStrokeDist += (details.localPosition - _petLastPos).distance;
    _petLastPos = details.localPosition;
    if (_petStrokeDist >= 34) {
      // 34 逻辑像素 ≈ 一下摸头；每下轻触觉一次，开心度爬升。
      _petStrokeDist = 0;
      _petStrokes++;
      HapticsGate.play(HapticCue.light);
      _lifeSetState(() => _happy = (0.15 + _petStrokes * 0.2).clamp(0.0, 1.0));
    }
  }

  Future<void> _onPetEnd(LongPressEndDetails details) async {
    if (!_petting) return;
    _petting = false;
    if (_isNight) return; // 夜里继续睡：不记账不弹台词
    try {
      final result = await MonsterBondPrefs.recordPet();
      if (!mounted) return;
      if (result.awarded && result.todayCount <= 1) {
        // 今日第一次摸它：羁绊 +1，开心台词 + 咕噜声。
        SfxPlayer.fire(Sfx.purr);
        _showRoomBubble(_roomSpeech.pick(SpeechSlot.petHappy, vars: {'name': _monsterName}));
        await _loadBondState();
      } else if (result.todayCount >= MonsterBondPrefs.annoyedAfterSessions) {
        // 摸太多了：性格登场（羁绊由同日闸门自然不再增长）。
        _showRoomBubble(_roomSpeech.pick(SpeechSlot.petAnnoyed, vars: const {}));
      } else {
        // 当日重复摸：咕噜声仍在，台词不再刷屏。
        SfxPlayer.fire(Sfx.purr);
      }
    } catch (e, s) {
      reportSwallowedError('抚摸羁绊记账失败', e, s);
    }
    if (!mounted) return;
    // 开心表情缓缓收回（收回期间再次抚摸会被 _petting 覆盖，不打断）。
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && !_petting) _lifeSetState(() => _happy = 0.0);
    });
  }

  // ── 舞台挂件：夜间色 + Zzz + 气泡（由 _buildStage 插入 Stack）──

  /// 夜幕层：家具整体压暗（怪兽在其上保持清晰）。
  Widget? get _nightOverlay => _isNight
      ? Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: TreasurePalette.ink.withValues(alpha: AppAlphas.o40)),
          ),
        )
      : null;

  /// 睡觉 Zzz（夜里常驻；静态文本——reduce-motion 与夜息共用无动画口径）。
  Widget? get _sleepGlyph => !_isNight
      ? null
      : Positioned(
          left: 232,
          bottom: 168,
          child: Text(
            'z Z',
            key: const ValueKey('monster-zzz'),
            style: MwTypography.bodySm.copyWith(fontWeight: FontWeight.w800, color: TreasurePalette.dim),
          ),
        );

  /// 房间气泡（需求/抚摸/睡话共用一个位：怪兽头顶居中）。
  Widget? get _lifeBubble => _roomBubble == null
      ? null
      : Positioned(
          left: 110,
          bottom: 168,
          width: 240,
          child: AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: TreasurePalette.card,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: TreasurePalette.line),
                boxShadow: const [BoxShadow(color: TreasurePalette.pillShadow, blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Text(
                _roomBubble!,
                key: const ValueKey('monster-room-bubble'),
                textAlign: TextAlign.center,
                style: MwTypography.micro.copyWith(fontWeight: FontWeight.w700, color: TreasurePalette.ink),
              ),
            ),
          ),
        );

  /// 怪兽本体包装：白天长按抚摸、夜里轻点说睡话（Semantics 可达）。
  Widget _monsterLifeWrap(Widget child) {
    return Semantics(
      label: _isNight ? '怪兽睡着了，轻点它会迷迷糊糊说梦话' : '长按抚摸怪兽',
      button: true,
      child: GestureDetector(
        key: const ValueKey('room-monster'),
        behavior: HitTestBehavior.opaque,
        onLongPressStart: _onPetStart,
        onLongPressMoveUpdate: _onPetMove,
        onLongPressEnd: _onPetEnd,
        onTap: () {
          if (_isNight) {
            _showRoomBubble(_roomSpeech.pick(SpeechSlot.sleepyGreeting, vars: {'name': _monsterName}));
          }
        },
        child: child,
      ),
    );
  }
}
