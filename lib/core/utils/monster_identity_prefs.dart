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

  // ── 测试注入缝（REG-START-002 / REG-HATCH-001 守护用）：SP 抛错场景
  // 无法经 setMockInitialValues 造出，注入抛错闭包模拟磁盘故障。──
  /// 破壳标记读取替身（非 null 时 [hatched] 直走替身）。
  static Future<bool> Function()? hatchedOverride;

  /// 命名保存替身（非 null 时 [save] 直走替身，可注入抛错）。
  static Future<String> Function({required String name})? saveOverride;

  /// 清除全部注入（测试 tearDown 调用；生产禁止调用）。
  static void resetForTest() {
    hatchedOverride = null;
    saveOverride = null;
  }

  /// 怪兽名（未命名返回 [defaultName]）。
  static Future<String> name() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(nameKey) ?? defaultName;
  }

  /// 三段顺序写（非原子）：半写态由下次启动重演仪式覆盖，`hatched` 未置位即视为未命名。
  /// 返回**实际落库的名字**（空输入归一为 [defaultName]），供调用方直接开口自报家门，
  /// 避免各处重算一遍默认名口径。
  static Future<String> save({required String name}) async {
    final override = saveOverride;
    if (override != null) return override(name: name);
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final trimmed = name.trim();
    final stored = trimmed.isEmpty ? defaultName : trimmed;
    final birthday = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // hatched 置位前先确认名字真的落了盘：写返回 false（磁盘满等）不抛错，
    // 若照样置位，调用方会跳过重演仪式——命名静默丢失。三写全查，任一失败即抛。
    if (!await prefs.setString(nameKey, stored)) {
      throw StateError('monster_name setString returned false');
    }
    if (!await prefs.setString(birthdayKey, birthday)) {
      throw StateError('monster_birthday setString returned false');
    }
    if (!await prefs.setInt(hatchedKey, 1)) {
      throw StateError('monster_hatched setInt returned false');
    }
    return stored;
  }

  /// 生日（命名仪式落库的破壳日；未落库返回 null）。
  /// 生日彩蛋消费方：小屋进届时检查「今天是它的生日吗」。
  static Future<DateTime?> birthday() async {
    final raw = (await SharedPreferences.getInstance()).getString(birthdayKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<bool> get hatched async {
    final override = hatchedOverride;
    if (override != null) return override();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(hatchedKey) == 1;
  }
}
