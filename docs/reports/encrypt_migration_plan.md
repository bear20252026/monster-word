# encrypt 包替代方案评估与迁移计划

> 日期：2026-08-24
> 审计人：LicenseReviewer
> 项目：Monster Word v2.0.0+2
> 背景：安全审计发现 `encrypt` 包维护放缓，需评估替代方案

---

## 1. 当前使用分析

### 1.1 使用范围

`encrypt` 包仅在 **1 个文件** 中使用：

| 文件 | 行数 | 用途 |
|---|---|---|
| `lib/utils/crypto_utils.dart` | 10 行（import + 调用） | AES-CBC 加解密 + API 签名 |

### 1.2 调用方

| 调用方 | 调用内容 | 说明 |
|---|---|---|
| `http_client.dart:142` | `WdTransAction.changeText()` | API 响应解密 |
| `http_client.dart:521` | `WdTransAction.generateSign()` | API 请求签名 |
| `http_client.dart:263` | `SecurityUtils.md5String()` | MD5 哈希（不依赖 encrypt） |
| `http_client.dart:824/895/963` | `SecurityUtils.getFileMd5String()` | 文件 MD5（不依赖 encrypt） |

### 1.3 加密参数

| 参数 | SecurityUtils | WdTransAction |
|---|---|---|
| 算法 | AES-128-CBC | AES-128-CBC |
| 填充 | PKCS7 | PKCS7 |
| 密钥 | 固定 "iscooler"（8 字节 → 128 位） | 运行时传入 |
| IV | 固定 `[1,0x70,97,0x74,2,0x72,0x71,0x73]` | 运行时传入 "1pat2rqs" |
| 编码 | Base64 | Base64 / Raw bytes |

---

## 2. 替代方案评估

### 2.1 方案对比

| 方案 | 包名 | 维护状态 | API 复杂度 | 依赖关系 | 许可证 | 推荐 |
|---|---|---|---|---|---|---|
| **A: pointycastle** | `pointycastle` | 🟢 活跃 | 🔴 高（底层原语） | 已在依赖树中（encrypt 的底层） | MIT | ⭐ 推荐 |
| B: cryptography | `cryptography` | 🟢 活跃 | 🟢 低（高级 API） | 新增依赖 | Apache-2.0 | 备选 |
| C: 手动实现 | 无 | — | 🔴 极高 | 无 | — | ❌ 不推荐 |

### 2.2 推荐方案：pointycastle（方案 A）

**理由**：

1. **已在依赖树中**：`encrypt` 包本身就是 `pointycastle` 的上层封装，`pointycastle` 已作为传递依赖存在（pubspec.lock 中可见），无需新增依赖
2. **维护活跃**：Dart 官方加密库，持续更新
3. **许可证安全**：MIT
4. **功能完备**：支持 AES-CBC + PKCS7，完全覆盖当前需求
5. **无额外体积**：已存在于 APK 中

**缺点**：API 较底层，需要手动实现 padding 和 Base64 编码。

### 2.3 备选方案：cryptography（方案 B）

**理由**：

1. **API 简洁**：高级封装，代码量少
2. **维护活跃**：Google Dart 团队维护
3. **跨平台**：支持 Web/Wasm

**缺点**：需新增依赖，API 与当前代码差异较大。

---

## 3. 迁移步骤（方案 A：pointycastle）

### 3.1 依赖变更

```yaml
# pubspec.yaml
dependencies:
  # 移除
  # encrypt: ^5.0.3

  # 显式声明（已存在于传递依赖中）
  pointycastle: ^3.9.1
```

### 3.2 代码迁移

#### SecurityUtils 类（crypto_utils.dart:12-58）

**当前代码**：
```dart
import 'package:encrypt/encrypt.dart' as encrypt_lib;

static final _iv = encrypt_lib.IV(Uint8List.fromList([1, 0x70, 97, 0x74, 2, 0x72, 0x71, 0x73]));

static String encryptDES(String str, {String key = 'iscooler'}) {
  final keyBytes = encrypt_lib.Key.fromUtf8(key);
  final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(keyBytes, mode: encrypt_lib.AESMode.cbc, padding: 'PKCS7'));
  return encrypter.encrypt(str, iv: _iv).base64;
}
```

