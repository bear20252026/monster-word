#!/usr/bin/env python3
"""
词书友好名解码器 - 规则引擎离线推断
根据 book_name_mapping_plan.md 方案实现
"""

import sqlite3
import json
import re
from pathlib import Path
from collections import defaultdict

# 词素词典
BRAND_PREFIXES = {
    'HZB': '红宝书',
    'LLY': '恋练有词',
    'XDF': '新东方',
    'RYD': '如鱼得水',
    'XHPRO': '星火英语',
    'XH': '星火英语',
    'HY': '华研外语',
    'BARRON': '巴朗',
    'COCA': 'COCA语料库',
    'LONGMAN': '朗文词典',
    'OXFORD': '牛津词典',
    'AWL': '学术词汇表',
    'ZT': '真题',
}

EXAM_TYPES = {
    'CET4': '四级',
    'CET6': '六级',
    'KY': '考研',
    'GAOKAO': '高考',
    'GK': '高考',
    'TJGK': '天津高考',
    'SHGK': '上海高考',
    'ZK': '中考',
    'SHZKKG': '上海中考考纲',
    'TOEFL': '托福',
    'TF': '托福',
    'IELTS': '雅思',
    'YS': '雅思',
    'YASJ': '雅思圣经',
    'GRE': 'GRE',
    'GMAT': 'GMAT',
    'SAT': 'SAT',
    'PTE': 'PTE',
    'TOEIC': '托业',
    'MBA': 'MBA',
    'KAOBO': '考博',
    'PETS1': '公共英语一级',
    'PETS2': '公共英语二级',
    'PETS3': '公共英语三级',
    'PETS4': '公共英语四级',
    'PETS5': '公共英语五级',
    'BECPRE': '商务英语初级',
    'BECVAN': '商务英语中级',
    'BECHIGHER': '商务英语高级',
    'BIZLAW': '商务法律',
    'KET': 'KET',
    'PET': 'PET',
    'FCE': 'FCE',
    'PRO4': '专四',
    'PRO8': '专八',
}

TEXTBOOK_VERSIONS = {
    'RJB': '人教版',
    'HWJ': '外研版',
    'HJB': '沪教版',
    'NJSH': '牛津上海版',
    'NJYLB': '牛津译林版',
    'XSYD': '新视野大学英语',
    'XGNYY': '新编大学英语',
    'SY4K': '上海教材',
}

CONTENT_TYPES = {
    'DGCH': '大纲词汇',
    'HXCH': '核心词汇',
    'HXCZ': '核心常考',
    'TZCZ': '拓展常考',
    'ZTHXCZ': '真题核心',
    'ZTTZCZ': '真题拓展',
    'GP': '高频',
    'CH': '冲刺',
    'CHSG': '冲刺高分',
    'SG': '闪过',
    'QJ': '全景',
    'JX': '精选',
    'JC': '基础',
    'LX': '练习',
    'ZJH': '真题汇',
    'N': '新版',
    'L': '乱序',
}

def tokenize(code):
    """最长匹配切分"""
    tokens = []
    remaining = code

    # 按长度降序排序所有词素
    all_terms = []
    for d in [BRAND_PREFIXES, EXAM_TYPES, TEXTBOOK_VERSIONS, CONTENT_TYPES]:
        for key in d.keys():
            all_terms.append(key)
    all_terms.sort(key=len, reverse=True)

    while remaining:
        matched = False
        for term in all_terms:
            if remaining.startswith(term):
                tokens.append(term)
                remaining = remaining[len(term):]
                matched = True
                break

        if not matched:
            # 匹配数字或单个字符
            match = re.match(r'^(\d+|[A-Z])', remaining)
            if match:
                tokens.append(match.group(0))
                remaining = remaining[match.end():]
            else:
                # 未知段
                tokens.append(remaining)
                remaining = ''

    return tokens

