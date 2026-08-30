# Monster Word 代码安全审计报告（2026-08-31）

> 审计口径：316 个 dart 文件全量扫描 + 词库二进制实测（解压资产库验证 schema/索引/查询计划）+ 高危项人工复核（三大高危均经二次 grep 确认）
> 范围：安全性 / 可靠性 / 性能 / 可维护性（5 维度）

## 整体健康度：7.0 / 10

| 维度 | 得分 | 一句话 |
|---|---|---|
| 安全性 | 6.5 | SQL/WebView/密钥管理基本盘扎实，凭证存储"假修复"是硬伤 |
| 可靠性 | 7.5 | dispose/Timer/mounted 纪律好；扣分在假登录与死代码 bug |
| 性能 | 6.5 | 30MB 全量加载 + 每启动 35MB 哈希是实测确认的浪费 |
| 可维护性 | 7.5 | 架构守卫测试优秀；命名双轨与注释荒漠拉低 |

---

## 🔴 高危（2 项，均已二次核实）

### S1. SecureTokenStorage 是死代码——token/secret 明文落盘
- **位置**：`lib/core/infrastructure/app_preferences.dart:55`（类定义，全库 0 处调用）；`lib/features/account/data/user_service_impl.dart:41-47`（登录后 `UserInfoBean`（含 token/secret 字段）jsonEncode → `monster_word_user_info` key 明文写 SharedPreferences）
- **影响**：Android root / Windows 同用户进程可直接读取凭证；注释声称"已迁移 secure storage"但迁移代码从未接线（假修复）
- **修复**：登录路径接 `SecureTokenStorage().setToken/setSecret`；`UserInfoBean.toJson()` 剔除 token/secret；补一次性迁移测试

### S2. 登录假实现 + 登出不清凭证
- **位置**：`lib/features/account/presentation/app_session_state.dart:30-35`（`login()` 无视校验恒返回 true）、`:44-49`（logout 只清两个 bool，不清 `monster_word_user_info`）
- **影响**：换账号后旧 token 残留；后续云同步/签到若依赖登录态会在未认证状态触发
- **修复**：logout 清 secure storage + remove userInfo key；真实认证接入前 UI 明示"本地占位登录"

---

## 🟡 中危（7 项）

| # | 问题 | 位置 | 修复 |
|---|---|---|---|
| S3 | WebView 白名单可绕过：`host.endsWith('beingfine.cn')` 放过 `evil-beingfine.cn` | help_page.dart:50（base_web_page.dart:49 的写法才对） | 抽公共 `_isUrlAllowed` 统一复用 |
| S4 | 音频缓存文件名取自网络 URL path 末段，无路径遍历过滤/大小校验 | audio_players.dart:380-386, 317-328 | `p.basename` + 白名单正则；Content-Length ≤10MB |
| R3 | 单例 `initialize()` 无并发防护（并发双调用撞文件锁） | wordbook_database.dart:84、user_database.dart:28 | `Future? _initFuture` 缓存去重 |
| R4 | 查询不存在的列：`getRandomWords` 用 `book_id != ?`（words 表无该列）；`getWordCount` 同病且异常被吞返回 0 | word_repository_impl.dart:111、book_repository_impl.dart:46 | 改查 word_books 表 |
| R2 | 5 个页面 TextEditingController 创建后从不 dispose | account_info/user_info_manage/class_checkin/word_detail_notes_section/settings | `await showDialog` 返回后 dispose |
| P1 | 全量 loadWords 大词书内存 ~30MB+（实测最大书 10001 词，example 字段平均 3KB） | book_state.dart:101 → getWordsByBook | 列表页轻列查询（不含 example/interpret），详情页再取全文 |
| P2 | 每次冷启动全量加载 34.8MB gz 资产算哈希（仅比对用途） | wordbook_database.dart:97-100 | 构建期哈希写死常量，不一致才加载解压 |

---

## 🟢 低危（8 项）

- **S5** LIKE 未转义 `%/_`（word_repository_impl.dart:83、book_repository_impl.dart:57）——参数化安全但 `%` 可全表拖慢
- **S6** base_web_page.dart:44 允许 http scheme 导航——限 https
- **S7** 下载异常吞掉不上报 Sentry（audio_players.dart:326）——CDN 故障监控盲区
- **R5** word.dart:94-145 `(item['t'] ?? '') as String` 对非字符串脏数据抛 TypeError——改 `as String? ?? ''`
- **P3** N+1：service_dictionary_content_reader.dart:41-46 循环内逐词查询——改 `getWordsByNames(Set)` 批量
- **P4** 缺索引：`main_word` 全表 SCAN + `COLLATE NOCASE` 排序 TEMP B-TREE——建 `idx_words_main_word`/`idx_words_word_nocase`（随下版词库）
- **M1** 命名双轨 sb_/mw_ 混用（约 9 文件）——定 mw_ 为规范，sb_* @Deprecated 逐替
- **M2** 表现层注释荒漠（learn_page 667 行仅 4 条）

## ✅ 已验证无问题

- SQL 注入：5 个含 SQL 文件逐条核对，100% 参数化，`FROM $table` 仅 3 个硬编码调用点
- 硬编码密钥：Sentry DSN 走 --dart-define；CI 签名全经 secrets；无回退泄漏
- 明文 HTTP：唯一存量点已被 example_parser 统一升级 https
- XSS：富文本无 WebView/renderHtml，XSS 面为空
- dispose/Timer/mounted：25 个 AnimationController 全配对；144 处 setState 抽查有 mounted 守卫
- fromMap：全部 `?? default` 防御模式，脏数据不崩

---

## 优先级改进路线图

1. **P0（本迭代）**：S1 凭证接线 + S2/R1 logout 清理；R4 两处错误列名；S3 白名单统一
2. **P1（下迭代）**：R2 controller dispose×5；S4 文件名净化+下载上限；P2 构建期哈希常量
3. **P2（随下版词库）**：P1 轻列查询 + P4 两个索引；P3 批量化；M1 sb_→mw_ 机械替换
4. **P3（持续）**：analysis_options 开 unawaited_futures/discarded_futures；表现层补注释；S7 接 Sentry
