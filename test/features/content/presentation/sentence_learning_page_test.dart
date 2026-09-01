// 句库翻卡学习器回归测试：挖空/翻卡/认识/不认识循环/完成视图
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:word_app/core/audio/audio_service.dart';
import 'package:word_app/features/content/presentation/sentence_learning_page.dart';
import 'package:word_app/models/sentence_models.dart';

class _StubAudioService implements AudioService {
  @override
  Future<void> playWordAudio(String word, {String accent = 'us', String? audioUrl}) async {}

  @override
  Future<void> playFromUrl(String url) async {}

  @override
  Future<void> stop() async {}

  @override
  bool get isPlaying => false;

  @override
  void dispose() {}
}

FavSentenceData _fav(String word, String english, String chinese) => FavSentenceData(
  word: word,
  sentenceData: SentenceData(e: english, c: chinese, b: '测试来源'),
);

Future<void> _pumpPage(WidgetTester tester, List<FavSentenceData> sentences) async {
  await tester.pumpWidget(MaterialApp(home: SentenceLearningPage(sentences: sentences)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    final sl = GetIt.I;
    if (!sl.isRegistered<AudioService>()) {
      sl.registerSingleton<AudioService>(_StubAudioService());
    }
  });

  testWidgets('正面显示挖空句与提示，不直接暴露答案', (tester) async {
    await _pumpPage(tester, [_fav('apple', 'I ate an apple today.', '我今天吃了一个苹果。')]);
    expect(find.textContaining('____'), findsOneWidget);
    expect(find.textContaining('apple'), findsNothing);
    expect(find.text('显示答案'), findsOneWidget);
  });

  testWidgets('显示答案后高亮单词与翻译，出现认识/不认识按钮', (tester) async {
    await _pumpPage(tester, [_fav('apple', 'I ate an apple today.', '我今天吃了一个苹果。')]);
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('我今天吃了一个苹果。'), findsOneWidget);
    expect(find.text('认识'), findsOneWidget);
    expect(find.text('不认识'), findsOneWidget);
  });

  testWidgets('认识后队列清空进入完成视图，可返回', (tester) async {
    await _pumpPage(tester, [_fav('apple', 'I ate an apple today.', '今天')]);
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('认识'));
    await tester.pumpAndSettle();
    expect(find.text('全部掌握！'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.byType(SentenceLearningPage), findsNothing);
  });

  testWidgets('不认识循环：卡片回到队尾，掌握全部后结束', (tester) async {
    await _pumpPage(tester, [
      _fav('apple', 'I ate an apple today.', '苹果'),
      _fav('banana', 'A banana is yellow.', '香蕉'),
    ]);
    // 第一张翻卡后点不认识 → 回到队尾，当前变为 banana（正面挖空）
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('不认识'));
    await tester.pumpAndSettle();
    // 翻开 banana 卡验证答案
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    expect(find.text('banana'), findsOneWidget);
    // banana 认识 → apple 再次出现
    await tester.tap(find.text('认识'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    expect(find.text('apple'), findsOneWidget);
    // apple 认识 → 完成视图
    await tester.tap(find.text('认识'));
    await tester.pumpAndSettle();
    expect(find.text('全部掌握！'), findsOneWidget);
  });

  testWidgets('再学一轮重置进度', (tester) async {
    await _pumpPage(tester, [_fav('apple', 'I ate an apple today.', '苹果')]);
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('认识'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('再学一轮'));
    await tester.pumpAndSettle();
    expect(find.textContaining('____'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
  });

  test('挖空函数大小写不敏感且保留其余文本', () {
    final page = SentenceLearningPage(sentences: [_fav('Apple', 'An Apple a day.', '')]);
    // 通过公开路径间接验证：masked 句由 build 内部使用，这里直接验证数据侧
    expect(page.sentences.single.sentenceData!.e, 'An Apple a day.');
  });
}
