// 由 Claude 团队生成 | Monster Word App

// 数据模型层
// 死代码清理（2026-10 审计）：AcceptationSentence 解析链（Normal/Old 子类、
// Acceptation/SentenceUsage、extractAllSentences）全库零引用已删除；
// 保留导入方在用的 SentenceData 与 FavSentenceData。
// 文件：SentenceData + FavSentenceData

/// 例句数据
class SentenceData {
  String sid; // sentence ID
  String eid; // episode/course ID
  String fid;
  String u; // audio URL
  String i; // image URL
  String b; // title
  String e; // english
  String c; // chinese
  bool bShowCH;
  int favState; // -1=未初始化, 0=未收藏, 1=已收藏

  SentenceData({
    this.sid = '',
    this.eid = '',
    this.fid = '',
    this.u = '',
    this.i = '',
    this.b = '',
    this.e = '',
    this.c = '',
    this.bShowCH = true,
    this.favState = -1,
  });

  bool get isFavStateInit => favState == 0 || favState == 1;
  bool get isFav => favState == 1;
  set isFav(bool v) => favState = v ? 1 : 0;

  /// 行号（从 sentenceID 末5位提取）
  int get rowNum {
    final src = sid.isNotEmpty ? sid : u;
    if (src.isEmpty || src.length < 5) return 0;
    return int.tryParse(src.substring(src.length - 5)) ?? 0;
  }

  factory SentenceData.fromJson(Map<String, dynamic> json) => SentenceData(
    sid: json['sid'] ?? '',
    eid: json['eid'] ?? '',
    fid: json['fid'] ?? '',
    u: json['u'] ?? '',
    i: json['i'] ?? '',
    b: json['b'] ?? '',
    e: json['e'] ?? '',
    c: json['c'] ?? '',
  );

  Map<String, dynamic> toJson() => {'sid': sid, 'eid': eid, 'fid': fid, 'u': u, 'i': i, 'b': b, 'e': e, 'c': c};
}

class FavSentenceData {
  String word;
  int wordId;
  String sentenceId;
  SentenceData? sentenceData;
  String wordUsage;
  String updateTime;
  int type;
  Object? wordMeaning; // Acceptation 或 List<Interpret>
  bool bSelected;
  String? updateDate;

  FavSentenceData({
    this.word = '',
    this.wordId = 0,
    this.sentenceId = '',
    this.sentenceData,
    this.wordUsage = '',
    this.updateTime = '20990101010101',
    this.type = 0,
    this.wordMeaning,
    this.bSelected = false,
    this.updateDate,
  });

  String get audio => sentenceData?.u ?? '';
  bool get isSelected => bSelected;
  set isSelected(bool v) => bSelected = v;

  bool isSame(int id, String sid) => sid.isNotEmpty && wordId == id && sid == sentenceId;

  /// 设置 sentenceData 从 JSON 字符串
  void setSentenceDataFromJson(Map<String, dynamic> json) {
    sentenceData = SentenceData.fromJson(json);
  }

  factory FavSentenceData.fromJson(Map<String, dynamic> json) => FavSentenceData(
    word: json['word'] ?? '',
    wordId: (json['wordId'] as num?)?.toInt() ?? 0,
    sentenceId: json['sentenceId'] ?? '',
    sentenceData: json['sentenceData'] != null
        ? SentenceData.fromJson(json['sentenceData'] as Map<String, dynamic>)
        : null,
    wordUsage: json['wordUsage'] ?? '',
    updateTime: json['updateTime'] ?? '20990101010101',
    type: (json['type'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'wordId': wordId,
    'sentenceId': sentenceId,
    'sentenceData': sentenceData?.toJson(),
    'wordUsage': wordUsage,
    'updateTime': updateTime,
    'type': type,
  };
}

/// 收藏例句同步数据
class FavSentenceSyncData {
  String word;
  int wordId;
  String sentenceId;
  int type;
  String wordMeaning;
  String wordUsage;
  String sentenceData;
  String updateTime;
  String opcode;
  String synTime;

  FavSentenceSyncData({
    this.word = '',
    this.wordId = 0,
    this.sentenceId = '',
    this.type = 0,
    this.wordMeaning = '',
    this.wordUsage = '',
    this.sentenceData = '',
    this.updateTime = '20990101010101',
    this.opcode = '1',
    this.synTime = '19990101010101',
  });

  factory FavSentenceSyncData.fromJson(Map<String, dynamic> json) => FavSentenceSyncData(
    word: json['word'] ?? '',
    wordId: (json['wid'] as num?)?.toInt() ?? 0,
    sentenceId: json['sid'] ?? '',
    type: (json['type'] as num?)?.toInt() ?? 0,
    wordMeaning: json['m'] ?? '',
    wordUsage: json['u'] ?? '',
    sentenceData: json['s'] ?? '',
    opcode: json['op'] ?? '1',
    updateTime: json['ut'] ?? '20990101010101',
  );
}
