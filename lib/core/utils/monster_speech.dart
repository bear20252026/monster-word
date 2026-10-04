// 怪兽台词引擎 — 纯本地模板槽（无网络、无 Flutter 依赖，仅 dart:math）。
// 蓝图红线：文案温暖不指责（不断签羞辱、不催促）；主动台词有每日预算，
// 用户主动点击（如点击首页怪兽）不受预算限制——预算只约束「主动弹」。
// stage 变量由调用方换算注入：MonsterIcon.stageName(MonsterIcon.stageFor(累计签到天数))
// → 0/7/30/100 天阈值映射 奶泡/尖角/飞翼/金冠（monster_icon.dart，阈值已核对）。
import 'dart:math' show Random;

import 'package:word_app/core/utils/debug_log.dart';

/// 台词槽位。
enum SpeechSlot {
  /// 日常打招呼：点击怪兽/主动问候共用文案组。
  dailyGreeting,

  /// 回归欢迎：距上次打开 ≥1 天时主动弹一次，语气温暖不指责。
  welcomeBack,

  /// 里程碑庆祝：连击/进化/天数达成等事件触发，不主动弹。
  milestone,

  /// 夜间睡话（W4.5 宠物化）：22:00–6:00 点击怪兽/摸到它时的迷糊反应。
  /// 语气红线：不指责熬夜（「快去睡吧」可以说，「你怎么还不睡」不说）。
  sleepyGreeting,

  /// 被摸开心（W4.5）：小屋抚摸会话结束、当日羁绊+1 时的反应。
  petHappy,

  /// 被摸烦了（W4.5）：同日抚摸会话 ≥4 次后的性格反应（脾气也是活物感）。
  /// 红线：不耐烦不指责——「摸够啦」可以，「别碰我」不说。
  petAnnoyed,

  /// 想被复习（W4.5 需求气泡）：到期词 ≥20 时小屋头顶的愿望，{due} 为真实到期数。
  needReview,

  /// 想被签到（W4.5 需求气泡）：≥2 天没签到时小屋头顶的愿望。语气不指责。
  needCheckin,
}

/// 怪兽台词模板引擎。
///
/// - [pick]：组内洗牌选一条；每槽记录最近 3 条避免重复（内存态，不持久化）。
/// - 每日主动预算：[canSpeak]/[consumeBudget]，每日 ≤3 条，跨日自动重置；
///   计数为进程级 static（全 app 主动弹共享同一预算）。预算只约束「主动弹」，
///   用户主动交互（点击怪兽冒 dailyGreeting）由调用方只 [pick] 不 [consumeBudget]。
/// - 可测性：构造参数注入 `now`（时间源）与 `random`（随机源）。
class MonsterSpeech {
  MonsterSpeech({DateTime Function()? now, Random? random}) : _now = now ?? DateTime.now, _random = random ?? Random();

  /// 时间源（默认 DateTime.now；测试注入固定/可控时间）。
  final DateTime Function() _now;

  /// 随机源（组内选条；测试注入固定种子）。
  final Random _random;

  /// 每日主动台词上限。
  static const int _maxProactivePerDay = 3;

  /// 每槽去重窗口：最近 3 条不再选中。
  static const int _recentWindow = 3;

  /// 模板变量名（渲染与「无通道跳过模板」共用同一口径）。
  static const List<String> _varKeys = ['days', 'streak', 'balance', 'stage', 'name', 'due'];

  // 每日预算（进程级）：_todayKey 为 yyyy-MM-dd，跨日首次访问清零 _todayCount。
  static String _todayKey = '';
  static int _todayCount = 0;

  /// 八槽文案组（每槽 6 条）。语气红线：温暖不指责。
  static const Map<SpeechSlot, List<String>> _templates = {
    SpeechSlot.dailyGreeting: [
      '今天也一起加油呀~',
      '我已经把单词卡叼来啦！',
      '你好呀，我现在是{stage}形态~',
      '钱包里躺着 {balance} 枚尖叫币，攒着换宝贝哦~',
      '咕噜咕噜~看到你我就安心了。',
      '签到 {days} 天啦，今天也从一小步开始吧。',
    ],
    SpeechSlot.welcomeBack: [
      '我就知道你会回来！',
      '这几天我一直在等你。',
      '回来啦！快看看我，已经长成{stage}啦~',
      '我们一起走过了 {days} 天，今天继续呀。',
      '你不在的日子，单词卡我都保管得好好的~',
      '想从 {streak} 连击再续上吗？不急，我陪你慢慢来。',
    ],
    SpeechSlot.milestone: [
      '第 {days} 天！我们一起长大了一点。',
      '{streak} 连击！这就是我们的小奇迹呀。',
      '看，我已经进化成{stage}啦，都是你的功劳~',
      '攒到 {balance} 枚尖叫币啦，钱包鼓鼓的真开心！',
      '新纪录达成！咕噜——撒花庆祝！',
      '{days} 天的旅程，每一步我都记着呢。',
    ],
    SpeechSlot.sleepyGreeting: [
      '唔……{name}……再睡一小会儿……',
      '呼……呼……（它翻了个身，把角埋进小毯子）',
      'z Z……单词卡我叼到枕头边了……呼……',
      '（揉眼睛）唔？天还没亮吧……',
      '夜深了，我在替你守着明天的词呢……快去睡吧。',
      '呼……明天的词……也一起……呼……',
    ],
    SpeechSlot.petHappy: [
      '咕噜咕噜~最喜欢{name}了！',
      '（眯起眼睛）好舒服……再摸摸角角。',
      '咕噜——这是开心的声音！',
      '今天也被你摸得暖暖的，学习都更有劲了。',
      '（尾巴摇成了小风扇）',
      '嘿嘿，被你摸到角角了~',
    ],
    SpeechSlot.petAnnoyed: [
      '摸够啦摸够啦，我要晕了！',
      '（歪头躲开）头要被摸秃啦！',
      '唔……让我自己静一会儿嘛。',
      '今天的贴贴额度用完啦，明天再来~',
      '（抱住自己的角护住）先让单词卡冷静一下。',
      '咕！再摸我要打嗝了哦。',
    ],
    SpeechSlot.needReview: [
      '有 {due} 个词在排队等你复习……我帮你数着呢。',
      '{due} 个词快被你忘啦，带我救回来好不好？',
      '（叼来一摞单词卡）到期的小词们在等我们！',
      '复习 {due} 个，就当今天喂我一顿饱饭~',
      '别怕多，我们一个一个来。',
      '到期的小词们排排坐，等牵它们回家呢。',
    ],
    SpeechSlot.needCheckin: [
      '今天还没签到呢，日历给我留了个空格。',
      '（趴在日历上）今天的格子还空着哦。',
      '签个到吧，我想在日历上再画一枚金币。',
      '今天的签到金币还没领呢~',
      '打卡的那一下，我最喜欢了。',
      '今天也从一小格开始吧。',
    ],
  };

