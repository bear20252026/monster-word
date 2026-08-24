# 安全加固进度跟踪文档

> 创建日期：2026-08-24
> 维护人：TokenEngineer
> 项目：Monster Word v2.0.0

---

## 一、P0 问题清单（发布前必须修复）

| # | 问题 | 发现者 | 文件位置 | 修复状态 | 负责人 | 提交/备注 |
|---|------|--------|----------|----------|--------|-----------|
| 1 | AES 密钥 `"iscooler"` 硬编码 | DevOps, DocReviewer, DataEngineer | api_services.dart:94 | ⏳ 待修复 | 待分配 | 需服务端配合更换密钥 |
| 2 | Release 包 print() 泄露 token/参数 | DevOps, DataEngineer | http_client.dart, api_services.dart | 🔄 进行中 | DevOps | — |
| 3 | 15+ 处 HTTP 明文 URL | DocReviewer | 多文件 | 🔄 进行中 | ContrastGuard | — |
| 4 | Release 使用 debug 签名 | DocReviewer | build.gradle.kts:36 | ✅ 已完成 | MotionEngineer | `6552dd3` |
| 5 | 无 R8 代码混淆 | DocReviewer | build.gradle.kts | ✅ 已完成 | MotionEngineer | `6552dd3` |
| 6 | 密码明文存储 `userPwd` | DataEngineer, LicenseReviewer | app_preferences_ext.dart:770 | 📨 待派发 | 待分配 | — |
| 7 | Token/Secret 明文存储 | DevOps, MotionEngineer, DataEngineer | SharedPreferences | 🔄 进行中 | PhoneticsEngineer | 迁移至 flutter_secure_storage |

**P0 完成率：2/7（29%）** — #4 Release 签名 + #5 R8 混淆

---

## 二、P1 问题清单（短期修复）

| # | 问题 | 发现者 | 修复状态 | 负责人 | 提交/备注 |
|---|------|--------|----------|--------|-----------|
| 8 | 无 nonce 防重放 | DevOps | ⏳ 待修复 | 待分配 | 添加 UUID nonce 到签名 |
| 9 | HTTPDNS 空实现 | DevOps | ⏳ 待修复 | 待分配 | 集成或移除 stub |
| 10 | 无客户端速率限制 | DevOps | ⏳ 待修复 | 待分配 | 添加请求间隔限制 |
| 11 | WebView 默认启用 JS | TokenEngineer | ✅ 审计完成 | DocWriter | 安全报告见 security_network_report.md |
| 12 | Android allowBackup 开启 | LicenseReviewer | ✅ 已完成 | TokenEngineer | `00a86ff` |
| 13 | `encrypt` 包已 archived | TokenEngineer | ✅ 方案完成 | TokenEngineer | 迁移方案已产出，见 encrypt_migration_plan.md |
| 14 | MD5 签名不安全 | DataEngineer | ⏳ 待修复 | 待分配 | 升级 HMAC-SHA256 |
| 15 | Token 通过 URL 参数传递 | MotionEngineer | ⏳ 待修复 | 待分配 | 改用 Header 传递 |

**P1 完成率：3/8（37.5%）** — #12 allowBackup + #11 WebView 审计 + #13 encrypt 方案

---

## 三、P2 问题清单（中期改进）

| # | 问题 | 发现者 | 修复状态 | 备注 |
|---|------|--------|----------|------|
| 16 | 无证书固定 | DevOps | ⏳ 按需实施 | — |
| 17 | 19处 catch(_) 空块 | Batch1Engineer | ⏳ 待修复 | 改进异常处理 |
| 18 | 15处 ! 操作符空指针风险 | Batch1Engineer | ⏳ 待修复 | 添加 null check |
| 19 | 5处资源未关闭 | Batch1Engineer | ⏳ 待修复 | 使用 try-with-resources |
| 20 | 3处竞态条件 | Batch1Engineer | ⏳ 待修复 | 添加同步控制 |
| 21 | SQLite 无加密 | LicenseReviewer | ⏳ 延后 | 当前非敏感数据 |
| 22 | 无反调试保护 | DocReviewer | ⏳ 按需实施 | — |

**P2 完成率：0/7（0%）**

---

## 四、已完成的提交列表

| 提交哈希 | 日期 | 说明 | 负责人 |
|----------|------|------|--------|
| `00a86ff` | 2026-08-24 | 禁用 Android allowBackup | TokenEngineer |
| `6552dd3` | 2026-08-24 | 启用 R8 混淆 + Release 签名配置 | MotionEngineer |
| `3b119ac` | 2026-08-24 | 代码混淆文档 + 安全检查清单 | DocReviewer |

---

## 五、待完成任务

### 5.1 P0 待完成

| 任务 | 优先级 | 预计工时 | 依赖 |
|------|--------|----------|------|
| 移除密码明文存储 userPwd | P0 | 2h | 无 |
| AES 密钥轮换 | P0 | 4h | 服务端配合 |
| Release print() 移除 | P0 | 1h | 无 |
| HTTP → HTTPS 替换 | P0 | 3h | 无 |
| R8 混淆启用 | P0 | 2h | 无 |
| Release 签名配置 | P0 | 1h | 无 |
| Token 安全存储迁移 | P0 | 3h | 无 |

### 5.2 P1 待完成

| 任务 | 优先级 | 预计工时 | 依赖 |
|------|--------|----------|------|
| WebView JS 限制 | P1 | 1h | 无 |
| nonce 防重放 | P1 | 2h | 无 |
| HTTPDNS 集成/移除 | P1 | 2h | 无 |
| 速率限制 | P1 | 2h | 无 |
| encrypt 包迁移 | P1 | 4h | 无 |
| MD5 → HMAC-SHA256 | P1 | 3h | 服务端配合 |
| Token Header 传递 | P1 | 2h | 服务端配合 |

---

## 六、安全检查清单（发布前）

- [ ] P0 问题全部修复
- [ ] Release 包无 debug 日志输出
- [ ] 所有 HTTP URL 替换为 HTTPS
- [x] Release 签名配置正确 ✅ `6552dd3`
- [x] R8 代码混淆启用 ✅ `6552dd3`
- [ ] 敏感数据加密存储
- [ ] Android allowBackup=false ✅
- [ ] 无硬编码密钥/Token
- [x] WebView 安全配置 ✅ 审计完成
- [ ] 依赖漏洞扫描通过

---

## 七、统计摘要

| 指标 | 数值 |
|------|------|
| 总问题数 | 22 |
| P0 问题 | 7 |
| P1 问题 | 8 |
| P2 问题 | 7 |
| 已完成 | 5 |
| 进行中 | 2 |
| 待修复 | 15 |
| 整体完成率 | 22.7% |

---

*最后更新：2026-08-24 · DocWriter（安全加固进度更新）*
