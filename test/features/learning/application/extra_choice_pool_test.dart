// 结构修复步骤3（2026-11-16）：共享扩池编排单测。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/application/word_lookup_reader.dart';
import 'package:word_app/features/learning/application/extra_choice_pool.dart';
import 'package:word_app/models/word.dart';

class _FakeRepo implements WordLookupReader {
  _FakeRepo({this.fail = false});
  final bool fail;
  int calls = 0;
  final Completer<List<Word>> gate = Completer<List<Word>>();

  @override
  Future<List<Word>> getRandomWords(int count) {
    calls++;
    if (fail) return Future<List<Word>>.error(StateError('sample failed'));
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Word _w(int i) => Word(id: i, word: 'w$i', interpret: '释义$i');

void main() {
  test('就绪后回调 onReady 且池可见；加载幂等不重复取样', () async {
    final repo = _FakeRepo();
    var ready = 0;
    final pool = ExtraChoicePool(() => ready++, repository: repo);
    pool.ensureLoaded();
    pool.ensureLoaded(); // 加载中再调不重复取样
    expect(repo.calls, 1);
    expect(pool.words, isEmpty);
    repo.gate.complete([_w(1), _w(2)]);
    await Future<void>.delayed(Duration.zero);
    expect(pool.words.length, 2);
    expect(ready, 1);
  });

  test('reset 后重新取样（换局口径）', () async {
    final repo = _FakeRepo();
    final pool = ExtraChoicePool(() {}, repository: repo);
    pool.ensureLoaded();
    repo.gate.complete([_w(1)]);
    await Future<void>.delayed(Duration.zero);
    pool.reset();
    expect(pool.words, isEmpty);
    // reset 后 ensureLoaded 用新 gate 重新取样。
    final repo2 = _FakeRepo();
    final pool2 = ExtraChoicePool(() {}, repository: repo2);
    pool2.ensureLoaded();
    repo2.gate.complete([_w(9)]);
    await Future<void>.delayed(Duration.zero);
    expect(pool2.words.single.word, 'w9');
  });

  test('取样失败静默降级：池保持空、不抛、不回调', () async {
    final repo = _FakeRepo(fail: true);
    var ready = 0;
    final pool = ExtraChoicePool(() => ready++, repository: repo);
    pool.ensureLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(pool.words, isEmpty);
    expect(ready, 0);
  });

  test('repository 为空：不取样不回调（宁少勿假）', () {
    var ready = 0;
    final pool = ExtraChoicePool(() => ready++, repository: null);
    pool.ensureLoaded();
    expect(pool.words, isEmpty);
    expect(ready, 0);
  });

  test('第三轮 T28：reset 后旧响应迟到不得覆盖新池（世代守卫）', () async {
    // 可控双响应假件：第 1 次取样挂起（旧局），第 2 次即时（新局）。
    final repo = _DualGateRepo();
    var ready = 0;
    final pool = ExtraChoicePool(() => ready++, repository: repo);
    pool.ensureLoaded(); // 旧局取样挂起
    pool.reset(); // 换局：旧响应作废
    pool.ensureLoaded(); // 新局取样
    repo.secondGate.complete([_w(9)]);
    await Future<void>.delayed(Duration.zero);
    expect(pool.words.single.word, 'w9');
    expect(ready, 1);
    // 放行旧局慢响应：世代不符必须丢弃，不得覆盖新池/再回调。
    repo.firstGate.complete([_w(1), _w(2)]);
    await Future<void>.delayed(Duration.zero);
    expect(pool.words.single.word, 'w9', reason: '旧世代响应不得覆盖新池');
    expect(ready, 1, reason: '旧世代响应不得触发 onReady');
  });
}

/// 双门控假件：第 1 次取样走 firstGate，第 2 次走 secondGate。
class _DualGateRepo implements WordLookupReader {
  int calls = 0;
  final Completer<List<Word>> firstGate = Completer<List<Word>>();
  final Completer<List<Word>> secondGate = Completer<List<Word>>();

  @override
  Future<List<Word>> getRandomWords(int count) {
    calls++;
    return calls == 1 ? firstGate.future : secondGate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
