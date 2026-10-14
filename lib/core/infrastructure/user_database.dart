// 由 Claude 团队生成 | 用户数据数据库
// 管理用户收藏、学习记录等数据
// 与 wordbook_database.dart（只读词库）分离

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';

/// 用户数据库管理器（单例）
///
/// 管理用户收藏、学习记录等可写数据
/// 与只读词库 wordbook_database 分离
class UserDatabase {
  static final UserDatabase instance = UserDatabase._();
  UserDatabase._();

  /// 应用当前支持的 schema 版本（与 [_onUpgrade] 步进保持同步）。
  static const int _schemaVersion = 7;

  Database? _db;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  /// MW-04：库版本新于应用（应用回滚安装旧版）时以只读方式打开。
  /// 此状态下所有写入会抛异常并经各 DAO 守卫上报，绝不允许旧版代码写坏新版 schema。
  bool _readOnlyDowngrade = false;
  bool get readOnlyDowngrade => _readOnlyDowngrade;

  Database get db {
    if (_db == null) {
      throw StateError('用户数据库尚未初始化，请先调用 initialize()');
    }
    return _db!;
  }

  /// 初始化用户数据库
  Future<void> initialize() {
    if (_initialized) return Future.value();
    final inflight = _initCompleter;
    if (inflight != null) return inflight.future;
    final completer = Completer<void>();
    _initCompleter = completer;
    completer.future.ignore();
    _initializeInner().then(
      (_) => completer.complete(),
      onError: (Object e, StackTrace st) {
        if (identical(_initCompleter, completer)) _initCompleter = null;
        completer.completeError(e, st);
      },
    );
    return completer.future;
  }

