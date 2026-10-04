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

  Database? _db;
  bool _initialized = false;
  Completer<void>? _initCompleter;

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
      _db = await _open(dbPath);
    } catch (e, s) {
      // 2026-10-04 审计 P1：打开失败不必然是损坏——Windows 上杀毒/备份软件
      // 的瞬时文件锁、磁盘瞬时 IO 错同样会让 openDatabase 抛错；而 new_words
      // （生词本）没有任何 SP 快照可回迁，误判损坏直接删库 = 永久清空。
      // 先关句柄重试一次，仍失败才按损坏走「备份 + 重建」。
      reportSwallowedError('用户数据库打开失败，关闭句柄后重试一次', e, s);
      await _safeClose();
      try {
        _db = await _open(dbPath);
      } catch (e2, s2) {
        // 错误处理审计 P2：user_data.db 损坏（onUpgrade 抛错/磁盘错误）会让
        // bootstrap 整体失败，runApp 永不执行（白屏死应用）。参照
        // WordBookDatabase 的口径：删坏库重建一次；收藏/尖叫币可由 SP 快照
        // 与 DAO 迁移路径回迁，优于完全起不来。首错与重建路径都必须上报。
        reportSwallowedError('用户数据库重试仍失败，按损坏备份后删除重建', e2, s2);
        _db = await _deleteAndRebuild(dir, dbPath);
      }
    }
    _initialized = true;
  }

  Future<Database> _open(String dbPath) {
    return openDatabase(
      dbPath,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // 审计 I37：sqflite 默认静默降版本号且不回滚 schema。这里不抛错
      //（抛错会落入下方删库重建路径毁掉用户数据），仅让降版本事件可观测。
      onDowngrade: (db, oldVersion, newVersion) async {
        reportSwallowedError(
          '用户数据库版本回退（old=$oldVersion new=$newVersion），schema 未回滚',
          StateError('database downgrade observed'),
          StackTrace.current,
        );
      },
    );
  }

  Future<Database> _deleteAndRebuild(Directory dir, String dbPath) async {
    await _safeClose();
    try {
      final file = File(p.join(dir.path, 'user_data.db'));
      if (file.existsSync()) {
        // 2026-10-04 审计 P1：损坏库先改名留档（.corrupt.bak，只保留最近一份）
        // 再重建——生词本无快照，直接删除把「可人工抢救」变成「永久清空」。
        final backup = File('$dbPath.corrupt.bak');
        if (backup.existsSync()) backup.deleteSync();
        file.renameSync(backup.path);
      }
    } catch (e, s) {
      // 改名失败（文件仍被占用等）也上报；退回直接删除，仍失败让异常上抛
      reportSwallowedError('用户数据库损坏文件备份改名失败，尝试直接删除', e, s);
      try {
        final file = File(p.join(dir.path, 'user_data.db'));
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e2, s2) {
        reportSwallowedError('用户数据库损坏文件删除失败，尝试直接重开', e2, s2);
      }
    }
    // 审计 P3-2：journal/wal/shm 边车与主库同源损坏，只删主文件可能留下
    // 与新建库不一致的边车导致再次打开失败；清理失败不阻断重建，仅上报。
    for (final suffix in const ['-journal', '-wal', '-shm']) {
      try {
        final sidecar = File('$dbPath$suffix');
        if (sidecar.existsSync()) sidecar.deleteSync();
      } catch (e, s) {
        reportSwallowedError('用户数据库边车文件清理失败（$suffix）', e, s);
      }
    }
    return openDatabase(dbPath, version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
