#!/usr/bin/env python3
"""
import 依赖检查脚本
检查所有页面的 import 依赖是否正确
"""

import re
from pathlib import Path
from collections import defaultdict

def scan_dart_files(base_path):
    """扫描所有 Dart 文件"""
    dart_files = []
    for pattern in ['lib/pages/*.dart', 'lib/screens/*.dart', 'lib/widgets/*.dart']:
        dart_files.extend(Path(base_path).glob(pattern))
    return dart_files

def extract_imports(file_path):
    """从 Dart 文件中提取 import 语句"""
    imports = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            # 匹配 import 语句
            import_pattern = r"import\s+'([^']+)'"
            imports = re.findall(import_pattern, content)
    except Exception as e:
        print(f'Error reading {file_path}: {e}')
    return imports

def check_import_validity(import_path, file_path, base_path):
    """检查 import 路径是否有效"""
    # 跳过 package imports
    if import_path.startswith('package:'):
        return True, 'package import'

    # 相对路径
    if import_path.startswith('../') or import_path.startswith('./'):
        # 计算实际路径
        file_dir = file_path.parent
        resolved = (file_dir / import_path).resolve()
        if resolved.exists():
            return True, 'relative path exists'
        else:
            return False, f'relative path not found: {resolved}'

    # 绝对路径（以 lib/ 开头）
    if import_path.startswith('lib/'):
        resolved = base_path / import_path
        if resolved.exists():
            return True, 'absolute path exists'
        else:
            return False, f'absolute path not found: {resolved}'

    return False, 'unknown import format'

def build_dependency_graph(dart_files, base_path):
    """构建依赖图"""
    graph = defaultdict(list)
    issues = []

    for file_path in dart_files:
        imports = extract_imports(file_path)
        file_key = str(file_path.relative_to(base_path))

        for imp in imports:
            # 检查 import 有效性
            is_valid, reason = check_import_validity(imp, file_path, base_path)

            if not is_valid:
                issues.append({
                    'file': file_key,
                    'import': imp,
                    'issue': reason
                })

            # 构建依赖图（只处理本地 import）
            if not imp.startswith('package:'):
                # 解析实际依赖文件
                if imp.startswith('../') or imp.startswith('./'):
                    resolved = (file_path.parent / imp).resolve()
                    dep_key = str(resolved.relative_to(base_path))
                elif imp.startswith('lib/'):
                    dep_key = imp
                else:
                    continue

                graph[file_key].append(dep_key)

    return graph, issues

def detect_cycles(graph):
    """检测循环依赖"""
    cycles = []
    visited = set()
    rec_stack = set()

    def dfs(node, path):
        visited.add(node)
        rec_stack.add(node)
        path.append(node)

        for neighbor in graph.get(node, []):
            if neighbor not in visited:
                if dfs(neighbor, path):
                    return True
            elif neighbor in rec_stack:
                # 找到循环
                cycle_start = path.index(neighbor)
                cycle = path[cycle_start:] + [neighbor]
                cycles.append(cycle)
                return True

        path.pop()
        rec_stack.remove(node)
        return False

    for node in graph:
        if node not in visited:
            dfs(node, [])

    return cycles

def analyze_dependencies(base_path):
    """分析依赖关系"""
    print('扫描 Dart 文件...')
    dart_files = scan_dart_files(base_path)
    print(f'找到 {len(dart_files)} 个文件')

    print('构建依赖图...')
    graph, issues = build_dependency_graph(dart_files, base_path)

    print('检测循环依赖...')
    cycles = detect_cycles(graph)

    # 统计
    total_files = len(dart_files)
    files_with_imports = len(graph)
    total_imports = sum(len(deps) for deps in graph.values())
    invalid_imports = len(issues)
    circular_deps = len(cycles)

    print(f'\n统计：')
    print(f'  总文件数：{total_files}')
    print(f'  有依赖的文件：{files_with_imports}')
    print(f'  总依赖数：{total_imports}')
    print(f'  无效导入：{invalid_imports}')
    print(f'  循环依赖：{circular_deps}')

    return graph, issues, cycles, dart_files

