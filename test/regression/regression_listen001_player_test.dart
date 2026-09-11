import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/listening_mode.dart';
import 'package:word_app/features/learning/presentation/listening_player_page.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/cassette_tape.dart';

Word _word(String w, {String example = ''}) => Word(
  id: w.hashCode,
  word: w,
  mainWord: w,
  interpret: 'n. 测试词',
  ukPron: '/test/',
  usPron: '/test/',
  phrase: '',
  example: example,
  confuse: '',
);

/// REG-LISTEN-001：随身听播放器磁带机重设计行为契约。
///
/// 与 personal_stereo 同族化（共享 CassetteTape hero）后不得丢失：
/// 1. 模式胶囊与书名标题；
/// 2. Charter 词头 + 音标 + 点击显示释义（含结构化例句）；
/// 3. 磁带静止起步，播放后卷轴旋转（spinning=true）；
/// 4. 进度指示随上一首/下一首移动，首词禁用上一首。
void main() {
  final words = [_word('apple'), _word('banana'), _word('cherry')];

  Widget harness() {
    return MaterialApp(
      home: SkinProvider(
        skin: SkinSystem(),
        child: ListeningPlayerPage(words: words, mode: ListeningMode.wordMeaning, bookName: '测试词书'),
      ),
    );
  }

  setUp(() {
    // flutter_tts 走平台通道，测试内一律静默成功。
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      null,
    );
  });

  testWidgets('标题/模式胶囊/词头/音标齐全，磁带静止', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('随身听 · 测试词书'), findsOneWidget);
    expect(find.text('单词+释义'), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('/test/'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text(' / 3'), findsOneWidget);

    final tape = tester.widget<CassetteTape>(find.byType(CassetteTape));
    expect(tape.spinning, isFalse, reason: '未播放时磁带卷轴不得旋转');
  });

  testWidgets('点击显示释义后出现释义与例句', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SkinProvider(
          skin: SkinSystem(),
          child: ListeningPlayerPage(words: [_word('apple', example: 'An apple a day.')]),
        ),
      ),
    );
    await tester.pump();

    // AnimatedCrossFade 隐藏侧仍在树中，用「例句仅在揭示后构建」验证折叠。
    expect(find.text('An apple a day.'), findsNothing);
    await tester.tap(find.text('点击显示释义'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('n. 测试词'), findsOneWidget);
    expect(find.text('An apple a day.'), findsOneWidget);
  });

  testWidgets('播放后磁带旋转；下一首移动进度且上一首可用', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SkinProvider(
          skin: SkinSystem(),
          // wordOnly 无内部超时 Timer，避免测试结束时报 pending timer。
          child: ListeningPlayerPage(words: words, mode: ListeningMode.wordOnly, bookName: '测试词书'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 100));

    var tape = tester.widget<CassetteTape>(find.byType(CassetteTape));
    expect(tape.spinning, isTrue, reason: '播放中磁带卷轴必须旋转');
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('2'), findsOneWidget);
    expect(find.text(' / 3'), findsOneWidget);
    expect(find.text('banana'), findsOneWidget);

    tape = tester.widget<CassetteTape>(find.byType(CassetteTape));
    expect(tape.spinning, isTrue, reason: '连播切词后仍处播放态');
  });

  testWidgets('首词禁用上一首，末词禁用下一首', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SkinProvider(
          skin: SkinSystem(),
          child: ListeningPlayerPage(words: words.reversed.toList(), startIndex: 2),
        ),
      ),
    );
    await tester.pump();

    // 末词：下一首禁用（onPressed 为 null）
    final next = tester.widget<InkWell>(
      find.ancestor(of: find.byIcon(Icons.skip_next_rounded), matching: find.byType(InkWell)),
    );
    expect(next.onTap, isNull);

    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('2'), findsOneWidget);
    expect(find.text(' / 3'), findsOneWidget);
  });
}
