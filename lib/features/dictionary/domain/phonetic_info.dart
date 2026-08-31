/// 音标信息值对象。
///
/// 封装英式/美式音标及其音频 URL，纯数据，无外部依赖。
class PhoneticInfo {
  const PhoneticInfo({required this.english, required this.american, this.ukAudio, this.usAudio});

  /// 英式音标
  final String english;

  /// 美式音标
  final String american;

  /// 英式发音音频 URL
  final String? ukAudio;

  /// 美式发音音频 URL
  final String? usAudio;

  /// 是否至少有一种音标
  bool get hasPhonetic => english.isNotEmpty || american.isNotEmpty;

  /// 是否至少有一种音频
  bool get hasAudio => (ukAudio != null && ukAudio!.isNotEmpty) || (usAudio != null && usAudio!.isNotEmpty);

  /// 从 `DictionaryService.getAudioUrls` 返回的 Map 创建音标信息。
  ///
  /// 期望 Map 包含 `english`、`american` 键，可选 `uk_audio`、`us_audio` 键。
  factory PhoneticInfo.fromService(Map<String, dynamic> map) {
    return PhoneticInfo(
      english: (map['english'] as String?)?.trim() ?? '',
      american: (map['american'] as String?)?.trim() ?? '',
      ukAudio: map['uk_audio'] as String?,
      usAudio: map['us_audio'] as String?,
    );
  }

  /// 从 interpret 与 audioUrls 创建音标信息。
  factory PhoneticInfo.fromRaw({required String english, required String american, String? ukAudio, String? usAudio}) {
    return PhoneticInfo(english: english.trim(), american: american.trim(), ukAudio: ukAudio, usAudio: usAudio);
  }
}
