# 【重构50】构建与发布基础设施审查报告

> 审查人：DevOps（Claude Code）
> 日期：2026-08-24
> 方式：只读检查，未执行任何构建命令
> 参考：docs/build_config_audit.md（【重构10】）、docs/release_pipeline.md（【重构23】）

---

## 1. SDK 版本与环境约束

| 项 | 值 | 来源 | 判定 |
|---|---|---|---|
| Dart SDK 约束 | `^3.13.0` | pubspec.yaml:22 | ✓ 合理 |
| Dart SDK 实际锁定 | `>=3.13.0 <4.0.0` | pubspec.lock:841 | ✓ 与约束一致 |
| Flutter SDK 最低要求 | `>=3.44.0` | pubspec.lock:842 | — 由依赖解析得出 |
| CI 固定 Flutter 版本 | `3.47.0` (stable) | .github/workflows/build.yml:19 | ✓ 显式锁定，好 |
| pubspec 中显式 Flutter 约束 | **无** | pubspec.yaml | ⚠️ 建议补充 |
| FVM / .flutter-version | **无** | 项目根目录 | — 未使用版本管理工具 |

**问题**：pubspec.yaml 只声明了 Dart SDK 约束，未声明 Flutter SDK 区间。CI 通过 `flutter-action` 固定了 3.47.0，但本地开发无此约束——团队成员 Flutter 版本不一致时可能产生不可复现的构建问题。

**建议**：在 `pubspec.yaml` 的 `environment` 块补充：
```yaml
environment:
  sdk: ^3.13.0
  flutter: ">=3.44.0"
```

---

## 2. 依赖健康状态

### 2.1 直接依赖清单（14 个）

| 包 | 版本约束 | 锁定版本 | 用途 | 判定 |
|---|---|---|---|---|
| cupertino_icons | ^1.0.8 | — | iOS 风格图标 | ✓ |
| sqflite | ^2.4.1 | — | SQLite（移动端） | ✓ |
| sqflite_common_ffi | ^2.3.4 | — | SQLite（Windows FFI） | ✓ |
| path_provider | ^2.1.5 | — | 应用目录路径 | ✓ |
| path | ^1.9.0 | — | 路径拼接 | ✓ |
| archive | ^3.6.1 | 3.6.1 | 解压 gzip | ✓ |
| provider | ^6.1.2 | — | 状态管理 | ✓ |
| shared_preferences | ^2.3.3 | — | 键值持久化 | ✓ |
| audioplayers | ^6.1.0 | — | 音频播放 | ⚠️ 与 just_audio 冗余 |
| flutter_svg | ^2.0.17 | — | SVG 渲染 | ✓ |
| crypto | ^3.0.6 | — | 哈希/加密 | ✓ |
| http | ^1.2.2 | — | HTTP 请求 | ✓ |
| http_parser | ^4.1.2 | — | HTTP 解析 | ✓ |
| encrypt | ^5.0.3 | — | AES 加密 | ✓ |
| just_audio | ^0.9.42 | — | 锁屏音频 | ⚠️ 与 audioplayers 冗余 |
| webview_flutter | ^4.10.0 | 4.14.1 | WebView | ✓ |

### 2.2 冗余依赖

**🔴 audioplayers + just_audio 并存**：两个音频播放库功能高度重叠。
- `audioplayers` 用于单词发音/例句播放
- `just_audio` 仅用于 `lock/lock_media.dart` 锁屏音频
- 建议统一为一个，减少包体积和音频焦点冲突

### 2.3 dev_dependencies

| 包 | 版本 | 判定 |
|---|---|---|
| flutter_test | SDK 内置 | ✓ 标准 |
| flutter_lints | ^6.0.0 | ✓ 但建议迁移到官方 `flutter_lints` → `lints` 或 `very_good_analysis` |

### 2.4 依赖安全

- 所有依赖均来自 pub.dev 官方源 ✓
- 无 git/path 依赖 ✓
- `publish_to: 'none'` 已设置 ✓
- 未发现已知高危漏洞包（需运行 `dart pub outdated` 确认是否有安全更新）

---

## 3. Windows 构建配置

### 3.1 CMakeLists.txt

| 项 | 值 | 判定 |
|---|---|---|
| project 名 | `word_app` | ⚠️ 需品牌化 |
| BINARY_NAME | `word_app` | ⚠️ 需改为 `MonsterWord` |
| CMake 最低版本 | 3.14 | ✓ |
| C++ 标准 | C++17 | ✓ |
| 编译选项 | `/W4 /WX /wd"4100"` | ✓ 严格模式 |

### 3.2 Runner.rc（Windows 元数据）

| 字段 | 当前值 | 判定 |
|---|---|---|
| CompanyName | `com.monsterword` | ✓ 已品牌化 |
| FileDescription | `word_app` | ⚠️ 需改为 `Monster Word` |
| InternalName | `word_app` | ⚠️ 需改 |
| OriginalFilename | `word_app.exe` | ⚠️ 需改为 `MonsterWord.exe` |
| ProductName | `word_app` | ⚠️ 需改 |
| LegalCopyright | `Copyright (C) 2026 com.monsterword` | ✓ |
| 版本号 | 由 Flutter 从 pubspec 自动注入 | ✓ 无需手改 |

