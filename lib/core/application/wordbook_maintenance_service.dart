// 由 Claude 团队生成 | Monster Word App

// 词库维护服务（REG-ARCH-005 收口）。
// 此前 book_words_page / more_settings_page 直接 `WordBookDatabase.instance`
// 调用 forceRebuild/diagnostics，违反 architecture_boundaries.md §2 且
// ImportGuard 只拦反向、拦不住此类正向直连。本服务是 presentation 消费
// 词库管理操作的唯一入口；页面经 Provider 注入（*_feature_providers.dart）。

import 'package:word_app/core/infrastructure/wordbook_database.dart';

// 页面所需的诊断/重建结果类型经此处转发，页面不得直接 import 数据库实现。
export 'package:word_app/core/infrastructure/wordbook_database.dart' show DbDiagnostics, DbRebuildResult;

/// 词库维护服务：诊断信息 + 一键全量重建（离线）。
class WordBookMaintenanceService {
  const WordBookMaintenanceService();

  /// 读取本地库诊断信息（books/words/links 计数、文件大小、更新时间）。
  Future<DbDiagnostics> diagnostics() => WordBookDatabase.instance.diagnostics();

  /// 一键全量重建本地词库（不联网，重新解压内置资产）。
  Future<DbRebuildResult> forceRebuild() => WordBookDatabase.instance.forceRebuild();
}
