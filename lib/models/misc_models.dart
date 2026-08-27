// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：LexisDaily + LearnDurationData + StudySignData + SignDayInfo + SentencePlayLog + ListLastPosInfo + SerializableMap + SentenceSetData + BaseItemInfo + BaseItemTypeInfo

/// 每日学习统计（翻译自 LexisDaily.java）
class LexisDaily {
  int id;
  int userId;
  String date;
  int learnDuration;
  int reviewDuration;
  int appDuration;
  int listenDuration;
  int syncFlag;
  String beginTime;
  String endTime;

  LexisDaily({
    this.id = 0,
    this.userId = 0,
    this.date = '',
    this.learnDuration = 0,
    this.reviewDuration = 0,
    this.appDuration = 0,
    this.listenDuration = 0,
    this.syncFlag = 0,
    this.beginTime = '',
    this.endTime = '',
  });

  factory LexisDaily.fromJson(Map<String, dynamic> json) => LexisDaily(
    id: (json['id'] as num?)?.toInt() ?? 0,
    userId: (json['user'] as num?)?.toInt() ?? 0,
    date: json['ld'] ?? '',
    learnDuration: (json['ldu'] as num?)?.toInt() ?? 0,
    reviewDuration: (json['rdu'] as num?)?.toInt() ?? 0,
    appDuration: (json['adu'] as num?)?.toInt() ?? 0,
    listenDuration: (json['idu'] as num?)?.toInt() ?? 0,
    beginTime: json['bt'] ?? '',
    endTime: json['et'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': userId,
    'bt': beginTime,
    'et': endTime,
    'ld': date,
    'adu': appDuration,
    'ldu': learnDuration,
    'rdu': reviewDuration,
    'idu': listenDuration,
  };

  /// 重置为今日初始状态
  void reset() {
    id = 0;
    date = _todayStr();
    learnDuration = 0;
    reviewDuration = 0;
    appDuration = 0;
    listenDuration = 0;
    syncFlag = 0;
    beginTime = _currentTimeStr();
    endTime = beginTime;
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  String _currentTimeStr() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }
}

/// 学习时长数据（翻译自 LearnDurationData.java）
class LearnDurationData {
  final _LDStruct? today;
  final _LDStruct? total;

  LearnDurationData({this.today, this.total});

  int get todayLearnDuration => today?.duration ?? 0;
  int get totalLearnDuration => total?.duration ?? 0;

  factory LearnDurationData.fromJson(Map<String, dynamic> json) => LearnDurationData(
    today: json['today'] != null ? _LDStruct.fromJson(json['today'] as Map<String, dynamic>) : null,
    total: json['total'] != null ? _LDStruct.fromJson(json['total'] as Map<String, dynamic>) : null,
  );
}

class _LDStruct {
  final int duration;
  final int amount;

  _LDStruct({this.duration = 0, this.amount = 0});

  factory _LDStruct.fromJson(Map<String, dynamic> json) =>
      _LDStruct(duration: (json['duration'] as num?)?.toInt() ?? 0, amount: (json['amount'] as num?)?.toInt() ?? 0);
}

/// 学习签到数据（翻译自 StudySignData.java）
class StudySignData {
  final int signIn;
  final int study;
  final int timestamp;

  StudySignData({this.signIn = 0, this.study = 0, this.timestamp = 0});

  bool get isStudy => study == 1;
  bool get isSignIn => signIn == 1;

  factory StudySignData.fromJson(Map<String, dynamic> json) => StudySignData(
    signIn: (json['sign_in'] as num?)?.toInt() ?? 0,
    study: (json['study'] as num?)?.toInt() ?? 0,
    timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
  );
}

/// 签到日期信息（翻译自 SignDayInfo.java）
class SignDayInfo {
  static const int _millisOfDay = 86400000;

  int weekDay;
  bool learned;
  bool signed;
  bool isToday;
  int monthDay;
  int timeStamp;

  SignDayInfo({
    this.weekDay = 0,
    this.learned = false,
    this.signed = false,
    this.isToday = false,
    this.monthDay = 0,
    this.timeStamp = 0,
  });

