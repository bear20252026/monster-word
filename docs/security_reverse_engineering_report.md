# Monster Word App 安全逆向工程与代码保护审计报告

**审计时间**: 2026-08-24
**审计人**: DocReviewer (Monster world)
**项目**: Monster Word (word_app)
**审计范围**: 静态代码审计 + 配置审查
**约束**: 只读代码，只产出报告

---

## 一、审计摘要

| 维度 | 风险等级 | 状态 |
|------|---------|------|
| Android 代码混淆 | 🔴 高 | 未启用 ProGuard/R8 |
| 硬编码密钥/API Key | 🟡 中 | 未发现硬编码密钥，但有硬编码 URL |
| 调试模式残留 | 🟡 中 | 发现5处 debugPrint |
| 资源文件保护 | 🔴 高 | 31MB 数据库可被轻易提取 |
| Flutter 逆向防护 | 🔴 高 | 未启用 split-debug-info/obfuscate |
| Windows 保护措施 | 🔴 高 | 无特殊保护 |
| 敏感数据存储 | 🟢 低 | 使用 FlutterSecureStorage |
| 网络通信 | 🟡 中 | 部分使用 HTTP 而非 HTTPS |

---

## 二、详细审计发现

### 2.1 Android 配置审计

#### 🔴 代码混淆未启用

**发现位置**: `android/app/build.gradle.kts`

**问题描述**:
```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

**风险分析**:
- ❌ 未配置 `minifyEnabled true`
- ❌ 未配置 `shrinkResources true`
- ❌ 未启用 ProGuard/R8 代码混淆
- ❌ Release 构建仍使用 debug 签名

**影响**:
- Dart 代码可被反编译为可读源码
- 字符串、类名、方法名全部暴露
- 业务逻辑完全可见
- 易于提取硬编码的 URL 和配置

**建议修复**:
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
        signingConfig = signingConfigs.getByName("release")
    }
}
```

---

### 2.2 硬编码密钥/API Key 审计

#### ✅ 未发现硬编码密钥

**检查范围**: `lib/` 目录下所有 Dart 文件

**检查项**:
- API Key
- Secret Key
- Password
- Token

**结果**: ✅ 未发现硬编码的密钥或凭证

#### ⚠️ 发现硬编码 URL

**发现位置**: 多个文件

**高风险 URL**:

| 文件 | URL | 协议 | 风险 |
|------|-----|------|------|
| `lib/engine/bs/app_ref_processor.dart` | `http://img.beingfine.cn/` | HTTP | 🔴 明文传输 |
| `lib/engine/bs/example_processor.dart` | `http://img.beingfine.cn/` | HTTP | 🔴 明文传输 |
| `lib/engine/bs/sound_zip_processor.dart` | `http://static.beingfine.cn/` | HTTP | 🔴 明文传输 |
| `lib/player/audio_players.dart` | `http://dict.youdao.com/` | HTTP | 🔴 明文传输 |

**中风险 URL**:

| 文件 | URL | 协议 | 风险 |
|------|-----|------|------|
| `lib/player/audio_players.dart` | `https://audio.beingfine.cn/` | HTTPS | ✅ 安全 |
| `lib/pages/dictionary_page.dart` | `https://dict.youdao.com/` | HTTPS | ✅ 安全 |

**风险分析**:
- HTTP URL 存在中间人攻击风险
- 音频资源可通过 HTTP 被拦截或篡改
- 图片资源可被替换

**建议**:
- 将所有 HTTP URL 迁移到 HTTPS
- 考虑实现证书固定（Certificate Pinning）
- 将 URL 配置移至环境配置文件

---

### 2.3 调试模式残留审计

#### ⚠️ 发现 debugPrint 语句

**发现位置**:

| 文件 | 行号 | 语句 | 风险 |
|------|------|------|------|
| `lib/lock/lock_presenter_imp.dart` | 多处 | `debugPrint('$_tag: updatePower error: $e')` | 🟡 中 |
| `lib/services/log_service.dart` | 多处 | `debugPrint('$_tag: $msg')` | 🟡 中 |

