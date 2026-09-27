# 崩溃与异常攻击测试报告

审计日期：2026-08-24
审计人：ComponentEngineer
项目：Monster Word (word_app)
范围：lib/ 全量代码审计（只读，未修改任何代码）

---

## 1. 执行摘要

| 风险等级 | 数量 | 说明 |
|---------|------|------|
| 🔴 高危 | 8 | 可导致 App 崩溃 |
| 🟡 中危 | 12 | 可导致功能异常或数据丢失 |
| 🟢 低危 | 6 | 边缘场景，概率较低 |

**整体评估：🟡 中等风险**
- 核心学习流程防护较好（有 try-catch）
- 数据层和工具层存在多处未防护的崩溃风险
- 资源管理整体规范，但有几处遗漏

---

## 2. 崩溃攻击分析

### 2.1 空指针解引用风险 🔴 高危

**问题：** 大量使用 `!` 运算符强制解引用 nullable 类型，无前置空检查。

| 文件 | 行号 | 代码 | 风险 |
|------|------|------|------|
| lock_screen_page.dart | 193 | `_elementAnimator!.setMinDistance(...)` | 若 `_elementAnimator` 未初始化则崩溃 |
| lock_screen_page.dart | 541 | `interp['type']!.isNotEmpty` | Map 值为 null 时崩溃 |
| lock_screen_page.dart | 789 | `_elementAnimator!.onScroll(delta)` | 同上 |
| my_element_animator.dart | 68 | `_animController!.addStatusListener(...)` | 若 controller 为 null 则崩溃 |
| ext_models.dart | 360 | `_curWordData!.wordBaseInfo` | 未初始化时崩溃 |
| ext_models.dart | 558 | `result!.addRefreshNewData(newData)` | result 为 null 时崩溃 |
| audio_players.dart | 489 | `_sentenceListener!.checkWhetherPlay(...)` | listener 未设置时崩溃 |
| media_download.dart | 213 | `_listener!.onClick()` | listener 为 null 时崩溃 |

**攻击向量：**
- 快速切换页面，使 `_elementAnimator` 未完成初始化就被访问
- 在音频播放器未完全配置时触发回调
- 在下载任务未完成初始化时触发点击事件

**建议修复：**
```dart
// 替代方案 1：空检查
if (_elementAnimator != null) {
  _elementAnimator!.setMinDistance(distance);
}

// 替代方案 2：安全调用
_elementAnimator?.setMinDistance(distance);
```

### 2.2 类型转换异常 🔴 高危

**问题：** 大量使用 `as Map<String, dynamic>` 进行不安全类型转换，无 try-catch 保护。

| 文件 | 行号 | 代码 | 风险 |
|------|------|------|------|
| app_preferences_ext.dart | 779 | `jsonDecode(jsonStr) as Map<String, dynamic>` | JSON 格式错误时崩溃 |
| http_client.dart | 145 | `jsonDecode(decryptedText) as Map<String, dynamic>?` | 解密数据异常时崩溃 |
| http_client.dart | 410 | `jsonDecode(response.body) as Map<String, dynamic>` | 服务器返回非 JSON 时崩溃 |
| http_client.dart | 598 | `jsonDecode(response.body) as Map<String, dynamic>` | 同上 |
| learning_state.dart | 100 | `jsonDecode(raw) as Map<String, dynamic>` | 本地存储数据损坏时崩溃 |
| data_utils.dart | 14 | `jsonDecode(str) as T` | 泛型转换失败时崩溃 |
| wordbook_database.dart | 29-78 | `map['id'] as int`, `map['word'] as String` | 数据库字段类型不匹配时崩溃 |

**攻击向量：**
- 篡改本地 SharedPreferences 数据
- 服务器返回异常响应（网络代理攻击）
- 数据库文件损坏

**建议修复：**
```dart
// 使用安全转换
final map = jsonDecode(jsonStr) as Map<String, dynamic>?;
if (map == null) return defaultValue;

// 或使用 try-catch
try {
  final map = jsonDecode(jsonStr) as Map<String, dynamic>;
} catch (e) {
  log('JSON parse error: $e');
  return defaultValue;
}
```