  /// 全部模板（测试断言用：气泡文案 ∈ 槽位模板的渲染结果集）。
  static Iterable<String> templatesOf(SpeechSlot slot) => _templates[slot]!;

  // 每槽最近选中记录（内存即可，不持久化）。
  // 去重窗口为进程级共享：调用方各持 MonsterSpeech() 实例（首页/进化仪式），
  // 实例级记忆会让连续两场仪式连出同一条台词。
  static final Map<SpeechSlot, List<String>> _recent = {};

  /// yyyy-MM-dd（本地时区；预算跨日键与「上次打开首页」SP 值共用同一口径）。
  static String dayKeyOf(DateTime d) {
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$month-$day';
  }

  /// 今日是否还有主动弹预算（每日 ≤3，跨日重置）。
  bool canSpeak() {
    _rollDayIfNeeded();
    return _todayCount < _maxProactivePerDay;
  }

  /// 测试隔离：复位进程级 static（每日预算/去重窗口），setUp 调用。
  /// 生产禁止调用（会重置当日已消耗预算，导致超预算弹窗）。
  static void resetForTest() {
    _todayKey = '';
    _todayCount = 0;
    _recent.clear();
  }

  /// 记一次主动弹（调用方应先用 [canSpeak] 把门再消耗）。
  void consumeBudget() {
    _rollDayIfNeeded();
    _todayCount++;
  }

  /// 从槽位文案组挑一条并渲染 {days}/{streak}/{balance}/{stage}/{name}。
  ///
  /// 纯挑选：不消耗每日预算——是否 [consumeBudget] 由调用方按「是否主动弹」决定。
  /// [vars] 值为 null（或键缺失）表示「这条数据没有通道」：含该占位符的模板整条跳过，
  /// 绝不渲染成 `{balance}` → 空串这种「怪兽对用户报假事实」。每槽都保有不含占位符的
  /// 条目（monster_speech_test 锁定该不变式），故过滤后候选必非空。
  String pick(SpeechSlot slot, {required Map<String, Object?> vars}) {
    final unknown = [
      for (final key in _varKeys)
        if (vars[key] == null) key,
    ];
    final group = _templates[slot]!.where((t) => !unknown.any((key) => t.contains('{$key}'))).toList();
    final recent = _recent.putIfAbsent(slot, () => <String>[]);
    final candidates = group.where((t) => !recent.contains(t)).toList();
    if (candidates.isEmpty) {
      // 兜底（窗口 3 < 组大小 6，正常不会触达）：全组解禁再挑。
      recent.clear();
      candidates.addAll(group);
    }
    if (candidates.isEmpty) {
      // 数据不变式被破坏（某槽全部模板都含未注入占位符）时的运行时守卫：
      // 降级为中性文案，绝不让 _random.nextInt(0) 抛 ArgumentError 炸掉仪式。
      // 不变量由 monster_speech_test 锁定，正常不可触达。
      debugLog('[MonsterSpeech] 槽位过滤后无候选（不变式被破坏）：$slot / 缺失变量=$unknown');
      return '……';
    }
    final picked = candidates[_random.nextInt(candidates.length)];
    recent.add(picked);
    while (recent.length > _recentWindow) {
      recent.removeAt(0);
    }
    return _render(picked, vars);
  }

  void _rollDayIfNeeded() {
    final key = dayKeyOf(_now());
    if (_todayKey != key) {
      _todayKey = key;
      _todayCount = 0;
    }
  }

  String _render(String template, Map<String, Object?> vars) {
    var out = template;
    for (final key in _varKeys) {
      final value = vars[key];
      out = out.replaceAll('{$key}', value == null ? '' : '$value');
    }
    return out;
  }
}
