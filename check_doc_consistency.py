#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Documentation Consistency Audit Script"""

import os
import re
from pathlib import Path
from datetime import datetime

# Configuration
docs_path = Path("D:/claude/work/cn_com_lange/word_app/docs")
project_root = Path("D:/claude/work/cn_com_lange/word_app")

# Initialize
total_files = 0
issues = {
    'cross_references': [],
    'version_mismatch': [],
    'app_name_mismatch': [],
    'outdated_info': [],
    'todo_placeholders': []
}

# Get all markdown files
md_files = list(docs_path.rglob("*.md"))

for file in md_files:
    total_files += 1
    relative_path = file.relative_to(project_root).as_posix()

    # Read file content
    try:
        content = file.read_text(encoding='utf-8')
    except:
        continue

    # 1. Check cross-references
    link_pattern = r'\[([^\]]+)\]\(([^)]+)\)'
    links = re.findall(link_pattern, content)

    for text, link in links:
        # Skip external URLs and anchors
        if link.startswith(('http://', 'https://', '#', 'mailto:')):
            continue

        # Remove anchors
        link = link.split('#')[0]

        # Skip empty links
        if not link:
            continue

        # Resolve the link path
        if link.startswith("./"):
            resolved_path = docs_path / link[2:]
        elif link.startswith("../"):
            resolved_path = project_root / link[3:]
        else:
            resolved_path = docs_path / link

        # Normalize path
        try:
            resolved_path = resolved_path.resolve()
        except:
            issues['cross_references'].append({
                'file': relative_path,
                'link': link,
                'error': 'Invalid path'
            })
            continue

        if not resolved_path.exists():
            issues['cross_references'].append({
                'file': relative_path,
                'link': link,
                'expected': resolved_path.relative_to(project_root).as_posix()
            })

    # 2. Check version number
    version_patterns = [
        r'v?(\d+\.\d+\.\d+)',
        r'版本[：:]\s*(\d+\.\d+\.\d+)',
        r'Version[：:]\s*(\d+\.\d+\.\d+)',
        r'(\d+\.\d+\.\d+)\+?\d*'
    ]

    for pattern in version_patterns:
        versions = re.findall(pattern, content)
        for version in versions:
            if version != '2.0.0' and version != '2.0.0+2':
                issues['version_mismatch'].append({
                    'file': relative_path,
                    'version': version,
                    'expected': '2.0.0'
                })

    # 3. Check app name
    old_names = ['不背单词', 'Mistral AI', 'Mistral', 'UnlearnableWord']
    new_name = 'Monster Word'

    for old_name in old_names:
        if old_name.lower() in content.lower():
            # Find the line with the old name
            for i, line in enumerate(content.split('\n'), 1):
                if old_name.lower() in line.lower():
                    issues['app_name_mismatch'].append({
                        'file': relative_path,
                        'line': i,
                        'found': old_name,
                        'expected': new_name,
                        'context': line[:100]
                    })
                    break

    # 4. Check for outdated information
    outdated_keywords = ['Mistral风格', 'Mistral AI风格', 'AI风格重构', '日落渐变条']
    for keyword in outdated_keywords:
        if keyword in content:
            # Find the line with outdated info
            for i, line in enumerate(content.split('\n'), 1):
                if keyword in line:
                    issues['outdated_info'].append({
                        'file': relative_path,
                        'line': i,
                        'keyword': keyword,
                        'context': line[:100]
                    })
                    break

    # 5. Check for TODO/placeholder
    todo_patterns = [r'TODO', r'TBD', r'PLACEHOLDER', r'占位', r'待定', r'待完善']
    for pattern in todo_patterns:
        todos = re.finditer(pattern, content, re.IGNORECASE)
        for todo in todos:
            # Find the line with TODO
            line_start = content.rfind('\n', 0, todo.start()) + 1
            line_end = content.find('\n', todo.end())
            if line_end == -1:
                line_end = len(content)
            line = content[line_start:line_end]
            line_num = content[:todo.start()].count('\n') + 1

            issues['todo_placeholders'].append({
                'file': relative_path,
                'line': line_num,
                'type': todo.group(),
                'context': line.strip()[:100]
            })

# Generate report
report = f"""# 文档一致性审查报告

**检查时间**: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
**项目路径**: {project_root}
**文档目录**: {docs_path}

---

## 一、统计概览

| 指标 | 数量 |
|------|------|
| 文档总数 | {total_files} |
| 交叉引用问题 | {len(issues['cross_references'])} |
| 版本号不一致 | {len(issues['version_mismatch'])} |
| 应用名不一致 | {len(issues['app_name_mismatch'])} |
| 过时信息 | {len(issues['outdated_info'])} |
| TODO/占位符 | {len(issues['todo_placeholders'])} |

---

## 二、交叉引用问题

"""

if issues['cross_references']:
    for ref in sorted(issues['cross_references'], key=lambda x: x['file']):
        if 'error' in ref:
            report += f"- **{ref['file']}**: 链接 \"{ref['link']}\" 错误: {ref['error']}\n"
        else:
            report += f"- **{ref['file']}**: 链接 \"{ref['link']}\" -> 期望路径: {ref.get('expected', 'N/A')}\n"
else:
    report += "✅ 所有交叉引用有效\n"

report += """
---

## 三、版本号不一致

"""

if issues['version_mismatch']:
    for ver in sorted(issues['version_mismatch'], key=lambda x: x['file']):
        report += f"- **{ver['file']}**: 发现版本号 \"{ver['version']}\"（应为 {ver['expected']}）\n"
