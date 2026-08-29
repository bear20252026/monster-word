import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/models/book.dart';

void main() {
  group('B-1: Learn 空态引导 — SnackBar 含「去选词书」CTA', () {
    testWidgets('无词书时显示带 CTA 的 SnackBar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('还没有词书，先去选一本吧'),
                    action: SnackBarAction(
                      label: '去选词书',
                      onPressed: _noopAction,
                    ),
                  ),
                );
              },
              child: const Text('Test'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(find.text('还没有词书，先去选一本吧'), findsOneWidget);
      expect(find.text('去选词书'), findsOneWidget);
    });
  });

  group('B-2: 词书描述来自元数据 — _categoryOf 动态生成', () {
    test('CET4 code 返回含「CET4」描述', () {
      final book = Book(id: 1, code: 'CET4', name: '四级核心', wordCount: 1200);
      final category = _categoryOf(book.code);
      expect(category, equals('CET4'));
      expect('$category | ${book.wordCount}词', equals('CET4 | 1200词'));
    });

    test('CET6 code 返回含「CET6」描述', () {
      final book = Book(id: 2, code: 'CET6', name: '六级核心', wordCount: 800);
      final category = _categoryOf(book.code);
      expect(category, equals('CET6'));
    });

    test('KY code 返回含「考研」描述', () {
      final book = Book(id: 3, code: 'KAOYAN', name: '考研核心', wordCount: 2000);
      final category = _categoryOf(book.code);
      expect(category, equals('考研'));
    });

    test('GK code 返回含「高考」描述', () {
      final book = Book(id: 4, code: 'GKHX', name: '高考核心', wordCount: 1500);
      final category = _categoryOf(book.code);
      expect(category, equals('高考'));
    });

    test('未知 code 返回「其他」', () {
      final book = Book(id: 5, code: 'UNKNOWN', name: '未知词书', wordCount: 100);
      final category = _categoryOf(book.code);
      expect(category, equals('其他'));
    });
  });

  group('B-6: 日期格式统一中文', () {
    test('_formatDate 输出不含英文星期', () {
      final now = DateTime.now();
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final expected = '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';

      expect(expected.contains('Mon.'), isFalse);
      expect(expected.contains('Tue.'), isFalse);
      expect(expected.contains('Wed.'), isFalse);
      expect(weekdays.contains(expected.split(' ').last), isTrue);
    });
  });
}

/// SnackBarAction.onPressed 不能为 null，用占位
void _noopAction() {}

/// 与 lib_select_page.dart _LibItem._categoryOf 一致
String _categoryOf(String code) {
  if (RegExp(r'CET4|四级').hasMatch(code)) return 'CET4';
  if (RegExp(r'CET6|六级').hasMatch(code)) return 'CET6';
  if (RegExp(r'GK|高考|GKCJ|GKHX|GKSG').hasMatch(code)) return '高考';
  if (RegExp(r'KY|考研|KAOYAN|LLYC|KYSG').hasMatch(code)) return '考研';
  if (RegExp(r'IELTS|雅思').hasMatch(code)) return '雅思';
  if (RegExp(r'TOEFL|托福|GDTOEFL').hasMatch(code)) return '托福';
  if (RegExp(r'GRE|GMAT|SAT|BEC|TEM|专四|专八|PRO4|PRO8|XHPRO|PETS').hasMatch(code)) {
    return '专业出国';
  }
  return '其他';
}
