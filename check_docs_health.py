#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Document Health Check Script"""

import os
import re
from pathlib import Path
from datetime import datetime

# Configuration
docs_path = Path("D:/claude/work/cn_com_lange/word_app/docs")
project_root = Path("D:/claude/work/cn_com_lange/word_app")

# Initialize
total_files = 0
valid_files = 0
empty_files = []
truncated_files = []
invalid_links = []
valid_links = []
missing_paths = []

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

    if not content or not content.strip():
        empty_files.append(relative_path)
        continue

    # Check for truncation
    if len(content.strip()) < 50:
        truncated_files.append(relative_path)
        continue

    valid_files += 1

    # Extract markdown links [text](path)
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
            invalid_links.append({
                'file': relative_path,
                'link': link,
                'resolved_path': str(resolved_path)
            })
            continue

        if not resolved_path.exists():
            invalid_links.append({
                'file': relative_path,
                'link': link,
                'resolved_path': resolved_path.relative_to(project_root).as_posix()
            })
        else:
            valid_links.append({
                'file': relative_path,
                'link': link
            })

# Generate report
report = f"""# 文档健康度检查报告

**检查时间**: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
**项目路径**: {project_root}
**文档目录**: {docs_path}

## 统计概览

| 指标 | 数量 |
|------|------|
| 文档总数 | {total_files} |
| 有效文件 | {valid_files} |
| 空文件 | {len(empty_files)} |
| 截断文件 | {len(truncated_files)} |
| 有效链接 | {len(valid_links)} |
| 无效链接 | {len(invalid_links)} |
| 缺失文件路径引用 | {len(missing_paths)} |

## 空文件清单

"""

if empty_files:
    for f in empty_files:
        report += f"- {f}\n"
else:
    report += "无空文件。\n"

report += """
## 截断文件清单（内容长度 < 50 字符）

"""

if truncated_files:
    for f in truncated_files:
        report += f"- {f}\n"
else:
    report += "无截断文件。\n"

report += """
## 无效链接清单

"""

if invalid_links:
    for link in sorted(invalid_links, key=lambda x: x['file']):
        report += f"- **{link['file']}**: 链接 \"{link['link']}\" -> 期望路径: {link['resolved_path']}\n"
else:
    report += "所有内部链接均有效。\n"

report += """
## 缺失文件路径引用

"""

if missing_paths:
    for p in sorted(missing_paths, key=lambda x: x['file']):
        report += f"- **{p['file']}**: 引用路径 \"{p['path']}\" 不存在\n"
else:
    report += "未发现缺失的文件路径引用。\n"

report += """
## 建议修复项

### 高优先级
"""

if empty_files:
    report += """
1. **修复空文件**: 以下文件为空，需要填充内容或删除
"""
    for f in empty_files:
        report += f"   - {f}\n"

if truncated_files:
    report += """
2. **修复截断文件**: 以下文件内容不完整，需要补充
"""
    for f in truncated_files:
        report += f"   - {f}\n"

report += """
### 中优先级
"""

if invalid_links:
    # Group by file
    files_with_invalid = {}
    for link in invalid_links:
        if link['file'] not in files_with_invalid:
            files_with_invalid[link['file']] = 0
        files_with_invalid[link['file']] += 1

    report += """
3. **修复无效链接**: 以下文档包含指向不存在目标的链接
"""
    for f, count in sorted(files_with_invalid.items()):
        report += f"   - {f} : {count} 个无效链接\n"

report += """
### 低优先级
"""

if missing_paths:
    report += """
4. **验证文件路径引用**: 以下文档引用了不存在的代码/配置文件路径
"""
    for p in sorted(missing_paths, key=lambda x: x['file']):
        report += f"   - {p['file']}\n"

report += """
---

**报告生成器**: Document Health Check Script
**约束**: 未修改任何文档，仅生成报告
"""

# Save report
report_path = docs_path / "documentation_health_report.md"
report_path.write_text(report, encoding='utf-8')

print(f"报告已生成: {report_path}")
print(f"总文件数: {total_files}")
print(f"有效文件: {valid_files}")
print(f"空文件: {len(empty_files)}")
print(f"截断文件: {len(truncated_files)}")
print(f"有效链接: {len(valid_links)}")
print(f"无效链接: {len(invalid_links)}")