### 3.3 main.cpp（窗口标题）

- 窗口标题：`L"word_app"` → ⚠️ 需改为 `L"Monster Word"`

### 3.4 应用图标

- `windows/runner/resources/app_icon.ico`（33,772 字节）→ ❌ **仍为 Flutter 默认蓝色图标**

---

## 4. Android 构建配置

### 4.1 build.gradle.kts

| 项 | 值 | 判定 |
|---|---|---|
| namespace | `com.monsterword.word_app` | ✓ 已品牌化 |
| applicationId | `com.monsterword.word_app` | ✓ |
| compileSdk | `flutter.compileSdkVersion` | ✓ 跟随 Flutter |
| minSdk | `flutter.minSdkVersion` | ✓ 跟随 Flutter |
| targetSdk | `flutter.targetSdkVersion` | ✓ 跟随 Flutter |
| Java 版本 | 17 | ✓ |
| Kotlin JVM Target | 17 | ✓ |
| release 签名 | `signingConfigs.getByName("debug")` | ❌ **仍是 debug keystore** |

### 4.2 AndroidManifest.xml

| 项 | 值 | 判定 |
|---|---|---|
| android:label | `"word_app"` | ⚠️ 需改为 `Monster Word` |
| INTERNET 权限（主 Manifest） | **缺失** | ❌ **release 包联网功能会失败** |
| INTERNET 权限（debug Manifest） | 有 | 仅调试生效 |

**🔴 高风险**：项目使用了 `http`、`webview_flutter` 等网络依赖，但主 Manifest 无 `<uses-permission android:name="android.permission.INTERNET"/>`。当前 release APK 的所有网络请求将静默失败。

### 4.3 Launcher 图标

- 5 个密度 mipmap（442–1443 字节）→ ❌ **全部为 Flutter 默认小图标**

### 4.4 启动屏

- `launch_background.xml`：`@android:color/white` 纯白 → ❌ 无品牌色
- `values-night/styles.xml`：同样白色 → ⚠️ 未做夜间差异化

### 4.5 签名安全

- `android/.gitignore` 已正确排除 `key.properties`、`**/*.keystore`、`**/*.jks` ✓
- `key.properties` 文件不存在（未生成 keystore）→ 正式发布前必须完成

---

## 5. .gitignore 审查

### 5.1 已正确排除的项

| 类别 | 排除项 | 判定 |
|---|---|---|
| Flutter 构建产物 | `.dart_tool/`, `build/`, `.flutter-plugins*` | ✓ |
| Android 构建 | `android/.gradle/`, `android/app/build/`, `android/local.properties` | ✓ |
| Android 签名 | `key.properties`, `*.keystore`, `*.jks` | ✓（在 android/.gitignore） |
| iOS | `ios/Pods/`, `ios/.symlinks/` | ✓ |
| Windows | `windows/flutter/ephemeral/` | ✓ |
| macOS/Linux | ephemeral 目录 | ✓ |
| 大文件 | `assets/db/wordbook.db.gz` | ✓ 正确排除（~33MB） |
| OS 垃圾 | `.DS_Store`, `Thumbs.db` | ✓ |
| IDE | `.idea/`, `.vscode/`, `*.iml` | ✓ |

### 5.2 潜在遗漏

| 项 | 风险 | 建议 |
|---|---|---|
| `release/` 目录 | 旧产物 zip（~44MB）可能被提交 | 建议添加 `release/` 或 `release/*.zip` |
| `*.dll` / `build/` 产物 | 低风险（已在 build/ 排除） | ✓ 无需额外处理 |

---

## 6. CI/CD 配置审查

### 6.1 工作流清单

| 文件 | 用途 | 状态 |
|---|---|---|
| `build.yml` | Windows Release 构建 | ⚠️ 有问题（见下） |
| `dart.yml` | Dart 分析+测试 | ⚠️ 不适用于 Flutter 项目 |
| `c-cpp.yml` | C/C++ CI（make） | ❌ **模板残留，与项目无关** |
| `cmake-multi-platform.yml` | CMake 多平台 | ❌ **模板残留，与项目无关** |
| `objective-c-xcode.yml` | Xcode 构建 | ❌ **模板残留，与项目无关** |
| `swift.yml` | Swift 构建 | ❌ **模板残留，与项目无关** |

### 6.2 build.yml 问题清单

| # | 问题 | 严重度 | 说明 |
|---|---|---|---|
| 1 | artifact 名 `bubei-word-windows` | 🟡 | 旧品牌拼音残留，应改为 `monsterword-windows` |
| 2 | `--no-fatal-warnings` | 🟡 | 分析步骤屏蔽了警告，建议移除以强制质量 |
| 3 | placeholder 词库 | 🟡 | CI 用 `echo placeholder > wordbook.db.gz`，构建产物不含真实词库 |
| 4 | 无 `flutter test` 步骤 | 🟡 | 只有 analyze + build，缺少测试环节 |
| 5 | 无缓存 | 🟢 | 未配置 Flutter/pub 缓存，每次全量下载 |

