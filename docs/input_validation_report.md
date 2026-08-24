# 输入验证与注入攻击安全审计报告

> 审计时间：2026-08-24
> 审计者：PhoneticsEngineer (Monster world)
> 范围：Monster Word App 全部 lib/ 目录

---

## 1. SQL 注入审计

### 1.1 数据库查询概览

项目使用 `sqflite` 包进行本地数据库操作，涉及以下文件：

| 文件 | rawQuery | query | rawUpdate | rawDelete | execute |
|---|---|---|---|---|---|
| wordbook_database.dart | 3 | 3 | 0 | 0 | 0 |
| user_database.dart | 1 | 3 | 0 | 0 | 3 |
| user_process_dao.dart | 3 | 3 | 1 | 0 | 0 |
| note_database.dart | 1 | 3 | 0 | 0 | 2 |
| dictionary_service.dart | 3 | 5 | 0 | 0 | 0 |
| log_service.dart | 1 | 0 | 0 | 1 | 1 |

### 1.2 参数化查询检查

**✅ 所有用户输入均通过参数化查询传递。**

| 查询模式 | 安全性 | 示例 |
|---|---|---|
| `db.query('table', where: 'col = ?', whereArgs: [value])` | ✅ 安全 | wordbook_database.dart:150 |
| `db.rawQuery('... WHERE col = ?', [value])` | ✅ 安全 | wordbook_database.dart:138-141 |
| `db.rawQuery('... IN ($placeholders)', batch)` | ✅ 安全 | wordbook_database.dart:163-166 |
| `db.rawQuery('SELECT COUNT(*) ...')` | ✅ 安全（无用户输入） | user_database.dart:114 |

**关键安全模式：** `wordbook_database.dart:163` 使用 `batch.map((_) => '?').join(',')` 生成参数化 IN 子句，避免了 SQL 注入风险。

### 1.3 表名动态拼接

| 位置 | 代码 | 风险 |
|---|---|---|
| user_process_dao.dart:138 | `'WHERE user_id = ? ... FROM $tableName'` | ⚠️ 低风险：tableName 来自内部枚举，非用户输入 |
| user_process_dao.dart:208 | `'UPDATE $tableName SET ...'` | ⚠️ 低风险：同上 |
| log_service.dart:190 | `'DELETE FROM $_table WHERE ...'` | ⚠️ 低风险：_table 是类常量 |

**结论：** 表名拼接均来自内部常量或枚举，非用户可控，无注入风险。

### 1.4 SQL 注入风险评级

| 维度 | 评级 |
|---|---|
| 用户输入处理 | ✅ 全部参数化 |
| 动态表名 | ✅ 内部常量，非用户可控 |
| 字符串拼接 SQL | ✅ 仅用于生成 `?` 占位符 |
| **总体评级** | **✅ 无 SQL 注入风险** |

---

## 2. XSS 攻击审计

### 2.1 WebView 使用情况

| 位置 | 状态 | 风险 |
|---|---|---|
| special_widgets.dart:427 | CustomWebView 类存在，但实现为占位符（未实际加载 URL） | ✅ 无风险 |
| misc_widgets.dart:123 | CustomWebView 类存在，但实现为占位符 | ✅ 无风险 |
| learn_widgets.dart:177 | WebViewPool 类存在，但实现为占位符 | ✅ 无风险 |

**结论：** WebView 组件全部为占位符实现，未实际加载任何 URL，无 XSS 攻击面。

### 2.2 URL 处理

| 位置 | 状态 | 风险 |
|---|---|---|
| app_ref_processor.dart:170 | `await launch(url)` — **已注释掉** | ✅ 无风险 |
| app_ref_processor.dart:175 | `await launch(url)` — **已注释掉** | ✅ 无风险 |
| media_download.dart | TTS 音频下载 URL — 内部 API 地址 | ✅ 无风险（非用户可控） |

**结论：** 所有 `url_launcher` 调用均已注释掉，无外部 URL 加载。

### 2.3 HTML 内容渲染

未发现任何 HTML 内容渲染代码。所有文本显示使用 Flutter 的 `Text` widget，不解析 HTML。

### 2.4 Deep Link 处理

未发现 deep link 处理代码。App 使用命名路由（`Navigator.pushNamed`），无外部 URI scheme 注册。

### 2.5 XSS 风险评级

| 维度 | 评级 |
|---|---|
| WebView | ✅ 全部占位符，未实际加载 |
| URL 处理 | ✅ 全部注释掉 |
| HTML 渲染 | ✅ 无 |
| Deep Link | ✅ 无 |
| **总体评级** | **✅ 无 XSS 攻击面** |

---

## 3. 缓冲区溢出/崩溃攻击审计

### 3.1 超长输入处理

| 场景 | 处理方式 | 风险 |
|---|---|---|
| 搜索框输入 | `LIKE ?` 前缀匹配，limit 20 | ✅ 安全 |
| 音标字段 | 数据库 TEXT 类型，无长度限制 | ⚠️ 理论风险，但数据来自内部词库 |
| 单词拼写 | 数据库 TEXT 类型 | ✅ 安全（词库数据预定义） |

**结论：** 用户输入仅限搜索框，已通过 `limit` 限制结果数量。词库数据来自静态资产，无用户可控的超长输入。

