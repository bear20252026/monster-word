// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：Background + SplashAdConfig + CustomeUITheme（简化版）

/// 背景图片（翻译自 Background.java）
class Background {
  String id;
  String src;
  String dimSrc;
  String type;
  String word;
  String phonetic;
  String url;
  String sharePhonetic;
  String shareInterpret;

  Background({
    this.id = '',
    this.src = '',
    this.dimSrc = '',
    this.type = '',
    this.word = '',
    this.phonetic = '',
    this.url = '',
    this.sharePhonetic = '',
    this.shareInterpret = '',
  });

  factory Background.fromJson(Map<String, dynamic> json) => Background(
        id: json['id'] ?? '',
        src: json['src'] ?? '',
        dimSrc: json['dimSrc'] ?? '',
        type: json['type'] ?? '',
        word: json['word'] ?? '',
        phonetic: json['phonetic'] ?? '',
        url: json['url'] ?? '',
        sharePhonetic: json['sharePhonetic'] ?? '',
        shareInterpret: json['shareInterpret'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'src': src,
        'dimSrc': dimSrc,
        'type': type,
        'word': word,
        'phonetic': phonetic,
        'url': url,
        'sharePhonetic': sharePhonetic,
        'shareInterpret': shareInterpret,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Background &&
          id == other.id &&
          src == other.src &&
          dimSrc == other.dimSrc &&
          type == other.type &&
          word == other.word;

  @override
  int get hashCode => Object.hash(id, src, dimSrc, type, word);
}

/// 启动页广告配置（翻译自 SplashAdConfig.java）
class SplashAdConfig {
  int id;
  String name;
  String imageUrl;
  int countdown;
  int intentType;
  String intentParam;

  SplashAdConfig({
    this.id = 0,
    this.name = '',
    this.imageUrl = '',
    this.countdown = 0,
    this.intentType = 0,
    this.intentParam = '',
  });

  factory SplashAdConfig.fromJson(Map<String, dynamic> json) =>
      SplashAdConfig(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] ?? '',
        imageUrl: json['image_url'] ?? '',
        countdown: (json['countdown'] as num?)?.toInt() ?? 0,
        intentType: (json['intent_type'] as num?)?.toInt() ?? 0,
        intentParam: json['intent_param'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'countdown': countdown,
        'intent_type': intentType,
        'intent_param': intentParam,
      };
}

/// UI 主题类型（翻译自 CustomeUITheme.java，仅保留类型常量）
class UIThemeType {
  static const int light = 0;
  static const int dark = 1;
  static const int black = 2;

  static String getName(int type) {
    switch (type) {
      case 0:
        return 'light';
      case 1:
        return 'dark';
      case 2:
        return 'black';
      default:
        return 'light';
    }
  }

  static String getDefaultWallPaperName(int type) {
    switch (type) {
      case 0:
        return 'Foam';
      case 1:
        return 'Jellyfish';
      case 2:
        return 'Dune';
      default:
        return 'Foam';
    }
  }

  static String getDefaultWallPaperInterpret(int type) {
    switch (type) {
      case 0:
        return '泡沫';
      case 1:
        return '水母';
      case 2:
        return '沙丘';
      default:
        return '泡沫';
    }
  }

  static String getDefaultWallPaperPhonetic(int type) {
    switch (type) {
      case 0:
        return '[foʊm]';
      case 1:
        return '[ˈdʒelifɪʃ]';
      case 2:
        return '[duːn]';
      default:
        return '[foʊm]';
    }
  }
}
