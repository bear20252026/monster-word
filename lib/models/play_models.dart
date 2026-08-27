// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：ExtensivePlayParameter + ExtensivePlayMode

/// 泛听播放参数（翻译自 ExtensivePlayParameter.java）
class ExtensivePlayParameter {
  static const int playTypeNone = 0;
  static const int playTypeWord = 1;
  static const int playTypeInterpret = 2;
  static const int playTypeSentenceEn = 3;
  static const int playTypeSentenceCh = 4;
  static const int playTypeSentenceEnSlow = 5;
  static const int playTypeWordSpell = 6;

  List<int> playTypes;
  int playTypeInterval;
  int nextTimesInterval;

  ExtensivePlayParameter({List<int>? playTypes, this.playTypeInterval = 1, this.nextTimesInterval = 2})
    : playTypes = playTypes ?? [playTypeWord];

  /// 慢速播放速度
  double get slowPlaySpeed => 0.7;

  /// 获取指定索引的播放类型
  int getPlayType(int index) {
    if (playTypes.isEmpty || index < 0 || index >= playTypes.length) {
      return playTypeNone;
    }
    return playTypes[index];
  }

  int get typeCount => playTypes.length;

  factory ExtensivePlayParameter.fromJson(Map<String, dynamic> json) => ExtensivePlayParameter(
    playTypes: (json['playTypes'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [playTypeWord],
    playTypeInterval: (json['playTypeInterval'] as num?)?.toInt() ?? 1,
    nextTimesInterval: (json['nextTimesInterval'] as num?)?.toInt() ?? 2,
  );

  Map<String, dynamic> toJson() => {
    'playTypes': playTypes,
    'playTypeInterval': playTypeInterval,
    'nextTimesInterval': nextTimesInterval,
  };
}

/// 泛听播放模式（翻译自 ExtensivePlayMode.java）
class ExtensivePlayMode {
  static const int listenModelBase = 1;
  static const int listenModelAdvanced = 2;
  static const int listenModelSpell = 3;
}