def classify_tokens(tokens):
    """分类token"""
    brand = None
    exam = None
    textbook = None
    content = []
    numbers = []
    unknown = []

    for token in tokens:
        if token in BRAND_PREFIXES:
            brand = BRAND_PREFIXES[token]
        elif token in EXAM_TYPES:
            exam = EXAM_TYPES[token]
        elif token in TEXTBOOK_VERSIONS:
            textbook = TEXTBOOK_VERSIONS[token]
        elif token in CONTENT_TYPES:
            content.append(CONTENT_TYPES[token])
        elif re.match(r'^\d+$', token):
            numbers.append(token)
        else:
            unknown.append(token)

    return {
        'brand': brand,
        'exam': exam,
        'textbook': textbook,
        'content': content,
        'numbers': numbers,
        'unknown': unknown
    }

def infer_grade(numbers):
    """推断年级"""
    grade_map = {
        '7': '七年级',
        '8': '八年级',
        '9': '九年级',
        '1': '高一',
        '2': '高二',
        '3': '高三',
    }

    # 检查是否有年级上下册标记
    for num in numbers:
        if len(num) >= 2:
            grade_num = num[0]
            if grade_num in grade_map:
                if len(num) > 1 and num[1] == 'X':
                    return grade_map[grade_num] + '下册'
                else:
                    return grade_map[grade_num] + '上册'

    return None

def generate_display_name(code, word_count, classification):
    """生成友好名"""
    parts = []
    desc_parts = []
    confidence = 'high'

    # 品牌
    if classification['brand']:
        parts.append(classification['brand'])
        desc_parts.append(classification['brand'])

    # 教材版本
    if classification['textbook']:
        parts.insert(0 if classification['brand'] else 0, classification['textbook'])
        desc_parts.append('教材同步')

        # 推断年级
        grade = infer_grade(classification['numbers'])
        if grade:
            parts.append(grade)

    # 考试类型
    if classification['exam']:
        if not classification['textbook']:
            parts.append(classification['exam'])
        desc_parts.append(classification['exam'])

    # 内容类型
    if classification['content']:
        content_str = '·'.join(classification['content'])
        parts.append(content_str)
        desc_parts.append(content_str)

    # 数字（词数或年份）
    for num in classification['numbers']:
        if len(num) == 4 and num.startswith('20'):  # 年份
            parts.append(num + '版')
            desc_parts.append(num + '版')
        elif len(num) <= 2:  # 年级或级别，已处理
            pass
        else:  # 词数
            if len(num) >= 4:
                parts.append(num + '词')
                desc_parts.append(num + '词')

    # 处理未知段
    if classification['unknown']:
        unknown_str = ''.join(classification['unknown'])
        parts.append(f'({unknown_str})')
        confidence = 'medium'

    # 如果没有足够的信息，降低置信度
    if len(parts) <= 1:
        confidence = 'low'

    # 生成友好名
    if len(parts) > 0:
        name = '·'.join(parts)
    else:
        name = code
        confidence = 'low'

    # 生成描述
    if desc_parts:
        desc = ' · '.join(desc_parts)
    else:
        desc = f'{word_count}词'

    # 限制长度
    if len(name) > 20:
        name = name[:18] + '...'

    return name, desc, confidence

