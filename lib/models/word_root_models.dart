// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：RootSuffixData + RootSuffixGroupData + RootSuffixItemData

/// 词根词缀数据（翻译自 RootSuffixData.java）
class RootSuffixData {
  String word;
  String wordgradle;
  String hightlight;
  String example;
  String ukPron;
  String usPron;
  bool isFold;
  bool isNewWord;
  List<RootSuffixItemData> rootsuffixList;

  RootSuffixData({
    this.word = '',
    this.wordgradle = '',
    this.hightlight = '',
    this.example = '',
    this.ukPron = '',
    this.usPron = '',
    this.isFold = true,
    this.isNewWord = false,
    List<RootSuffixItemData>? rootsuffixList,
  }) : rootsuffixList = rootsuffixList ?? [];

  factory RootSuffixData.fromJson(Map<String, dynamic> json) =>
      RootSuffixData(
        word: json['word'] ?? '',
        wordgradle: json['wordgradle'] ?? '',
        hightlight: json['hightlight'] ?? '',
        example: json['example'] ?? '',
        ukPron: json['uk_pron'] ?? '',
        usPron: json['us_pron'] ?? '',
        rootsuffixList: (json['rootsuffixList'] as List?)
                ?.map((e) =>
                    RootSuffixItemData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'wordgradle': wordgradle,
        'hightlight': hightlight,
        'example': example,
        'uk_pron': ukPron,
        'us_pron': usPron,
        'rootsuffixList': rootsuffixList.map((e) => e.toJson()).toList(),
      };
}

/// 词根词缀分组数据（翻译自 RootSuffixGroupData.java）
class RootSuffixGroupData {
  List<RootSuffixData> listData;

  RootSuffixGroupData([List<RootSuffixData>? list]) : listData = list ?? [];

  int get count => listData.length;

  RootSuffixData? getData(int i) {
    if (i >= 0 && i < listData.length) return listData[i];
    return null;
  }

  void setAllFold() {
    for (final item in listData) {
      item.isFold = true;
    }
  }

  void setAllUnFold() {
    for (final item in listData) {
      item.isFold = false;
    }
  }

  bool get isAllFold => listData.every((e) => e.isFold);
  bool get isAllUnFold => listData.every((e) => !e.isFold);
}

/// 词根词缀项数据（翻译自 RootSuffixItemData.java）
class RootSuffixItemData {
  static const int typePrefix = 1;
  static const int typeRoot = 2;
  static const int typeSuffix = 3;
  static const int typeMemory = 4;

  int id;
  int type;
  String content;

  RootSuffixItemData({
    this.id = 0,
    this.type = 0,
    this.content = '',
  });

  String get lableName {
    switch (type) {
      case 1:
        return '前缀';
      case 2:
        return '词根';
      case 3:
        return '后缀';
      case 4:
        return '记忆';
      default:
        return '';
    }
  }

  factory RootSuffixItemData.fromJson(Map<String, dynamic> json) =>
      RootSuffixItemData(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: (json['type'] as num?)?.toInt() ?? 0,
        content: json['content'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'content': content,
      };
}
