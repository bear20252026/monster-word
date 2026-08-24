// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：BBListWord + BBUserNewWord + SpellBean + CollinsDetail + SentenceWordInfo

import 'lexis_dict.dart';
import 'learning_models.dart';

/// 列表单词项（翻译自 BBListWord.java）
class BBListWord {
  String word;
  int wordId;
  int duration;
  String updateTime;
  String zpkName;
  Interpret? firstInterpret;
  BBWordBaseInfo? wordBaseInfo;
  bool isSelected;

  BBListWord({
    this.word = '',
    this.wordId = 0,
    this.duration = 0,
    this.updateTime = '',
    this.zpkName = '',
    this.firstInterpret,
    this.wordBaseInfo,
    this.isSelected = false,
  });

  /// 系统标记完成（学习时长 > 90 秒）
  bool get isSystemMarkFinished => duration > 90;

  factory BBListWord.fromJson(Map<String, dynamic> json) => BBListWord(
        word: json['word'] ?? '',
        wordId: (json['wordId'] as num?)?.toInt() ?? 0,
        duration: (json['duration'] as num?)?.toInt() ?? 0,
        updateTime: json['updateTime'] ?? '',
        zpkName: json['zpkName'] ?? '',
      );
}

/// 用户生词（翻译自 BBUserNewWord.java）
class BBUserNewWord {
  int wordId;
  String zpk;
  String newword;
  String updatetime;
  String opcode;
  String synTime;
  String lookUp;

  BBUserNewWord({
    this.wordId = 0,
    this.zpk = '',
    this.newword = '',
    this.updatetime = '20990101010101',
    this.opcode = '1',
    this.synTime = '19990101010101',
    this.lookUp = '*',
  });

  factory BBUserNewWord.fromJson(Map<String, dynamic> json) => BBUserNewWord(
        newword: json['word'] ?? '',
        opcode: json['oc'] ?? '1',
        updatetime: json['ut'] ?? '20990101010101',
        wordId: (json['wi'] as num?)?.toInt() ?? 0,
        zpk: json['zu'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'word': newword,
        'oc': opcode,
        'ut': updatetime,
        'wi': wordId,
        'zu': zpk,
      };
}

/// 拼写数据（翻译自 SpellBean.java）
class SpellBean {
  String word;
  String interpret;
  String usPron;
  String ukPron;
  List<String> spells;

  SpellBean({
    this.word = '',
    this.interpret = '',
    this.usPron = '',
    this.ukPron = '',
    List<String>? spells,
  }) : spells = spells ?? [];

  factory SpellBean.fromJson(Map<String, dynamic> json) => SpellBean(
        word: json['word'] ?? '',
        interpret: json['interpret'] ?? '',
        usPron: json['us_pron'] ?? '',
        ukPron: json['uk_pron'] ?? '',
        spells: (json['spells'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpellBean &&
          word == other.word &&
          interpret == other.interpret &&
          usPron == other.usPron &&
          ukPron == other.ukPron;

  @override
  int get hashCode => Object.hash(word, interpret, usPron, ukPron);
}

/// 柯林斯词义详情（翻译自 CollinsDetail.java）
class CollinsDetail {
  String word;
  String interpret;
  int dType;

  CollinsDetail({
    this.word = '',
    this.interpret = '',
    this.dType = 0,
  });

  factory CollinsDetail.fromJson(Map<String, dynamic> json) => CollinsDetail(
        word: json['word'] ?? '',
        interpret: json['interpret'] ?? '',
        dType: (json['d_type'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'interpret': interpret,
        'd_type': dType,
      };
}

/// 柯林斯词典释义详情（富格式）
class CollinsWordDetail {
  final String word;
  final int rating; // 1-5 星级
  final List<String> tags; // CET4, TEM4, CET6 等
  final String wordType; // 词性 n./v./adj.
  final String definition; // 英文释义
  final List<String> seeAlso; // 相关词
  final List<CollinsExample> examples; // 例句

  const CollinsWordDetail({
    required this.word,
    this.rating = 3,
    this.tags = const [],
    this.wordType = '',
    this.definition = '',
    this.seeAlso = const [],
    this.examples = const [],
  });
}

/// 柯林斯例句
class CollinsExample {
  final String english;
  final String chinese;

  const CollinsExample({required this.english, required this.chinese});
}

/// 句子单词信息（翻译自 SentenceWordInfo.java）
class SentenceWordInfo {
  String word;
  String enSentence;
  String sentenceID;
  String audioUrl;
  String courseId;
  String spanId;

  SentenceWordInfo({
    this.word = '',
    this.enSentence = '',
    this.sentenceID = '*',
    this.audioUrl = '',
    this.courseId = '*',
    this.spanId = '*',
  });

  /// 获取课程ID
  String get courseID {
    if (courseId.isNotEmpty && courseId != '*') return courseId;
    final baseName =
        sentenceID.isNotEmpty && sentenceID != '*' ? sentenceID : audioUrl;
    if (baseName.isEmpty || baseName.length < 5) return '';
    return baseName.substring(0, baseName.length - 5);
  }

  /// 获取行号
  int get rowNum {
    final baseName =
        sentenceID.isNotEmpty && sentenceID != '*' ? sentenceID : audioUrl;
    if (baseName.isEmpty || baseName.length < 5) return 0;
    return int.tryParse(baseName.substring(baseName.length - 5)) ?? 0;
  }

  /// 获取简短句子ID
  String get simpleSentenceID {
    final n = rowNum;
    return n > 0 ? '$n' : '';
  }

  factory SentenceWordInfo.fromJson(Map<String, dynamic> json) =>
      SentenceWordInfo(
        word: json['word'] ?? '',
        enSentence: json['enSentence'] ?? '',
        sentenceID: json['sentenceID'] ?? '*',
        audioUrl: json['audioUrl'] ?? '',
        courseId: json['courseId'] ?? '*',
        spanId: json['spanId'] ?? '*',
      );
}

