// 由账号4生成
// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：LibBook（词书信息）

/// 词书信息（翻译自 LibBook.java）
class LibBook {
  static const int typePhrase = 8; // 词组词书
  static const int tagBought = 4;
  static const int tagHistory = 2;
  static const int tagUpload = 3;
  static const int typeMine = 0;

  final int id;
  final String code;
  final String name;
  final int count; // 单词量
  final int version;
  final String url;
  final String desc;
  final String cover;
  final String sortBy;
  final int forSale;
  final int purchased;
  final int lvl1TagId;
  final List<int> lvl2TagIds;

  LibBook({
    this.id = 0,
    this.code = '',
    this.name = '',
    this.count = 0,
    this.version = 0,
    this.url = '',
    this.desc = '',
    this.cover = '',
    this.sortBy = '',
    this.forSale = 0,
    this.purchased = 0,
    this.lvl1TagId = 0,
    List<int>? lvl2TagIds,
  }) : lvl2TagIds = lvl2TagIds ?? [];

  bool isForSale() => forSale == 1;
  bool isHasBought() => purchased == 1;

  /// 是否属于某二级标签
  bool isBelongToTag(int tag) => lvl2TagIds.contains(tag);

  /// 历史词书
  bool isHistoryLib() => lvl1TagId == 0 && lvl2TagIds.contains(tagHistory);

  bool isOnlyHistoryLib() =>
      lvl1TagId == 0 && lvl2TagIds.length == 1 && lvl2TagIds.contains(tagHistory);

  static bool isUploadTag(int id) => id == tagUpload;
  static bool isHistoryTag(int id) => id == tagHistory;
  static bool isHasBuyedTag(int id) => id == tagBought;

  factory LibBook.fromJson(Map<String, dynamic> json) => LibBook(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code'] ?? '',
        name: json['name'] ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        version: (json['version'] as num?)?.toInt() ?? 0,
        url: json['url'] ?? '',
        desc: json['desc'] ?? '',
        cover: json['cover'] ?? '',
        sortBy: json['sortBy'] ?? '',
        forSale: (json['forSale'] as num?)?.toInt() ?? 0,
        purchased: (json['purchased'] as num?)?.toInt() ?? 0,
        lvl1TagId: (json['lvl1TagId'] as num?)?.toInt() ?? 0,
        lvl2TagIds: (json['lvl2TagIds'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [],
      );
}
