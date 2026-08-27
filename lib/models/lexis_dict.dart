// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：LexisDict + Interpret（词典词条/释义）

/// 词典词条（翻译自 LexisDict.java）
class LexisDict {
  String word;
  String definition;
  String usPron;
  String ukPron;
  String selection;
  String detailWord;
  List<Interpret> interpretList;

  LexisDict({
    this.word = '',
    this.definition = '',
    this.usPron = '',
    this.ukPron = '',
    this.selection = '',
    this.detailWord = '',
    List<Interpret>? interpretList,
  }) : interpretList = interpretList ?? [];

  /// 从 JSON 解析（zpk 词条字段）
  factory LexisDict.fromZpkJson(Map<String, dynamic> json) {
    final dict = LexisDict(
      word: json['word'] ?? '',
      usPron: json['us_pron'] ?? '',
      ukPron: json['uk_pron'] ?? '',
      interpretList: [],
    );
    // 解析 interpret_v2 或 interpret 字符串
    final interpretV2 = json['interpret_v2'];
    if (interpretV2 is List) {
      dict.interpretList = interpretV2.map((e) => Interpret.fromJson(e as Map<String, dynamic>)).toList();
    } else if (json['interpret'] != null) {
      dict.interpret = json['interpret'];
    }
    return dict;
  }

  /// 释义列表（Interpret 结构）
  set interpret(String raw) {
    definition = raw;
  }

  String get interpret => definition;

  /// 生成完整释义文本（原版 setInterpret 逻辑：p + "  " + i，换行分隔）
  String get interpretComplete {
    final sb = StringBuffer();
    for (var i = 0; i < interpretList.length; i++) {
      final it = interpretList[i];
      if (it.p.isNotEmpty) {
        sb.write('${it.p}  ');
      }
      sb.write(it.i);
      if (i < interpretList.length - 1) {
        sb.write('\n');
      }
    }
    return sb.toString();
  }

  /// 第一个释义
  Interpret? get firstInterpret => interpretList.isEmpty ? null : interpretList.first;
}

/// 释义项（翻译自 LexisDict.Interpret）
class Interpret {
  String p; // 词性 (n./vt./adj.)
  String i; // 释义
  String ei; // 英文释义
  bool bCi; // 是否词组

  Interpret({this.p = '', this.i = '', this.ei = '', this.bCi = false});

  factory Interpret.fromJson(Map<String, dynamic> json) =>
      Interpret(p: json['p'] ?? '', i: json['i'] ?? '', ei: json['ei'] ?? '', bCi: json['bCi'] ?? false);

  /// 完整释义字符串（原版 getInterpretCompleteString）
  String get interpretComplete => p.isNotEmpty ? '$p  $i' : i;
}
