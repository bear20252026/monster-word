# 使用统计（遥测）

记录「使用时长 + 基本情况」并每日上报到自建统计服务器，供管理员查看。

> ⚠️ **隐私披露是这条链路的组成部分，不是附件。**
> 本功能的每一处改动都要回头确认 `lib/features/account/domain/legal_documents.dart`
> 里的表述仍然成立。历史上已经因为「披露与工程事实不一致」返工过两次（R2-23、R2-01）。
> 披露测试（`test/features/account/domain/legal_documents_test.dart`）里有一组
> 互斥断言专门守这条线。

---

## 1. 上报频率：每日一次（这是刻意的选择）

业主问过「多久收几次合理」。答案是**每日一次聚合上报**，理由：

| 方案 | 每设备每年请求 | 问题 |
|---|---|---|
| 每个事件上报 | 上万 | 电池/流量/服务端压力大；形成高精度行为日志，隐私代价最大而「时长 + 基本情况」根本用不上 |
| 每 N 分钟 | ~10 万 | 同上，更糟 |
| 每次退出 App 上报 | 不确定 | 移动端会被强杀、Windows 关窗口不一定走得到 ⇒ **丢数据** |
| **每日一次（本地累计）** | **~365** | **采用** |
| 每周一次 | ~52 | 「今天有没有人用」就答不了；一次失败丢一周 |

「使用时长 + 基本情况」本身就是**日粒度**数据，实时上报不增加任何信息量。

实现：本地按天累计 → 回到前台时判断「距上次成功 ≥ 24h 且有待上报数据」→ 一次批量
POST（最多带 31 天，含补传）。失败写退避（2h），本地数据保留，下一轮补传。

频率常量只有一处：`UsageStatsCollector.uploadInterval`。**改它之前先看披露里怎么写的**
（披露里写了「每日最多一次」）。

---

## 2. 隐私边界（改字段前必读）

### 上报什么

使用时长、打开次数、学习会话数、答题量与正确率、新学词数、词书进度（只传数字不传书名）、
连续签到天数、虚拟道具数量、各模块打开次数；信封里带应用版本、构建号、平台、系统版本、
界面语言、**随机生成的设备标识**。

### 不上报什么

- **学习内容**：学了哪些词、搜索词、笔记正文、收藏内容 —— 一律不上报
- **逐条答题记录**：只上报当天汇总的词次与正确数
- **设备强标识**：不用 IMEI / Android ID / 广告标识 / 序列号；deviceId 是本地 `Random.secure()`
  生成的 128 bit 十六进制，只为在服务端把同一台设备的上报归并成一条线
- **位置、通讯录**：不涉及

### 为什么 deviceId 不与 `user_id` 绑定

本功能的目的是「使用时长 + 基本情况」，不需要知道是谁。不绑定 ⇒ 这批数据**不可识别到个人**，
合规压力最小。若日后要按人看，**必须同步改披露**（那就成了可识别到个人的行为记录）。

### 开关

默认 **关闭**（`PrefsUsageStatsSettings`，可用 `--dart-define=USAGE_STATS_DEFAULT=on` 改默认值）。
开启前有一次明确告知的确认弹窗；关闭会**立即清除本机未上报的统计**（既然承诺关了就不收集，
就不该把之前攒的数据留着等哪天又被打开）。

默认关闭的原因：业主尚未确认用户里有没有不满 14 周岁的人，PIPL 对不满 14 周岁的个人信息
要求监护人单独同意。确认可以默认开启后，改 `_defaultEnabled` 并**同步改披露文案**。

---

## 3. 分层与「为什么这么分」

```
domain/usage_daily_stats.dart          模型 + JSON + 夹紧（纯 Dart）
application/usage_stats_ports.dart     四个端口：Store / Uploader / Environment / Settings
application/usage_stats_collector.dart 累计与上报决策（纯 Dart）
data/usage_stats_dao.dart              SQLite（表见 user_database.dart 的 _createUsageStatsTables）
data/http_usage_stats_uploader.dart    HTTP 出口
data/platform_usage_stats_environment.dart  设备标识 / 版本 / 平台 / 语言
data/prefs_usage_stats_settings.dart   开关
presentation/usage_stats_providers.dart     装配 + 设置页开关状态
```

`domain` 与 `application` **不 import flutter**，因此能用普通 Dart VM 直接执行：

```bash
/d/flutter/bin/cache/dart-sdk/bin/dart.exe <探针>.dart
```

这不是洁癖 —— 本仓 `flutter test` 受 365vpn 影响不可用（见工作区记忆），
只有不 import flutter 的代码能在本机**真跑断言**而不是只做编译校验。
所以核心逻辑（跨午夜切分、退避、补传、夹紧、白名单）全部放在这两层。

---

## 4. 已经处理掉的边界情况

| 情况 | 处理 |
|---|---|
| 跨午夜连续使用（23:50→00:20） | 按本地午夜切成两天，各记各的（否则任一天都偏一小时） |
| 系统时钟被回拨 | 丢弃该段，不写负数 |
| 系统时钟被前跳 | 单段循环上限 8 次，且前台时长夹到 24h |
| 数据库打不开 / 写失败 | 全部方法不抛，只记 Sentry，降级为「不统计」 |
| 上报失败 | 写退避、**不**标记已传、**不**清理数据 ⇒ 下轮补传 |
| 攒了多天 | 一次请求批量带上去（不逐天发） |
| 上报地址未配置 | 返回 false（不是静默成功）+ 报一次错误 —— 静默成功会让数据被标成已上报而永久丢失 |
| 用户关掉开关 | 停收 + 清本机未上报数据 |
| 旧版本写坏的 JSON | 按空处理，不让一行坏数据毁掉整批 |
| 装了但没打开的日子 | 不入库、不上报（否则日活指标被稀释） |

---

## 5. 还没做的部分

- **服务端**：`deploy/telemetry/`（接收服务 + 独立库 + 只读管理页 + Caddy 路由）。
  客户端已经能发，服务端未落地前上报会失败并走退避，数据留在本地不会丢。
- **学习行为埋点**：`recordStudySession` / `recordAnswers` / `recordNewWordsLearned` /
  `syncBookProgress` / `syncStreak` / `recordCoinsEarned` 这些 API 已就绪并有测试覆盖，
  但**尚未接到学习功能里**（需要在学习会话结束、答题批改、签到成功等处调用）。
  目前只有「使用时长 / 打开次数」由 `app.dart` 的生命周期钩子自动采集。
- **模块打开次数**：`recordModuleOpen` 已就绪，尚未接到路由/页面入口。
- **发版流水线**：需要在 `release_packages.yml` 注入 `STATS_BASE_URL`（见下）。

## 6. 接更多埋点怎么做

在业务侧拿到 `UsageStatsCollector` 后调用对应方法即可，例如学习会话结束时：

```dart
context.read<UsageStatsCollector>().recordStudySession();
```

注意：**不要**在 UI 里直接读 `UsageStatsCollector` 之外的东西，也不要在埋点里传词文本、
搜索词等任何内容 —— 那是「学习内容」，与披露冲突。

## 7. 构建参数

```bash
--dart-define=STATS_BASE_URL=https://<统计服务域名>   # 缺省则不上报（并报一次配置错误）
--dart-define=USAGE_STATS_DEFAULT=on                  # 缺省 off
```
