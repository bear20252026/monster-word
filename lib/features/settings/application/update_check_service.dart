// 由 Claude 团队生成 | Monster Word App

// 检查更新端口：真实对比 GitHub Releases 最新 tag 与当前版本。
// 结果值对象见 domain/version_compare.dart。
import 'package:word_app/features/settings/domain/version_compare.dart';

/// 仓库主页（评价应用 / 打开仓库共用）。
/// presentation 只允许 import application，不得 import data 层常量。
const String appGitHubRepoUrl = 'https://github.com/bear20252026/monster-word';

abstract class UpdateCheckService {
  Future<UpdateCheckResult> check({required String currentVersion});
}
