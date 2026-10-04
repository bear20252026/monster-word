// 怪兽身份（名字 / 生日 / 破壳标记）的 SharedPreferences 单一读写出口（蓝图 W4「开局命名仪式」）。
//
// 放 core/utils 的原因：写入方在 account（命名仪式页），展示方在 settings（小屋门牌），
// 而跨 feature 只允许引用对方 application 端口（import_guard R4）——同族怪兽原语
// （monster_speech / monster_mood / milestone_guard）也都收在 core/utils。
// 世界观红线：名字与生日只进展示，绝不参与任何数值计算。
import 'package:shared_preferences/shared_preferences.dart';

/// 怪兽身份 SP 键与读写。
class MonsterIdentityPrefs {
  MonsterIdentityPrefs._();

  static const String nameKey = 'monster_name';
  static const String birthdayKey = 'monster_birthday';
  static const String hatchedKey = 'monster_hatched';

  /// 未命名时的默认名。
  static const String defaultName = '咕噜';

  /// 怪兽名（未命名返回 [defaultName]）。
  static Future<String> name() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(nameKey) ?? defaultName;
  }

  /// 三段顺序写（非原子）：半写态由下次启动重演仪式覆盖，`hatched` 未置位即视为未命名。
  /// 返回**实际落库的名字**（空输入归一为 [defaultName]），供调用方直接开口自报家门，
  /// 避免各处重算一遍默认名口径。
  static Future<String> save({required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final trimmed = name.trim();
    final stored = trimmed.isEmpty ? defaultName : trimmed;
    await prefs.setString(nameKey, stored);
    await prefs.setString(
      birthdayKey,
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
    await prefs.setInt(hatchedKey, 1);
    return stored;
  }

  static Future<bool> get hatched async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(hatchedKey) == 1;
  }
}
