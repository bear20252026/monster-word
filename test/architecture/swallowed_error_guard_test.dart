// 吞错治理守卫（审计跟进批次 C / REG-OBS-001；2026-10-15 审计 R3-L06/R3-E08 收紧）。
// A 级文件（用户数据丢失/持久化失败路径）的**每一个** catch 块都必须
// 上报（reportSwallowedError）或 rethrow，否则测试失败。
// 分级规则见 lib/core/utils/swallowed_error_report.dart 文件头。
//
// 为什么从「文件级」改成「按 catch 块」（2026-10-15 第三轮审计）：
// 旧断言是 `src.contains('reportSwallowedError')` —— **文件里出现这个字符串就算过**：
//   - 注释里提一句函数名即可通过；
//   - 同一文件里只要任意一处有调用，其余 `catch (_) {}` 全被放行
//     （`review_schedule_repository.dart` 有 22 个 catch）。
// 实测证据：`message_store.dart` 含该字符串因而通过，但它的 `_loadLocked` 与
// `_persist` 两条真实数据路径当时既无上报也无状态复位。
// 同族的「断言匹配到注释造成假绿」已在台账 REG-ARCH-010 记过一次。
//
// 收紧后立刻的价值：在 13 个文件 / 74 个 catch 里扫出 5 处「块内没有上报」，
// 逐个核实后确认都是**合法的延迟上报**（3 处暂存到 lastError 后同一方法内统一上报，
// 2 处逐行跳过损坏行、循环后按 skipped 聚合上报），已按机制加显式豁免标记。
// 扫描逻辑在 `swallowed_error_scan.dart`（纯 Dart，可脱离 flutter_test 直接跑）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'swallowed_error_scan.dart';

void main() {
  test('A 级数据路径的每个 catch 块都必须上报或 rethrow（REG-OBS-001）', () {
    final violations = <String>[];
    var catchTotal = 0;

    for (final path in kALevelFiles) {
      final f = File(path);
      expect(f.existsSync(), isTrue, reason: '$path 不存在（请在仓库根目录运行）');
      final src = f.readAsStringSync();
      catchTotal += RegExp(r'\bcatch\b').allMatches(stripComments(src).code).length;

      for (final bad in findUnreportedCatches(src)) {
        final line = '\n'.allMatches(src.substring(0, bad.rawOffset)).length + 1;
        violations.add(
          '$path:$line 的 catch 块既没有 reportSwallowedError 也没有 rethrow'
          '（数据路径异常不得静默吞掉）\n      ${bad.snippet.replaceAll('\n', ' ')}',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下 catch 块静默吞掉了异常。若确实不需要上报，请在块内或 catch 上一行写\n'
          '`// 吞错豁免: <理由>`（理由必填）：\n${violations.join('\n')}',
    );

    // 反向守卫：清单本身不能变成空转（全删光就「通过」了）
    expect(kALevelFiles.length, greaterThanOrEqualTo(10), reason: 'A 级清单被削得只剩几条，守卫失去意义');
    expect(catchTotal, greaterThan(30), reason: '扫到的 catch 数异常少，可能扫描逻辑坏了');
  });

  test('扫描器本身可用：能识别出未上报的 catch、也能识别豁免标记', () {
    // 正例：空捕获应被判为违规
    expect(findUnreportedCatches('void f() { try { g(); } catch (_) {} }'), hasLength(1));
    // 有上报 → 通过
    expect(
      findUnreportedCatches('void f() { try { g(); } catch (e, s) { reportSwallowedError("x", e, s); } }'),
      isEmpty,
    );
    // rethrow → 通过
    expect(findUnreportedCatches('void f() { try { g(); } catch (e) { rethrow; } }'), isEmpty);
    // 注释里出现函数名**不算**上报（旧断言的漏洞）
    expect(findUnreportedCatches('void f() { try { g(); } catch (_) { /* reportSwallowedError */ } }'), hasLength(1));
    // 显式豁免且理由非空 → 通过
    expect(findUnreportedCatches('void f() { try { g(); } catch (_) { // 吞错豁免: 故意\n } }'), isEmpty);
    // 豁免但理由为空 → 仍判违规
    expect(findUnreportedCatches('void f() { try { g(); } catch (_) { // 吞错豁免:\n } }'), hasLength(1));
  });

  test('上报工具不得在 Sentry 未初始化时调用平台通道', () {
    final src = File('lib/core/utils/swallowed_error_report.dart').readAsStringSync();
    expect(src, contains('Sentry.isEnabled'), reason: '必须用 isEnabled 守卫，避免测试环境崩溃');
  });
}
