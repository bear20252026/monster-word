// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：BBWordBaseInfo + LearnCardData + LearnResultData + CandidateWord

import 'lexis_dict.dart';

/// 单词基础信息（翻译自 BBWordBaseInfo.java）
class BBWordBaseInfo {
  String word;
  String interpret;
  String usPron;
  String ukPron;
  String example;
  List<String> spell;
  List<String> confuse;
  List<String> confuseExps;
  List<Interpret> interpretList;

  BBWordBaseInfo({
    this.word = '',
    this.interpret = '',
    this.usPron = '',
    this.ukPron = '',
    this.example = '',
    List<String>? spell,
    List<String>? confuse,
    List<String>? confuseExps,
    List<Interpret>? interpretList,
  })  : spell = spell ?? [],
        confuse = confuse ?? [],
        confuseExps = confuseExps ?? [],
        interpretList = interpretList ?? [];

  /// 从 JSON 解析（zpk 词条）
  factory BBWordBaseInfo.fromJson(Map<String, dynamic> json) {
    final info = BBWordBaseInfo(
      word: json['word'] ?? '',
      interpret: json['interpret'] ?? '',
      usPron: json['us_pron'] ?? '',
      ukPron: json['uk_pron'] ?? '',
      example: json['example']?.toString() ?? '',
      spell: (json['spell'] as List?)?.map((e) => e.toString()).toList() ?? [],
      confuse:
          (json['confuse'] as List?)?.map((e) => e.toString()).toList() ?? [],
      confuseExps:
          (json['confuse_exps'] as List?)?.map((e) => e.toString()).toList() ??
              [],
    );
    final v2 = json['interpret_v2'];
    if (v2 is List) {
      info.interpretList = v2
          .map((e) => Interpret.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return info;
  }
}

/// 学习卡片数据（翻译自 LearnCardData.java）
/// dataList 结构：可选 RootSuffixData(0) + AcceptationSentence 列表
class LearnCardData {
  final String word;
  final int wordId;
  final List<Object> dataList = [];

  LearnCardData(this.word, this.wordId);

  void setData(Object? rootSuffixData, List<Object> sentences) {
    dataList.clear();
    if (rootSuffixData != null) {
      dataList.add(rootSuffixData);
    }
    if (sentences.isNotEmpty) {
      dataList.addAll(sentences);
    }
  }

  Object? getObject(int i) =>
      (i >= 0 && i < dataList.length) ? dataList[i] : null;

  int get count => dataList.length;

  void clear() => dataList.clear();

  /// 第一个元素是否为词根词缀数据
  bool hasRootSuffixData() =>
      dataList.isNotEmpty && dataList.first is Map<String, dynamic>;

  void removeWordRootData() {
    if (hasRootSuffixData()) dataList.removeAt(0);
  }

  /// 词根词缀起始位置
  int get rootSuffixStartPos =>
      dataList.indexWhere((e) => e is Map<String, dynamic>).clamp(0, dataList.length);

  /// 例句起始位置
  int get acceptionStartPos => 0;
}

/// 学习结果数据（翻译自 LearnResultData.java）
class LearnResultData {
  int studyCount = 0; // 学习单词数
  int reviewCount = 0; // 复习单词数
  int newCount = 0; // 新学单词数
  int successCount = 0; // 答对次数
  int failCount = 0; // 答错次数
  int duration = 0; // 学习时长(秒)
  List<String> wrongWords = []; // 错误单词

  int get total => studyCount + reviewCount;
  double get successRate =>
      (studyCount + reviewCount) == 0 ? 0 : successCount / (studyCount + reviewCount);
}

/// 候选词（翻译自 CandidateWord.java，4 选 1 用）
class CandidateWord {
  final String word;
  final String interpret;
  final bool isAnswer;

  CandidateWord({
    required this.word,
    required this.interpret,
    this.isAnswer = false,
  });
}
