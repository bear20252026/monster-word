#!/usr/bin/env python3
"""检查 WORDS 数据格式"""
import re

with open('generate_wordbook_db.py', 'r', encoding='utf8') as f:
    content = f.read()

# 提取 WORDS 列表
start = content.index('WORDS = [')
# 找到匹配的 ]
depth = 0
end = start
for i, c in enumerate(content[start:], start):
    if c == '[':
        depth += 1
    elif c == ']':
        depth -= 1
        if depth == 0:
            end = i + 1
            break

words_str = content[start:end]

# 逐行检查
lines = words_str.split('\n')
for i, line in enumerate(lines):
    line = line.strip()
    if not line or line.startswith('WORDS') or line == ']':
        continue
    # 统计引号数量（粗略检查）
    quote_count = line.count('"') + line.count("'")
    if quote_count % 2 != 0:
        print(f"Line {i+1}: odd quotes ({quote_count}): {line[:80]}...")
    # 检查括号匹配
    if line.startswith('('):
        depth = 0
        for c in line:
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
        if depth != 0:
            print(f"Line {i+1}: unbalanced parens (depth={depth}): {line[:80]}...")

print("检查完成")
