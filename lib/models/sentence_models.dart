// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/sentence/（v3.2 源码 1:1）
// 文件：SentenceData + AcceptationSentence + NormalAcceptationSentence + OldAcceptationSentence + Acceptation + SentenceUsage + FavSentenceData + FavSentenceSyncData

import 'lexis_dict.dart';

/// 例句数据（翻译自 SentenceData.java）
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

  Map<String, dynamic> toJson() => {
        'sid': sid,
        'eid': eid,
        'fid': fid,
        'u': u,
        'i': i,
        'b': b,
        'e': e,
        'c': c,
      };
}

/// 词义句子基类（翻译自 AcceptationSentence.java，抽象类）
abstract class AcceptationSentence {
  static const int typeNormalMeaning = 1;
  static const int typeExtendMeaning = 2;
  static const int typeNormalIdm = 3;
  static const int typeExtendIdm = 4;
  static const int typePhrase = 5;
  static const int typeOld = 99;

  int type = 0;
  int _pageCount = 0;
  int _pagePos = 0;

  List<SentenceData> getAllSentence();
  Object? getInterpret();

  String get acceptationLabel {
    if (type == 99) return '简明词义';
    switch (type) {
      case 1:
        return '核心词义';
      case 2:
        return '扩展词义';
      case 3:
        return '核心短语';
      case 4:
        return '扩展短语';
      case 5:
        return '词组词义';
      default:
        return '';
    }
  }

  void setPagePosInfo(int pos, int count) {
    _pagePos = pos;
    _pageCount = count;
  }

  int get pagePos => _pagePos;
  int get pageCount => _pageCount;

  /// 从 JSON 解析（工厂方法，根据 type 分派）
  static AcceptationSentence? fromJson(Map<String, dynamic> json) {
    if (json['type'] == null) return null;
    final t = (json['type'] as num).toInt();
    if (t == 99) {
      return OldAcceptationSentence.fromJson(json);
    } else {
      return NormalAcceptationSentence.fromJson(json);
    }
  }

  /// 提取所有例句
  static List<SentenceData> extractAllSentences(List<AcceptationSentence>? list) {
    if (list == null) return [];
    final result = <SentenceData>[];
    for (final item in list) {
      result.addAll(item.getAllSentence());
    }
    return result;
  }
}

/// 普通词义句子（翻译自 NormalAcceptationSentence.java）
class NormalAcceptationSentence extends AcceptationSentence {
  Acceptation? i; // 词义信息
  List<SentenceUsage> g; // 用法+例句列表

  NormalAcceptationSentence({
    this.i,
    List<SentenceUsage>? g,
  }) : g = g ?? [] {
    type = 0; // 从 JSON 中读取
  }

  @override
  Object? getInterpret() => i;

  @override
  List<SentenceData> getAllSentence() {
    final result = <SentenceData>[];
    for (final usage in g) {
      final sList = usage.sentenceList;
      if (sList != null) result.addAll(sList);
    }
    return result;
  }

  /// 获取所有用法
  List<String> getAllUsage() {
    final result = <String>[];
    for (final usage in g) {
      final u = usage.usage;
      if (u.isNotEmpty) result.add(u);
    }
    return result;
  }

  /// 根据位置获取用法
  String getUsageByPos(int pos) {
    if (pos < 0) return '';
    int sentenceCount = 0;
    for (final usage in g) {
      if (pos >= usage.sentenceCount + sentenceCount) {
        sentenceCount += usage.sentenceCount;
      } else {
        return usage.usage;
      }
    }
    return '';
  }

  /// 根据用法获取位置
  int getPosByUsage(String str) {
    if (str.isEmpty) return -1;
    int sentenceCount = 0;
    for (final usage in g) {
      if (usage.usage == str) {
        return usage.sentenceCount > 0 ? sentenceCount : -1;
      }
      sentenceCount += usage.sentenceCount;
    }
    return -1;
  }

  String get phraseType => i?.phraseType ?? '';
  String get phraseInterpret => i?.phraseInterpret ?? '';

