// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：StudyRemindText + StudyRemindTextConfig

/// 学习提醒文本（翻译自 StudyRemindText.java）
class StudyRemindText {
  int notifyType;
  int type;
  String content;
  int startTime;
  int endTime;

  StudyRemindText({
    this.notifyType = 0,
    this.type = 0,
    this.content = '',
    this.startTime = 0,
    this.endTime = 0,
  });

  factory StudyRemindText.fromJson(Map<String, dynamic> json) =>
      StudyRemindText(
        notifyType: (json['notifyType'] as num?)?.toInt() ?? 0,
        type: (json['type'] as num?)?.toInt() ?? 0,
        content: json['content'] ?? '',
        startTime: (json['startTime'] as num?)?.toInt() ?? 0,
        endTime: (json['endTime'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'notifyType': notifyType,
        'type': type,
        'content': content,
        'startTime': startTime,
        'endTime': endTime,
      };
}

/// 学习提醒文本配置（翻译自 StudyRemindTextConfig.java）
class StudyRemindTextConfig {
  static const int typeHasReviewTask = 0;
  static const int typeNoReviewTaskNoOpened = 1;
  static const int typeNoReviewTaskOpened = 2;

  List<StudyRemindText> datas;
  List<StudyRemindText> _hasReviewList = [];
  List<StudyRemindText> _noReviewNoOpenedList = [];
  List<StudyRemindText> _noReviewOpendList = [];
  List<StudyRemindText> _dateList = [];
  bool _initialized = false;

  StudyRemindTextConfig({List<StudyRemindText>? datas})
      : datas = datas ?? [];

  /// 初始化分类数据
  void _initData() {
    if (_initialized) return;
    _initialized = true;
    _hasReviewList = [];
    _noReviewNoOpenedList = [];
    _noReviewOpendList = [];
    _dateList = [];

    for (final item in datas) {
      if (item.notifyType == 0) {
        if (item.type == 1) {
          _dateList.add(item);
        } else {
          _hasReviewList.add(item);
        }
      } else if (item.notifyType == 1) {
        if (item.type == 1) {
          _dateList.add(item);
        } else {
          _noReviewNoOpenedList.add(item);
        }
      } else if (item.notifyType == 2) {
        if (item.type == 1) {
          _dateList.add(item);
        } else {
          _noReviewOpendList.add(item);
        }
      }
    }
  }

  /// 获取提醒文本
  String getRemindText(int type, int timestampMs, int reviewCount) {
    _initData();
    switch (type) {
      case 0:
        final text = _getRemindTextFromList(_hasReviewList, timestampMs, 0);
        return text.isNotEmpty
            ? text.replaceAll('\${num}', '$reviewCount')
            : '$reviewCount个单词在等你复习，它们说你若不来，以后再见就是陌生人了！';
      case 1:
        final text =
            _getRemindTextFromList(_noReviewNoOpenedList, timestampMs, 1);
        return text.isNotEmpty
            ? text
            : '别着急，单词就是每天一个一个一个一个一个一个一个背完的，今日打卡>>';
      case 2:
        final text =
            _getRemindTextFromList(_noReviewOpendList, timestampMs, 1);
        return text.isNotEmpty ? text : '没时间了我长话短说：你该背单词了>>';
      default:
        return '';
    }
  }

  String _getRemindTextFromList(
      List<StudyRemindText> list, int timestampMs, int notifyType) {
    final ts = timestampMs ~/ 1000;

    // 先检查日期列表
    for (final item in _dateList) {
      if (item.notifyType == notifyType &&
          ts > item.startTime &&
          ts < item.endTime) {
        return item.content;
      }
    }

    if (list.isEmpty) return '';
    return list[DateTime.now().millisecondsSinceEpoch % list.length].content;
  }

  factory StudyRemindTextConfig.fromJson(Map<String, dynamic> json) =>
      StudyRemindTextConfig(
        datas: (json['datas'] as List?)
                ?.map((e) =>
                    StudyRemindText.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