  Future<void> _initializeInner() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'user_data.db');

    try {
      _db = await _openWithGuard(dbPath);
    } catch (e, s) {
      // 2026-10-04 审计 P1：打开失败不必然是损坏——Windows 上杀毒/备份软件
      // 的瞬时文件锁、磁盘瞬时 IO 错同样会让 openDatabase 抛错；而 new_words
      // （生词本）没有任何 SP 快照可回迁，误判损坏直接删库 = 永久清空。
      // 先关句柄重试一次，仍失败才进入「恢复分类」。
      reportSwallowedError('用户数据库打开失败，关闭句柄后重试一次', e, s);
      await _safeClose();
      try {
        _db = await _openWithGuard(dbPath);
      } catch (e2, s2) {
        // MW-01（第二阶段审计 P0）：「连续打开失败」不再直接等同「数据库损坏」。
        // 进入恢复分类：只有 PRAGMA quick_check 确证损坏才走备份重建；
        // 文件锁/权限/磁盘满等可重试故障保留原库并把异常上抛给启动兜底页。
        reportSwallowedError('用户数据库重试仍失败，进入恢复分类', e2, s2);
        _db = await _recoverOrRethrow(dbPath, e2, s2);
      }
    }
    _initialized = true;
  }

  /// MW-04：打开前检查库文件 user_version。
  ///
  /// sqflite 的版本管理在 openDatabase 内部执行 onDowngrade——到那一步时连接
  /// 已以可写方式建立。因此在打开前先以只读裸连接读取 user_version：库版本比
  /// 应用支持的新（应用回滚）→ 只读打开保护数据，不触发降级写路径，更不落入
  /// 「损坏重建」。
  Future<Database> _openWithGuard(String dbPath) async {
    final file = File(dbPath);
    if (file.existsSync() && file.lengthSync() > 0) {
      final onDisk = await _peekUserVersion(dbPath);
      if (onDisk != null && onDisk > _schemaVersion) {
        reportSwallowedError(
          '用户数据库 schema($onDisk) 新于应用支持版本($_schemaVersion)——按应用回滚处理，只读保护打开',
          StateError('database downgrade blocked'),
          StackTrace.current,
        );
        _readOnlyDowngrade = true;
        return openDatabase(dbPath, readOnly: true);
      }
    }
    _readOnlyDowngrade = false;
    return _open(dbPath);
  }

  /// 只读裸连接读取 user_version；任何失败返回 null（交给正常打开路径抛错）。
  Future<int?> _peekUserVersion(String dbPath) async {
    Database? ro;
    try {
      ro = await openDatabase(dbPath, readOnly: true);
      final rows = await ro.rawQuery('PRAGMA user_version');
      if (rows.isEmpty) return null;
      return (rows.first['user_version'] as num?)?.toInt();
    } catch (_) {
      return null;
    } finally {
      try {
        await ro?.close();
      } catch (_) {}
    }
  }

  Future<Database> _open(String dbPath) {
    return openDatabase(
      dbPath,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // 审计 I37：sqflite 默认静默降版本号且不回滚 schema。这里不抛错
      //（抛错会落入恢复分类路径），仅让降版本事件可观测。
      onDowngrade: (db, oldVersion, newVersion) async {
        reportSwallowedError(
          '用户数据库版本回退（old=$oldVersion new=$newVersion），schema 未回滚',
          StateError('database downgrade observed'),
          StackTrace.current,
        );
      },
    );
  }

  /// 恢复分类（MW-01/P0-02 恢复状态机）：
  ///
  /// 打开失败 ≠ 数据库损坏。只有「能只读打开 + quick_check 明确失败」才认定
  /// 损坏并进入备份重建；其余一切情况（文件锁/权限/磁盘满/瞬态 IO/无法分类）
  /// 一律保留原库并把原始错误上抛给启动兜底页（可重试）。
  Future<Database> _recoverOrRethrow(String dbPath, Object openError, StackTrace openStack) async {
    await _safeClose();
    final verdict = await _classifyCorruption(dbPath);
    switch (verdict) {
      case _DbHealth.healthy:
        // 内容完好却打不开 = 可重试故障（锁/权限/磁盘满）。绝不删库。
        reportSwallowedError('用户数据库内容完好（quick_check 通过）但打开失败，保留原库上抛', openError, openStack);
        Error.throwWithStackTrace(openError, openStack);
      case _DbHealth.unreadable:
        // 连只读分类都做不了：无法确证损坏，同样保留原库。
        reportSwallowedError('用户数据库无法分类（只读打开也失败），保留原库上抛', openError, openStack);
        Error.throwWithStackTrace(openError, openStack);
      case _DbHealth.corrupt:
        reportSwallowedError('用户数据库 quick_check 确证损坏，进入备份重建', openError, openStack);
        return _backupAndRebuild(dbPath);
    }
  }

  Future<_DbHealth> _classifyCorruption(String dbPath) async {
    Database? ro;
    try {
      ro = await openDatabase(dbPath, readOnly: true);
      final rows = await ro.rawQuery('PRAGMA quick_check');
      final result = rows.isEmpty ? null : (rows.first.values.first as String?);
      return result == 'ok' ? _DbHealth.healthy : _DbHealth.corrupt;
    } catch (_) {
      return _DbHealth.unreadable;
    } finally {
      try {
        await ro?.close();
      } catch (_) {}
    }
  }

  /// 确证损坏后的备份重建：
  ///
  /// 1. 备份文件名带毫秒时间戳——永不覆盖历史备份（原实现会先删旧 .bak）。
  /// 2. 改名失败（文件占用等）→ 复制到备份并校验字节数，**校验通过才**移除
  ///    原文件；复制也失败 → 原库原样保留，不再继续重建。
  /// 3. 边车（journal/wal/shm）只在主库成功留档后随行处理。
  /// 4. 重建失败时原库必然存在于备份处，唯一副本永不消失。
  Future<Database> _backupAndRebuild(String dbPath) async {
    await _safeClose();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final backupMain = '$dbPath.corrupt.$stamp.bak';
    final file = File(dbPath);
    var preserved = true;

    if (file.existsSync()) {
      try {
        file.renameSync(backupMain);
      } catch (e, s) {
        reportSwallowedError('损坏库改名备份失败，尝试复制+校验后备', e, s);
        try {
          file.copySync(backupMain);
          if (File(backupMain).lengthSync() != file.lengthSync()) {
            throw StateError('备份副本字节数与原库不一致');
          }
          // 已有校验通过的副本，才允许移除原文件（等价改名，但不丢数据）。
          file.deleteSync();
        } catch (e2, s2) {
          preserved = false;
          reportSwallowedError('损坏库备份失败——原库保持原样，放弃重建以防数据丢失', e2, s2);
        }
      }
    }
    if (!preserved) {
      Error.throwWithStackTrace(StateError('用户数据库无法安全备份，已保留原库待重试或人工恢复'), StackTrace.current);
    }

    // 审计 P3-2：边车与主库同源，主库已留档时把边车一并移出新库路径；
    // 改名失败才删除（孤立边车不含可独立恢复的数据，残留会让新库打开失败）。
    for (final suffix in const ['-journal', '-wal', '-shm']) {
      final sidecar = File('$dbPath$suffix');
      if (!sidecar.existsSync()) continue;
      try {
        sidecar.renameSync('$backupMain$suffix');
      } catch (e, s) {
        reportSwallowedError('用户数据库边车随备份改名失败，删除（$suffix）', e, s);
        try {
          sidecar.deleteSync();
        } catch (_) {
          // 删除失败不阻断：新库打开若再失败会走重试/兜底页
        }
      }
    }

    try {
      final db = await openDatabase(dbPath, version: _schemaVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
      reportSwallowedError(
        '用户数据库已按损坏流程重建（原库备份：${p.basename(backupMain)}，未删除任何历史备份）',
        StateError('user db rebuilt after confirmed corruption'),
        StackTrace.current,
      );
      return db;
    } catch (e, s) {
      // 重建失败：原库在时间戳备份处完好保留，绝不丢唯一副本。
      reportSwallowedError('用户数据库重建失败（原库备份保留在 ${p.basename(backupMain)}）', e, s);
      rethrow;
    }
  }

  Future<void> _safeClose() async {
    final db = _db;
    _db = null;
    try {
      await db?.close();
    } catch (_) {
      // 关闭坏库失败可忽略：句柄即将被丢弃
    }
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 收藏表
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(word_id)
      )
    ''');

    // 创建索引（idx_favorites_word_id 与 UNIQUE(word_id) 隐式索引重复，纯写放大，已删）
    await db.execute('CREATE INDEX idx_favorites_created_at ON favorites(created_at)');
    await _createNewWordsTable(db);
    await _createFavoriteTables(db);
    await _createScareCoinTables(db);
    await _createRewardTables(db);
    await _createWordNotesTable(db);
    await _createUsageStatsTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createNewWordsTable(db);
    }
    // MEM/U3+U6：收藏迁 SQLite（ FavoriteWordsDao / FavSentenceDao 的事实来源）
    if (oldVersion < 3) {
      await _createFavoriteTables(db);
    }
    // P0-4（I18）：尖叫币账本迁 SQLite（ScareCoinLedgerDao 的事实来源）
    if (oldVersion < 4) {
      await _createScareCoinTables(db);
    }
    // P1-03：奖励事件幂等表 + 签到日期（签到/答题奖励/保护卡与币同库同事务）
    if (oldVersion < 5) {
      await _createRewardTables(db);
    }
    // P1-07：笔记迁入本库（MW-41/42/43 一次解决：AUTOINCREMENT 由 DB 生成 ID、
    // 单条 INSERT 消灭整键读改写竞态、word 文本作稳定身份）。
    if (oldVersion < 6) {
      await _createWordNotesTable(db);
    }
    // 使用统计（使用时长与基本情况）。**只存聚合量，不存任何内容**：
    // 具体学了哪些词、搜索词、笔记正文一律不入此表。
    // 与账号库无关、也不与 user_id 绑定（设备级匿名统计）。
    if (oldVersion < 7) {
      await _createUsageStatsTables(db);
    }
  }

  /// 使用统计的本地累计表（R2-01 之后新增）。
  ///
  /// 两张表：
  ///   - `usage_stats_daily`：按天的聚合量。`uploaded_at` 为 NULL 表示尚未上报
  ///     （失败要能补传，所以不能删）。
  ///   - `usage_stats_meta`：上报调度用的键值（上次成功时间、退避到期时间）。
  ///     用 KV 而不是再加列：这两个是**单例状态**，不是按天的记录。
  ///
  /// `module_open_counts` 存 JSON 文本而不是拆列：模块集合会随功能演进变化，
  /// 拆列意味着每次加模块都要改 schema。读取端有白名单校验（见 domain 模型），
  /// 所以这里不必担心塞进任意键。
  Future<void> _createUsageStatsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usage_stats_daily (
        day TEXT PRIMARY KEY,
        foreground_ms INTEGER NOT NULL DEFAULT 0,
        session_count INTEGER NOT NULL DEFAULT 0,
        study_session_count INTEGER NOT NULL DEFAULT 0,
        words_reviewed INTEGER NOT NULL DEFAULT 0,
        words_correct INTEGER NOT NULL DEFAULT 0,
        new_words_learned INTEGER NOT NULL DEFAULT 0,
        book_word_count INTEGER NOT NULL DEFAULT 0,
        book_learned_count INTEGER NOT NULL DEFAULT 0,
        streak_days INTEGER NOT NULL DEFAULT 0,
        coins_earned INTEGER NOT NULL DEFAULT 0,
        module_open_counts TEXT NOT NULL DEFAULT '{}',
        uploaded_at INTEGER
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_usage_stats_pending ON usage_stats_daily(uploaded_at, day)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usage_stats_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// P1-07：笔记表。以 word 文本为稳定业务身份（与 favorite_words 同口径，
  /// word_id 在词库重建后不保证稳定，只作当前词库版本的加速引用，可空）。
  Future<void> _createWordNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL DEFAULT '',
        word_id INTEGER,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_word_notes_word ON word_notes(word)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_word_notes_word_id ON word_notes(word_id)');
  }

  /// P1-03：奖励域表。
  ///
  /// reward_events：业务幂等键（如 checkin:2026-10-10、answer:2026-10-10:18）。
  /// UNIQUE(event_key) 让 N 个并发签到/奖励只有一个能插入成功——
  /// 并发幂等从 UI 层 _busy/SP 读改写下沉为数据库约束。
  /// checkin_dates：签到日历迁入本库，与 +10 币同事务（MW-25 跨存储半成功收口）。
  Future<void> _createRewardTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reward_events (
        event_key TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checkin_dates (
        date TEXT PRIMARY KEY
      )
    ''');
  }

  /// P0-4（I18）：尖叫币账本表。
  ///
  /// entries 为追加式流水（写侧不再整表截断，展示仍取最新 200 条）；
  /// meta 为标量 KV（balance / migrated_from_sp），余额变动与流水追加
  /// 同事务提交，杜绝旧 SP 双写（余额 int + 全量 JSON）的中间态。
  Future<void> _createScareCoinTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scare_coin_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time_ms INTEGER NOT NULL,
        delta INTEGER NOT NULL,
        reason TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_scare_coin_entries_time ON scare_coin_entries(time_ms DESC, id DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scare_coin_meta (
        key TEXT PRIMARY KEY,
        value INTEGER NOT NULL
      )
    ''');
  }

  /// MEM/U3+U6：收藏持久化表。
  ///
  /// 单词收藏以【单词文本】为主键——与 mastered/mastered_words_v1 一致，
  /// 文本身份在词库重建/资产更新后仍稳定（自增 word_id 不保证跨版本稳定）。
  /// 例句收藏以 (word_id, sentence_id) 复合主键，data_json 原样保存
  /// FavSentenceData.toJson()，保证新增列外的历史字段无损往返。
  Future<void> _createFavoriteTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_words (
        word TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_favorite_words_created ON favorite_words(created_at)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_sentences (
        word_id INTEGER NOT NULL,
        sentence_id TEXT NOT NULL,
        word TEXT NOT NULL DEFAULT '',
        update_time TEXT NOT NULL,
        data_json TEXT NOT NULL,
        PRIMARY KEY(word_id, sentence_id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_favorite_sentences_time ON favorite_sentences(update_time DESC)');
  }

  Future<void> _createNewWordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE new_words (
        word_id INTEGER PRIMARY KEY,
        word_text TEXT NOT NULL,
        source TEXT NOT NULL,
        operation_code TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_new_words_operation_updated ON new_words(operation_code, updated_at DESC)');
  }

  // ============================================================
  // 收藏管理
  // ─────────────────────────────────────────────────────────────
  // 数据层审计：旧版 favorites(word_id) 整块 API 经全库 grep 零调用方
  // （收藏已迁 favorite_words 文本主键，见 FavoriteWordsDao/FavSentenceDao），
  // 属死代码误导维护，已删除。表 DDL 保留以兼容存量安装的 schema 校验。
  // ============================================================

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
    // 数据层审计 P3：close 后再 initialize() 会复用旧 completed future
    // 而直接返回（_db==null，后续 db getter 抛 StateError）。
    _initCompleter = null;
  }
}

/// 数据库健康分类结果（[UserDatabase._classifyCorruption]）。
enum _DbHealth {
  /// 只读打开成功且 quick_check 通过——失败原因是环境性的，可重试。
  healthy,

  /// 连只读分类都无法完成——无法确证损坏，保守处理。
  unreadable,

  /// quick_check 明确失败——确证损坏。
  corrupt,
}