def generate_report(graph, issues, cycles, dart_files, base_path):
    """生成依赖报告"""
    report_path = Path('D:/claude/work/cn_com_lange/word_app/docs/import_dependency_report.md')

    with open(report_path, 'w', encoding='utf-8') as f:
        f.write('# Import 依赖检查报告\n\n')
        f.write('> 检查时间：2026-08-24\n')
        f.write('> 检查范围：lib/pages/、lib/screens/、lib/widgets/\n\n')

        # 总体统计
        f.write('## 一、总体统计\n\n')
        total_files = len(dart_files)
        files_with_imports = len(graph)
        total_imports = sum(len(deps) for deps in graph.values())
        f.write(f'- **总文件数**：{total_files}\n')
        f.write(f'- **有依赖的文件**：{files_with_imports}\n')
        f.write(f'- **总依赖数**：{total_imports}\n')
        f.write(f'- **无效导入**：{len(issues)}\n')
        f.write(f'- **循环依赖**：{len(cycles)}\n\n')

        # 无效导入
        if issues:
            f.write('## 二、无效导入\n\n')
            f.write('以下导入路径无法解析：\n\n')
            f.write('| 文件 | 导入路径 | 问题 |\n')
            f.write('|---|---|---|\n')
            for issue in issues:
                f.write(f"| {issue['file']} | {issue['import']} | {issue['issue']} |\n")
            f.write('\n')
        else:
            f.write('## 二、无效导入\n\n')
            f.write('✅ 未发现无效导入\n\n')

        # 循环依赖
        if cycles:
            f.write('## 三、循环依赖\n\n')
            f.write('发现以下循环依赖：\n\n')
            for i, cycle in enumerate(cycles, 1):
                f.write(f'### 循环 {i}\n\n')
                f.write('```\n')
                for j, node in enumerate(cycle):
                    f.write(node)
                    if j < len(cycle) - 1:
                        f.write(' → ')
                f.write('\n```\n\n')
        else:
            f.write('## 三、循环依赖\n\n')
            f.write('✅ 未发现循环依赖\n\n')

        # 依赖统计
        f.write('## 四、依赖统计\n\n')
        f.write('### 依赖最多的文件（Top 10）\n\n')
        sorted_deps = sorted(graph.items(), key=lambda x: len(x[1]), reverse=True)[:10]
        f.write('| 文件 | 依赖数 |\n')
        f.write('|---|---|\n')
        for file, deps in sorted_deps:
            f.write(f'| {file} | {len(deps)} |\n')
        f.write('\n')

        # 被依赖最多的文件（被引用）
        f.write('### 被依赖最多的文件（Top 10）\n\n')
        reverse_graph = defaultdict(list)
        for file, deps in graph.items():
            for dep in deps:
                reverse_graph[dep].append(file)

        sorted_reverse = sorted(reverse_graph.items(), key=lambda x: len(x[1]), reverse=True)[:10]
        f.write('| 文件 | 被引用数 |\n')
        f.write('|---|---|\n')
        for file, refs in sorted_reverse:
            f.write(f'| {file} | {len(refs)} |\n')
        f.write('\n')

        # 建议
        f.write('## 五、建议\n\n')
        if issues:
            f.write('### 无效导入处理\n\n')
            f.write('1. 检查导入路径是否正确\n')
            f.write('2. 确认文件是否存在\n')
            f.write('3. 修正路径或删除无效导入\n\n')

        if cycles:
            f.write('### 循环依赖处理\n\n')
            f.write('1. 分析循环依赖的原因\n')
            f.write('2. 考虑提取公共模块\n')
            f.write('3. 使用依赖注入或接口解耦\n\n')

        if not issues and not cycles:
            f.write('✅ 依赖关系健康，无明显问题\n\n')

    print(f'报告已生成: {report_path}')
    return report_path

def main():
    base_path = Path('D:/claude/work/cn_com_lange/word_app')
    graph, issues, cycles, dart_files = analyze_dependencies(base_path)
    generate_report(graph, issues, cycles, dart_files, base_path)

if __name__ == '__main__':
    main()
