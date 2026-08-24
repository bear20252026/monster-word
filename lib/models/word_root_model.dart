// 由 Claude 团队生成 | Monster Word App

// 词根词缀数据模型
// 用于解析和展示单词的词根、前缀、后缀信息

import 'dart:convert';

/// 词根词缀数据模型
class WordRootData {
  final String prefix;
  final List<String> roots;
  final String suffix;

  const WordRootData({
    this.prefix = '',
    this.roots = const [],
    this.suffix = '',
  });

  /// 从 JSON 字符串解析
  factory WordRootData.fromJson(String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == '{}') {
      return const WordRootData();
    }
    try {
      final Map<String, dynamic> json = jsonDecode(jsonStr);
      return WordRootData(
        prefix: (json['prefix'] as String?) ?? '',
        roots: List<String>.from(json['roots'] ?? []),
        suffix: (json['suffix'] as String?) ?? '',
      );
    } catch (e) {
      return const WordRootData();
    }
  }

  /// 是否有词根数据
  bool get hasData => prefix.isNotEmpty || roots.isNotEmpty || suffix.isNotEmpty;

  /// 获取所有词根组成部分
  List<WordRootComponent> get components {
    final List<WordRootComponent> components = [];

    if (prefix.isNotEmpty) {
      components.add(WordRootComponent(
        type: WordRootType.prefix,
        text: prefix,
      ));
    }

    for (final root in roots) {
      components.add(WordRootComponent(
        type: WordRootType.root,
        text: root,
      ));
    }

    if (suffix.isNotEmpty) {
      components.add(WordRootComponent(
        type: WordRootType.suffix,
        text: suffix,
      ));
    }

    return components;
  }
}

/// 词根类型
enum WordRootType {
  prefix,  // 前缀
  root,    // 词根
  suffix,  // 后缀
}

/// 词根组成部分
class WordRootComponent {
  final WordRootType type;
  final String text;

  const WordRootComponent({
    required this.type,
    required this.text,
  });

  /// 获取类型名称
  String get typeName {
    switch (type) {
      case WordRootType.prefix:
        return '前缀';
      case WordRootType.root:
        return '词根';
      case WordRootType.suffix:
        return '后缀';
    }
  }

  /// 获取类型颜色（用于UI展示）
  int get colorValue {
    switch (type) {
      case WordRootType.prefix:
        return 0xFF4CAF50; // 绿色
      case WordRootType.root:
        return 0xFF2196F3; // 蓝色
      case WordRootType.suffix:
        return 0xFFFF9800; // 橙色
    }
  }
}
