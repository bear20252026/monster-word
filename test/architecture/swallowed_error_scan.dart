// 吞错扫描器（纯 Dart，**不 import flutter_test**）—— 便于本机直接跑验证。
//
// 为什么要把逻辑抽出来（2026-10-15 审计 R3-L06 / R3-E08）：
// 旧守卫对 13 个 A 级文件只断言 `src.contains('reportSwallowedError')` ——
// **文件里出现这个字符串就算过**，于是：
//   - 注释里提一句函数名即可通过；
//   - 同一文件里只要**任意一处**有调用，其余 `catch (_) {}` 全被放行
//     （`review_schedule_repository.dart` 有 22 个 catch）。
// 实测证据：`message_store.dart` 含该字符串因而通过，但它的 `_loadLocked` 与
// `_persist` 两条真实数据路径当时既无上报、也无状态复位。
// 同族的「断言匹配到注释造成假绿」已在台账 REG-ARCH-010 记过一次。

/// A 级路径：这些文件的异常曾导致用户数据静默丢失，**每一个** catch 块都必须
/// 接 reportSwallowedError（或 rethrow），否则就是静默吞错。
const List<String> kALevelFiles = [
  // MEM/U3+U6：收藏持久化下沉到 DAO（SQLite 事实来源 + SP 回退），
  // 上报随之迁移到 DAO 层；impl 仅做端口转发。
  'lib/core/infrastructure/favorite_words_dao.dart', // 收藏列表（SQLite/SP 持久化）
  'lib/core/infrastructure/fav_sentence_dao.dart', // 收藏例句（SQLite/SP 持久化）
  'lib/core/repositories/note_repository_impl.dart', // 笔记
  'lib/features/learning/data/mastered_repository_impl.dart', // 已掌握词表
  'lib/features/learning/application/review_session_starter.dart', // 复习会话启动
  'lib/features/learning/presentation/review_word_action_coordinator.dart', // 收藏/掌握持久化
  'lib/features/scare_coin/data/preferences_scare_coin_store.dart', // 金币账本（签到/保护卡 SP 路径 + SP 回退）
  'lib/core/infrastructure/scare_coin_ledger_dao.dart', // 金币账本 SQLite 事实来源（P0-4 / I18）
  'lib/features/account/data/user_service_impl.dart', // 用户信息
  'lib/features/learning/data/review_schedule_repository.dart', // FSRS 持久化/迁移（N4）
  'lib/features/learning/presentation/learning_session_state.dart', // 今日已学写入
  'lib/core/application/today_progress_store.dart', // 目标/已学单源
  'lib/features/account/application/message_store.dart', // 消息本地仓
];

/// 一个「没有上报的 catch 块」。
class UnreportedCatch {
  UnreportedCatch(this.rawOffset, this.snippet);

  /// 在**原始**源码里的字符偏移（用于换算行号）。
  final int rawOffset;

  /// 块体前若干字符，便于人读。
  final String snippet;
}

/// 豁免标记：某个 catch 块确实不需要上报时，在块内或块前写上
/// `// 吞错豁免: <理由>`。理由必填（空的会被当成没写）。
const String kExemptionMarker = '吞错豁免:';

/// 剥注释的结果：`code` 是去掉注释的源码，`rawIndex` 把 code 的每个下标映射回
/// 原始源码下标（用于在原文里找豁免标记这类**注释内容**）。
class StrippedSource {
  StrippedSource(this.code, this.rawIndex);

  final String code;
  final List<int> rawIndex;

  /// code 下标 → 原始下标（越界则回落到末尾）。
  int rawOf(int codeOffset) =>
      codeOffset >= rawIndex.length ? (rawIndex.isEmpty ? 0 : rawIndex.last) : rawIndex[codeOffset];
}