### 2.3 数组越界风险 🟡 中危

**问题：** 使用 `.first` 和 `[index]` 访问集合元素，未检查是否为空。

| 文件 | 行号 | 代码 | 风险 |
|------|------|------|------|
| wordbook_database.dart | 152 | `Word.fromMap(rows.first)` | 查询结果为空时崩溃 |
| user_database.dart | 115 | `result.first['count'] as int` | 查询无结果时崩溃 |
| note_database.dart | 76 | `result.first['cnt'] as int?` | 查询无结果时崩溃 |
| user_process_dao.dart | 143 | `rows.first['cnt'] as int?` | 查询无结果时崩溃 |
| example_processor.dart | 561 | `final h4 = elements[0]` | 元素不存在时崩溃 |
| ext_models.dart | 437 | `_updateWordBaseInfo(originalWordList[0])` | 列表为空时崩溃 |
| distractor_engine.dart | 74 | `if (target[0] == candidate[0])` | 空字符串时崩溃 |

**攻击向量：**
- 数据库查询返回空结果（数据被清空）
- 用户输入空字符串触发引擎逻辑
- 词书数据不完整

**建议修复：**
```dart
// 使用 isEmpty 检查
if (rows.isEmpty) return null;
return Word.fromMap(rows.first);

// 或使用 singleOrNull
final row = result.singleOrNull;
if (row == null) return 0;
```

---

## 3. 资源耗尽攻击分析

### 3.1 内存泄漏风险 🟡 中危

**问题：** 部分 Timer、AnimationController 可能未正确释放。

| 文件 | 资源类型 | 状态 | 风险 |
|------|---------|------|------|
| lock_presenter_imp.dart | `Timer? _timeTickTimer` | ✅ 有取消 | 低 |
| lock_presenter_imp.dart | `Timer? _batteryTimer` | ✅ 有取消 | 低 |
| exam_quick_review_page.dart | `Timer? _timer` | ⚠️ 需确认 dispose | 中 |
| lock_screen_page.dart | 3 个 AnimationController | ✅ 有 dispose | 低 |
| lock_screen_page.dart | 2 个 PageController | ✅ 有 dispose | 低 |
| immersive_swipe_page.dart | 2 个 AnimationController | ✅ 有 dispose | 低 |

**已确认安全：**
- lock_screen_page.dart: `dispose()` 中正确释放所有 controller 和 timer
- my_element_animator.dart: `dispose()` 中释放 `_animController`
- dictionary_page.dart: `dispose()` 中释放 `_tabController`

**潜在风险：**
- `exam_quick_review_page.dart`: Timer 在 `_startTimer()` 中创建，需确认 `dispose()` 中有 `_timer?.cancel()`

### 3.2 无限循环风险 🟡 中危

**问题：** 7 处 `while(true)` 循环，依赖 break 条件退出。

| 文件 | 行号 | 循环目的 | 收敛性 |
|------|------|---------|--------|
| example_processor.dart | 193 | 处理大写字母缩写句点 | ✅ 每轮替换减少，必收敛 |
| example_processor.dart | 203 | 处理大写字母缩写 | ✅ 同上 |
| example_processor.dart | 213 | 处理大写字母缩写 | ✅ 同上 |
| example_processor.dart | 223 | 处理大写字母缩写 | ✅ 同上 |
| example_processor.dart | 347 | HTML 解析 | ⚠️ 依赖外部输入 |
| example_processor.dart | 429 | HTML 解析 | ⚠️ 依赖外部输入 |
| learning_state.dart | 231 | 连续天数计算 | ✅ 日期递减必收敛 |

**攻击向量：**
- 构造特殊 HTML 内容使 example_processor 的解析循环不收敛
- 超长字符串导致正则替换效率极低（ReDoS）

**建议修复：**
```dart
// 添加最大迭代次数限制
int maxIterations = 1000;
while (maxIterations-- > 0) {
  final next = text.replaceAllMapped(pattern, replacer);
  if (next == text) break;
  text = next;
}
```

### 3.3 文件句柄泄漏 🟢 低危

**问题：** 文件操作大多使用 `File()` 直接操作，未显式关闭句柄。

