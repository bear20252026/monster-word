// 怪兽性格（蓝图 W4「开局命名仪式」：三性格 = 三组待机动画 + 三套台词组）。
//
// 性格在破壳命名仪式上选定，随 MonsterIdentityPrefs 落库；台词引擎与待机
// 动画都从这里取数——单一来源，不在各页面各写一套。
// 世界观红线：性格只影响「怎么演、怎么说」，绝不参与任何数值计算
// （奖励/概率/难度一律与性格无关）。
// 文案红线与台词引擎同口径：温暖不指责，零 emoji。
import 'package:word_app/core/utils/monster_identity_prefs.dart';
import 'package:word_app/core/utils/monster_speech.dart';

/// 三种性格（枚举名即 SP 存储值，改名等于丢档，勿动）。
enum MonsterPersonality {
  /// 活泼：闲不住，待机蹦得欢，说话热热闹闹。
  lively,

  /// 安静：慢悠悠，待机轻轻晃，说话温温软软。
  calm,

  /// 倔强：有主意，待机带点小顿挫，说话嘴硬心软。
  stubborn,
}

/// 性格展示名（选择卡与门牌用）。
const Map<MonsterPersonality, String> personalityLabels = {
  MonsterPersonality.lively: '活泼',
  MonsterPersonality.calm: '安静',
  MonsterPersonality.stubborn: '倔强',
};

/// 性格一句话简介（选择卡副标题；只描述脾气，不承诺数值）。
const Map<MonsterPersonality, String> personalityDescriptions = {
  MonsterPersonality.lively: '闲不住的小太阳，见到你就蹦跶',
  MonsterPersonality.calm: '慢悠悠的小月亮，陪你安安静静地学',
  MonsterPersonality.stubborn: '有主意的小石头，嘴硬但一直陪着你',
};

/// 解析 SP 存储值；null/未知值回退 [MonsterPersonality.lively]（老档无性格字段）。
MonsterPersonality parsePersonality(String? raw) {
  for (final p in MonsterPersonality.values) {
    if (p.name == raw) return p;
  }
  return MonsterPersonality.lively;
}

/// 待机动画参数（纯数据，渲染层消费；单位与 monster_presence 的 bob 一致）。
class IdleMotion {
  const IdleMotion({required this.amplitude, required this.tiltAmplitude, required this.periodMs});

  /// 上下浮动幅度（逻辑像素）。
  final double amplitude;

  /// 左右倾摆幅度（弧度；0 = 不倾摆）。
  final double tiltAmplitude;

  /// 一个完整待机循环的时长（毫秒）。
  final int periodMs;
}

/// 三组待机动画：活泼快而蹦、安静慢而轻、倔强中速带顿挫（倾摆表达「拿主意」）。
const Map<MonsterPersonality, IdleMotion> idleMotions = {
  MonsterPersonality.lively: IdleMotion(amplitude: 3.2, tiltAmplitude: 0.05, periodMs: 2000),
  MonsterPersonality.calm: IdleMotion(amplitude: 1.6, tiltAmplitude: 0.0, periodMs: 4200),
  MonsterPersonality.stubborn: IdleMotion(amplitude: 2.2, tiltAmplitude: 0.07, periodMs: 2800),
};

