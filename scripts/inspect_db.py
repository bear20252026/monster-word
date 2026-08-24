import sqlite3, gzip, os, tempfile

with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
    f.write(gzip.open('assets/db/wordbook.db.gz', 'rb').read())
    tmp = f.name

conn = sqlite3.connect(tmp)
cur = conn.cursor()

# Get all tables
cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [r[0] for r in cur.fetchall()]
print('Tables:', tables)

# Get schema for each table
for t in tables:
    cur.execute(f'PRAGMA table_info({t})')
    cols = [(r[1], r[2]) for r in cur.fetchall()]
    print(f'  {t}: {cols}')

# Get all books
print()
print('=== ALL BOOKS (from books table) ===')
cur.execute('SELECT id, code, name, word_count FROM books ORDER BY word_count DESC')
rows = cur.fetchall()
print(f'Total books: {len(rows)}')
for r in rows:
    print(f'id={r[0]:3d} | {r[1]:20s} | words={r[3]:5d} | {r[2]}')

conn.close()
os.unlink(tmp)
