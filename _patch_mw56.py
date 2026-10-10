# -*- coding: utf-8 -*-
"""MW-56 — feedback durable success semantics — CRLF-safe."""
import io

CRLF = chr(13) + chr(10)


def patch(path, pairs, label):
    with io.open(path, 'r', encoding='utf-8', newline='') as f:
        raw = f.read()
    src = raw.replace(CRLF, chr(10))
    for name, old, new in pairs:
        assert old in src, '%s: %s not found' % (label, name)
        src = src.replace(old, new, 1)
    with io.open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(src.replace(chr(10), CRLF) if CRLF in raw else src)
    print('OK:', label)


# 1) FeedbackArchive.submit：返回持久化/上传双布尔结果 + SP 写返回值校验
patch(
    r'lib\features\account\application\feedback_archive.dart',
    [
        ('result class',
         """  /// 单写者闸：读改写无闸时并发提交互相覆盖丢条目。
  Future<void> _gate = Future<void>.value();""",
         """  /// 单写者闸：读改写无闸时并发提交互相覆盖丢条目。
  Future<void> _gate = Future<void>.value();"""),
        ('submit return type',
         """  Future<List<FeedbackEntry>> submit({required String content, String? contact}) async {
    final entry = FeedbackEntry(content: content.trim(), contact: contact?.trim(), submittedAt: DateTime.now());
    final run = _gate.then((_) => _doSubmit(entry));
    _gate = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }""",
         """  /// 提交结果（MW-56 durable 语义）：至少一个通道成功才算提交成功。
  class FeedbackSubmitResult {
    const FeedbackSubmitResult({required this.localPersisted, required this.remoteUploaded, required this.history});
    final bool localPersisted;
    final bool remoteUploaded;
    final List<FeedbackEntry> history;
    bool get durable => localPersisted || remoteUploaded;
  }

  Future<FeedbackSubmitResult> submit({required String content, String? contact}) async {
    final entry = FeedbackEntry(content: content.trim(), contact: contact?.trim(), submittedAt: DateTime.now());
    final run = _gate.then((_) => _doSubmit(entry));
    _gate = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }"""),
        ('doSubmit semantics',
         """  Future<List<FeedbackEntry>> _doSubmit(FeedbackEntry entry) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final decoded = _decode(prefs.getString(_storageKey));
    final history = (decoded ?? <FeedbackEntry>[])..add(entry);
    if (decoded != null) {
      // MEM：本地反馈存档封顶，避免 SP 与内存无界增长。
      const maxEntries = 50;
      final trimmed = history.length > maxEntries ? history.sublist(history.length - maxEntries) : history;
      await prefs.setString(_storageKey, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
    }
    // decoded == null（存档损坏）：不覆写原档，本条仍上报 Sentry 兜底

    try {
      await upload(entry);
    } catch (e, s) {
      // 上报失败不阻断提交：内容已在本地存档，下次诊断/反馈可复查。
      // 但上报通道自身故障必须可观测（否则「永远上报成功」是假象）。
      reportSwallowedError('反馈 Sentry 上报失败（本地存档仍完整）', e, s);
    }
    return history;
  }""",
         """  Future<FeedbackSubmitResult> _doSubmit(FeedbackEntry entry) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final decoded = _decode(prefs.getString(_storageKey));
    final history = (decoded ?? <FeedbackEntry>[])..add(entry);
    var localPersisted = false;
    if (decoded != null) {
      // MEM：本地反馈存档封顶，避免 SP 与内存无界增长。
      const maxEntries = 50;
      final trimmed = history.length > maxEntries ? history.sublist(history.length - maxEntries) : history;
      // MW-56：setString 返回值必须校验——false 不是成功，本地通道未落盘。
      localPersisted = await prefs.setString(_storageKey, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
      if (!localPersisted) {
        reportSwallowedError('反馈本地存档写入返回 false', StateError('feedback SP setString false'), StackTrace.current);
      }
    }
    // decoded == null（存档损坏）：不覆写原档，本条只能依赖远端通道。

    var remoteUploaded = false;
    try {
      await upload(entry);
      remoteUploaded = true;
    } catch (e, s) {
      // 上报失败不阻断提交：内容可能已在本地存档，下次诊断/反馈可复查。
      // 但上报通道自身故障必须可观测（否则「永远上报成功」是假象）。
      reportSwallowedError('反馈 Sentry 上报失败（本地存档仍完整）', e, s);
    }
    return FeedbackSubmitResult(localPersisted: localPersisted, remoteUploaded: remoteUploaded, history: history);
  }"""),
    ],
    'feedback_archive (MW-56)',
)

# 2) FeedbackPage：两个通道都失败必须如实提示
patch(
    r'lib\features\account\presentation\feedback_page.dart',
    [
        ('submit semantics',
         """    setState(() => _isSubmitting = true);
    // 本地存档兜底 + Sentry 上报（失败不阻断提交语义）。
    try {
      final archive = widget.archiveOverride ?? FeedbackArchive();
      await archive.submit(content: _controller.text, contact: _contactController.text);
    } catch (_) {
      // FeedbackArchive.submit 自身已兜底，此层防御意外的同步异常。
    }
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submitted = true;
    });
  }""",
         """    setState(() => _isSubmitting = true);
    // MW-56：本地存档 OR 远端上传至少一个 durable 成功才算提交成功；
    // 双通道全失败必须如实告知「内容尚未保存」，不得显示感谢页。
    var durable = false;
    try {
      final archive = widget.archiveOverride ?? FeedbackArchive();
      final result = await archive.submit(content: _controller.text, contact: _contactController.text);
      durable = result.durable;
    } catch (_) {
      // FeedbackArchive.submit 自身已兜底，此层防御意外的同步异常。
      durable = false;
    }
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _submitted = durable;
      if (!durable) {
        _submitFailed = true;
      }
    });
  }"""),
    ],
    'feedback_page (MW-56)',
)

print('DONE MW-56')
