# Monster Word 数据存储安全审计报告

> 审计日期：2026-08-24
> 审计人：LicenseReviewer
> 项目：Monster Word v2.0.0+2（D:\claude\work\cn_com_lange\word_app）
> 方法：只读代码审查，未运行任何安全工具

---

## 1. 审计结论速览

**🟡 整体风险等级：中**

发现 1 个高风险问题和 3 个中风险问题：

| # | 问题 | 风险等级 | 说明 |
|---|---|---|---|
| 🔴 H1 | 密码明文存储 | **高** | `app_preferences_ext.dart:770` 将密码以明文存入 SharedPreferences |
| 🟡 M1 | SQLite 无加密 | **中** | wordbook.db 明文存储，含词书版权数据 |
| 🟡 M2 | Android allowBackup 默认开启 | **中** | 未显式设置 `android:allowBackup="false"` |
| 🟡 M3 | 用户凭据明文存储 | **中** | user_token / user_secret / userId 明文存储 |

---

## 2. SharedPreferences 存储安全

### 2.1 存储的键值对清单

| 键名 | 类型 | 敏感度 | 说明 |
|---|---|---|---|
| `user_token` | String | 🔴 高 | 用户认证 token |
| `user_secret` | String | 🔴 高 | 用户密钥 |
| `key_userId` | String | 🟡 中 | 用户 ID |
| `userPwd` | String | 🔴 高 | **用户密码（明文）** |
| `key_search_history` | StringList | 🟢 低 | 搜索历史（最近 50 条） |
| `skin_theme_id` | String | 🟢 低 | 主题偏好 |
| `skin_follow_system` | bool | 🟢 低 | 跟随系统设置 |
| `key_pronounceType` | int | 🟢 低 | 发音类型 |
| `app_user_rules_agree` | bool | 🟢 低 | 用户协议同意状态 |
| `study_remind_text` | String | 🟢 低 | 学习提醒文本 |
| `key_group_library_List_v3_2` | String | 🟢 低 | 词书分组列表 |
| `extensive_mode` | bool | 🟢 低 | 扩展模式 |
| `key_net_line_type` | int | 🟢 低 | 网络线路类型 |
| `history_query` | String | 🟢 低 | 历史查询 |
| `app_need_migrate_to_v3` | bool | 🟢 低 | 迁移标记 |
| `key_app_first_checkin` | bool | 🟢 低 | 首次签到 |
| `key_user_track_enable` | bool | 🟢 低 | 用户追踪开关 |

### 2.2 🔴 高风险：密码明文存储

**位置**：`lib/data/app_preferences_ext.dart:770`

```dart
Future<bool> savePassword(String value) => _setString(password, value);
```

**问题**：用户密码以明文形式存储在 SharedPreferences 中。SharedPreferences 在 Android 上存储为 `/data/data/<package>/shared_prefs/*.xml` 明文文件，root 设备或备份可直接读取。

**建议**：
- 不存储密码，仅存储认证 token
- 若必须存储凭据，使用 `flutter_secure_plugin` 或 Android Keystore
- 当前登录流程为占位实现，正式上线前必须修复

### 2.3 🟡 中风险：用户凭据明文存储

**位置**：`lib/data/app_preferences.dart:61-63`

```dart
static const String userToken = 'user_token';
static const String userSecret = 'user_secret';
static const String userId = 'key_userId';
```

**问题**：认证 token 和密钥以明文存储。

**建议**：
- 使用 `flutter_secure_storage` 替代 SharedPreferences 存储敏感凭据
- Android 端使用 EncryptedSharedPreferences
- iOS 端使用 Keychain

---

## 3. SQLite 数据库安全

### 3.1 wordbook.db

| 属性 | 状态 | 说明 |
|---|---|---|
| 加密 | ❌ 无加密 | 明文 SQLite |
| 访问模式 | ✅ 只读 | `openDatabase(dbPath, readOnly: true)` |
| 存储位置 | ✅ 应用私有目录 | `getApplicationSupportDirectory()` |
| 数据内容 | 词书/单词/释义 | 非敏感用户数据 |
| 版权风险 | ⚠️ 有 | 含反编译 APK 导出数据 |

**评估**：wordbook.db 为只读词书数据，不含用户敏感信息。明文存储风险低，但版权数据需合规处理（已有专项方案）。

### 3.2 UserDatabase（sqflite）

| 属性 | 状态 | 说明 |
|---|---|---|
| 加密 | ❌ 无加密 | 明文 SQLite |
| 数据内容 | 收藏/学习进度 | 非敏感用户数据 |
| 存储位置 | ✅ 应用私有目录 | sqflite 默认位置 |

**评估**：用户数据库仅存储学习进度和收藏，无敏感信息。风险低。

---

## 4. 文件存储安全