else:
    report += "✅ 所有版本号一致为 2.0.0\n"

report += """
---

## 四、应用名不一致

"""

if issues['app_name_mismatch']:
    for name in sorted(issues['app_name_mismatch'], key=lambda x: x['file']):
        report += f"- **{name['file']}** (行 {name['line']}): 发现 \"{name['found']}\"（应为 {name['expected']}）\n"
        report += f"  - 上下文: {name['context']}\n"
else:
    report += "✅ 所有应用名一致为 Monster Word\n"

report += """
---

## 五、过时信息

"""

if issues['outdated_info']:
    for info in sorted(issues['outdated_info'], key=lambda x: x['file']):
        report += f"- **{info['file']}** (行 {info['line']}): 关键词 \"{info['keyword']}\"\n"
        report += f"  - 上下文: {info['context']}\n"
else:
    report += "✅ 未发现过时信息\n"

report += """
---

## 六、TODO/占位符

"""

if issues['todo_placeholders']:
    for todo in sorted(issues['todo_placeholders'], key=lambda x: x['file']):
        report += f"- **{todo['file']}** (行 {todo['line']}): {todo['type']}\n"
        report += f"  - 上下文: {todo['context']}\n"
else:
    report += "✅ 未发现 TODO 或占位符\n"

report += """
---

## 七、建议修复项

### 高优先级

"""

if issues['app_name_mismatch']:
    report += "1. **统一应用名**: 以下文档中存在旧的应用名（不背单词/Mistral AI/Mistral/UnlearnableWord）\n"
    unique_files = set(name['file'] for name in issues['app_name_mismatch'])
    for f in sorted(unique_files):
        count = sum(1 for name in issues['app_name_mismatch'] if name['file'] == f)
        report += f"   - {f}: {count} 处\n"

if issues['version_mismatch']:
    report += """
2. **统一版本号**: 以下文档中存在不一致的版本号
"""
    unique_files = set(ver['file'] for ver in issues['version_mismatch'])
    for f in sorted(unique_files):
        versions = [ver['version'] for ver in issues['version_mismatch'] if ver['file'] == f]
        report += f"   - {f}: 发现 {', '.join(set(versions))}\n"

report += """
### 中优先级

"""

if issues['outdated_info']:
    report += "3. **清理过时信息**: 以下文档中存在过时的内容\n"
    unique_files = set(info['file'] for info in issues['outdated_info'])
    for f in sorted(unique_files):
        keywords = [info['keyword'] for info in issues['outdated_info'] if info['file'] == f]
        report += f"   - {f}: {', '.join(set(keywords))}\n"

report += """
### 低优先级

"""

if issues['todo_placeholders']:
    report += "4. **处理 TODO/占位符**: 以下文档中存在未完成项\n"
    unique_files = set(todo['file'] for todo in issues['todo_placeholders'])
    for f in sorted(unique_files):
        todo_count = sum(1 for todo in issues['todo_placeholders'] if todo['file'] == f)
        report += f"   - {f}: {todo_count} 处 TODO/占位符\n"

if issues['cross_references']:
    report += """
5. **修复无效链接**: 以下文档包含指向不存在目标的链接
"""
    unique_files = set(ref['file'] for ref in issues['cross_references'])
    for f in sorted(unique_files):
        link_count = sum(1 for ref in issues['cross_references'] if ref['file'] == f)
        report += f"   - {f}: {link_count} 个无效链接\n"

report += """
---

## 八、一致性评估

| 维度 | 状态 | 说明 |
|------|------|------|
| 交叉引用 | """ + ("✅ 通过" if not issues['cross_references'] else f"⚠️ {len(issues['cross_references'])} 个问题") + """ | 文档间引用完整性 |
| 版本号 | """ + ("✅ 统一" if not issues['version_mismatch'] else f"⚠️ {len(issues['version_mismatch'])} 处不一致") + """ | 版本标识一致性 |
| 应用名 | """ + ("✅ 统一" if not issues['app_name_mismatch'] else f"❌ {len(issues['app_name_mismatch'])} 处不一致") + """ | 品牌标识一致性 |
| 过时信息 | """ + ("✅ 已清理" if not issues['outdated_info'] else f"⚠️ {len(issues['outdated_info'])} 处") + """ | 内容时效性 |
| TODO/占位符 | """ + ("✅ 无" if not issues['todo_placeholders'] else f"⚠️ {len(issues['todo_placeholders'])} 处") + """ | 文档完整性 |

**总体评估**: """ + ("✅ 优秀" if not any([issues['cross_references'], issues['version_mismatch'], issues['app_name_mismatch']]) else "⚠️ 需修复") + """

---

*审查报告生成器: Documentation Consistency Audit Script*
*约束: 未修改任何文档，仅生成报告*
"""

# Save report
report_path = docs_path / "documentation_consistency_audit.md"
report_path.write_text(report, encoding='utf-8')

print(f"报告已生成: {report_path}")
print(f"总文件数: {total_files}")
print(f"交叉引用问题: {len(issues['cross_references'])}")
print(f"版本号不一致: {len(issues['version_mismatch'])}")
print(f"应用名不一致: {len(issues['app_name_mismatch'])}")
print(f"过时信息: {len(issues['outdated_info'])}")
print(f"TODO/占位符: {len(issues['todo_placeholders'])}")