| 文件 | 操作 | 风险 |
|------|------|------|
| sound_zip_processor.dart | `File(zipPath).readAsBytes()` | 低（Dart GC 会回收） |
| audio_players.dart | `File(localPath)` 多处 | 低 |
| wordbook_database.dart | `File(dbPath).writeAsBytes(...)` | 低 |

**评估：** Dart 的 `File` 操作基于 `dart:io`，底层使用 `RandomAccessFile` 时需要显式关闭，但 `readAsBytes()`/`writeAsBytes()` 等高级 API 会自动管理句柄。当前代码安全。

---

## 4. 异常输入攻击分析

### 4.1 超长字符串处理 🟡 中危

**问题：** 搜索和文本处理未限制输入长度。

| 文件 | 场景 | 风险 |
|------|------|------|
| search_page.dart | `_search(query)` | 超长查询可能导致数据库查询慢 |
| example_processor.dart | HTML 解析 | 超长文本导致正则 ReDoS |
| text_formatter.dart | 文本格式化 | 超长文本导致 substring 越界 |

**攻击向量：**
- 粘贴超长字符串到搜索框
- 词典数据中包含超长 HTML 内容

**建议修复：**
```dart
// 搜索框限制输入长度
TextField(
  maxLength: 100,
  onChanged: (value) => _search(value),
)

// 或在搜索函数中截断
Future<void> _search(String query) async {
  final trimmed = query.trim().substring(0, query.trim().length.clamp(0, 100));
  ...
}
```

### 4.2 特殊字符处理 🟢 低危

**问题：** 部分字符串操作未考虑 emoji 和 Unicode 组合字符。

| 文件 | 操作 | 风险 |
|------|------|------|
| example_processor.dart | `substring()` | emoji 由多个 code unit 组成，可能截断 |
| distractor_engine.dart | `word[0]` | emoji 字符串取首字符可能异常 |
| class_checkin_page.dart | `name[0]` | 同上 |

**攻击向量：**
- 用户昵称包含 emoji
- 单词数据中包含 Unicode 特殊字符

**建议修复：**
```dart
// 使用 characters 包处理 Unicode
import 'package:characters/characters.dart';
final firstChar = name.characters.first;
```

### 4.3 空值/null 处理 🟡 中危

**问题：** 部分函数未处理 null 输入，直接传递给下游。

| 文件 | 场景 | 风险 |
|------|------|------|
| wordbook_database.dart | `Word.fromMap(map)` | map 中字段为 null 时崩溃 |
| example_parser.dart | JSON 解析 | 字段缺失时返回空值但不报错 |
| fav_sentence_dao.dart | JSON 解析 | 已有 try-catch 保护 ✅ |

**评估：** 数据层的 null 处理整体较好，但 `Word.fromMap()` 的强制类型转换（`as int`, `as String`）是主要风险点。

---

## 5. 并发攻击分析

### 5.1 竞态条件 🟡 中危

**问题：** 多处 `setState()` 在 `await` 之后调用，未检查 `mounted` 状态。

| 文件 | 行号 | 代码 | 风险 |
|------|------|------|------|
| search_page.dart | 62-67 | `setState(() {}); await ... setState(...)` | 页面销毁后 setState 崩溃 |
| exam_quick_review_page.dart | 98 | `setState(() => _isLoading = true); await ...` | 同上 |
| list_words_page.dart | 34 | `setState(() => _isLoading = true); await ...` | 同上 |
| message_page.dart | 50 | `setState(() => _isLoading = true); await ...` | 同上 |
| my_fav_page.dart | 33 | `setState(() => _isLoading = true); await ...` | 同上 |
| my_fav_sentence_page.dart | 33 | `setState(() => _isLoading = true); await ...` | 同上 |

**已有防护的文件：**
- login_page.dart: ✅ `if (mounted) setState(...)` 在 finally 块中
- learn_page.dart: ✅ `if (mounted) Navigator.pushNamed(...)` 在延迟后
- lib_select_page.dart: ✅ `if (context.mounted)` 检查

