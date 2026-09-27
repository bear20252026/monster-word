# 逆向工程与代码保护审计报告

- 审计日期：2026-08-24
- 审计范围：Monster Word App 全代码库
- 审计方法：静态代码分析（grep/文件结构审查）
- 结论：**抗逆向能力极低** — 无任何主动防御措施

---

## 一、代码混淆

### 1.1 Dart 代码混淆

| 检查项 | 状态 | 说明 |
|---|---|---|
| `--obfuscate` 编译标志 | ❌ 未启用 | build.yml 中 `flutter build windows --release` 无 `--obfuscate` |
| `--split-debug-info` | ❌ 未启用 | 无符号表分离 |

**影响**：Release 包中的 Dart 代码可被 `dart-decompile` 等工具直接反编译为可读源码。所有业务逻辑、API 调用逻辑、签名算法完全暴露。

### 1.2 Android ProGuard/R8

| 检查项 | 状态 | 说明 |
|---|---|---|
| `minifyEnabled` | ❌ 未配置 | `build.gradle.kts` 中无 `buildTypes.release.minifyEnabled` |
| `proguard-rules.pro` | ❌ 不存在 | 无 ProGuard 规则文件 |
| `shrinkResources` | ❌ 未配置 | 未启用资源压缩 |

**影响**：Java/Kotlin 代码未混淆，类名、方法名、字段名全部保留原始命名。

### 1.3 Release 签名

```
// android/app/build.gradle.kts:36
signingConfig = signingConfigs.getByName("debug")
```

**⚠️ 严重**：Release 构建使用 **debug 签名密钥**。这意味着：
- 任何人都可以构建相同签名的 APK
- 无法验证 APK 来源的真实性
- 应用无法上架 Google Play（需要正式签名）

---

## 二、反调试保护

| 检查项 | 状态 | 说明 |
|---|---|---|
| 反调试检测 | ❌ 无 | 无 `ptrace` 检测、无调试器附加检测 |
| Root/Jailbreak 检测 | ❌ 无 | 无 root 检测库（如 RootBeer） |
| 模拟器检测 | ❌ 无 | 无模拟器环境判断 |
| 代码完整性校验 | ❌ 无 | 无 APK 签名验证、无文件哈希校验 |
| Hook 框架检测 | ❌ 无 | 无 Frida/Xposed 检测 |

**影响**：攻击者可以：
- 用 Frida 附加进程，Hook 任意函数
- 在 root 设备上自由修改内存和逻辑
- 在模拟器中调试分析，无障碍

---

## 三、资源保护

### 3.1 词书数据库

```yaml
# pubspec.yaml:91
assets:
  - assets/db/wordbook.db.gz
```

**⚠️ 高风险**：词书数据库 `wordbook.db.gz` 以 gzip 压缩的 SQLite 文件直接打包在 assets 中。

**可被直接提取**：
```bash
# 从 APK 中提取
unzip app.apk assets/db/wordbook.db.gz
gunzip wordbook.db.gz
sqlite3 wordbook.db "SELECT * FROM words"
```

**影响**：
- 全部词条数据（单词、释义、音标、词根等）可被完整导出
- 竞品可直接复制词书内容
- 无加密、无混淆、无防篡改

### 3.2 壁纸资源

```
assets/wallpapers/
```

壁纸文件直接打包，可被提取复用。

---

## 四、密钥管理

### 4.1 硬编码密钥（严重）

```dart
// lib/services/api_services.dart:94
static const String _userSecret = 'iscooler';

// lib/services/api_services.dart:93
static const String appId = '600000001';
```

**⚠️ 严重**：API 签名密钥 `_userSecret` 硬编码在源码中。

**攻击路径**：
1. 反编译 APK → 找到 `_userSecret = 'iscooler'`
2. 用该密钥伪造任意 API 请求的签名
3. 绕过服务端鉴权，调用任意接口

### 4.2 签名算法暴露

