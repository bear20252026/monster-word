#!/usr/bin/env python3
"""
应用质量审查修正到 book_display_v1_draft.json
"""

import json
from pathlib import Path
from datetime import datetime

def load_draft():
    """加载草稿文件"""
    draft_path = Path('D:/claude/work/cn_com_lange/word_app/docs/book_display_v1_draft.json')
    with open(draft_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_draft(draft):
    """保存草稿文件"""
    draft_path = Path('D:/claude/work/cn_com_lange/word_app/docs/book_display_v1_draft.json')
    with open(draft_path, 'w', encoding='utf-8') as f:
        json.dump(draft, f, ensure_ascii=False, indent=2)

def apply_corrections():
    """应用修正"""
    draft = load_draft()
    books = draft['books']

    # 1. 31本提升至高置信
    high_confidence_corrections = {
        'AWL': {'name': '学术词汇表', 'basis': '已知考试/词汇表缩写：AWL=Academic Word List'},
        'BECHIGHER': {'name': 'BEC高级', 'basis': '已知考试缩写：BEC Higher'},
        'BECPRE': {'name': 'BEC初级', 'basis': '已知考试缩写：BEC Preliminary'},
        'BECVAN': {'name': 'BEC中级', 'basis': '已知考试缩写：BEC Vantage'},
        'COCA1': {'name': 'COCA语料库·第1级', 'basis': '已知语料库缩写：COCA Corpus of Contemporary American English'},
        'COCA2': {'name': 'COCA语料库·第2级', 'basis': '已知语料库缩写：COCA Corpus of Contemporary American English'},
        'COCA3': {'name': 'COCA语料库·第3级', 'basis': '已知语料库缩写：COCA Corpus of Contemporary American English'},
        'GAOKAO': {'name': '高考词汇', 'basis': '已知考试缩写：高考'},
        'KAOBO': {'name': '考博词汇', 'basis': '已知考试缩写：考博'},
        'MBA': {'name': 'MBA词汇', 'basis': '已知考试缩写：MBA'},
        'PETS1': {'name': '公共英语一级', 'basis': '已知考试缩写：PETS1'},
        'PETS2': {'name': '公共英语二级', 'basis': '已知考试缩写：PETS2'},
        'PETS3': {'name': '公共英语三级', 'basis': '已知考试缩写：PETS3'},
        'PETS4': {'name': '公共英语四级', 'basis': '已知考试缩写：PETS4'},
        'PETS5': {'name': '公共英语五级', 'basis': '已知考试缩写：PETS5'},
        'PRO4': {'name': '专四词汇', 'basis': '已知考试缩写：专四'},
        'PRO8': {'name': '专八词汇', 'basis': '已知考试缩写：专八'},
        'SAT': {'name': 'SAT词汇', 'basis': '已知考试缩写：SAT'},
        'SHZKKG': {'name': '上海中考考纲词汇', 'basis': '已知考试缩写：上海中考考纲'},
        'SY4K1': {'name': '上海教材分册·第1册', 'basis': '教材分册模式：SY4K+数字'},
        'SY4K2': {'name': '上海教材分册·第2册', 'basis': '教材分册模式：SY4K+数字'},
        'SY4K3': {'name': '上海教材分册·第3册', 'basis': '教材分册模式：SY4K+数字'},
        'SY4K4': {'name': '上海教材分册·第4册', 'basis': '教材分册模式：SY4K+数字'},
        'SY4K5': {'name': '上海教材分册·第5册', 'basis': '教材分册模式：SY4K+数字'},
        'SY4K6': {'name': '上海教材分册·第6册', 'basis': '教材分册模式：SY4K+数字'},
        'TOEIC': {'name': '托业词汇', 'basis': '已知考试缩写：TOEIC'},
        'XGNYY1': {'name': '新编大学英语·第1册', 'basis': '教材分册模式：XGNYY+数字'},
        'XGNYY2': {'name': '新编大学英语·第2册', 'basis': '教材分册模式：XGNYY+数字'},
        'XGNYY3': {'name': '新编大学英语·第3册', 'basis': '教材分册模式：XGNYY+数字'},
        'XGNYY4': {'name': '新编大学英语·第4册', 'basis': '教材分册模式：XGNYY+数字'},
        'YASJ': {'name': '雅思圣经', 'basis': '已知考试缩写：雅思圣经'},
    }

    # 2. 1本提升至中置信
    medium_confidence_corrections = {
        'BIZLAW': {'name': '商务法律英语', 'basis': '已知考试缩写：Business Law'},
    }

    # 3. 4本保持低置信但补充候选解释
    low_confidence_candidates = {
        'CZBGZDC': {'basis': '待人工确认：可能是"初中背诵古诗词"或"初中必背古诗词"'},
        'DBGZYY': {'basis': '候选解释：大纲?高中? 可能是"大纲高中英语"'},
        'GZBGZDC': {'basis': '待人工确认：可能是"高中背诵古诗词"或"高中必背古诗词"'},
        'WKDCZ': {'basis': '候选解释：文都考研? 可能是"文都考研词汇"'},
    }

    # 应用修正
    updated_count = {'high': 0, 'medium': 0, 'low': 0}

    for code, correction in high_confidence_corrections.items():
        if code in books:
            books[code]['name'] = correction['name']
            books[code]['confidence'] = 'high'
            books[code]['basis'] = correction['basis']
            updated_count['high'] += 1

    for code, correction in medium_confidence_corrections.items():
        if code in books:
            books[code]['name'] = correction['name']
            books[code]['confidence'] = 'medium'
            books[code]['basis'] = correction['basis']
            updated_count['medium'] += 1

    for code, correction in low_confidence_candidates.items():
        if code in books:
            books[code]['basis'] = correction['basis']
            updated_count['low'] += 1

    # 更新版本信息
    draft['version'] = 2
    draft['updated'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    draft['update_notes'] = '应用质量审查修正：31本提升至高置信，1本提升至中置信，4本补充候选解释'

    # 统计
    stats = {'high': 0, 'medium': 0, 'low': 0}
    for code, info in books.items():
        stats[info['confidence']] += 1

    draft['statistics'] = {
        'total': len(books),
        'high': stats['high'],
        'medium': stats['medium'],
        'low': stats['low']
    }

    # 保存
    save_draft(draft)

    print('修正完成！')
    print(f'更新统计：')
    print(f'  高置信：{updated_count["high"]} 本')
    print(f'  中置信：{updated_count["medium"]} 本')
    print(f'  低置信：{updated_count["low"]} 本')
    print(f'\n最终统计：')
    print(f'  高置信：{stats["high"]} 本')
    print(f'  中置信：{stats["medium"]} 本')
    print(f'  低置信：{stats["low"]} 本')

def main():
    apply_corrections()

if __name__ == '__main__':
    main()
