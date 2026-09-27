# Monster Word App 隐私与数据安全审计报告

**审计时间**: 2026-08-24  
**审计范围**: Monster Word App 源代码、配置文件、依赖项  
**审计目标**: 评估隐私合规性和数据安全风险

---

## 1. 数据收集审计

### 1.1 用户数据收集清单

| 数据类型 | 存储位置 | 字段名 | 敏感级别 |
|---------|---------|--------|----------|
| **用户身份信息** | | | |
| 用户ID | SharedPreferences | `key_userId` | 中 |
| 手机号 | SharedPreferences | `phone` | 高 |
| 昵称 | SharedPreferences | `nickname` | 低 |
| 头像URL | SharedPreferences | `avatar` | 低 |
| 用户Token | SharedPreferences | `user_token` | 高 |
| 用户密钥 | SharedPreferences | `user_secret` | 高 |
| **学习数据** | | | |
| 学习进度 | SharedPreferences | `learnedCount` | 低 |
| 学习词书 | SharedPreferences | `library_learning` | 低 |
| 学习策略 | SharedPreferences | `setting_learn_strategy_*` | 低 |
| 搜索历史 | SharedPreferences | `key_search_history` | 中 |
| 签到日期 | SharedPreferences | `checkIn_date` | 低 |
| **配置数据** | | | |
| 发音设置 | SharedPreferences | `key_pronounceType` | 低 |
| 主题设置 | SharedPreferences | `ui_theme` | 低 |
| 提醒设置 | SharedPreferences | `remind_time` | 低 |

**数据总量**: 约25+个数据字段  
**存储方式**: SharedPreferences（明文存储）  
**⚠️ 问题**: 用户Token、密钥、手机号明文存储，存在安全风险

---

### 1.2 隐私政策检查

**检查结果**: ❌ **未发现隐私政策文件**

**发现**:
- 项目中无 `privacy_policy.md` 或类似文件
- App内无隐私政策展示页面
- 无用户同意机制的代码（仅有 `app_user_rules_agree` 字段，但未发现实际展示）

**合规风险**: 🔴 **严重** - 无法满足《个人信息保护法》要求

---

### 1.3 用户同意机制检查

**检查结果**: ⚠️ **部分实现**

**发现**:
- `AppPreferences` 中有 `appUserRulesAgree` 字段
- `appPermissionGrantShow` 字段存在
- 但未发现实际的同意弹窗或授权流程代码

**建议**: 需要实现完整的用户同意流程

---

## 2. 数据泄露风险审计

### 2.1 日志打印检查

**检查结果**: ✅ **有保护机制**

**发现**:
```dart
// http_client.dart:30-33
void _log(Object? message) {
  if (kDebugMode) print(message); // Release包禁用print
}
```

**优点**:
- Release包禁用日志输出
- 防止Token/URL/参数泄露到logcat

**⚠️ 问题**:
- 统计模块 (`statistics.dart`) 中的事件仍在内存中累积
- 调试时可能打印敏感信息

---

### 2.2 剪贴板使用检查

**检查结果**: ⚠️ **需进一步确认**

**发现**:
- 未发现明显的 `Clipboard.setData` 调用
- 但搜索功能可能涉及复制单词到剪贴板
- 建议检查是否有敏感数据（如Token）被复制

---

### 2.3 截图/录屏保护

**检查结果**: ❌ **未发现保护措施**

**发现**:
- 无 `SecureWindow` 或类似的截图保护
- 学习页面、个人信息页面可被截图
- Android 未设置 `FLAG_SECURE`

**建议**: 对敏感页面（如登录、个人信息）添加截图保护

---

## 3. 第三方服务审计

### 3.1 第三方SDK清单

| SDK | 用途 | 数据收集 | 隐私风险 |
|-----|------|---------|---------|
| **shared_preferences** | 本地存储 | 无 | 低 |
| **http** | 网络请求 | 无 | 低 |
| **crypto/encrypt** | 加密 | 无 | 低 |
| **webview_flutter** | WebView | 可能收集浏览数据 | 中 |
| **audioplayers/just_audio** | 音频播放 | 无 | 低 |
| **友盟统计** (疑似) | 数据分析 | 用户行为数据 | 高 |

**⚠️ 问题**:
- 代码注释中提到"原版发送到友盟/统计平台"
- 当前实现仅为本地事件队列，未实际发送
- 但如果集成友盟，需遵守其隐私政策

---

### 3.2 第三方服务端点

**发现的服务器域名**:
1. `api.beingfine.cn` - API服务器
2. `sapi.beingfine.cn` - 安全API服务器（v1/v3版本）
3. `img.beingfine.cn` - 图片服务器
4. `audio.beingfine.cn` - 音频服务器
5. `7ncdn.beingfine.cn` - CDN服务器

**数据传输**:
- 所有服务器均为 `beingfine.cn`（不背单词）
- 使用 **HTTP**（非HTTPS）- 🔴 严重安全风险
- 数据可能包含用户Token和学习数据

**合规风险**: 
- 数据传输未加密（HTTP）
- 数据发送到第三方服务器（beingfine.cn）

---

## 4. 本地数据保护审计

### 4.1 数据加密存储

**检查结果**: ⚠️ **部分加密**

**发现**:
- SharedPreferences **明文存储**所有数据
- 用户Token、密钥、手机号均未加密
- API通信使用AES加密（密钥: "iscooler" - 硬编码，安全性低）

**加密机制**:
```dart
// crypto_utils.dart
static String encryptDES(String str, {String key = 'iscooler'}) {
  // AES CBC模式，固定IV
}
```

**⚠️ 问题**:
- 加密密钥硬编码在代码中
- SharedPreferences未加密
- 数据库（wordbook.db）未加密