**攻击向量：**
- 快速切换页面，使 async 操作完成时 Widget 已被 dispose
- 在加载过程中按返回键

**建议修复：**
```dart
Future<void> _loadData() async {
  setState(() => _isLoading = true);
  final data = await fetchData();
  if (!mounted) return;  // 添加 mounted 检查
  setState(() {
    _data = data;
    _isLoading = false;
  });
}
```

### 5.2 死锁风险 🟢 低危

**问题：** 未发现明显的锁机制或嵌套同步原语。

**评估：** 项目使用 Dart 的单线程事件循环模型，不存在传统意义上的死锁。但以下场景可能导致"逻辑死锁"：
- 多个异步操作互相等待（未发现）
- Stream 监听器中的递归调用（未发现）

---

## 6. 按文件风险评级

| 文件 | 风险等级 | 主要问题 |
|------|---------|---------|
| http_client.dart | 🔴 高 | JSON 解析未防护，类型转换崩溃 |
| wordbook_database.dart | 🔴 高 | .first 未检查空，类型转换崩溃 |
| example_processor.dart | 🔴 高 | while(true) 循环，substring 越界 |
| lock_screen_page.dart | 🟡 中 | 强制解引用，但有初始化保护 |
| search_page.dart | 🟡 中 | setState 无 mounted 检查 |
| ext_models.dart | 🟡 中 | 强制解引用，列表越界 |
| audio_players.dart | 🟡 中 | 强制解引用 |
| learning_state.dart | 🟢 低 | while(true) 有收敛保证 |
| splash_page.dart | 🟢 低 | 防护较好 |

---

## 7. 修复优先级建议

### 第一批（立即修复 — 高崩溃风险）

| 修复项 | 影响范围 | 预计工时 |
|--------|---------|---------|
| http_client.dart JSON 解析防护 | 网络请求全部 | 30 min |
| wordbook_database.dart .first 检查 | 数据查询全部 | 20 min |
| search_page.dart mounted 检查 | 搜索页面 | 5 min |
| 其他页面 mounted 检查 | 6 个页面 | 15 min |

### 第二批（本周修复 — 中等风险）

| 修复项 | 影响范围 | 预计工时 |
|--------|---------|---------|
| 强制解引用 `!` → 安全调用 `?.` | 全局 30+ 处 | 45 min |
| example_processor.dart 循环限制 | 文本处理 | 15 min |
| Word.fromMap 安全转换 | 数据层 | 15 min |

### 第三批（后续优化 — 低风险）

| 修复项 | 影响范围 | 预计工时 |
|--------|---------|---------|
| Unicode 字符处理 | 边缘场景 | 20 min |
| 超长输入限制 | UI 层 | 10 min |

**总预计工时：~3.5h**

---

## 8. 防御性编程建议

### 8.1 全局模式

```dart
// 1. 安全 JSON 解析
Map<String, dynamic>? safeJsonDecode(String? str) {
  if (str == null || str.isEmpty) return null;
  try {
    final decoded = jsonDecode(str);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

// 2. 安全集合访问
T? safeFirst<T>(List<T> list) => list.isEmpty ? null : list.first;

// 3. 安全 setState
void safeSetState(VoidCallback fn) {
  if (mounted) setState(fn);
}
```

### 8.2 数据层加固

```dart
// Word.fromMap 安全版本
factory Word.fromMap(Map<String, dynamic> map) {
  final id = map['id'] as int?;
  final word = map['word'] as String?;
  if (id == null || word == null) throw FormatException('Invalid word data');
  return Word(id: id, word: word, ...);
}
```

---

## 9. 结论

**整体评估：🟡 中等风险**

- ✅ 核心学习流程有 try-catch 保护
- ✅ 资源管理整体规范（dispose/cancel 模式）
- ✅ 大部分异步操作有错误处理
- ⚠️ 数据层类型转换缺乏防护
- ⚠️ 部分页面缺少 mounted 检查
- ❌ http_client.dart JSON 解析是最大风险点

**App 在正常使用下稳定性良好，但在异常输入、网络攻击、快速操作等边缘场景下存在崩溃风险。**

---

*审计完成于 2026-08-24 · ComponentEngineer*
