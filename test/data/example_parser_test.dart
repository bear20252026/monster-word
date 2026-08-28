import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/data/example_parser.dart';

void main() {
  group('ExampleParser.parse', () {
    test('从例句 s["u"] 字段提取并归一化音频 URL（修复例句发音缺失）', () {
      const raw =
          '{"v":1,"data":[{"oid":1,"i":{"e":"abandon","c":"放弃"},"g":[{"uid":0,'
          '"u":"用法","s":[{"eid":1,"e":"He <b>abandoned</b> the plan.","c":"他放弃了计划。",'
          '"b":"生活大爆炸 第三季","u":"/sentence/audio/6389561345574934.mp3"}]}]}]}';

      final sentences = ExampleParser.parse(raw);

      expect(sentences, isNotEmpty);
      final s = sentences.first;
      expect(s.en, 'He <b>abandoned</b> the plan.');
      expect(s.cleanEn, 'He abandoned the plan.');
      expect(s.cn, '他放弃了计划。');
      expect(s.source, '生活大爆炸 第三季');
      expect(s.audioUrl, 'https://audio.beingfine.cn/sentence/audio/6389561345574934.mp3');
    });

    test('完整的 http URL 保持原样（不再重复拼接域名）', () {
      const raw =
          '{"v":1,"data":[{"i":{"e":"test","c":"测试"},"g":[{"u":"用法","s":[{"eid":9,'
          '"e":"This is a test.","c":"这是测试。","b":"","u":"http://audio.beingfine.cn/sentence/audio/abc.mp3"}]}]}]}';

      final sentences = ExampleParser.parse(raw);

      expect(sentences.first.audioUrl, 'http://audio.beingfine.cn/sentence/audio/abc.mp3');
    });

    test('无音频字段的例句 audioUrl 为 null', () {
      const raw =
          '{"v":1,"data":[{"i":{"e":"test","c":"测试"},"g":[{"u":"用法","s":[{"eid":9,'
          '"e":"No audio.","c":"没有音频。","b":""}]}]}]}';

      final sentences = ExampleParser.parse(raw);

      expect(sentences.first.audioUrl, isNull);
    });
  });
}