### 6.3 dart.yml 问题

- 使用 `dart analyze` 而非 `flutter analyze` → 对 Flutter 项目可能遗漏插件相关分析
- 使用 `dart test` 而非 `flutter test` → Flutter 测试需要 Flutter test runner
- 该文件可能是 GitHub 自动生成的模板，未针对项目调整

### 6.4 模板残留工作流

以下 4 个文件是 GitHub Actions starter workflow 模板，与本 Flutter 项目**完全无关**：
- `.github/workflows/c-cpp.yml` — 假设项目有 `./configure` + `make`
- `.github/workflows/cmake-multi-platform.yml` — 假设项目是 CMake 项目
- `.github/workflows/objective-c-xcode.yml` — 假设项目有 .xcodeproj
- `.github/workflows/swift.yml` — 假设项目是 Swift 包

**建议**：全部删除，避免混淆和无意义的 CI 运行（会一直失败）。

---

## 7. 构建环境健康度评分

| 维度 | 评分 | 权重 | 加权分 |
|---|---|---|---|
| SDK 与环境约束 | 7/10 | 15% | 1.05 |
| 依赖健康 | 6/10 | 20% | 1.20 |
| Windows 构建配置 | 4/10 | 20% | 0.80 |
| Android 构建配置 | 3/10 | 20% | 0.60 |
| .gitignore 完整性 | 8/10 | 10% | 0.80 |
| CI/CD 配置 | 3/10 | 15% | 0.45 |
| **总分** | | **100%** | **4.90 / 10** |

**等级：🟠 不合格（< 6.0）**

主要拉分项：
- Android release 签名仍是 debug keystore（发布阻断）
- Android 主 Manifest 缺 INTERNET 权限（功能阻断）
- CI 有 4/6 工作流是无关模板残留
- Windows/Android 品牌化几乎未开始

---

## 8. 改进建议（按优先级排序）

### P0 — 发布阻断（必须在首次发版前完成）

| # | 改进项 | 涉及文件 | 工作量 |
|---|---|---|---|
| 1 | Android 主 Manifest 补 INTERNET 权限 | `android/app/src/main/AndroidManifest.xml` | 1 行 |
| 2 | 生成 release keystore 并配置 signingConfig | `android/app/build.gradle.kts` + 外部密钥 | 半天 |
| 3 | 替换 Windows 应用图标 | `windows/runner/resources/app_icon.ico` | 10 分钟 |
| 4 | 替换 Android launcher 图标全套 | `android/app/src/main/res/mipmap-*/` | 10 分钟（flutter_launcher_icons） |

### P1 — 品牌化（统一改名）

| # | 改进项 | 涉及文件 |
|---|---|---|
| 5 | Windows：BINARY_NAME / 窗口标题 / Runner.rc 元数据 → `MonsterWord` | CMakeLists.txt, main.cpp, Runner.rc |
| 6 | Android：android:label → `Monster Word` | AndroidManifest.xml |
| 7 | pubspec：name/description/version | pubspec.yaml |

### P2 — CI/CD 清理与加固

| # | 改进项 |
|---|---|
| 8 | 删除 4 个无关模板工作流（c-cpp/cmake/objc/swift） |
| 9 | build.yml：artifact 名改为 `monsterword-windows` |
| 10 | build.yml：移除 `--no-fatal-warnings`，加 `flutter test` 步骤 |
| 11 | dart.yml：改为 `flutter analyze` + `flutter test`，或合并到 build.yml |
| 12 | build.yml：加 Flutter/pub 缓存（`subosito/flutter-action` 自带缓存选项） |

### P3 — 依赖优化

| # | 改进项 |
|---|---|
| 13 | 统一音频库：audioplayers 与 just_audio 择一 |
| 14 | pubspec 补充 Flutter SDK 约束 |
| 15 | 运行 `dart pub outdated` 检查过时依赖 |

### P4 — 补充

| # | 改进项 |
|---|---|
| 16 | 启动屏品牌化（浅色 #F2F0EB / 深色 #1E3932） |
| 17 | .gitignore 补充 `release/` 排除 |
| 18 | 考虑引入 FVM 统一团队 Flutter 版本 |

---

## 9. 与既有审计的关系

本报告为**独立复查**，结论与以下既有报告一致：

| 既有报告 | 本报告对应章节 | 一致性 |
|---|---|---|
| 【重构10】build_config_audit.md | §2–§6 | ✓ 完全一致 |
| 【重构23】release_pipeline.md | §4.1 签名、§6.2 CI | ✓ 完全一致 |

新增发现：
- CI 有 4 个无关模板工作流（既有报告未提及）
- pubspec.lock 显示 Flutter 最低要求 >=3.44.0（既有报告未锁版本分析）
- `assets/db/wordbook.db.gz` 在 .gitignore 中被排除（既有报告未确认此点）

---

*审查完成：DevOps（Claude Code）· 2026-08-24 · 只读，未执行构建*
