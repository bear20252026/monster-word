// 怪兽小屋「生活层」（W4.5 宠物化）——profile_screen 的 part 文件。
//
// 职责：抚摸交互（撸怪）、房间气泡（需求/抚摸/睡话）、羁绊门牌。
// 与心情机（monster_mood）的分工：心情机管「它今天状态如何」（数据驱动
// 待机动作），本层管「你对它做什么、它如何回应」（交互驱动反馈）。
// 昼夜节律（MonsterRhythm）是两层的总闸：夜里它在睡觉，抚摸只会被摸醒
// 说句睡话，不弹开心、不涨羁绊。
part of 'profile_screen.dart';

extension _MonsterRoomLife on _MonsterRoomViewState {
  /// 用户昵称：{name} 台词通道的正确语义是「怪兽在喊你」（「最喜欢{name}了」
  /// 是它对主人说的话）。此前喂的是怪兽自己的名字——咕噜夸「最喜欢阿咕了」。
  String? get _userNickname {
    try {
      final nick = context.read<AccountProfileState>().nickname.trim();
      return nick.isEmpty ? null : nick;
    } catch (_) {
      return null; // 未装配资料域 → 含 {name} 的台词自动跳过，不硬凑
    }
  }

  /// initState 接线：判定昼夜并调整待机节奏（夜间呼吸放慢一倍多）。
  void _initRoomLife() {
    _isNight = MonsterRhythm.isSleepTime();
    _loadBondState();
    _loadSkyScene();
    _maybeCelebrateBirthday();
    // 房间时钟：每分钟重估昼夜与自动天色。跨过 22:00 时怪兽当场犯困，
    // 跨过 6:00 时醒来——不再需要重进页面才看到节律变化。
    _roomClock = Timer.periodic(const Duration(minutes: 1), (_) => _refreshRoomClock());
  }

  /// 时钟 tick：昼夜翻转时同步待机节奏；自动天色模式下窗外随真实时间流转。
  void _refreshRoomClock() {
    if (!mounted) return;
    final night = MonsterRhythm.isSleepTime();
    if (night != _isNight) {
      _lifeSetState(() => _isNight = night);
      if (!_reduceMotion) {
        _idleCtrl.stop();
        _idleCtrl.duration = Duration(milliseconds: (3200 * _idleSpeed * (night ? 2.4 : 1.0)).round());
        _idleCtrl.repeat();
      }
      if (night) {
        _blinkTimer?.cancel();
      } else if (!_reduceMotion) {
        _blinkTimer ??= Timer.periodic(const Duration(milliseconds: 3400), (_) => _runBlink());
      }
    }
    if (_skyAuto) {
      final auto = _autoSkyFor(MonsterRhythm.now());
      if (auto != _sceneIdx) _lifeSetState(() => _sceneIdx = auto);
    }
  }

  /// 载入持久化天色；无记录则自动模式按当前时刻起档。
  Future<void> _loadSkyScene() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_MonsterRoomViewState._skySceneKey);
      if (!mounted) return;
      if (saved == null || saved < 0 || saved > 2) {
        _lifeSetState(() {
          _skyAuto = true;
          _sceneIdx = _autoSkyFor(MonsterRhythm.now());
        });
      } else {
        _lifeSetState(() {
          _skyAuto = false;
          _sceneIdx = saved;
        });
      }
    } catch (e, s) {
      reportSwallowedError('小屋天色偏好读取失败', e, s);
    }
  }

  /// 点窗循环天色（专利要点④）：日 → 暮 → 夜 → 回自动。怪兽对天色有一句
  /// 感想（房间气泡通道，不占台词预算——与需求/睡话同口径）。
  Future<void> _cycleSky() async {
    final next = (_sceneIdx + 1) % 3;
    _lifeSetState(() {
      _skyAuto = false;
      _sceneIdx = next;
    });
    if (!_reduceMotion && !_isNight) _hopCtrl.forward(from: 0);
    const skyTalks = ['天亮堂堂的，最适合学单词啦！', '晚霞把云都染成橘子色了呢~', '星星出来啦，我们一起数星星背词吧。'];
    _showRoomBubble(skyTalks[next]);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_MonsterRoomViewState._skySceneKey, next);
    } catch (e, s) {
      reportSwallowedError('小屋天色偏好写入失败', e, s);
    }
  }

  /// 生日彩蛋：今天是它的破壳日（同月同日）时，进屋给一次生日惊喜
  ///（每年只庆一次，SP 按年落标；多邻国 Duo 生日问候的同款温度）。
  Future<void> _maybeCelebrateBirthday() async {
    try {
      if (!await MonsterIdentityPrefs.hatched) return;
      final birthday = await MonsterIdentityPrefs.birthday();
      if (birthday == null) return;
      final now = MonsterRhythm.now();
      if (birthday.month != now.month || birthday.day != now.day) return;
      final yearKey = 'monster_birthday_celebrated_${now.year}';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(yearKey) ?? false) return;
      if (!mounted) return;
      final saved = await prefs.setBool(yearKey, true);
      if (!saved) return;
      final name = _monsterName ?? '小怪兽';
      final age = now.year - birthday.year;
      if (!mounted) return;
      if (!_reduceMotion) _hopCtrl.forward(from: 0);
      SfxPlayer.fire(Sfx.milestone);
      _showRoomBubble(age <= 0 ? '今天是$name的破壳日！谢谢你把它带回家。' : '$name今天满 $age 岁啦！生日快乐！');
    } catch (e, s) {
      reportSwallowedError('生日彩蛋读取失败', e, s);
    }
  }

  /// 门牌羁绊（读失败保持 null → 门牌不出羁绊段，不假装认识）。
  Future<void> _loadBondState() async {
    final points = await MonsterBondPrefs.points();
    if (!mounted) return;
    final level = BondLevel.levelOf(points);
    final lastMin = _lastBondMin;
    _lifeSetState(() {
      _bondLevelName = level.name;
      _lastBondMin = level.min;
    });
    // 跨阈值（初识→熟络→…）时触发升级仪式：关系时刻值得庆祝。
    if (lastMin != null && level.min > lastMin) {
      final next = BondLevel.nextMin(points);
      BondLevelUpOverlay.show(context, levelName: level.name, pointsToNext: next == null ? null : next - points);
    }
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
      if (!mounted) return; // async gap 后先验挂载，再取 provider（防对失效元素 read）
      final store = context.read<ScareCoinStore>();
      final lastIso = await store.lastCheckInDate();
      if (lastIso.isNotEmpty) {
        final last = DateTime.tryParse(lastIso);
        final now = MonsterRhythm.now();
        if (last != null) {
          // 日历日差（DST 安全）：影响催签阈值判定。
          daysSince = calendarDaysBetween(last, now);
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
      _showRoomBubble(_roomSpeech.pick(SpeechSlot.sleepyGreeting, vars: {'name': _userNickname}));
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
        _showRoomBubble(_roomSpeech.pick(SpeechSlot.petHappy, vars: {'name': _userNickname}));
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
            _showRoomBubble(_roomSpeech.pick(SpeechSlot.sleepyGreeting, vars: {'name': _userNickname}));
          }
        },
        child: child,
      ),
    );
  }
}

/// 真实时钟 → 天色档（6-16 日 / 17-18 暮 / 其余夜）。
int _autoSkyFor(DateTime now) {
  final h = now.hour;
  if (h >= 6 && h < 17) return 0;
  if (h >= 17 && h < 19) return 1;
  return 2;
}