  factory NormalAcceptationSentence.fromJson(Map<String, dynamic> json) {
    final obj = NormalAcceptationSentence(
      i: json['i'] != null
          ? Acceptation.fromJson(json['i'] as Map<String, dynamic>)
          : null,
      g: (json['g'] as List?)
              ?.map((e) => SentenceUsage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
    obj.type = (json['type'] as num?)?.toInt() ?? 0;
    return obj;
  }
}

/// 旧版词义句子（翻译自 OldAcceptationSentence.java）
class OldAcceptationSentence extends AcceptationSentence {
  List<Interpret>? interprets; // 释义列表
  List<SentenceData> g; // 例句列表

  OldAcceptationSentence({
    this.interprets,
    List<SentenceData>? g,
  }) : g = g ?? [] {
    type = 99;
  }

  static OldAcceptationSentence create(List<Interpret>? interprets, List<SentenceData> sentences) {
    final obj = OldAcceptationSentence(interprets: interprets, g: sentences);
    obj.type = 99;
    obj.setPagePosInfo(1, 1);
    return obj;
  }

  @override
  Object? getInterpret() => interprets;

  @override
  List<SentenceData> getAllSentence() => g;

  factory OldAcceptationSentence.fromJson(Map<String, dynamic> json) {
    final obj = OldAcceptationSentence(
      interprets: (json['interprets'] as List?)
              ?.map((e) => Interpret.fromJson(e as Map<String, dynamic>))
              .toList(),
      g: (json['g'] as List?)
              ?.map((e) => SentenceData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
    obj.type = 99;
    return obj;
  }
}

/// 词义信息（翻译自 Acceptation.java）
class Acceptation {
  String p; // word property (词性)
  String e; // english interpret
  String c; // chinese interpret
  String t; // phrase type
  String u; // phrase interpret

  Acceptation({
    this.p = '',
    this.e = '',
    this.c = '',
    this.t = '',
    this.u = '',
  });

  String get wordProperty => p;
  String get enInterpret => e;
  String get chInterpret => c;
  String get phraseType => t;
  String get phraseInterpret => u;

  factory Acceptation.fromJson(Map<String, dynamic> json) => Acceptation(
        p: json['p'] ?? '',
        e: json['e'] ?? '',
        c: json['c'] ?? '',
        t: json['t'] ?? '',
        u: json['u'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'p': p,
        'e': e,
        'c': c,
        't': t,
        'u': u,
      };
}

/// 例句用法（翻译自 SentenceUsage.java）
class SentenceUsage {
  String u; // usage text
  List<SentenceData> s; // sentence list

  SentenceUsage({
    this.u = '',
    List<SentenceData>? s,
  }) : s = s ?? [];

  String get usage => u;
  List<SentenceData> get sentenceList => s;
  int get sentenceCount => s.length;

  factory SentenceUsage.fromJson(Map<String, dynamic> json) => SentenceUsage(
        u: json['u'] ?? '',
        s: (json['s'] as List?)
                ?.map((e) => SentenceData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'u': u,
        's': s.map((e) => e.toJson()).toList(),
      };
}

/// 收藏例句数据（翻译自 FavSentenceData.java）
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

  bool isSame(int id, String sid) =>
      sid.isNotEmpty && wordId == id && sid == sentenceId;

  /// 设置 sentenceData 从 JSON 字符串
  void setSentenceDataFromJson(Map<String, dynamic> json) {
    sentenceData = SentenceData.fromJson(json);
  }

  factory FavSentenceData.fromJson(Map<String, dynamic> json) =>
      FavSentenceData(
        word: json['word'] ?? '',
        wordId: (json['wordId'] as num?)?.toInt() ?? 0,
        sentenceId: json['sentenceId'] ?? '',
        sentenceData: json['sentenceData'] != null
            ? SentenceData.fromJson(
                json['sentenceData'] as Map<String, dynamic>)
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

/// 收藏例句同步数据（翻译自 FavSentenceSyncData.java）
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

  factory FavSentenceSyncData.fromJson(Map<String, dynamic> json) =>
      FavSentenceSyncData(
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