### 3.2 整数溢出风险

| 场景 | 风险 |
|---|---|
| 词书 ID（int 主键） | ✅ 自增 ID，无溢出风险 |
| 词数统计（wordCount） | ✅ 来自数据库预定义值 |
| 进度百分比（0.0-1.0） | ✅ 使用 `.clamp(0.0, 1.0)` 限制 |

### 3.3 空指针解引用风险

Flutter 的 Dart 语言具有空安全（null safety），类型系统强制处理 null 值。已检查的关键路径：

| 场景 | 处理方式 | 风险 |
|---|---|---|
| 数据库查询结果 | `result.first['count'] as int` | ⚠️ 若结果为空会抛异常 |
| SharedPreferences | `prefs.getInt(key)` 返回 `int?` | ✅ 已做 null 检查 |
| Widget context | `context.mounted` 检查 | ✅ 异步操作后已检查 |

**结论：** 空安全机制有效，关键路径有 null 检查。数据库查询结果的 `.first` 访问在理论上存在空结果风险，但实际场景中表始终有数据。

### 3.4 缓冲区溢出/崩溃风险评级

| 维度 | 评级 |
|---|---|
| 超长输入 | ✅ 安全（静态词库 + limit 限制） |
| 整数溢出 | ✅ 安全（clamp 限制） |
| 空指针 | ✅ 基本安全（空安全 + null 检查） |
| **总体评级** | **✅ 低风险** |

---

## 4. 拒绝服务攻击审计

### 4.1 资源耗尽风险

| 场景 | 风险 | 防御 |
|---|---|---|
| 无限循环 | ⚠️ 存在 `while(true)` 循环 | ✅ 全部有 break 条件（见下） |
| 大量数据加载 | ⚠️ 词库 32,154 条 | ✅ 分批查询（500 条/批） |
| 内存泄漏 | ⚠️ 动画控制器 | ✅ dispose() 中正确释放 |

**while(true) 循环分析：**

| 位置 | 循环目的 | break 条件 | 安全性 |
|---|---|---|---|
| learning_state.dart:231 | 计算连续打卡天数 | 日期不在活跃集合中 | ✅ 有界（最大天数有限） |
| example_processor.dart:193 | 正则替换连续大写字母 | 无更多替换（收敛） | ✅ 有界（输入长度有限） |
| example_processor.dart:203 | 正则替换缩写句点 | 无更多替换（收敛） | ✅ 有界 |
| example_processor.dart:213 | 正则替换 | 无更多替换（收敛） | ✅ 有界 |
| example_processor.dart:223 | 正则替换 | 无更多替换（收敛） | ✅ 有界 |
| example_processor.dart:347 | 正则替换 | 无更多替换（收敛） | ✅ 有界 |
| example_processor.dart:429 | 正则替换 | 无更多替换（收敛） | ✅ 有界 |

### 4.2 数据库资源管理

| 场景 | 处理方式 | 风险 |
|---|---|---|
| 数据库连接 | 单例模式（`WordBookDatabase.instance`） | ✅ 无连接泄漏 |
| SharedPreferences | `getInstance()` 单例 | ✅ 无泄漏 |
| 动画控制器 | `dispose()` 释放 | ✅ 无泄漏 |
| PageController | `dispose()` 释放 | ✅ 无泄漏 |

### 4.3 拒绝服务风险评级

| 维度 | 评级 |
|---|---|
| 无限循环 | ✅ 全部有界 |
| 数据加载 | ✅ 分批处理 |
| 内存管理 | ✅ 正确释放 |
| **总体评级** | **✅ 低风险** |

---

## 5. 综合安全评估

| 攻击向量 | 风险等级 | 说明 |
|---|---|---|
| SQL 注入 | ✅ 无风险 | 全部参数化查询，表名来自内部常量 |
| XSS 攻击 | ✅ 无风险 | WebView 全部占位符，无 HTML 渲染，无 Deep Link |
| 缓冲区溢出 | ✅ 低风险 | 静态词库 + 空安全 + clamp 限制 |
| 拒绝服务 | ✅ 低风险 | while(true) 全部有界，资源正确释放 |

**总体安全评级：✅ 良好**

### 5.1 安全优势

1. **参数化查询全覆盖**：所有数据库操作使用 `?` 占位符，无字符串拼接 SQL
2. **静态数据架构**：词库来自随包资产，用户无法注入恶意数据
3. **Dart 空安全**：类型系统强制处理 null，减少空指针崩溃
4. **无外部攻击面**：无 WebView 实际加载、无 Deep Link、无外部 URL 处理
5. **资源管理规范**：动画控制器、数据库连接等均有正确的释放机制

### 5.2 潜在改进建议

| 优先级 | 建议 | 说明 |
|---|---|---|
| P3 | 数据库查询结果 `.first` 增加空检查 | 防御极端情况下的空结果异常 |
| P3 | WebView 占位符代码清理 | 移除未使用的 WebView 类，减少代码复杂度 |
| P3 | 注释掉的 `launch()` 代码清理 | 移除未使用的 url_launcher 引用 |

> 注：以上建议均为 P3（低优先级），不影响当前安全状态。

---

*审计者：PhoneticsEngineer (Monster world)*
*审计时间：2026-08-24*
