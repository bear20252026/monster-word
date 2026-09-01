// 由 Claude 团队生成 | Monster Word App

// 检查更新端口：真实对比 GitHub Releases 最新 tag 与当前版本。
// 结果值对象见 domain/version_compare.dart。
import 'package:word_app/features/settings/domain/version_compare.dart';

abstract class UpdateCheckService {
  Future<UpdateCheckResult> check({required String currentVersion});
}
