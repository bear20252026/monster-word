// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 数据模型层
// 文件：Interpret（释义项）
// 死代码清理（2026-10 审计）：LexisDict 词条壳（fromZpkJson/interpretComplete/
// firstInterpret）全库零引用已删除，仅保留 core_engine 消费的 Interpret。

/// 释义项
class Interpret {
  String p; // 词性 (n./vt./adj.)
  String i; // 释义
  String ei; // 英文释义
  bool bCi; // 是否词组

  Interpret({this.p = '', this.i = '', this.ei = '', this.bCi = false});

  factory Interpret.fromJson(Map<String, dynamic> json) =>
      Interpret(p: json['p'] ?? '', i: json['i'] ?? '', ei: json['ei'] ?? '', bCi: json['bCi'] ?? false);

  /// 完整释义字符串（getInterpretCompleteString）
  String get interpretComplete => p.isNotEmpty ? '$p  $i' : i;
}
