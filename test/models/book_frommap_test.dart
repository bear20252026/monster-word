import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/models/book.dart';

void main() {
  group('Book.fromMap (XP-FIX-4)', () {
    test('标准 word_count 列名解析正确', () {
      final book = Book.fromMap({
        'id': 1,
        'code': 'cet4',
        'name': 'CET-4',
        'word_count': 4000,
      });
      expect(book.id, 1);
      expect(book.code, 'cet4');
      expect(book.name, 'CET-4');
      expect(book.wordCount, 4000);
    });

    test('word_count 列缺失时尝试 wordCount 列名', () {
      final book = Book.fromMap({
        'id': 2,
        'code': 'cet6',
        'name': 'CET-6',
        'wordCount': 3000,
      });
      expect(book.wordCount, 3000);
    });

    test('word_count 和 wordCount 都缺失时尝试 total_words', () {
      final book = Book.fromMap({
        'id': 3,
        'code': 'toefl',
        'name': 'TOEFL',
        'total_words': 5000,
      });
      expect(book.wordCount, 5000);
    });

    test('所有 word_count 列都缺失时降级为 0', () {
      final book = Book.fromMap({
        'id': 4,
        'code': 'ielts',
        'name': 'IELTS',
      });
      expect(book.wordCount, 0);
    });

    test('word_count 为字符串数字时正确解析', () {
      final book = Book.fromMap({
        'id': 5,
        'code': 'gre',
        'name': 'GRE',
        'word_count': 6000,
      });
      expect(book.wordCount, 6000);
    });

    test('空 Map 时使用默认值', () {
      final book = Book.fromMap(<String, dynamic>{});
      expect(book.id, 0);
      expect(book.code, '');
      expect(book.wordCount, 0);
    });
  });
}
