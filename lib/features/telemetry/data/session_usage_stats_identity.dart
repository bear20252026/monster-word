// 从账号会话里取当前用户标识，供上报信封使用。
//
// 放在 telemetry 的 data 层并 import account 的 **application** 层端口
// （`AuthSessionStore`）—— 这是架构守卫 R4 允许的跨 feature 通道
// （只允许 import 对方的 application 层抽象）。不碰 account 的 data/presentation。
//
// 只取 UUID，不取用户名：用户名的权威来源是账号服务，客户端再存一份必然漂移。
// 管理页要显示名字时由统计服务向账号服务解析。

import 'package:word_app/features/account/application/auth_session_store.dart';
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';

class SessionUsageStatsIdentity implements UsageStatsIdentity {
  SessionUsageStatsIdentity(this.sessions);

  final AuthSessionStore sessions;

  @override
  Future<String?> userId() async {
    try {
      final session = await sessions.read();
      final id = session?.userId;
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (_) {
      // 会话读取失败（安全存储不可用、内容损坏）不该让整条上报失败：
      // 退回「未绑定账号」，数据仍然上去，只是关联不到人。
      return null;
    }
  }
}
