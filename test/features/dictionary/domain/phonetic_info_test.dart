import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/dictionary/domain/phonetic_info.dart';

void main() {
  group('PhoneticInfo', () {
    test('fromService 正确解析完整 Map', () {
      final info = PhoneticInfo.fromService({
        'english': '/ˈhelp/',
        'american': '/hɛlp/',
        'uk_audio': 'https://ex.com/uk.mp3',
        'us_audio': 'https://ex.com/us.mp3',
      });

      expect(info.english, '/ˈhelp/');
      expect(info.american, '/hɛlp/');
      expect(info.ukAudio, 'https://ex.com/uk.mp3');
      expect(info.usAudio, 'https://ex.com/us.mp3');
      expect(info.hasPhonetic, isTrue);
      expect(info.hasAudio, isTrue);
    });

    test('fromService 对缺失键返回空字符串而非 null', () {
      final info = PhoneticInfo.fromService({});

      expect(info.english, '');
      expect(info.american, '');
      expect(info.ukAudio, isNull);
      expect(info.usAudio, isNull);
      expect(info.hasPhonetic, isFalse);
      expect(info.hasAudio, isFalse);
    });

    test('fromService 自动 trim 空白', () {
      final info = PhoneticInfo.fromService({'english': '  /test/  ', 'american': ''});

      expect(info.english, '/test/');
    });

    test('hasPhonetic 在仅有一种音标时为 true', () {
      const info = PhoneticInfo(english: '/a/', american: '');
      expect(info.hasPhonetic, isTrue);
    });

    test('hasAudio 在仅有 UK 音频时为 true', () {
      const info = PhoneticInfo(english: '', american: '', ukAudio: 'https://x.com/uk.mp3');
      expect(info.hasAudio, isTrue);
    });

    test('fromRaw 正确传递所有字段', () {
      final info = PhoneticInfo.fromRaw(english: '/raw-uk/', american: '/raw-us/', ukAudio: 'uk', usAudio: 'us');

      expect(info.english, '/raw-uk/');
      expect(info.american, '/raw-us/');
      expect(info.ukAudio, 'uk');
      expect(info.usAudio, 'us');
    });
  });
}
