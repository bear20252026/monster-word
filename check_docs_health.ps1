# Document Health Check Script
$docsPath = "D:\claude\work\cn_com_lange\word_app\docs"
$projectRoot = "D:\claude\work\cn_com_lange\word_app"

# Initialize counters and arrays
$totalFiles = 0
$validFiles = 0
$emptyFiles = @()
$truncatedFiles = @()
$invalidLinks = @()
$validLinks = @()
$missingPaths = @()
$missingCommits = @()

# Get all markdown files
$mdFiles = Get-ChildItem -Path $docsPath -Recurse -Filter "*.md"

foreach ($file in $mdFiles) {
    $totalFiles++
    $relativePath = $file.FullName.Replace($projectRoot, ".").Replace("\", "/")

    # Read file content
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($content)) {
        $emptyFiles += $relativePath
        continue
    }

    # Check for truncation (less than 50 chars is suspiciously short for a doc)
    if ($content.Length -lt 50) {
        $truncatedFiles += $relativePath
        continue
    }

    $validFiles++

    # Extract markdown links
    $matches = [regex]::Matches($content, '\[([^\]]+)\]\(([^)]+)\)')

    foreach ($match in $matches) {
        $linkTarget = $match.Groups[2].Value

        # Skip external URLs and anchors
        if ($linkTarget -match '^(https?://|#|mailto:)') { continue }

        # Remove anchors
        $linkTarget = $linkTarget.Split('#')[0]

        # Skip empty links
        if ([string]::IsNullOrWhiteSpace($linkTarget)) { continue }

        # Resolve the link path
        $resolvedPath = $null
        if ($linkTarget.StartsWith("./")) {
            $resolvedPath = Join-Path $docsPath $linkTarget.Substring(2)
        } elseif ($linkTarget.StartsWith("../")) {
            $resolvedPath = Join-Path $projectRoot $linkTarget.Substring(3)
        } else {
            $resolvedPath = Join-Path $docsPath $linkTarget
        }

        # Normalize path
        $resolvedPath = [System.IO.Path]::GetFullPath($resolvedPath)

        if (-not (Test-Path $resolvedPath)) {
            $invalidLinks += @{
                file = $relativePath
                link = $linkTarget
                resolvedPath = $resolvedPath.Replace($projectRoot, ".").Replace("\", "/")
            }
        } else {
            $validLinks += @{
                file = $relativePath
                link = $linkTarget
            }
        }
    }

    # Check for file path references
    $pathMatches = [regex]::Matches($content, '(?:src|path|file|directory)["\s:=]+([a-zA-Z0-9_\-/\\]+\.(?:ts|tsx|js|jsx|json|css|scss))')

    foreach ($pathMatch in $pathMatches) {
        $referencedPath = $pathMatch.Groups[1].Value
        $resolvedPath = Join-Path $projectRoot $referencedPath

        if (-not (Test-Path $resolvedPath)) {
            $missingPaths += @{
                file = $relativePath
                path = $referencedPath
            }
        }
    }
}

# Generate report
$report = @"
# 文档健康度检查报告

**检查时间**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**项目路径**: $projectRoot
**文档目录**: $docsPath

## 统计概览

| 指标 | 数量 |
|------|------|
| 文档总数 | $totalFiles |
| 有效文件 | $validFiles |
| 空文件 | $($emptyFiles.Count) |
| 截断文件 | $($truncatedFiles.Count) |
| 有效链接 | $($validLinks.Count) |
| 无效链接 | $($invalidLinks.Count) |
| 缺失文件路径引用 | $($missingPaths.Count) |

## 空文件清单

"@

if ($emptyFiles.Count -gt 0) {
    foreach ($file in $emptyFiles) {
        $report += "- $file" + "`n"
    }
} else {
    $report += "无空文件。" + "`n"
}

$report += @"

## 截断文件清单（内容长度 < 50 字符）

"@

if ($truncatedFiles.Count -gt 0) {
    foreach ($file in $truncatedFiles) {
        $report += "- $file" + "`n"
    }
} else {
    $report += "无截断文件。" + "`n"
}

$report += @"

## 无效链接清单

"@

if ($invalidLinks.Count -gt 0) {
    $sortedLinks = $invalidLinks | Sort-Object file
    foreach ($link in $sortedLinks) {
        $report += "- **$($link.file)**: 链接 `"$($link.link)`" -> 期望路径: $($link.resolvedPath)" + "`n"
    }
} else {
    $report += "所有内部链接均有效。" + "`n"
}

$report += @"

## 缺失文件路径引用

"@

if ($missingPaths.Count -gt 0) {
    $sortedPaths = $missingPaths | Sort-Object file
    foreach ($path in $sortedPaths) {
        $report += "- **$($path.file)**: 引用路径 `"$($path.path)`" 不存在" + "`n"
    }
} else {
    $report += "未发现缺失的文件路径引用。" + "`n"
}

$report += @"

## 建议修复项

### 高优先级
"@

if ($emptyFiles.Count -gt 0) {
    $report += @"

1. **修复空文件**: 以下文件为空，需要填充内容或删除
"@
    foreach ($file in $emptyFiles) {
        $report += "   - $file" + "`n"
    }
}

if ($truncatedFiles.Count -gt 0) {
    $report += @"

2. **修复截断文件**: 以下文件内容不完整，需要补充
"@
    foreach ($file in $truncatedFiles) {
        $report += "   - $file" + "`n"
    }
}

$report += @"

### 中优先级
"@

if ($invalidLinks.Count -gt 0) {
    $uniqueFiles = $invalidLinks | Select-Object -ExpandProperty file -Unique
    $report += @"

3. **修复无效链接**: 以下文档包含指向不存在目标的链接
"@
    foreach ($file in $uniqueFiles) {
        $linkCount = ($invalidLinks | Where-Object { $_.file -eq $file }).Count
        $report += "   - $file : $linkCount 个无效链接" + "`n"
    }
}

$report += @"

### 低优先级
"@

if ($missingPaths.Count -gt 0) {
    $uniquePathFiles = $missingPaths | Select-Object -ExpandProperty file -Unique
    $report += @"

4. **验证文件路径引用**: 以下文档引用了不存在的代码/配置文件路径
"@
    foreach ($file in $uniquePathFiles) {
        $report += "   - $file" + "`n"
    }
}

$report += @"

---

**报告生成器**: Document Health Check Script
**约束**: 未修改任何文档，仅生成报告
"@

# Save report
$reportPath = Join-Path $docsPath "documentation_health_report.md"
$report | Out-File -FilePath $reportPath -Encoding UTF8 -Force

Write-Host "报告已生成: $reportPath"
Write-Host "总文件数: $totalFiles"
Write-Host "有效文件: $validFiles"
Write-Host "空文件: $($emptyFiles.Count)"
Write-Host "截断文件: $($truncatedFiles.Count)"
Write-Host "有效链接: $($validLinks.Count)"
Write-Host "无效链接: $($invalidLinks.Count)"
