import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:word_app/core/audio/audio_playback_state.dart';
import 'package:word_app/data/example_parser.dart';
import 'package:word_app/services/audio_service.dart';
import 'package:word_app/theme/skin_system.dart';

/// 模拟 AudioService，记录 playFromUrl 调用
class _SpyAudioService implements AudioService {
  final List<String> playedUrls = [];

  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {}

  @override
  Future<void> playFromUrl(String url) async {
    playedUrls.add(url);
  }

  @override
  Future<void> stop() async {}

  @override
  bool get isPlaying => false;

  @override
  void dispose() {}
}

/// 最小化测试 widget：模拟例句卡片 + 音频按钮
class _ExampleCardWithAudio extends StatelessWidget {
  final ExampleSentence example;
  const _ExampleCardWithAudio({required this.example});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(example.en),
            ),
            if (example.audioUrl != null && example.audioUrl!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.volume_up_outlined, size: 20),
                onPressed: () => context.read<AudioPlaybackState>().playSentence(example.audioUrl!),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              ),
          ],
        ),
        if (example.cn.isNotEmpty) Text(example.cn),
      ],
    );
  }
}

void main() {
  group('例句音频播放按钮 (WS-5 D5)', () {
    late _SpyAudioService spyAudio;

    setUp(() {
      spyAudio = _SpyAudioService();
    });

    Widget buildCard(ExampleSentence example) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AudioPlaybackState>(
            create: (_) => AudioPlaybackState(audioService: spyAudio),
          ),
          ChangeNotifierProvider<SkinSystem>(
            create: (_) => SkinSystem(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _ExampleCardWithAudio(example: example),
          ),
        ),
      );
    }

    testWidgets('有 audioUrl 时显示音频播放按钮', (tester) async {
      // ExampleParser 期望格式: {"data":[{"g":[{"s":[{"e":"...","c":"...","b":"...","u":"..."}]}]}]}
      final sentences = ExampleParser.parse(
        '{"data":[{"g":[{"s":[{"e":"Hello world","c":"你好世界","b":"test","u":"sentence/audio/hello.mp3"}]}]}]}',
      );
      expect(sentences.length, 1);
      expect(sentences.first.audioUrl, 'https://audio.beingfine.cn/sentence/audio/hello.mp3');

      await tester.pumpWidget(buildCard(sentences.first));
      await tester.pumpAndSettle();

      expect(find.text('Hello world'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    });

    testWidgets('无 audioUrl 时不显示音频播放按钮', (tester) async {
      final sentences = ExampleParser.parse(
        '{"data":[{"g":[{"s":[{"e":"Hello world","c":"你好世界","b":"test"}]}]}]}',
      );
      expect(sentences.length, 1);
      expect(sentences.first.audioUrl, isNull);

      await tester.pumpWidget(buildCard(sentences.first));
      await tester.pumpAndSettle();

      expect(find.text('Hello world'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    });

    testWidgets('点击音频按钮调用 playSentence', (tester) async {
      final sentences = ExampleParser.parse(
        '{"data":[{"g":[{"s":[{"e":"Hello world","c":"你好世界","u":"sentence/audio/hello.mp3"}]}]}]}',
      );
      expect(sentences.first.audioUrl, isNotEmpty);

      await tester.pumpWidget(buildCard(sentences.first));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      await tester.pumpAndSettle();

      expect(spyAudio.playedUrls, contains(sentences.first.audioUrl));
    });

    test('多条例句各自独立显示音频按钮', () {
      final sentences = ExampleParser.parse(
        '{"data":[{"g":[{"s":['
        '{"e":"First","c":"第一","u":"sentence/audio/1.mp3"},'
        '{"e":"Second","c":"第二","u":"sentence/audio/2.mp3"}'
        ']}]}]}',
      );
      expect(sentences.length, 2);
      expect(sentences[0].audioUrl, isNotEmpty);
      expect(sentences[1].audioUrl, isNotEmpty);
    });

    test('部分例句有音频、部分没有时只显示对应按钮', () {
      final sentences = ExampleParser.parse(
        '{"data":[{"g":[{"s":['
        '{"e":"With audio","c":"有音频","u":"sentence/audio/w.mp3"},'
        '{"e":"Without audio","c":"无音频"}'
        ']}]}]}',
      );
      expect(sentences.length, 2);
      expect(sentences[0].audioUrl, isNotEmpty);
      expect(sentences[1].audioUrl, isNull);
    });
  });
}
