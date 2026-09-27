# .gitignore 规则审计报告

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 方法：逐条审查 `.gitignore` 规则 + `git ls-files` 实际跟踪文件交叉验证

---

## 一、现状概览

| 维度 | 结果 |
|---|---|
| 根 .gitignore 行数 | 38 行 |
| 平台子 .gitignore | android ✅ / ios ✅ / windows ✅（空） / macos ❌ 缺失 / linux ❌ 缺失 |
| 实际跟踪文件数 | 311 个 |
| 跟踪的大文件 | `assets/db/wordbook.db.gz`（32.7MB）— 由 #121 单独处理 |
| 跟踪的敏感文件 | 无（keystore/key.properties 已被 android/.gitignore 覆盖） |
| 跟踪的临时文件 | **3 个**（见 §二.1） |

---

## 二、问题清单

### 2.1 🔴 需立即修复：被跟踪的临时/缓存文件

| 文件 | 问题 | 建议 |
|---|---|---|
| `android/.kotlin/errors/errors-1787331605354.log` | Kotlin 编译器错误日志，不应入库 | 根 .gitignore 添加 `android/.kotlin/` |
| `android/.kotlin/errors/errors-1787331605461.log` | 同上 | 同上 |
| `android/.kotlin/sessions/kotlin-compiler-*.salive` | Kotlin 编译器会话文件 | 同上 |

修复后需执行：`git rm --cached -r android/.kotlin/`

### 2.2 🟡 建议补充的规则

| 缺失规则 | 理由 | 优先级 |
|---|---|---|
| `android/.kotlin/` | Kotlin 编译器缓存，平台升级自动生成 | 🔴 高 |
| `*.log` | 通用日志文件（当前有 2 个 .log 被跟踪） | 🟡 中 |
| `.metadata` | Flutter 自动生成的元数据文件，当前被跟踪 | 🟡 中 |
| `coverage/` | `flutter test --coverage` 产出的覆盖率报告 | 🟡 中 |
| `doc/` | `dart doc` 产出的 API 文档目录 | 🟢 低 |
| `*.apk` / `*.aab` / `*.ipa` | 构建产物二进制（`release/` 已覆盖部分，但显式声明更安全） | 🟢 低 |

### 2.3 🟡 平台子 .gitignore 缺失

| 平台 | 状态 | 风险 |
|---|---|---|
| `macos/` | 无 `.gitignore` 文件 | 低——根规则 `macos/Pods/` 和 `macos/Flutter/ephemeral/` 已覆盖关键目录 |
| `linux/` | 无 `.gitignore` 文件 | 低——根规则 `linux/flutter/ephemeral/` 已覆盖 |
| `windows/` | `.gitignore` 存在但**为空** | 低——根规则 `windows/flutter/ephemeral/` 已覆盖 |

> Flutter `flutter create` 模板会为每个平台生成 `.gitignore`，但本项目仅 android 和 ios 保留了完整模板。建议补充 macos/linux/windows 的标准模板。

### 2.4 🟢 规则冗余（无害，仅记录）

| 根规则 | 子规则 | 重叠 |
|---|---|---|
| `ios/Pods/` | `ios/.gitignore`: `**/Pods/` | 重复，无害 |
| `android/.gradle/` | `android/.gitignore`: `/.gradle` | 重复，无害 |

---

## 三、覆盖良好的部分

| 类别 | 覆盖规则 | 评价 |
|---|---|---|
| Flutter 构建产物 | `.dart_tool/`, `build/`, `.flutter-plugins*`, `.packages` | ✅ 完整 |
| IDE 文件 | `.idea/`, `.vscode/`, `*.iml` | ✅ 完整 |
| Android | `.gradle/`, `app/build/`, `local.properties`, `key.properties`, `*.keystore`, `*.jks` | ✅ 完整 |
| iOS | `Pods/`, `xcuserdata/`, `.symlinks/`, `GeneratedPluginRegistrant` | ✅ 完整 |
| Windows | `flutter/ephemeral/`, VS 缓存/构建目录 | ✅ 基本覆盖 |
| OS 临时文件 | `.DS_Store`, `Thumbs.db` | ✅ 完整 |
| 构建产物 | `release/` | ✅ 已覆盖 |

---

## 四、建议的根 .gitignore 补充（追加到末尾）

```gitignore
# Kotlin compiler cache
android/.kotlin/

# Logs
*.log

# Flutter metadata
.metadata

# Test coverage
coverage/

# Dartdoc output
doc/

# Build artifacts (explicit)
*.apk
*.aab
*.ipa
```

---

## 五、执行清单

| 步骤 | 命令 | 说明 |
|---|---|---|
| 1 | 编辑根 `.gitignore` 追加 §四 规则 | 无需提交先 |
| 2 | `git rm --cached -r android/.kotlin/` | 从索引移除已跟踪的缓存文件 |
| 3 | `git rm --cached .metadata` | 从索引移除 Flutter 元数据 |
| 4 | `git commit -m "chore: update .gitignore rules"` | 提交规则变更 + 索引清理 |

> 注：`assets/db/wordbook.db.gz`（32.7MB）的 Git 策略由 #121 单独处理，本报告不涉及。
