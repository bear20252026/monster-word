// 学习伴侣 AI 化 · 小怪兽长期记忆端口（core/application，中性接口，守 R-core）。
//
// 分层记忆（借鉴 N.E.K.O 的记忆体系，落地为本地 SQLite）：
// - fact 事实层：从学习数据自动沉淀的稳定事实（如「累计签到 N 天」「常错词」）。
// - recent 近期层：最近对话/事件提取的短期记忆（按时间淘汰）。
// - persona 人格层：性格与相处模式（读性格设置，沉淀独特互动）。
//
// 端口只暴露中性读写，不感知业务；presentation 经此消费（R-DB），实现见
// core/infrastructure/companion_memory_dao。读失败返回空（对话降级无记忆不阻断）。

/// 记忆分层。
enum MemoryKind { fact, recent, persona }

/// 一条记忆。
class MemoryEntry {
  const MemoryEntry({required this.kind, required this.key, required this.content, required this.updatedAt});

  final MemoryKind kind;
  final String key;
  final String content;
  final int updatedAt;
}

/// 小怪兽长期记忆端口。
abstract interface class MonsterMemoryPort {
  /// 写入/覆盖一条记忆（同层同键 upsert，幂等）。失败仅上报不抛。
  Future<void> put(MemoryKind kind, String key, String content);

  /// 读取某层全部记忆（按更新时间倒序）。读失败返回空列表。
  Future<List<MemoryEntry>> read(MemoryKind kind);

  /// 读取某层指定键的记忆；不存在返回 null。
  Future<MemoryEntry?> get(MemoryKind kind, String key);

  /// 删除某层指定键的记忆。失败仅上报不抛。
  Future<void> remove(MemoryKind kind, String key);

  /// 近期层容量控制：只保留最新 [limit] 条，淘汰更旧的。失败仅上报不抛。
  Future<void> trimRecent(int limit);
}
