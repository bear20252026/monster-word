#!/usr/bin/env python3
"""Check WORDS data for format issues"""
import ast

with open('generate_wordbook_db.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Find WORDS = [
start = content.index('WORDS = [')
# Find matching ]
depth = 0
end = start
for i, ch in enumerate(content[start:], start):
    if ch == '[':
        depth += 1
    elif ch == ']':
        depth -= 1
        if depth == 0:
            end = i + 1
            break

words_code = content[start:end]
# Use ast to parse
try:
    words = ast.literal_eval(words_code.split('=', 1)[1].strip())
    print(f"Total words: {len(words)}")
    for i, w in enumerate(words):
        if len(w) != 10:
            print(f"Word {i}: {len(w)} values - {repr(w[0])}")
except Exception as e:
    print(f"Parse error: {e}")
    # Try to find the problematic line
    for i, line in enumerate(words_code.split('\n')):
        line = line.strip()
        if line.startswith('(') and line.endswith('),'):
            parts = line[1:-2].split('", "')
            if len(parts) != 10:
                print(f"Line {i}: {len(parts)} parts - {line[:60]}...")
