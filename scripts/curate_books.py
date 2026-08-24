"""
精选词书：约 50 本，大学水平为主，少量保留基础水平。
策略：
- 大学核心（CET4/6）：精选 6 本
- 考研：精选 5 本
- 留学考试（GRE/TOEFL/IELTS/GMAT/SAT）：8 本
- 词汇大师（COCA/Oxford/Longman）：5 本
- 学术/专业（AWL/MBA/BEC/TOEIC/PTE）：5 本
- 专业英语（专四/专八）：4 本
- 真题冲刺：6 本
- 高考（基础代表）：3 本
- PETS（公共英语 3-5 级）：3 本
- 核心词汇综合：5 本
"""

import sqlite3, gzip, os, tempfile, shutil

# Book IDs to keep (selected from 191 total)
KEEP_IDS = [
    # === 大学核心 CET4/6 (6) ===
    62,   # HZBCET4        四级核心         6135
    7,    # CET4DGCH       四级大纲词汇     4755
    64,   # HZBCET6N       六级核心         7799
    11,   # CET6CHSG       六级核心词汇     5298
    12,   # CET6DGCH       六级大纲词汇     4036
    166,  # XHCET4QJ       四级强化         2352

    # === 考研 (5) ===
    72,   # KYHBS2027      考研核心         6590
    75,   # KYLX2026       考研练习         7349
    76,   # KYSG2027       考研高分         6023
    74,   # KYHXCH         考研核心词汇     1883
    77,   # KYZTHXCZ       考研真题         571

    # === 留学考试 (8) ===
    37,   # GRECH          GRE核心          6506
    38,   # GRECHLX        GRE练习          6485
    161,  # XDFTOEFL       托福核心         4262
    160,  # XDFIELTS       雅思核心         3835
    36,   # GMATJICHU      GMAT基础         2866
    133,  # SAT            SAT              10001
    2,    # BARRONSAT      Barron SAT       3348
    35,   # GMATGAOFEN     GMAT高分         1101

    # === 词汇大师 (5) ===
    17,   # COCA1          COCA高频         5585
    18,   # COCA2          COCA高频         5537
    19,   # COCA3          COCA高频         6039
    94,   # OXFORD3K       牛津3000         3306
    83,   # LONGMAN3K      朗文3000         3151

    # === 学术/专业 (5) ===
    1,    # AWL            学术词汇         1272
    85,   # MBA             MBA              4480
    3,    # BECHIGHER      BEC高级          2339
    150,  # TOEIC          托业             1633
    109,  # PTECH          PTE              4740

    # === 专业英语 (4) ===
    101,  # PRO4           专四             4567
    105,  # PRO8           专八             5353
    131,  # RYDSPRO4       专四真题         5104
    132,  # RYDSPRO8       专八真题         4291

    # === 真题冲刺 (6) ===
    155,  # WKD2025L1      真题             7120
    154,  # WKD2024LX      真题练习         5432
    134,  # SGSJ2025       真题集           5066
    16,   # CHDLJ2025      真题             4702
    168,  # XHGK2024       高考真题         4956
    135,  # SHGK2025       高考真题         4251

    # === 高考基础 (3) ===
    26,   # GAOKAO         高考             3521
    32,   # GKSG2027       高考高分         4206
    29,   # GKHXCH         高考核心词汇     1824

    # === PETS 公共英语 (3) ===
    98,   # PETS3          三级             4120
    99,   # PETS4          四级             5470
    100,  # PETS5          五级             7527

    # === 核心词汇综合 (5) ===
    81,   # LLYC2027       核心词汇         7969
    82,   # LLYCKY2026     核心词汇         7806
    61,   # HZB2027        核心词汇         5877
    191,  # ZSLX           练习             6046
    102,  # PRO4HY8000     专四核心         4343
]

def main():
    db_path = 'assets/db/wordbook.db.gz'
    
    # Decompress to temp
    with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
        f.write(gzip.open(db_path, 'rb').read())
        tmp_orig = f.name

    with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
        tmp_new = f.name

    conn = sqlite3.connect(tmp_orig)
    cur = conn.cursor()

    # Get book info for selected IDs
    placeholders = ','.join('?' * len(KEEP_IDS))
    cur.execute(f'SELECT id, code, name, word_count FROM books WHERE id IN ({placeholders}) ORDER BY word_count DESC', KEEP_IDS)
    kept_books = cur.fetchall()
    
    print(f'=== 精选词书 ({len(kept_books)} 本) ===')
    total_words_estimate = 0
    for b in kept_books:
        print(f'  id={b[0]:3d} | {b[1]:20s} | words={b[3]:5d} | {b[2]}')
        total_words_estimate += b[3]
    print(f'\n词书总数: {len(kept_books)}')
    print(f'词条关联总数(含重复): {total_words_estimate}')

    # Create new database
    conn_new = sqlite3.connect(tmp_new)
    cur_new = conn_new.cursor()

    # Copy schema (skip sqlite_sequence - internal table)
    cur.execute("SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name != 'sqlite_sequence'")
    for (sql,) in cur.fetchall():
        cur_new.execute(sql)

    # Copy selected books
    cur.execute(f'SELECT * FROM books WHERE id IN ({placeholders})', KEEP_IDS)
    books_rows = cur.fetchall()
    cur_new.executemany('INSERT INTO books VALUES (?,?,?,?)', books_rows)

    # Copy word_books for selected books only
    cur.execute(f'SELECT * FROM word_books WHERE book_id IN ({placeholders})', KEEP_IDS)
    wb_rows = cur.fetchall()
    cur_new.executemany('INSERT INTO word_books VALUES (?,?)', wb_rows)
    print(f'word_books 关联: {len(wb_rows)}')

    # Copy only words that are referenced by kept books
    cur.execute(f'SELECT DISTINCT word_id FROM word_books WHERE book_id IN ({placeholders})', KEEP_IDS)
    word_ids = [r[0] for r in cur.fetchall()]
    print(f'独立单词数: {len(word_ids)}')

    # Copy words in batches
    batch_size = 500
    for i in range(0, len(word_ids), batch_size):
        batch = word_ids[i:i+batch_size]
        ph = ','.join('?' * len(batch))
        cur.execute(f'SELECT * FROM words WHERE id IN ({ph})', batch)
        word_rows = cur.fetchall()
        cur_new.executemany('INSERT INTO words VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', word_rows)

    # Skip sqlite_sequence (internal AUTOINCREMENT table, not used by our schema)

    conn.close()
    conn_new.commit()
    conn_new.close()

    # Compress and replace
    with open(tmp_new, 'rb') as f_in:
        with gzip.open(db_path, 'wb', compresslevel=9) as f_out:
            shutil.copyfileobj(f_in, f_out)

    # Stats
    orig_size = os.path.getsize(tmp_orig)
    new_size = os.path.getsize(db_path)
    print(f'\n=== 压缩后 ===')
    print(f'原始 DB: {orig_size/1024/1024:.1f} MB')
    print(f'精选 DB: {new_size/1024/1024:.1f} MB')

    os.unlink(tmp_orig)
    os.unlink(tmp_new)
    print('\n✅ 词书精选完成')

if __name__ == '__main__':
    main()
