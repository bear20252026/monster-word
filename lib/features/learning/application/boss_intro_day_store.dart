// Boss 战「当日首次入场」标记的应用层门面。
//
// 为什么不直接在页面里读写 SharedPreferences：架构守卫 R-prefs 禁止 presentation
// 直触 core/infrastructure/app_preferences.dart（见 lib/core/import_guard.dart 与
// test/architecture/import_guard_test.dart）。这里与 TodayProgressStore 同一收口
// 思路：application 持有键名与读写，页面只拿一个纯值（今天是否已播过）。
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

/// 只做两件事：读当日标记、写当日标记。
class BossIntroDayStore {
  const BossIntroDayStore();

  /// 已记录的日期（`yyyy-MM-dd`）；key 缺失或未初始化时为空串。
  String readDay() => AppPreferences().getBossIntroDay();

  /// 写当日标记。失败不阻断复习（C 级降级：明天重开再演一次也无害），但要上报。
  Future<void> markDay(String day) async {
    try {
      await AppPreferences().setBossIntroDay(day);
    } catch (e, s) {
      reportSwallowedError('头目首次入场标记写入失败', e, s);
    }
  }
}
