// 第四轮审计 M3（2026-11-17）：用户数据 SP 备份注册表。
//
// 为什么需要注册表：备份服务此前硬编码只快照两个 db 文件，SP 独有数据
// （保护卡/兑换章/奖励队列/降级日志/签到日历快照/怪兽羁绊…）完全不在备份内，
// 恢复后 SP 与 DB 不同步；且今后任何新增 SP 存储都会**静默漏备**。
//
// 口径：
// - **全量快照 + 显式排除**：SP 键空间整体入快照（新增键自动被覆盖，无需
//   记得来登记），只排除凭证类键（token/secret/用户信息 Bean——它们的事实
//   来源是 flutter_secure_storage，明文副本绝不落备份文件）。
// - 键值按 SP 原生类型保真（bool/int/double/String/List<String>），
//   JSON 序列化带类型标签，恢复时按原类型写回。
// - 本文件是「排除面 + 类型保真」的单一事实来源；备份/恢复服务消费它。
//   新增**凭证类**存储时必须把键加进 [excludedKeys]（守卫测试锁定清单）。
import 'package:shared_preferences/shared_preferences.dart';

/// SP 快照中单个键的类型保真条目。
class SpSnapshotEntry {
  const SpSnapshotEntry({required this.type, required this.value});

  /// 'bool' | 'int' | 'double' | 'String' | `List<String>`
  final String type;
  final Object value;

  Map<String, Object?> toJson() => {'type': type, 'value': value};

  static SpSnapshotEntry? fromJson(Map<String, Object?> json) {
    final type = json['type'];
    final value = json['value'];
    if (type is! String || value == null) return null;
    switch (type) {
      case 'bool':
        return value is bool ? SpSnapshotEntry(type: type, value: value) : null;
      case 'int':
        return value is int ? SpSnapshotEntry(type: type, value: value) : null;
      case 'double':
        return value is double ? SpSnapshotEntry(type: type, value: value) : null;
      case 'String':
        return value is String ? SpSnapshotEntry(type: type, value: value) : null;
      case 'List<String>':
        if (value is List && value.every((e) => e is String)) {
          return SpSnapshotEntry(type: type, value: value.cast<String>());
        }
        return null;
      default:
        return null; // 未知类型：整条丢弃（宁丢一条新键，不写坏 SP）
    }
  }
}

class UserDataSpRegistry {
  UserDataSpRegistry._();

  /// 凭证类键：事实来源是 secure_storage，SP 里只可能有历史明文残留。
  /// 备份**绝不**携带它们（备份文件是明文 JSON，落盘即泄露面）。
  /// 与 app_preferences.dart 的 key 单源对齐（I62）；新增凭证存储必须登记。
  static const Set<String> excludedKeys = {
    'user_token', // AppPreferences.userToken
    'user_secret', // AppPreferences.userSecret
    'monster_word_user_info', // kUserInfoPrefsKey（含历史 token/secret 字段）
  };

  /// 采集当前 SP 全量快照（排除凭证键），键→类型保真条目。
  static Future<Map<String, SpSnapshotEntry>> capture() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, SpSnapshotEntry>{};
    for (final key in prefs.getKeys()) {
      if (excludedKeys.contains(key)) continue;
      final value = prefs.get(key);
      if (value == null) continue;
      final entry = _entryOf(value);
      if (entry != null) result[key] = entry;
    }
    return result;
  }

  static SpSnapshotEntry? _entryOf(Object value) {
    if (value is bool) return SpSnapshotEntry(type: 'bool', value: value);
    if (value is int) return SpSnapshotEntry(type: 'int', value: value);
    if (value is double) return SpSnapshotEntry(type: 'double', value: value);
    if (value is String) return SpSnapshotEntry(type: 'String', value: value);
    if (value is List<String>) return SpSnapshotEntry(type: 'List<String>', value: value);
    return null; // SP 理论上只有这五类；未知类型跳过并留给上报侧观测
  }

  /// 把快照写回 SP（恢复路径）。
  ///
  /// 口径：**先清后写**——恢复的语义是「回到备份时刻」，备份后新增的键
  /// 必须消失（否则恢复后 SP 与 DB 不同步，正是 M3 要修的缺陷）。
  /// 凭证键不在快照内，清理后由 secure_storage 事实源在下次登录链路自愈
  /// （SecureTokenStorage 读安全存储→回退 SP→迁移，SP 空不影响安全存储值）。
  /// 任何单键写失败返回 false（调用方按恢复失败处理，绝不半恢复静默）。
  static Future<bool> restore(Map<String, SpSnapshotEntry> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    // 保留凭证键现值：它们不属于备份面，清掉会误伤本机登录态。
    final preserved = <String, Object>{};
    for (final key in excludedKeys) {
      final value = prefs.get(key);
      if (value != null) preserved[key] = value;
    }
    if (!await prefs.clear()) return false;
    for (final e in preserved.entries) {
      if (!await _write(prefs, e.key, e.value)) return false;
    }
    for (final e in snapshot.entries) {
      if (excludedKeys.contains(e.key)) continue; // 双保险：旧备份混入凭证键也拒写
      if (!await _writeEntry(prefs, e.key, e.value)) return false;
    }
    // SP 写是异步落盘：flush 语义由插件保证（setX 返回 true 即已提交平台）。
    return true;
  }

  static Future<bool> _writeEntry(SharedPreferences prefs, String key, SpSnapshotEntry entry) {
    return _write(prefs, key, entry.value);
  }

  static Future<bool> _write(SharedPreferences prefs, String key, Object value) {
    if (value is bool) return prefs.setBool(key, value);
    if (value is int) return prefs.setInt(key, value);
    if (value is double) return prefs.setDouble(key, value);
    if (value is String) return prefs.setString(key, value);
    if (value is List<String>) return prefs.setStringList(key, value);
    return Future.value(false);
  }
}