/// 三套台词组：每槽 3 条，至少 1 条不含占位符（与主模板表同不变式，
/// monster_personality_test 锁定）。未列出的槽位回退主模板表。
const Map<MonsterPersonality, Map<SpeechSlot, List<String>>> personalityTemplates = {
  MonsterPersonality.lively: {
    SpeechSlot.dailyGreeting: [
      '你来啦你来啦！单词卡我都叼好了！',
      '今天也要元气满满地学单词哦~',
      '签到 {days} 天啦！我们击个掌！',
      '我先把单词卡排好队啦，就等你！',
      '咕噜咕噜~今天也是精神满满的一天！',
      '钱包里有 {balance} 枚尖叫币啦，攒着换宝贝！',
    ],
    SpeechSlot.welcomeBack: [
      '你回来啦！我蹦得好高你看到没！',
      '等你等得我把单词卡都数了一遍~',
      '回来就好！{streak} 连击我们接着续！',
      '我就知道你会回来！击掌！',
      '单词卡我都保管得好好的，随时开工！',
      '一起走过 {days} 天啦，今天继续热闹！',
    ],
    SpeechSlot.milestone: [
      '{streak} 连击！我要原地转三圈庆祝！',
      '第 {days} 天！撒花撒花撒花！',
      '进化成{stage}啦！快看我快看我！',
      '新纪录！咕噜——撒花庆祝！',
      '太棒啦！我要蹦得比台灯还高！',
      '攒到 {balance} 枚尖叫币啦，钱包鼓鼓！',
    ],
    SpeechSlot.petHappy: [
      '嘿嘿嘿，再摸一下嘛，就一下！',
      '开心得尾巴都要摇飞啦~',
      '被你摸到角角了！咕噜咕噜！',
      '最喜欢被摸角角啦，嘿嘿！',
      '（尾巴摇成小风扇）再来再来！',
      '咕噜咕噜~这是开心到冒泡的声音！',
    ],
  },
  MonsterPersonality.calm: {
    SpeechSlot.dailyGreeting: [
      '嗯，你来了。单词卡在老地方。',
      '慢慢来，今天也一起学一点。',
      '签到 {days} 天了。不急，我们一步一步走。',
      '我把单词卡理好了。你随时可以开始。',
      '咕噜……看到你，就安心了。',
      '钱包里 {balance} 枚尖叫币，都替你收着。',
    ],
    SpeechSlot.welcomeBack: [
      '你回来了。我一直在这儿。',
      '单词卡都替你收好了，随时可以开始。',
      '嗯，回来就好。{streak} 连击还在，慢慢续。',
      '这几天，我把单词卡都保管得好好的。',
      '一起走过 {days} 天了。今天也慢慢来。',
      '回来就好。我不催你。',
    ],
    SpeechSlot.milestone: [
      '第 {days} 天。我都记得。',
      '{streak} 连击了。真好。',
      '长成{stage}了。是我们一起慢慢走到的。',
      '又长大了一点。真好。',
      '这一步，我们都记着呢。',
      '{balance} 枚尖叫币了。慢慢攒，也会满。',
    ],
    SpeechSlot.petHappy: [
      '（轻轻眯起眼睛）嗯……很舒服。',
      '咕噜……慢慢地，再多一会儿。',
      '暖暖的。谢谢你。',
      '（尾巴轻轻摆了一下）嗯。',
      '这样安静地待着，就很好。',
      '咕噜……今天也被你摸得暖暖的。',
    ],
  },
  MonsterPersonality.stubborn: {
    SpeechSlot.dailyGreeting: [
      '哼，才没有在等你。单词卡……顺便叼来了。',
      '今天也要学。说好了的，不许赖。',
      '{days} 天了。既然开始了，就走下去。',
      '单词卡我叼来了。别误会，只是顺便。',
      '既然说好了每天学，那就开始吧。',
      '{balance} 枚尖叫币。我替你数着呢，一枚不少。',
    ],
    SpeechSlot.welcomeBack: [
      '回来了？我……刚好把单词卡理好而已。',
      '别误会，我只是顺手替你保管着。',
      '{streak} 连击还没断。算你守约。',
      '哼，回来就好。单词卡我没动过。',
      '一起走过 {days} 天了。既然开始了，就别停。',
      '我才没有担心你。只是单词卡不能没人管。',
    ],
    SpeechSlot.milestone: [
      '{streak} 连击。哼，我就知道你能做到。',
      '第 {days} 天。这一步，我认。',
      '{stage}形态了。是我们一起挣来的。',
      '新纪录。哼，算我们厉害。',
      '这一步走得漂亮。我说的。',
      '{balance} 枚尖叫币了。攒得不错，我认。',
    ],
    SpeechSlot.petHappy: [
      '（别过脸）就……就这一次，下不为例。',
      '咕噜。这不是撒娇，是嗓子自己响的。',
      '（尾巴悄悄摇了一下）看什么看。',
      '（耳朵动了动）哼，随你摸。',
      '就一会儿。说好了，就一会儿。',
      '咕噜……这是条件反射，不算数。',
    ],
  },
};

/// 性格设置门面（与 SfxSettings 同款「启动预热 + 进程内缓存」）：
/// 台词引擎的默认构造读 [MonsterSpeech.currentPersonality]，启动时 [load]
/// 从 SP 预热一次；命名仪式保存后经 [set] 同步，无需重启即生效。
class MonsterPersonalitySettings {
  MonsterPersonalitySettings._();

  /// 启动预热：读 SP 性格写入进程级缓存（老档无字段回退活泼）。
  static Future<void> load() async {
    MonsterSpeech.currentPersonality = await MonsterIdentityPrefs.personality();
  }

  /// 保存成功后同步进程级缓存（落库由 MonsterIdentityPrefs.save 负责）。
  static void set(MonsterPersonality personality) {
    MonsterSpeech.currentPersonality = personality;
  }
}
