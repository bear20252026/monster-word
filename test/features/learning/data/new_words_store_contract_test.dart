import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/core/learning/new_words_store.dart';
import 'package:word_app/models/word.dart';

/// 模拟学习侧经 core 契约暴露的生词本。
///
/// 该 fake 只依赖 `NewWordsStore`（core），不 import learning/presentation ——
/// 验证 WS-6 C2 后消费方（如 book 词卡徽标）只依赖 core 契约。
class _FakeNewWordsStore extends ChangeNotifier implements NewWordsStore {
  _FakeNewWordsStore([Set<int>? init]) : _ids = Set.of(init ?? const [7, 9]);

  final Set<int> _ids;
  bool _initialized = false;

  @override
  bool get initialized => _initialized;

  @override
  int get count => _ids.length;

  @override
  bool isNewWord(int wordId) => _ids.contains(wordId);

  @override
  Future<void> initialize() async {
    _initialized = true;
    notifyListeners();
  }

  @override
  Future<void> toggleNewWord(Word word, {String source = 'manual'}) async {
    if (_ids.contains(word.id)) {
      _ids.remove(word.id);
    } else {
      _ids.add(word.id);
    }
    notifyListeners();
  }
}

Word _word(int id) => Word(id: id, word: 'w$id');

void main() {
  group('NewWordsStore (WS-6 core contract)', () {
    test('isNewWord/count reflect the seeded ids', () {
      final store = _FakeNewWordsStore();
      expect(store.isNewWord(7), isTrue);
      expect(store.isNewWord(42), isFalse);
      expect(store.count, 2);
    });

    test('toggleNewWord adds/removes and updates count', () async {
      final store = _FakeNewWordsStore();
      await store.toggleNewWord(_word(42));
      expect(store.isNewWord(42), isTrue);
      expect(store.count, 3);

      await store.toggleNewWord(_word(42));
      expect(store.isNewWord(42), isFalse);
      expect(store.count, 2);
    });
  });
}