```dart
// lib/services/api_services.dart:117-122
static void appendParamSign(RequestParams params) {
  final sorted = _sortParams(params.params);
  final joined = sorted.entries.map((e) => '${e.key}=${e.value}').join('&');
  final sign = SecurityUtils.md5String('$joined$_userSecret');
  params.put('sign', sign);
}
```

签名算法为简单的 `md5(sorted_params + secret)`，反编译后一目了然。

### 4.3 HTTP 明文传输

```dart
// lib/services/api_services.dart:90
static const String baseUrl = 'http://api.beingfine.cn/';
```

**⚠️ 中风险**：API 使用 HTTP（非 HTTPS），所有请求参数和响应数据在网络传输中**明文可见**，可被中间人攻击截获。

### 4.4 密钥存储

| 检查项 | 状态 | 说明 |
|---|---|---|
| Android KeyStore | ❌ 未使用 | 无 `AndroidKeyStore` 相关代码 |
| iOS Keychain | ❌ 未使用 | 无 `flutter_secure_storage` 等安全存储 |
| SharedPreferences | ⚠️ 用于敏感数据 | `app_preferences.dart` 存储用户状态，未加密 |

---

## 五、综合评估

### 5.1 风险矩阵

| 风险项 | 严重程度 | 可利用性 | 影响 |
|---|---|---|---|
| 无代码混淆 | 🔴 高 | 极易 | 全部源码可逆向 |
| 硬编码 API 密钥 | 🔴 高 | 极易 | API 签名可伪造 |
| HTTP 明文传输 | 🟡 中 | 易 | 中间人攻击 |
| 词书数据库未加密 | 🔴 高 | 极易 | 数据可完整导出 |
| Release 用 debug 签名 | 🔴 高 | 极易 | APK 可被仿冒 |
| 无反调试保护 | 🟡 中 | 易 | 动态分析无障碍 |
| 无 root/模拟器检测 | 🟢 低 | — | 本地调试无阻碍 |

### 5.2 抗逆向能力评分

| 维度 | 满分 | 得分 | 说明 |
|---|---|---|---|
| 代码保护 | 25 | **2** | 仅依赖 Dart 编译的天然混淆（极弱） |
| 运行时保护 | 25 | **0** | 无任何反调试/反篡改措施 |
| 资源保护 | 25 | **0** | 数据库和资源完全裸露 |
| 密钥管理 | 25 | **3** | 使用了 SecurityUtils.md5 但密钥硬编码 |
| **总分** | 100 | **5** | **极低** |

---

## 六、修复建议（按优先级）

### P0 — 立即修复

1. **API 密钥外置**：将 `_userSecret` 移至服务端下发或环境变量，不硬编码在客户端
2. **启用 HTTPS**：`baseUrl` 改为 `https://api.beingfine.cn/`
3. **正式签名**：Release 构建使用正式 keystore，替换 debug 签名

### P1 — 短期修复

4. **启用 Dart 代码混淆**：构建时添加 `--obfuscate --split-debug-info`
5. **启用 R8 混淆**：`build.gradle.kts` 中设置 `minifyEnabled = true`
6. **词书数据库加密**：对 `wordbook.db.gz` 做 AES 加密，运行时解密

### P2 — 中期加固

7. **添加反调试检测**：集成 RootBeer（root 检测）、ptrace 自检
8. **代码完整性校验**：APK 签名校验、关键文件哈希校验
9. **密钥安全存储**：使用 `flutter_secure_storage` 替代 SharedPreferences

### P3 — 长期规划

10. **服务端签名校验**：API 请求增加设备指纹、时间戳校验
11. **资源混淆**：使用 Flutter 资源混淆工具
12. **安全审计常态化**：每次发版前做安全扫描

---

## 七、免责说明

本审计仅基于静态代码分析，未做动态分析（如实际反编译 APK、抓包测试等）。实际攻击面可能更大。建议委托专业安全团队做完整的渗透测试。
