// SnackBar 出口卫生守卫——lib 下禁止绕过 showMwSnackBar 出口直接弹 SnackBar
// （P1-D，审计 I4 收尾；P2-11 补口：ScaffoldMessenger.of / maybeOf?. 链式与局部持有
// messenger 变量后直弹，三种形态全部收进口径；出口实现自身豁免）。
//
// 防误伤口径：word_app 代码里 showSnackBar 只存在于 ScaffoldMessenger 上，第二分支
// 仅匹配「非空白字符紧邻 .showSnackBar(」的成员调用；白名单仅出口实现 mw_feedback.dart。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _scanRoots = <String>['lib/features', 'lib/widgets', 'lib/app', 'lib/core', 'lib/main.dart'];

const _whitelist = <String>{'lib/widgets/common/mw_feedback.dart'};

final _callRe = RegExp(r'ScaffoldMessenger\.(?:of|maybeOf)\([^)]*\)\s*\??\.\s*showSnackBar\s*\(|(\S)\.showSnackBar\(');

void main() {
  test('ScaffoldMessenger 链式与局部持有直弹 SnackBar 存量为 0（统一走 showMwSnackBar）', () {
    final hits = <String>[];
    for (final root in _scanRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll('\\', '/');
        if (_whitelist.contains(rel)) continue;
        final src = f.readAsStringSync();
        for (final m in _callRe.allMatches(src)) {
          final line = src.substring(0, m.start).split('\n').length;
          hits.add('$rel:$line');
        }
      }
    }
    expect(hits, isEmpty, reason: '以下调用应改走 showMwSnackBar 出口：\n${hits.join('\n')}');
  });

  test('showMwSnackBar 出口存在且基于 ScaffoldMessenger', () {
    final src = File('lib/widgets/common/mw_feedback.dart').readAsStringSync();
    expect(src.contains('void showMwSnackBar('), isTrue);
  });
}
