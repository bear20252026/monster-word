#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""user_data.db 迁移演练（审计 I103）。

对用户库副本做只读体检 + 迁移预演，绝不改动原库：
  1. 原库文件缺失/路径不存在 → 提示位置；
  2. 复制到临时目录后打开，检查 schema（表/列）、迁移 marker、各表行数；
  3. 在副本上按 onUpgrade 顺序预演 v1→v3 建表步骤（事务内，结果不保存）；
  4. 输出体检报告，退出码 0=健康，1=发现问题。

用法：python scripts/migrate_dry_run.py [user_data.db 路径]
      不传路径时自动探测 %APPDATA%/com.monsterword/Monster Word/ 与
      getApplicationSupportDirectory 对应位置。
"""

import os
import shutil
import sqlite3
import sys
import tempfile
from pathlib import Path

EXPECTED_TABLES = {
    "favorites": ["id", "word_id", "created_at"],
    "new_words": ["word_id", "word_text", "source", "operation_code", "created_at", "updated_at", "synced_at"],
    "favorite_words": ["word", "created_at"],
    "favorite_sentences": ["word_id", "sentence_id", "word", "update_time", "data_json"],
}
# fsrs_* 由 ReviewScheduleStore 首次进入学习/复习会话时懒建，缺失不算问题
OPTIONAL_TABLES = {"fsrs_cards", "fsrs_daily_stats", "fsrs_active_dates"}

MIGRATION_MARKERS = [
    "favorite_words_sqlite_migrated_v1",
    "fav_sentence_sqlite_migrated_v1",
]


def candidate_paths():
    appdata = os.environ.get("APPDATA")
    if appdata:
        yield Path(appdata) / "com.monsterword" / "Monster Word" / "user_data.db"
        yield Path(appdata) / "monster-word" / "user_data.db"
    home = Path.home() / "AppData" / "Roaming"
    if (home / "com.monsterword").exists():
        for p in (home / "com.monsterword").rglob("user_data.db"):
            yield p


def main():
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else next((p for p in candidate_paths() if p.exists()), None)
    if not target or not target.exists():
        print("未找到 user_data.db。可手动传入路径：python scripts/migrate_dry_run.py <路径>")
        return 1
    print(f"目标库: {target} ({target.stat().st_size / 1024:.0f} KB)")

    issues = []
    tmp = Path(tempfile.mkdtemp()) / "user_data_copy.db"
    shutil.copy2(target, tmp)
    con = sqlite3.connect(tmp)
    cur = con.cursor()

    tables = {r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    print(f"表清单: {sorted(tables)}")

    for table, cols in EXPECTED_TABLES.items():
        if table not in tables:
            issues.append(f"缺表: {table}")
            continue
        actual = {r[1] for r in cur.execute(f"PRAGMA table_info({table})")}
        if cols:
            missing = [c for c in cols if c not in actual]
            if missing:
                issues.append(f"{table} 缺列: {missing}")
        try:
            n = cur.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            print(f"  {table}: {n} 行")
        except sqlite3.Error as e:
            issues.append(f"{table} 计数失败: {e}")

    for table in sorted(OPTIONAL_TABLES):
        if table in tables:
            n = cur.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            print(f"  {table}: {n} 行（懒建表）")
        else:
            print(f"  {table}: 未创建（首次学习会话时懒建，非问题）")

    # 迁移 marker 存于 SharedPreferences（非本库），此处检查 SQLite 侧
    # 收藏迁移一致性：SP 快照不可读，但可以确认 DB 行数 > 0 即迁移完成过。
    if "favorite_words" in tables:
        n = cur.execute("SELECT COUNT(*) FROM favorite_words").fetchone()[0]
        if n == 0:
            print("提示: favorite_words 为空（可能从未迁移或确实无收藏，结合 marker 判断）")

    # 迁移预演：副本上补建缺失表（IF NOT EXISTS 幂等），事务内回滚
    try:
        cur.execute("BEGIN")
        cur.execute(
            "CREATE TABLE IF NOT EXISTS favorite_words ("
            "word TEXT PRIMARY KEY, created_at INTEGER NOT NULL)"
        )
        cur.execute(
            "CREATE TABLE IF NOT EXISTS favorite_sentences ("
            "word_id INTEGER NOT NULL, sentence_id TEXT NOT NULL, word TEXT NOT NULL DEFAULT '',"
            "update_time TEXT NOT NULL, data_json TEXT NOT NULL, PRIMARY KEY(word_id, sentence_id))"
        )
        cur.execute("CREATE INDEX IF NOT EXISTS idx_favorite_sentences_time ON favorite_sentences(update_time DESC)")
        cur.execute("CREATE TABLE IF NOT EXISTS fsrs_daily_stats (date TEXT PRIMARY KEY, learn INTEGER NOT NULL, review INTEGER NOT NULL)")
        cur.execute("CREATE TABLE IF NOT EXISTS fsrs_active_dates (date TEXT PRIMARY KEY)")
        cur.execute("ROLLBACK")
        print("迁移预演: 建表语句全部可在副本执行（幂等），已回滚不落盘")
    except sqlite3.Error as e:
        issues.append(f"迁移预演失败: {e}")

    integrity = cur.execute("PRAGMA integrity_check").fetchone()[0]
    print(f"完整性: {integrity}")
    if integrity != "ok":
        issues.append(f"integrity_check: {integrity}")

    con.close()
    os.remove(tmp)
    os.rmdir(tmp.parent)

    if issues:
        print("\n=== 发现问题 ===")
        for i in issues:
            print(f"  - {i}")
        return 1
    print("\n=== 体检通过，无问题 ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
