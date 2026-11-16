import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/quick_review/domain/exam_book_mapping.dart';
import 'package:word_app/features/quick_review/domain/exam_type.dart';
import 'package:word_app/models/book.dart';

/// 审计 R12：考试类型→词书匹配纯函数表驱动单测。
void main() {
  Book b(int id, String code, String name) => Book(id: id, code: code, name: name, wordCount: 10);

  final books = [
    b(1, 'CET4DGCH', '四级词汇大纲'),
    b(2, 'CET6', '六级高频'),
    b(3, 'GAOKAO3500', '高考词汇3500'),
    b(4, 'KAOYAN', '考研核心词'),
    b(5, 'YASI', '雅思圣经'),
    b(6, 'TOEFL', '托福核心'),
    b(7, 'PETS4', '公共英语四级'),
    b(8, 'AWL', '学术词汇 AWL'),
  ];

  test('各考试类型匹配对应词书（name/code 关键词）', () {
    expect(matchExamBooks(ExamType.cet4, books).map((e) => e.id), [1]);
    expect(matchExamBooks(ExamType.cet6, books).map((e) => e.id), [2]);
    expect(matchExamBooks(ExamType.gaokao, books).map((e) => e.id), [3]);
    expect(matchExamBooks(ExamType.kaoyan, books).map((e) => e.id), [4]);
    expect(matchExamBooks(ExamType.ielts, books).map((e) => e.id), [5]);
    expect(matchExamBooks(ExamType.toefl, books).map((e) => e.id), [6]);
  });

  test('PETS4/公共英语 排除，不误配四级', () {
    expect(matchExamBooks(ExamType.cet4, [b(7, 'PETS4', '公共英语四级')]), isEmpty);
  });

  test('无关词书不匹配（AWL 不含任何考试关键词）', () {
    expect(matchExamBooks(ExamType.cet4, [b(8, 'AWL', '学术词汇 AWL')]), isEmpty);
    expect(matchExamBooks(ExamType.gaokao, [b(8, 'AWL', '学术词汇 AWL')]), isEmpty);
  });

  test('空目录返回空', () {
    for (final t in ExamType.values) {
      expect(matchExamBooks(t, const []), isEmpty);
    }
  });

  test('多本匹配全部返回（调用方随机选一本）', () {
    final two = [b(1, 'CET4', '四级词汇'), b(9, 'CET4ZT', '四级真题')];
    expect(matchExamBooks(ExamType.cet4, two).map((e) => e.id).toSet(), {1, 9});
  });
}
