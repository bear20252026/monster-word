// SfxSettings：音效静音模式持久化（SP 单键，进程内同步缓存）。
//
// 供设置页切换与 Sfx 门面读取；默认全开。
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/sfx.dart';

class SfxSettings {
  SfxSettings._();

  static const String _key = 'sfx_mode';

  /// 当前模式（启动时调用 [load] 初始化；切换走 [setMode]）。
  static SfxMode current = SfxMode.all;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    current = SfxMode.values.firstWhere((m) => m.name == raw, orElse: () => SfxMode.all);
    SfxPlayer.mode = current;
  }

  static Future<void> setMode(SfxMode mode) async {
    current = mode;
    SfxPlayer.mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// 循环切换：全开 → 仅视觉 → 全静音 → 全开。
  static Future<SfxMode> cycle() async {
    final next = switch (current) {
      SfxMode.all => SfxMode.visualOnly,
      SfxMode.visualOnly => SfxMode.silent,
      SfxMode.silent => SfxMode.all,
    };
    await setMode(next);
    return next;
  }
}
