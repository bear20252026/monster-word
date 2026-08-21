// 由账号4生成
// 数据模型层：翻译自 bean/BBWordProcess.java（v3.2 源码 1:1）
// 单词学习进度（SRS 核心数据模型，对应 SQLite 用户表字段）

import 'lexis_dict.dart';

/// 单词学习进度（翻译自 BBWordProcess.java）
class BBWordProcess {
  int id;
  String word;
  int wordId; // word_id
  int freq; // 词频
  int state; // 学习状态（0=未学/1=学习中/2=已掌握）
  int level; // 记忆等级
  int position; // 在词书中的位置
  String reviewDate; // 复习日期
  int process; // 学习进度
  int success; // 成功次数
  int fail; // 失败次数
  int duration; // 学习时长
  double eFactor; // 易度因子（SM-2）
  int r1;
  int r2;
  int reFail; // 复习失败次数
  int reSuccess; // 复习成功次数
  int comeFrom;
  int learnFrom;
  int cFail;
  int userRating; // 用户评分
  int testMode; // 测试模式
  String interpret; // 释义
  String usPron; // 美音
  String ukPron; // 英音
  String example; // 例句
  String updateTime; // 更新时间
  String syncTime; // 同步时间
  String zpk; // zpk 文件名
  String oldZpk; // 旧 zpk

  // 派生数据（原版有 setWordBaseInfo/setLexisDict）
  List<Interpret> confusedList = [];
  List<String> confusedWordList = [];
  List<String> confusedWordExpList = [];
  List<String> spells = [];

  BBWordProcess({
    this.id = 0,
    this.word = '',
    this.wordId = 0,
    this.freq = 0,
    this.state = 0,
    this.level = 0,
    this.position = 0,
    this.reviewDate = '',
    this.process = 0,
    this.success = 0,
    this.fail = 0,
    this.duration = 0,
    this.eFactor = 2.5,
    this.r1 = 0,
    this.r2 = 0,
    this.reFail = 0,
    this.reSuccess = 0,
    this.comeFrom = 0,
    this.learnFrom = 0,
    this.cFail = 0,
    this.userRating = 0,
    this.testMode = 0,
    this.interpret = '',
    this.usPron = '',
    this.ukPron = '',
    this.example = '',
    this.updateTime = '',
    this.syncTime = '',
    this.zpk = '',
    this.oldZpk = '',
    List<String>? confusedWordList,
    List<String>? confusedWordExpList,
    List<String>? spells,
  })  : confusedWordList = confusedWordList ?? [],
        confusedWordExpList = confusedWordExpList ?? [],
        spells = spells ?? [];

  /// 从词库 JSON（zpk 词条）初始化
  factory BBWordProcess.fromWordJson(
    String word,
    Map<String, dynamic> json, {
    String? zpk,
  }) {
    return BBWordProcess(
      word: word,
      wordId: (json['word_id'] as num?)?.toInt() ?? 0,
      interpret: json['interpret'] ?? '',
      usPron: json['us_pron'] ?? '',
      ukPron: json['uk_pron'] ?? '',
      example: json['example'] != null
          ? json['example'].toString()
          : '',
      zpk: zpk ?? '',
      confusedWordList: (json['confuse'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      confusedWordExpList: (json['confuse_exps'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      spells: (json['spell'] as List?)?.map((e) => e.toString()).toList() ??
          [],
    );
  }

  /// 是否有释义数据
  bool isBaseInfoOK() => interpret.isNotEmpty || usPron.isNotEmpty;

  /// 形近词列表
  List<String> get confusedWordListSafe => confusedWordList;

  factory BBWordProcess.fromMap(Map<String, dynamic> map) => BBWordProcess(
        id: (map['id'] as num?)?.toInt() ?? 0,
        word: map['word'] ?? '',
        wordId: (map['word_id'] as num?)?.toInt() ?? 0,
        freq: (map['freq'] as num?)?.toInt() ?? 0,
        state: (map['state'] as num?)?.toInt() ?? 0,
        level: (map['level'] as num?)?.toInt() ?? 0,
        position: (map['position'] as num?)?.toInt() ?? 0,
        reviewDate: map['reviewdate'] ?? '',
        process: (map['process'] as num?)?.toInt() ?? 0,
        success: (map['success'] as num?)?.toInt() ?? 0,
        fail: (map['fail'] as num?)?.toInt() ?? 0,
        duration: (map['duration'] as num?)?.toInt() ?? 0,
        eFactor: (map['efactor'] as num?)?.toDouble() ?? 2.5,
        reFail: (map['reFail'] as num?)?.toInt() ?? 0,
        reSuccess: (map['reSuccess'] as num?)?.toInt() ?? 0,
        comeFrom: (map['comeFrom'] as num?)?.toInt() ?? 0,
        interpret: map['interpret'] ?? '',
        usPron: map['us_pron'] ?? '',
        ukPron: map['uk_pron'] ?? '',
        example: map['example'] ?? '',
        updateTime: map['updatetime'] ?? '',
        syncTime: map['synTime'] ?? '',
        zpk: map['zpk'] ?? '',
        oldZpk: map['old_zpk'] ?? '',
      );
}
