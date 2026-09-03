import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/parsers/example_parser.dart';

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

    test('完整的 http URL 升级为 https（Android 9+ 禁明文流量，http 例句被静默拦截）', () {
      const raw =
          '{"v":1,"data":[{"i":{"e":"test","c":"测试"},"g":[{"u":"用法","s":[{"eid":9,'
          '"e":"This is a test.","c":"这是测试。","b":"","u":"http://audio.beingfine.cn/sentence/audio/abc.mp3"}]}]}]}';

      final sentences = ExampleParser.parse(raw);

      expect(sentences.first.audioUrl, 'https://audio.beingfine.cn/sentence/audio/abc.mp3');
    });

    test('双重编码 JSON 兼容：外层多包一层字符串时二次解码（REG-DICT-004，全库 84% 词条此形态）', () {
      const inner =
          '{"v":1,"data":[{"oid":16063,"type":1,"i":{"e":"to leave sb","c":"离弃","p":"vt."},'
          '"g":[{"uid":0,"u":"","s":[{"eid":1,"e":"They just <b>abandon</b> us?","c":"他们就要抛弃我们了？",'
          '"b":"破产姐妹","u":"/sentence/audio/6389561345574934.mp3"}]}]}]}';
      // 模拟词库双重编码形态：外层再包一层 JSON 字符串
      final raw = jsonEncode(inner);

      final sentences = ExampleParser.parse(raw);

      expect(sentences, isNotEmpty, reason: '双重编码词条此前静默返回空（84% 词例句 tab 恒「暂无例句」）');
      expect(sentences.first.cleanEn, 'They just abandon us?');
      expect(sentences.first.source, '破产姐妹');
      expect(sentences.first.audioUrl, 'https://audio.beingfine.cn/sentence/audio/6389561345574934.mp3');
    });

    test('彻底损坏的原文返回空列表，绝不把原文当例句渲染', () {
      expect(ExampleParser.parse('not a json at all'), isEmpty);
      expect(ExampleParser.parse('{"broken":'), isEmpty);
    });

    test('无音频字段的例句 audioUrl 为 null', () {
      const raw =
          '{"v":1,"data":[{"i":{"e":"test","c":"测试"},"g":[{"u":"用法","s":[{"eid":9,'
          '"e":"No audio.","c":"没有音频。","b":""}]}]}]}';

      final sentences = ExampleParser.parse(raw);

      expect(sentences.first.audioUrl, isNull);
    });
  });

  group('ExampleParser.parseCollins', () {
    test('解析释义（i）+ 用法说明（g.u）+ 分组例句（g.s）', () {
      const raw =
          '{"v":1,"data":[{"oid":1,"type":1,"i":{"e":"a plan made in secret","c":"密谋","p":"n."},'
          '"g":[{"uid":0,"u":"an ~ to sth","s":[{"eid":1,"e":"an <b>adjustment</b> to the schedule","c":"对日程的调整","b":"","u":"/sentence/audio/x.mp3"}]},'
          '{"uid":1,"u":"","s":[{"eid":2,"e":"minor adjustments","c":"微调","b":""}]}]}]}';

      final senses = ExampleParser.parseCollins(raw);

      expect(senses, hasLength(2));
      expect(senses[0].enDef, 'a plan made in secret');
      expect(senses[0].cnDef, '密谋');
      expect(senses[0].pos, 'n.');
      expect(senses[0].usage, 'an ~ to sth');
      expect(senses[0].examples, hasLength(1));
      expect(senses[0].examples.first.audioUrl, 'https://audio.beingfine.cn/sentence/audio/x.mp3');
      expect(senses[1].usage, isEmpty);
      expect(senses[1].examples, hasLength(1));
    });

    test('只有释义、无用法组的词条仍输出释义行（examples 为空）', () {
      const raw = '{"v":1,"data":[{"oid":1,"type":1,"i":{"e":"very usual","c":"普通的","p":"adj."},"g":[]}]}';

      final senses = ExampleParser.parseCollins(raw);

      expect(senses, hasLength(1));
      expect(senses.first.enDef, 'very usual');
      expect(senses.first.examples, isEmpty);
    });

    test('双重编码 JSON 兼容（与 parse 同源二次解码）', () {
      const inner =
          '{"v":1,"data":[{"oid":1,"type":1,"i":{"e":"to leave sb","c":"离弃","p":"vt."},'
          '"g":[{"uid":0,"u":"","s":[{"eid":1,"e":"They <b>abandon</b> us?","c":"他们要抛弃我们？","b":""}]}]}]}';
      final raw = jsonEncode(inner);

      final senses = ExampleParser.parseCollins(raw);

      expect(senses, hasLength(1));
      expect(senses.first.enDef, 'to leave sb');
      expect(senses.first.examples.first.cleanEn, 'They abandon us?');
    });

    test('损坏原文返回空列表', () {
      expect(ExampleParser.parseCollins('garbage'), isEmpty);
    });
  });
}