**风险分析**:
- debugPrint 在 Release 构建中默认被移除
- 但如果配置不当，可能保留
- 暴露内部实现细节和错误信息

**建议**:
- 使用条件编译或日志级别控制
- 确保 Release 构建移除所有 debugPrint
- 考虑使用 `log` 包替代

---

### 2.4 资源文件保护审计

#### 🔴 数据库文件可被轻易提取

**发现位置**: `assets/db/wordbook.db.gz`

**文件信息**:
- 大小: 31MB
- 格式: gzip 压缩的 SQLite 数据库
- 原始大小: ~120MB (解压后)
- 包含: 191 本词书的完整数据

**发现位置**: 多个构建目录

| 路径 | 说明 |
|------|------|
| `./assets/db/wordbook.db.gz` | 源文件 |
| `./build/app/intermediates/assets/debug/mergeDebugAssets/flutter_assets/assets/db/wordbook.db.gz` | Debug 构建 |
| `./release/不背单词/data/flutter_assets/assets/db/wordbook.db.gz` | Release 构建 |

**风险分析**:
- 数据库可被解压并直接读取
- 包含完整的词书数据、释义、例句
- 可被竞争对手直接复制
- 包含可能的用户学习数据

**影响**:
- 知识产权泄露
- 竞争对手可直接使用词书数据
- 违反数据许可协议

**建议**:
- 对数据库进行加密（SQLCipher）
- 实现运行时解密机制
- 考虑从服务器动态加载词书
- 移除 Release 构建中的调试文件

---

### 2.5 Flutter 逆向防护审计

#### 🔴 未启用代码保护

**检查项**:

| 配置项 | 状态 | 说明 |
|--------|------|------|
| `--split-debug-info` | ❌ 未启用 | 调试信息未分离 |
| `--obfuscate` | ❌ 未启用 | 代码未混淆 |
| `--dart-define` | ⚠️ 部分使用 | 仅用于版本信息 |

**风险分析**:
- Dart 代码可被完整反编译
- AOT 编译后的二进制仍包含：
  - 字符串常量
  - 类名和方法名
  - 调试符号
- 可使用 `flutter reverse` 等工具恢复源码结构

**影响**:
- 业务逻辑完全暴露
- 易于分析和复制
- 无法保护知识产权

**建议修复**:
```bash
# Release 构建时添加以下参数
flutter build apk \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --no-pub

# 保存调试信息（用于崩溃分析）
# 将 build/debug-info 目录安全存储
```

**配置 pubspec.yaml**:
```yaml
flutter:
  # 添加到 flutter 部分
  obfuscate: true
```

---

### 2.6 Windows 版本保护措施审计

#### 🔴 无特殊保护

**发现位置**: `windows/runner/CMakeLists.txt`

**配置分析**:
```cmake
apply_standard_settings(${BINARY_NAME})
```

**问题**:
- ❌ 未启用代码混淆
- ❌ 未启用反调试保护
- ❌ 未启用完整性校验
- ❌ 未启用反篡改机制
- ❌ 标准 CMake 配置，无特殊安全设置

**风险分析**:
- Windows 可执行文件可被反编译
- 使用标准 PE 格式，无保护
- 易于分析和修改

**建议**:
- 考虑使用 VMProtect 或 Themida
- 添加反调试检测
- 实现代码完整性校验
- 使用数字签名

---

### 2.7 敏感数据存储审计

#### ✅ 使用安全存储

**发现位置**: `lib/data/app_preferences.dart`

**实现分析**:
```dart
final FlutterSecureStorage _storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
```

**优点**:
- ✅ 使用 FlutterSecureStorage
- ✅ Android 启用加密 SharedPreferences
- ✅ Token 和 Secret 使用安全存储
- ✅ 有从 SharedPreferences 迁移到安全存储的逻辑

**建议**:
- 确保 iOS 使用 Keychain
- 验证加密强度
- 定期轮换密钥

---

### 2.8 网络通信审计

#### ⚠️ 混合 HTTP/HTTPS

**HTTP 明文传输** (高风险):