**迁移后**：
```dart
import 'package:pointycastle/export.dart' as pc;

static final _iv = Uint8List.fromList([1, 0x70, 97, 0x74, 2, 0x72, 0x71, 0x73]);

static String encryptDES(String str, {String key = 'iscooler'}) {
  final keyBytes = Uint8List.fromList(utf8.encode(key));
  final cipher = pc.CBCBlockCipher(pc.AESEngine())
    ..init(true, pc.ParametersWithIV(pc.KeyParameter(keyBytes), _iv));
  final padded = _pkcs7Pad(utf8.encode(str));
  final output = Uint8List(padded.length);
  for (var i = 0; i < padded.length; i += 16) {
    cipher.processBlock(padded, i, output, i);
  }
  return base64Encode(output);
}

static Uint8List _pkcs7Pad(List<int> data) {
  final padLen = 16 - (data.length % 16);
  return Uint8List.fromList(data + List.filled(padLen, padLen));
}

static Uint8List _pkcs7Unpad(List<int> data) {
  final padLen = data.last;
  return Uint8List.fromList(data.sublist(0, data.length - padLen));
}
```

#### WdTransAction 类（crypto_utils.dart:78-136）

同样模式：用 `CBCBlockCipher(AESEngine())` 替换 `Encrypter(AES(...))`。

### 3.3 完整迁移清单

| # | 改动 | 文件 | 行范围 |
|---|---|---|---|
| 1 | 移除 `import 'package:encrypt/encrypt.dart'` | crypto_utils.dart | 10 |
| 2 | 添加 `import 'package:pointycastle/export.dart'` | crypto_utils.dart | 10 |
| 3 | 实现 `_pkcs7Pad` / `_pkcs7Unpad` 辅助函数 | crypto_utils.dart | 新增 |
| 4 | 重写 `SecurityUtils.encryptDES` | crypto_utils.dart | 17-21 |
| 5 | 重写 `SecurityUtils.decryptDES` | crypto_utils.dart | 24-28 |
| 6 | 重写 `WdTransAction.transfer` | crypto_utils.dart | 81-90 |
| 7 | 重写 `WdTransAction.trans` | crypto_utils.dart | 93-100 |
| 8 | pubspec.yaml 移除 encrypt，显式声明 pointycastle | pubspec.yaml | — |
| 9 | 运行 `flutter pub get` | — | — |
| 10 | flutter analyze + flutter test 验证 | — | — |

---

## 4. 风险评估

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 加密结果不兼容 | 🟡 中 | pointycastle 的 AES 实现可能与 encrypt 有细微差异 | 迁移后用已知测试向量验证加解密一致性 |
| PKCS7 实现错误 | 🟡 中 | 手动实现 padding 需要仔细测试 | 添加边界测试（空字符串、恰好16倍数、最大长度） |
| API 签名失效 | 🔴 高 | 如果加密结果不同，API 签名将失效，导致服务端拒绝 | 迁移后必须用真实 API 请求验证 |
| 传递依赖冲突 | 🟢 低 | pointycastle 已在依赖树中 | flutter pub get 验证 |

### 4.1 关键验证点

迁移后必须验证：

1. **加密一致性**：`encryptDES("test")` 的输出在新旧实现中完全相同
2. **解密一致性**：用旧实现加密的数据能被新实现正确解密
3. **API 签名**：`WdTransAction.generateSign()` 的输出在新旧实现中完全相同
4. **API 通信**：真实 API 请求能正常签名和解密

---

## 5. 工期估算

| 步骤 | 工时 |
|---|---|
| 代码迁移 | 2-3 小时 |
| 测试向量验证 | 1 小时 |
| API 通信验证 | 1 小时 |
| flutter analyze + test | 0.5 小时 |
| **合计** | **0.5-0.75 天** |

---

## 6. 结论

**推荐方案 A（pointycastle）**：

- 无需新增依赖（已在传递依赖中）
- MIT 许可证，维护活跃
- 覆盖当前 AES-CBC + PKCS7 全部需求
- 迁移成本低（0.5-0.75 天）
- 唯一风险是加密结果一致性，需用测试向量验证

**建议时机**：当前 encrypt 包虽维护放缓但功能正常，可作为 P2 任务在下一个迭代周期处理。若即将公开发布，建议提前迁移以消除安全审计标记。
