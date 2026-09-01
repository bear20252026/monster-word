// 由 Claude 团队生成 | Monster Word App

// FeedbackArchive 单元测试：本地存档、上传失败兜底、联系方式分流。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/application/feedback_archive.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('FeedbackArchive', () {
    test('submit 后本地存档含内容，history 可读回', () async {
      final uploads = <FeedbackEntry>[];
      final archive = FeedbackArchive(prefsOverride: prefs, upload: (entry) async => uploads.add(entry));

      await archive.submit(content: '单词卡片字体太小', contact: 'user@example.com');

      final history = await archive.history();
      expect(history, hasLength(1));
      expect(history.first.content, '单词卡片字体太小');
      expect(history.first.contact, 'user@example.com');
      expect(uploads, hasLength(1));
    });

    test('上传抛异常不阻断提交语义，本地仍存档成功', () async {
      final archive = FeedbackArchive(prefsOverride: prefs, upload: (entry) async => throw Exception('network down'));

      final history = await archive.submit(content: '断网也能提交的反馈');

      expect(history, hasLength(1));
      expect((await archive.history()).first.content, '断网也能提交的反馈');
    });

    test('多次提交累加（新条目在末尾）', () async {
      final archive = FeedbackArchive(prefsOverride: prefs, upload: (entry) async {});

      await archive.submit(content: '第一条');
      await archive.submit(content: '第二条');

      final history = await archive.history();
      expect(history, hasLength(2));
      expect(history[0].content, '第一条');
      expect(history[1].content, '第二条');
    });
  });
}
