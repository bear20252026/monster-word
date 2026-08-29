import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/features/learning/data/mastered_repository_impl.dart';

void main() {
  test('MasteredRepositoryImpl 读取并继续写入既有 mastered_words_v1 数据', () async {
    SharedPreferences.setMockInitialValues({
      'mastered_words_v1': ['apple'],
    });
    final repository = MasteredRepositoryImpl();

    expect(await repository.getMasteredWords(), {'apple'});
    expect(repository.isMastered('apple'), isTrue);
    expect(repository.masteredCount, 1);

    await repository.toggleMastered('banana');
    expect(repository.isMastered('banana'), isTrue);
    expect(repository.masteredCount, 2);

    await repository.toggleMastered('apple');
    expect(repository.isMastered('apple'), isFalse);
    expect(await repository.getMasteredWords(), {'banana'});
  });
}