### 4.1 Assets 目录

| 文件 | 权限 | 风险 |
|---|---|---|
| `assets/db/wordbook.db.gz` | 只读（打包在 APK 中） | 🟢 低 |
| `assets/wallpapers/` | 只读 | 🟢 低 |
| `assets/fonts/` | 只读 | 🟢 低 |

**评估**：Assets 打包在 APK 内，运行时只读，无安全风险。

### 4.2 临时文件

| 文件 | 位置 | 清理策略 | 风险 |
|---|---|---|---|
| `wordbook.db`（解压后） | 应用支持目录 | 首启解压，不删除 | 🟢 低 |
| 其他临时文件 | 系统临时目录 | 系统自动清理 | 🟢 低 |

**评估**：解压后的 wordbook.db 留在应用私有目录，属正常行为。无临时文件泄露风险。

---

## 5. 剪贴板安全

### 5.1 剪贴板使用

**位置**：`lib/utils/app_utils.dart:117-118`

```dart
static Future<void> copyText2Clipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
```

**用途**：用于复制单词/释义到剪贴板（用户主动操作）。

**风险**：
- 剪贴板内容可能被其他应用读取（Android 10 以下）
- 无自动清理机制

**评估**：🟢 低风险。仅复制学习内容（单词/释义），无敏感数据。建议：
- Android 10+ 使用 `Clipboard.setData` 时设置 `label` 字段
- 考虑添加剪贴板自动清理（延迟 60 秒后清除）

---

## 6. Android 备份安全

### 6.1 allowBackup 检查

**位置**：`android/app/src/main/AndroidManifest.xml`

**当前状态**：未显式设置 `android:allowBackup`。

**问题**：Android 默认 `allowBackup="true"`，应用数据可通过 `adb backup` 备份，包括：
- SharedPreferences（含 token/密码）
- SQLite 数据库
- 应用私有文件

**建议**：
```xml
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    ...>
```

或使用 Android 12+ 的 `dataExtractionRules` 精细控制备份内容。

### 6.2 风险评估

| 风险 | 影响 | 缓解 |
|---|---|---|
| ADB 备份泄露 token | 🔴 高 | 禁用 allowBackup 或迁移到 EncryptedSharedPreferences |
| ADB 备份泄露密码 | 🔴 高 | 不存储密码（见 §2.2） |
| ADB 备份泄露词书数据 | 🟡 中 | 版权数据泄露扩大分发面 |

---

## 7. 风险汇总与建议

### 7.1 按优先级排序

| 优先级 | 问题 | 建议 | 预估工期 |
|---|---|---|---|
| **P0** | 密码明文存储 | 删除 savePassword，改用 token 认证 | 0.5 天 |
| **P1** | 凭据明文存储 | 迁移到 flutter_secure_storage | 1 天 |
| **P1** | allowBackup 默认开启 | AndroidManifest 设置 allowBackup="false" | 0.5 小时 |
| **P2** | SQLite 无加密 | 评估是否需要 SQLCipher（当前数据非敏感） | 1 天 |
| **P3** | 剪贴板无清理 | 添加延迟清理逻辑 | 0.5 小时 |

### 7.2 发布前必须修复

| # | 修复项 | 说明 |
|---|---|---|
| 1 | 移除密码明文存储 | 当前登录为占位实现，正式上线前必须重构 |
| 2 | 设置 allowBackup="false" | 一行代码改动 |
| 3 | 敏感凭据迁移到 SecureStorage | flutter_secure_storage 包 |

### 7.3 可延后处理

| # | 修复项 | 说明 |
|---|---|---|
| 1 | SQLite 加密 | 当前数据非敏感，可后续评估 |
| 2 | 剪贴板清理 | 低风险，可后续优化 |

---

## 8. Android 权限审计

| 权限 | 声明 | 必要性 | 风险 |
|---|---|---|---|
| `INTERNET` | ✅ 已声明 | ✅ 必要（网络请求/WebView/音频） | 🟢 低 |
| `RECORD_AUDIO` | ❌ 未声明 | — | 🟢 无 |
| `READ/WRITE_EXTERNAL_STORAGE` | ❌ 未声明 | — | 🟢 无 |
| `CAMERA` | ❌ 未声明 | — | 🟢 无 |
| `LOCATION` | ❌ 未声明 | — | 🟢 无 |
| `ACCESS_NETWORK_STATE` | ❌ 未声明 | — | 🟢 无 |

**评估**：仅请求 INTERNET 权限，无过度权限请求。权限配置安全。

---

**总结**：Monster Word v2.0.0 的数据存储整体安全，但存在 1 个高风险问题（密码明文存储）需在发布前修复。建议发布前完成 P0/P1 修复项（密码移除 + 凭据加密 + 备份禁用），P2/P3 可延后处理。