def main():
    # 连接数据库（只读）
    db_path = Path.home() / 'AppData' / 'Local' / 'Temp' / 'word_app_db' / 'wordbook.db'
    conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
    cursor = conn.cursor()

    # 查询全部词书
    cursor.execute('SELECT code, name, word_count FROM books ORDER BY code')
    books = cursor.fetchall()

    print(f'共查询到 {len(books)} 本词书')

    # 解码结果
    results = {}
    review_notes = []

    for code, name, word_count in books:
        tokens = tokenize(code)
        classification = classify_tokens(tokens)
        display_name, desc, confidence = generate_display_name(code, word_count, classification)

        results[code] = {
            'name': display_name,
            'confidence': confidence,
            'basis': f'tokens: {tokens}, classification: {classification}'
        }

        review_notes.append({
            'code': code,
            'name': display_name,
            'desc': desc,
            'confidence': confidence,
            'word_count': word_count,
            'classification': classification
        })

    # 写入 JSON 文件
    output_dir = Path('D:/claude/work/cn_com_lange/word_app/docs')
    output_dir.mkdir(exist_ok=True)

    draft_path = output_dir / 'book_display_v1_draft.json'
    with open(draft_path, 'w', encoding='utf-8') as f:
        json.dump({
            'version': 1,
            'generated': '2026-08-24',
            'books': results
        }, f, ensure_ascii=False, indent=2)

    print(f'已生成草稿文件: {draft_path}')

    # 生成人工校对指引
    review_path = output_dir / 'book_display_review_notes.md'
    with open(review_path, 'w', encoding='utf-8') as f:
        f.write('# 词书友好名 v1 人工校对指引\n\n')
        f.write('> 生成时间：2026-08-24\n')
        f.write('> 词书总数：191本\n\n')

        # 按置信度分组
        high_conf = [b for b in review_notes if b['confidence'] == 'high']
        medium_conf = [b for b in review_notes if b['confidence'] == 'medium']
        low_conf = [b for b in review_notes if b['confidence'] == 'low']

        f.write('## 一、高置信清单（抽查即可）\n\n')
        f.write(f'预计 {len(high_conf)} 本，抽查即可\n\n')
        f.write('| code | 推荐名 | 描述 | 词数 |\n')
        f.write('|---|---|---|---|\n')
        for b in high_conf:
            f.write(f"| {b['code']} | {b['name']} | {b['desc']} | {b['word_count']:,} |\n")

        f.write('\n## 二、中置信复核清单\n\n')
        f.write(f'预计 {len(medium_conf)} 本，需人工复核\n\n')
        f.write('| code | 推荐名 | 描述 | 词数 | 复核说明 |\n')
        f.write('|---|---|---|---|---|\n')
        for b in medium_conf:
            unknown = b['classification']['unknown']
            note = f'未知词素: {unknown}' if unknown else '需确认名称准确性'
            f.write(f"| {b['code']} | {b['name']} | {b['desc']} | {b['word_count']:,} | {note} |\n")

        f.write('\n## 三、低置信/歧义清单\n\n')
        f.write(f'预计 {len(low_conf)} 本，需逐个人工裁决\n\n')
        f.write('| code | 推荐名 | 描述 | 词数 | 候选解释 |\n')
        f.write('|---|---|---|---|---|\n')
        for b in low_conf:
            candidates = []
            if 'WKD' in b['code']:
                candidates.append('文都考研?')
            if 'TPYW' in b['code']:
                candidates.append('唐迟英语?')
            if 'BX' in b['code'] or 'XB' in b['code']:
                candidates.append('必修?')
            if not candidates:
                candidates.append('待人工确认')
            f.write(f"| {b['code']} | {b['name']} | {b['desc']} | {b['word_count']:,} | {' / '.join(candidates)} |\n")

        f.write('\n## 四、命名风格规范\n\n')
        f.write('1. **主标题+副标题制**：如"红宝书·四级词汇"\n')
        f.write('2. **数字后缀转中文语义**：688→核心高频688词\n')
        f.write('3. **UI宽度适配**：超长名截断策略（建议20字以内）\n')
        f.write('4. **描述行格式**：品牌 · 考试 · 类型 · 词数\n')

    print(f'已生成校对指引: {review_path}')

    # 统计
    print(f'\n统计:')
    print(f'  高置信: {len(high_conf)} 本')
    print(f'  中置信: {len(medium_conf)} 本')
    print(f'  低置信: {len(low_conf)} 本')

    conn.close()

if __name__ == '__main__':
    main()
