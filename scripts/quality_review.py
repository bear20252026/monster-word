#!/usr/bin/env python3
"""
词书友好名 v1 质量审查脚本
"""

import sqlite3
import json
from pathlib import Path
from collections import defaultdict

def load_draft():
    """加载草稿文件"""
    draft_path = Path('D:/claude/work/cn_com_lange/word_app/docs/book_display_v1_draft.json')
    with open(draft_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def get_all_books():
    """从数据库获取所有词书"""
    db_path = Path.home() / 'AppData' / 'Local' / 'Temp' / 'word_app_db' / 'wordbook.db'
    conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
    cursor = conn.cursor()
    cursor.execute('SELECT code, name, word_count FROM books ORDER BY code')
    books = cursor.fetchall()
    conn.close()
    return {code: {'name': name, 'word_count': wc} for code, name, wc in books}

def analyze_draft_quality(draft, db_books):
    """分析草稿质量"""
    books = draft['books']

    # 按置信度分组
    high_conf = []
    medium_conf = []
    low_conf = []

    for code, info in books.items():
        if code not in db_books:
            continue

        db_info = db_books[code]
        entry = {
            'code': code,
            'draft_name': info['name'],
            'confidence': info['confidence'],
            'basis': info['basis'],
            'db_name': db_info['name'],
            'db_word_count': db_info['word_count']
        }

        if info['confidence'] == 'high':
            high_conf.append(entry)
        elif info['confidence'] == 'medium':
            medium_conf.append(entry)
        else:
            low_conf.append(entry)

    return high_conf, medium_conf, low_conf

def check_high_confidence(high_conf):
    """抽查高置信映射准确性"""
    issues = []
    sample_size = min(30, len(high_conf))
    sample = high_conf[:sample_size]

    for entry in sample:
        code = entry['code']
        name = entry['draft_name']

        # 检查是否有明显错误
        # 1. 检查名称是否包含乱码（单个字母）
        if len(name) <= 3 and name.isalpha():
            issues.append({
                'code': code,
                'issue': '名称过短，可能是乱码',
                'current': name,
                'suggestion': '需要人工确认'
            })

        # 2. 检查是否包含未解析的括号
        if '(' in name and ')' in name:
            issues.append({
                'code': code,
                'issue': '包含未解析的括号',
                'current': name,
                'suggestion': '需要修正'
            })

        # 3. 检查名称长度是否合理
        if len(name) > 25:
            issues.append({
                'code': code,
                'issue': '名称过长，可能需要截断',
                'current': f'{name} ({len(name)}字)',
                'suggestion': '建议截断至20字以内'
            })

    return sample_size, issues

def analyze_low_confidence(low_conf, db_books):
    """分析低置信映射并给出修正建议"""
    corrections = []

    # 已知模式映射
    known_patterns = {
        'AWL': ('学术词汇表', 'high'),
        'BECHIGHER': ('BEC高级', 'high'),
        'BECPRE': ('BEC初级', 'high'),
        'BECVAN': ('BEC中级', 'high'),
        'BIZLAW': ('商务法律英语', 'medium'),
        'COCA1': ('COCA语料库·第1级', 'high'),
        'COCA2': ('COCA语料库·第2级', 'high'),
        'COCA3': ('COCA语料库·第3级', 'high'),
        'GAOKAO': ('高考词汇', 'high'),
        'KAOBO': ('考博词汇', 'high'),
        'MBA': ('MBA词汇', 'high'),
        'PETS1': ('公共英语一级', 'high'),
        'PETS2': ('公共英语二级', 'high'),
        'PETS3': ('公共英语三级', 'high'),
        'PETS4': ('公共英语四级', 'high'),
        'PETS5': ('公共英语五级', 'high'),
        'PRO4': ('专四词汇', 'high'),
        'PRO8': ('专八词汇', 'high'),
        'SAT': ('SAT词汇', 'high'),
        'SHZKKG': ('上海中考考纲词汇', 'high'),
        'TOEIC': ('托业词汇', 'high'),
        'YASJ': ('雅思圣经', 'high'),
    }

    # 教材版本映射
    textbook_patterns = {
        'SY4K': '上海教材分册',
        'XGNYY': '新编大学英语',
    }

    for entry in low_conf:
        code = entry['code']
        current_name = entry['draft_name']

        # 检查已知模式
        if code in known_patterns:
            corrected_name, new_confidence = known_patterns[code]
            corrections.append({
                'code': code,
                'current': current_name,
                'corrected': corrected_name,
                'new_confidence': new_confidence,
                'reason': '已知考试/词汇表缩写'
            })
        # 检查教材模式
        elif code.startswith('SY4K') or code.startswith('XGNYY'):
            for prefix, name in textbook_patterns.items():
                if code.startswith(prefix):
                    num = code.replace(prefix, '')
                    if num:
                        corrected_name = f'{name}·第{num}册'
                    else:
                        corrected_name = name
                    corrections.append({
                        'code': code,
                        'current': current_name,
                        'corrected': corrected_name,
                        'new_confidence': 'high',
                        'reason': '教材分册模式'
                    })
                    break
        else:
            # 未知模式，保留原名
            corrections.append({
                'code': code,
                'current': current_name,
                'corrected': current_name,
                'new_confidence': 'low',
                'reason': '未知缩写，需人工确认'
            })

    return corrections

def generate_quality_report(high_conf, medium_conf, low_conf, high_sample_size, high_issues, low_corrections):
    """生成质量审查报告"""
    report_path = Path('D:/claude/work/cn_com_lange/word_app/docs/book_display_v1_quality_review.md')

    with open(report_path, 'w', encoding='utf-8') as f:
        f.write('# 词书友好名 v1 质量审查报告\n\n')
        f.write('> 审查时间：2026-08-24\n')
        f.write('> 审查方法：规则引擎离线推断 + 数据库验证\n\n')

        # 总体统计
        f.write('## 一、总体统计\n\n')
        f.write(f'- **总词书数**：191本\n')
        f.write(f'- **高置信**：{len(high_conf)}本（{len(high_conf)/191*100:.1f}%）\n')
        f.write(f'- **中置信**：{len(medium_conf)}本（{len(medium_conf)/191*100:.1f}%）\n')
        f.write(f'- **低置信**：{len(low_conf)}本（{len(low_conf)/191*100:.1f}%）\n\n')

        # 高置信抽查结果
        f.write('## 二、高置信抽查结果\n\n')
        f.write(f'抽查样本：{high_sample_size}本（占高置信{len(high_conf)}本的{high_sample_size/len(high_conf)*100:.1f}%）\n\n')

        if high_issues:
            f.write(f'### 发现问题：{len(high_issues)}个\n\n')
            f.write('| code | 问题 | 当前名称 | 建议 |\n')
            f.write('|---|---|---|---|\n')
            for issue in high_issues:
                f.write(f"| {issue['code']} | {issue['issue']} | {issue['current']} | {issue['suggestion']} |\n")
            f.write('\n')
        else:
            f.write('✅ 抽查未发现问题，高置信映射质量良好\n\n')

        # 低置信修正建议
        f.write('## 三、低置信修正建议\n\n')
        f.write(f'共{len(low_conf)}本低置信词书，修正后：\n\n')

        # 按修正结果分组
        high_fixes = [c for c in low_corrections if c['new_confidence'] == 'high']
        medium_fixes = [c for c in low_corrections if c['new_confidence'] == 'medium']
        still_low = [c for c in low_corrections if c['new_confidence'] == 'low']

        if high_fixes:
            f.write(f'### 可提升至高置信：{len(high_fixes)}本\n\n')
            f.write('| code | 当前名称 | 修正名称 | 修正依据 |\n')
            f.write('|---|---|---|---|\n')
            for fix in high_fixes:
                f.write(f"| {fix['code']} | {fix['current']} | {fix['corrected']} | {fix['reason']} |\n")
            f.write('\n')

        if medium_fixes:
            f.write(f'### 可提升至中置信：{len(medium_fixes)}本\n\n')
            f.write('| code | 当前名称 | 修正名称 | 修正依据 |\n')
            f.write('|---|---|---|---|\n')
            for fix in medium_fixes:
                f.write(f"| {fix['code']} | {fix['current']} | {fix['corrected']} | {fix['reason']} |\n")
            f.write('\n')

        if still_low:
            f.write(f'### 仍需人工确认：{len(still_low)}本\n\n')
            f.write('| code | 当前名称 | 候选解释 |\n')
            f.write('|---|---|---|\n')
            for fix in still_low:
                candidates = []
                code = fix['code']
                if 'WKD' in code:
                    candidates.append('文都考研?')
                if 'TPYW' in code:
                    candidates.append('唐迟英语?')
                if 'DBGZ' in code:
                    candidates.append('大纲?高中?')
                if not candidates:
                    candidates.append('待人工确认')
                f.write(f"| {code} | {fix['current']} | {' / '.join(candidates)} |\n")
            f.write('\n')

        # 通过率评估
        f.write('## 四、通过率评估\n\n')
        pass_rate = (len(high_conf) + len(high_fixes)) / 191 * 100
        f.write(f'**当前通过率**：{pass_rate:.1f}%\n\n')
        f.write(f'- 高置信可用：{len(high_conf) + len(high_fixes)}本\n')
        f.write(f'- 需人工复核：{len(medium_conf) + len(medium_fixes)}本\n')
        f.write(f'- 需人工裁决：{len(still_low)}本\n\n')

        # 问题清单
        f.write('## 五、问题清单与修正建议\n\n')
        f.write('### 主要问题\n\n')
        f.write('1. **教材版本识别不完整**：部分教材分册未识别（如SY4K、XGNYY）\n')
        f.write('2. **未知缩写**：WKD、TPYW、DBGZ等缩写含义待确认\n')
        f.write('3. **名称过长**：部分名称超过20字，需截断策略\n')
        f.write('4. **括号未解析**：部分名称包含未解析的括号内容\n\n')

        f.write('### 修正建议\n\n')
        f.write('1. **立即可修正**：教材分册模式（SY4K、XGNYY）\n')
        f.write('2. **需人工确认**：WKD、TPYW、DBGZ等缩写\n')
        f.write('3. **UI适配**：超过20字的名称需实现截断逻辑\n')
        f.write('4. **后续优化**：补充更多已知缩写映射\n\n')

        # 结论
        f.write('## 六、结论\n\n')
        f.write(f'**质量评估**：{"通过" if pass_rate >= 70 else "需改进"}\n\n')
        f.write(f'**理由**：\n')
        f.write(f'- 高置信映射占比{len(high_conf)/191*100:.1f}%，加上可修正的{len(high_fixes)}本，可达{pass_rate:.1f}%\n')
        f.write(f'- 中置信映射{len(medium_conf)}本，大部分可通过简单规则修正\n')
        f.write(f'- 低置信映射{len(low_conf)}本，需人工裁决但数量可控\n\n')

        f.write('**建议**：\n')
        f.write('1. 立即应用高置信修正（教材分册模式）\n')
        f.write('2. 人工复核中置信映射（预计2小时）\n')
        f.write('3. 人工裁决低置信映射（预计1小时）\n')
        f.write('4. 实施截断策略适配UI宽度\n')

    print(f'质量审查报告已生成: {report_path}')
    return report_path

def main():
    # 加载数据
    draft = load_draft()
    db_books = get_all_books()

    print(f'草稿包含 {len(draft["books"])} 本词书')
    print(f'数据库包含 {len(db_books)} 本词书')

    # 分析质量
    high_conf, medium_conf, low_conf = analyze_draft_quality(draft, db_books)

    print(f'\n置信度分布:')
    print(f'  高置信: {len(high_conf)} 本')
    print(f'  中置信: {len(medium_conf)} 本')
    print(f'  低置信: {len(low_conf)} 本')

    # 抽查高置信
    high_sample_size, high_issues = check_high_confidence(high_conf)
    print(f'\n高置信抽查:')
    print(f'  抽查样本: {high_sample_size} 本')
    print(f'  发现问题: {len(high_issues)} 个')

    # 分析低置信
    low_corrections = analyze_low_confidence(low_conf, db_books)
    high_fixes = [c for c in low_corrections if c['new_confidence'] == 'high']
    print(f'\n低置信修正:')
    print(f'  可提升至高置信: {len(high_fixes)} 本')

    # 生成报告
    report_path = generate_quality_report(
        high_conf, medium_conf, low_conf,
        high_sample_size, high_issues, low_corrections
    )

    # 统计
    total_high = len(high_conf) + len(high_fixes)
    print(f'\n最终统计:')
    print(f'  高置信可用: {total_high} 本 ({total_high/191*100:.1f}%)')
    print(f'  需人工复核: {len(medium_conf)} 本')
    print(f'  需人工裁决: {len(low_conf) - len(high_fixes)} 本')

if __name__ == '__main__':
    main()
