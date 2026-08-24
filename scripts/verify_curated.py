import sqlite3, gzip, os, tempfile

with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
    f.write(gzip.open('assets/db/wordbook.db.gz', 'rb').read())
    tmp = f.name

conn = sqlite3.connect(tmp)
cur = conn.cursor()

cur.execute('SELECT COUNT(*) FROM books')
print(f'Books: {cur.fetchone()[0]}')

cur.execute('SELECT COUNT(*) FROM words')
print(f'Words: {cur.fetchone()[0]}')

cur.execute('SELECT COUNT(*) FROM word_books')
print(f'Word-Book relations: {cur.fetchone()[0]}')

cur.execute('SELECT id, code, word_count FROM books ORDER BY word_count DESC LIMIT 10')
print()
print('Top 10 by word count:')
for r in cur.fetchall():
    print(f'  id={r[0]:3d} | {r[1]:20s} | {r[2]} words')

conn.close()
os.unlink(tmp)

size_mb = os.path.getsize('assets/db/wordbook.db.gz') / 1024 / 1024
print()
print(f'File size: {size_mb:.1f} MB')