---

### 4.2 数据备份保护

**检查结果**: ⚠️ **需配置**

**发现**:
- Android: 未设置 `android:allowBackup`
- iOS: 默认允许iCloud备份
- 学习数据可能被备份到云端

**建议**: 
- Android设置 `android:allowBackup="false"`
- iOS排除敏感数据的iCloud备份

---

### 4.3 数据清除机制

**检查结果**: ✅ **有实现**

**发现**:
- `SharedPreferences.clear()` 方法存在
- 用户可清除搜索历史
- 但卸载时的数据清除由系统处理

---

## 5. 权限使用审计

### 5.1 Android权限

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

**评估**: ✅ 最小权限原则，仅需网络权限

---

### 5.2 iOS权限

**检查结果**: ✅ **未申请敏感权限**

**发现**:
- 无相机/相册权限
- 无麦克风权限
- 无位置权限
- 无通讯录权限

---

## 6. 安全漏洞清单

### 🔴 **严重 (P0)**

1. **HTTP明文传输**
   - 问题: 所有API使用HTTP，非HTTPS
   - 风险: 中间人攻击、数据泄露
   - 建议: 迁移到HTTPS

2. **敏感数据明文存储**
   - 问题: Token、密钥、手机号明文存储在SharedPreferences
   - 风险: Root设备可直接读取
   - 建议: 使用flutter_secure_storage

3. **硬编码加密密钥**
   - 问题: AES密钥"iscooler"硬编码在代码中
   - 风险: 密钥泄露后所有加密无效
   - 建议: 使用安全的密钥管理方案

### 🟡 **中等 (P1)**

4. **缺少隐私政策**
   - 问题: 无隐私政策文件和展示页面
   - 合规风险: 违反《个人信息保护法》
   - 建议: 添加隐私政策并获取用户同意

5. **缺少截图保护**
   - 问题: 敏感页面可被截图
   - 风险: 用户信息泄露
   - 建议: 添加FLAG_SECURE

6. **备份保护缺失**
   - 问题: 数据可能被备份到云端
   - 建议: 禁用备份或排除敏感数据

### 🟢 **建议 (P2)**

7. **统计功能不明确**
   - 问题: 代码提到友盟但未实际集成
   - 建议: 明确统计方案并告知用户

8. **WebView安全**
   - 问题: WebView可能加载外部内容
   - 建议: 限制WebView功能

---

## 7. 合规性评估

### 7.1 《个人信息保护法》合规性

| 要求 | 状态 | 说明 |
|------|------|------|
| **告知义务** | ❌ 不合规 | 无隐私政策 |
| **同意机制** | ⚠️ 部分 | 有字段但无实际流程 |
| **最小必要** | ✅ 基本合规 | 收集数据与功能相关 |
| **安全保障** | ⚠️ 部分 | 有加密但存储不安全 |
| **用户权利** | ⚠️ 部分 | 有删除功能但不完整 |

**总体评估**: 🔴 **不合规** - 需要重大改进

---

### 7.2 GDPR合规性 (如需出海)

| 要求 | 状态 |
|------|------|
| 数据最小化 | ⚠️ |
| 用户同意 | ❌ |
| 数据可移植性 | ❌ |
| 删除权 | ⚠️ |
| 数据保护官 | ❌ |

---

## 8. 修复建议

### 8.1 立即修复 (本周)

1. ✅ **迁移到HTTPS**
   - 修改所有API端点为HTTPS
   - 验证SSL证书

2. ✅ **加密敏感数据**
   - 使用 `flutter_secure_storage` 存储Token
   - 加密SharedPreferences中的敏感字段

3. ✅ **添加隐私政策**
   - 编写隐私政策文档
   - 在App首次启动时展示
   - 实现用户同意机制

### 8.2 中期优化 (本月)

4. **移除硬编码密钥**
   - 实现动态密钥生成
   - 使用安全的密钥存储

5. **添加截图保护**
   - 对敏感页面设置FLAG_SECURE
   - iOS使用UIScreen.Capture

6. **备份保护**
   - Android设置allowBackup=false
   - iOS排除敏感数据

### 8.3 长期规划 (下季度)

7. **实现完整的用户权利**
   - 数据导出功能
   - 账号注销功能
   - 数据删除确认

8. **安全审计自动化**
   - 添加隐私扫描脚本
   - CI/CD集成安全检查

---

## 9. 附录：关键代码位置

### 数据存储
- `lib/data/app_preferences.dart` - SharedPreferences封装
- `lib/data/wordbook_database.dart` - 词书数据库

### 网络通信
- `lib/services/http_client.dart` - HTTP客户端
- `lib/services/api_services.dart` - API服务
- `lib/services/media_download.dart` - 媒体下载

### 加密工具
- `lib/utils/crypto_utils.dart` - 加密工具

### 统计服务
- `lib/services/statistics.dart` - 事件统计

---

## 10. 审计结论

**总体安全等级**: 🟡 **中等风险**

**主要发现**:
1. ✅ 优点：权限最小化、日志保护、基本加密机制
2. 🔴 严重问题：HTTP传输、明文存储、缺少隐私政策
3. 🟡 中等问题：截图保护缺失、备份保护不足

**优先行动**:
1. **立即**：迁移到HTTPS + 加密存储
2. **本周**：添加隐私政策 + 用户同意
3. **本月**：完善安全机制

**合规建议**:
- 暂缓公开发布，先解决P0问题
- 咨询法律专家完善隐私政策
- 考虑第三方安全审计

---

**审计执行**: BookNameProducer  
**日期**: 2026-08-24  
**版本**: v1.0