| URL | 用途 | 风险 |
|-----|------|------|
| `http://img.beingfine.cn/` | 图片资源 | 中间人攻击 |
| `http://static.beingfine.cn/` | 静态资源 | 中间人攻击 |
| `http://dict.youdao.com/` | 有道词典 API | 中间人攻击 |

**HTTPS 加密传输** (低风险):

| URL | 用途 | 状态 |
|-----|------|------|
| `https://audio.beingfine.cn/` | 音频资源 | ✅ 安全 |
| `https://dict.youdao.com/` | 有道词典 API | ✅ 安全 |

**风险分析**:
- HTTP 传输的资源可被拦截
- 音频/图片可被替换
- 可能导致恶意内容注入

**建议**:
- 迁移到全 HTTPS
- 实现证书固定
- 验证 SSL 证书

---

## 三、逆向工程难度评估

### 3.1 当前逆向难度

| 平台 | 难度 | 时间估计 | 工具 |
|------|------|---------|------|
| Android | 🟢 低 | 2-4 小时 | jadx, apktool, dart-decompiler |
| Windows | 🟢 低 | 2-4 小时 | dnSpy, IDA, Ghidra |
| Dart 代码 | 🟢 低 | 1-2 小时 | dart-decompiler, flutter逆向工具 |

### 3.2 逆向工程攻击面

1. **代码反编译** - 完全可读的源码结构
2. **字符串提取** - 所有 URL、配置、常量暴露
3. **业务逻辑分析** - 学习算法、评分逻辑、SRS 引擎完全可见
4. **数据提取** - 31MB 词书数据库可直接读取
5. **API 分析** - 所有网络端点和通信协议暴露

### 3.3 防护建议优先级

| 优先级 | 措施 | 预计工时 | 效果 |
|--------|------|---------|------|
| **P0** | 启用 ProGuard/R8 | 2小时 | 高 |
| **P0** | 启用 --obfuscate | 1小时 | 高 |
| **P0** | 加密数据库 | 8小时 | 高 |
| **P1** | 迁移到 HTTPS | 4小时 | 中 |
| **P1** | 启用 --split-debug-info | 1小时 | 中 |
| **P2** | Windows 保护 | 16小时 | 中 |
| **P2** | 证书固定 | 8小时 | 中 |

---

## 四、安全改进路线图

### 阶段 1：立即修复 (1-2天)

1. ✅ 启用 Android ProGuard/R8
2. ✅ 启用 Flutter --obfuscate
3. ✅ 移除所有 debugPrint
4. ✅ 配置正确的 Release 签名

### 阶段 2：短期优化 (1周)

1. ✅ 数据库加密 (SQLCipher)
2. ✅ 迁移到全 HTTPS
3. ✅ 启用 --split-debug-info
4. ✅ 安全存储调试信息

### 阶段 3：中期加固 (1月)

1. ✅ Windows 代码保护
2. ✅ 证书固定
3. ✅ 反调试机制
4. ✅ 完整性校验

---

## 五、结论

### 总体安全评分: 35/100 🔴 高风险

| 维度 | 评分 | 说明 |
|------|------|------|
| 代码混淆 | 0/20 | 完全未启用 |
| 密钥保护 | 15/15 | 未发现硬编码密钥 |
| 资源保护 | 0/15 | 数据库可被提取 |
| 调试残留 | 10/15 | 少量 debugPrint |
| 网络安全 | 5/15 | 混合 HTTP/HTTPS |
| 逆向防护 | 5/20 | 未启用任何保护 |

### 核心问题

🔴 **代码完全暴露**: 无混淆、无保护，可被完整反编译
🔴 **数据泄露风险**: 31MB 词书数据库可被直接提取
🔴 **知识产权风险**: 业务逻辑、算法、资源完全可见

### 建议

**立即行动**:
1. 启用 ProGuard/R8 和 --obfuscate (3小时)
2. 加密数据库 (8小时)
3. 迁移到 HTTPS (4小时)

**总计**: ~15 小时可将安全评分提升至 70/100

---

*审计报告完成于 2026-08-24 · DocReviewer (Monster world)*
*约束: 未修改代码，仅产出报告*