  String get monthDayName => isToday ? '今' : '$monthDay';

  String get weekDayName {
    const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    if (weekDay >= 0 && weekDay < names.length) return names[weekDay];
    return '';
  }

  /// 用 StudySignData 更新状态
  bool updateData(StudySignData? data) {
    if (data == null || data.timestamp < timeStamp || data.timestamp >= timeStamp + _millisOfDay) {
      return false;
    }
    if (data.isSignIn) signed = true;
    if (data.isStudy) learned = true;
    return true;
  }

  /// 创建本周日期信息列表
  static List<SignDayInfo> createWeekDayInfo() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday = 1 in Dart, we want Monday = 0
    int weekDayOffset = today.weekday - 1; // 0=Mon, 6=Sun
    final monday = today.subtract(Duration(days: weekDayOffset));

    final result = <SignDayInfo>[];
    for (int i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      result.add(
        SignDayInfo(weekDay: i, monthDay: d.day, timeStamp: d.millisecondsSinceEpoch, isToday: weekDayOffset == i),
      );
    }
    return result;
  }
}

/// 例句播放日志（翻译自 SentencePlayLog.java）
class SentencePlayLog {
  String sentenceId;
  String episodeId;
  int wordId;
  int bookId;
  int wordStatus;
  int playtime;

  SentencePlayLog({
    this.sentenceId = '',
    this.episodeId = '',
    this.wordId = 0,
    this.bookId = 0,
    this.wordStatus = 0,
    this.playtime = 0,
  });

  factory SentencePlayLog.fromJson(Map<String, dynamic> json) => SentencePlayLog(
    sentenceId: json['sentenceId'] ?? '',
    episodeId: json['episodeId'] ?? '',
    wordId: (json['wordId'] as num?)?.toInt() ?? 0,
    bookId: (json['bookId'] as num?)?.toInt() ?? 0,
    wordStatus: (json['wordStatus'] as num?)?.toInt() ?? 0,
    playtime: (json['playtime'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'sentenceId': sentenceId,
    'episodeId': episodeId,
    'wordId': wordId,
    'bookId': bookId,
    'wordStatus': wordStatus,
    'playtime': playtime,
  };
}

/// 列表最后位置信息（翻译自 ListLastPosInfo.java）
class ListLastPosInfo {
  String word;
  int listPos;
  String dataTime;
  List<String> alreadyListenView;

  ListLastPosInfo({this.word = '', this.listPos = 0, this.dataTime = '', List<String>? alreadyListenView})
    : alreadyListenView = alreadyListenView ?? [];

  factory ListLastPosInfo.fromJson(Map<String, dynamic> json) => ListLastPosInfo(
    word: json['word'] ?? '',
    listPos: (json['listPos'] as num?)?.toInt() ?? 0,
    dataTime: json['dataTime'] ?? '',
    alreadyListenView: (json['alreadyListenView'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'listPos': listPos,
    'dataTime': dataTime,
    'alreadyListenView': alreadyListenView,
  };
}

/// 可序列化 Map（翻译自 SerializableMap.java）
class SerializableMap {
  Map<int, String> map;

  SerializableMap([Map<int, String>? map]) : map = map ?? {};

  factory SerializableMap.fromJson(Map<String, dynamic> json) {
    final m = <int, String>{};
    if (json['map'] != null) {
      (json['map'] as Map<String, dynamic>).forEach((k, v) {
        final key = int.tryParse(k);
        if (key != null) m[key] = v.toString();
      });
    }
    return SerializableMap(m);
  }

  Map<String, dynamic> toJson() => {'map': map.map((k, v) => MapEntry('$k', v))};
}

/// 例句集合数据（翻译自 SentenceSetData.java，基类占位）
class SentenceSetData {
  void addMoreData(SentenceSetData other) {}
}

/// 基础项信息接口（翻译自 BaseItemInfo.java）
abstract class BaseItemInfo {
  String get title;
  String get subtitle;
  int get drawableResourceId;
}

/// 基础项类型信息接口（翻译自 BaseItemTypeInfo.java）
abstract class BaseItemTypeInfo extends BaseItemInfo {
  int get type;
}
