// 由 Claude 团队生成 | Monster Word App

// 网络诊断端口：逐步返回真实检测结果，由 presentation 层消费。
import 'package:word_app/features/settings/domain/diagnosis_result.dart';

abstract class NetworkDiagnosisService {
  /// 依次执行各诊断步骤。
  ///
  /// [onStep] 在每个步骤完成后立即回调（页面可渐进显示），
  /// 全部完成后完整列表由返回值给出。
  Future<List<DiagnosisResult>> runDiagnosis({void Function(DiagnosisResult step)? onStep});
}
