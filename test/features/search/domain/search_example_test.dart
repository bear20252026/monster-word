import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/search/domain/search_example.dart';

void main() {
  group('SearchExample', () {
    test('cleanEn 去掉高亮标签', () {
      const ex = SearchExample(en: 'I <b>am</b> a student', cn: '我是学生');
      expect(ex.cleanEn, 'I am a student');
    });

    test('highlightedParts 在有高亮时分段', () {
      const ex = SearchExample(en: 'I <b>am</b> a <b>student</b>', cn: '我是学生');
      final parts = ex.highlightedParts;
      // 'I ' + 'am' + ' a ' + 'student' → 4 segments
      expect(parts.length, 4);
      expect(parts[0].text, 'I ');
      expect(parts[0].highlight, false);
      expect(parts[1].text, 'am');
      expect(parts[1].highlight, true);
      expect(parts[2].text, ' a ');
      expect(parts[2].highlight, false);
      expect(parts[3].text, 'student');
      expect(parts[3].highlight, true);
    });

    test('highlightedParts 在无高亮时返回单段', () {
      const ex = SearchExample(en: 'I am a student', cn: '我是学生');
      final parts = ex.highlightedParts;
      expect(parts.length, 1);
      expect(parts[0].text, 'I am a student');
      expect(parts[0].highlight, false);
    });

    test('highlightedParts 在空字符串时返回空列表', () {
      const ex = SearchExample(en: '', cn: '');
      final parts = ex.highlightedParts;
      expect(parts, isEmpty);
    });

    test('音频 URL 为可选字段', () {
      const ex1 = SearchExample(en: 'hello', cn: '你好');
      expect(ex1.audioUrl, isNull);

      const ex2 = SearchExample(en: 'hello', cn: '你好', audioUrl: 'https://example.com/audio.mp3');
      expect(ex2.audioUrl, 'https://example.com/audio.mp3');
    });
  });
}