/// 去掉注释，但**保留字符串字面量** —— 否则 `'https://…'` 会被当成行注释截断，
/// 导致后面的真实代码被误删、漏报违规。
StrippedSource stripComments(String src) {
  final out = StringBuffer();
  final map = <int>[];
  var i = 0;

  void emit(String s) {
    for (var k = 0; k < s.length; k++) {
      out.write(s[k]);
      map.add(i + k);
    }
  }

  while (i < src.length) {
    final c = src[i];

    // 行注释
    if (c == '/' && i + 1 < src.length && src[i + 1] == '/') {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
      continue;
    }

    // 块注释
    if (c == '/' && i + 1 < src.length && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i = i + 2 > src.length ? src.length : i + 2;
      continue;
    }

    // 字符串（含三引号与 r'' 原始串）
    if (c == "'" || c == '"') {
      final triple = i + 2 < src.length && src[i + 1] == c && src[i + 2] == c;
      final quote = triple ? c * 3 : c;
      final raw = i > 0 && src[i - 1] == 'r';
      emit(quote);
      i += quote.length;
      while (i < src.length) {
        if (!raw && !triple && src[i] == r'\' && i + 1 < src.length) {
          emit(src.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (src.startsWith(quote, i)) {
          emit(quote);
          i += quote.length;
          break;
        }
        emit(src[i]);
        i++;
      }
      continue;
    }

    emit(c);
    i++;
  }
  return StrippedSource(out.toString(), map);
}

/// 找出 [src] 里所有「块体内既没有 reportSwallowedError、也没有 rethrow」的 catch。
///
/// [src] 应为**原始**源码（内部会自己剥注释），因为豁免标记是注释。
List<UnreportedCatch> findUnreportedCatches(String src) {
  final stripped = stripComments(src);
  final code = stripped.code;
  final result = <UnreportedCatch>[];
  final catchRe = RegExp(r'\bcatch\b');

  for (final m in catchRe.allMatches(code)) {
    var i = _skipWs(code, m.end);

    // 跳过可选的 `(e, s)` 参数列表
    if (i < code.length && code[i] == '(') {
      var depth = 0;
      while (i < code.length) {
        if (code[i] == '(') depth++;
        if (code[i] == ')') {
          depth--;
          if (depth == 0) {
            i++;
            break;
          }
        }
        i++;
      }
    }
    i = _skipWs(code, i);

    // 表达式体 `catch (e) => ...`：取到行尾
    if (i < code.length && code.startsWith('=>', i)) {
      final end = code.indexOf('\n', i);
      final stop = end < 0 ? code.length : end;
      final body = code.substring(i, stop);
      if (!_reports(body) && !_exempt(src, stripped, m.start, stop)) {
        result.add(UnreportedCatch(stripped.rawOf(m.start), body.trim()));
      }
      continue;
    }

    if (i >= code.length || code[i] != '{') continue;

    // 花括号配对取块体
    var depth = 0;
    final start = i;
    while (i < code.length) {
      if (code[i] == '{') depth++;
      if (code[i] == '}') {
        depth--;
        if (depth == 0) {
          i++;
          break;
        }
      }
      i++;
    }
    final body = code.substring(start, i);
    if (_reports(body)) continue;
    if (_exempt(src, stripped, m.start, i)) continue;
    result.add(UnreportedCatch(stripped.rawOf(m.start), body.length > 120 ? '${body.substring(0, 120)}…' : body));
  }
  return result;
}

int _skipWs(String s, int i) {
  while (i < s.length && (s[i] == ' ' || s[i] == '\n' || s[i] == '\r' || s[i] == '\t')) {
    i++;
  }
  return i;
}

bool _reports(String body) =>
    body.contains('reportSwallowedError') || body.contains('rethrow') || body.contains('throwWithStackTrace');

/// 块内、或 catch 所在行的**上一行**，是否有带非空理由的豁免标记。
bool _exempt(String rawSrc, StrippedSource stripped, int codeCatchStart, int codeBlockEnd) {
  final rawStart = stripped.rawOf(codeCatchStart);
  final rawEnd = stripped.rawOf(codeBlockEnd);
  // 往前多取一行，覆盖「标记写在 catch 上一行」的写法
  final prevNl = rawSrc.lastIndexOf('\n', rawStart > 0 ? rawStart - 1 : 0);
  final from = prevNl < 0 ? 0 : prevNl + 1;
  final to = rawEnd > rawSrc.length ? rawSrc.length : rawEnd;
  if (from >= to) return false;

  final window = rawSrc.substring(from, to);
  final idx = window.indexOf(kExemptionMarker);
  if (idx < 0) return false;
  final lineEnd = window.indexOf('\n', idx);
  final reason = window.substring(idx + kExemptionMarker.length, lineEnd < 0 ? window.length : lineEnd).trim();
  return reason.isNotEmpty;
}
