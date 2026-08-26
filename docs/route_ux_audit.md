# 全路径 UX 审查：逐路由用户体验走查与错误风险评估

**日期**: 2026-08-25  
**项目**: Monster Word v2.0.0  
**路由定义**: `lib/main.dart:283-393`（onGenerateRoute）

---

## 一、路由错误风险总览

### 1.1 参数类型转换风险（最高优先级）

以下路由使用 `args as Map<String, dynamic>?` 进行类型转换，**若调用方传入错误类型将直接崩溃**：

| 路由 | 参数转换方式 | 崩溃条件 | 严重度 |
|------|-------------|---------|--------|
| `/sentence_detail` | `args as Map<String, dynamic>?` | args 非 Map 类型 | **Critical** |
| `/listen_mode_select` | `args as Map<String, dynamic>?` | args 非 Map 类型 | **Critical** |
| `/spell_check` | `args as Map<String, dynamic>?` | args 非 Map 类型 | **Critical** |
| `/linked_me` | `args as Map<String, dynamic>?` | args 非 Map 类型 | **Critical** |
| `/listening_player` | `args as Map<String, dynamic>?` + `(a['words'] as List).cast<Word>()` | words 非 List 或元素非 Word | **Critical** |
| `/dictation_session` | `args as Map<String, dynamic>?` + `(a['words'] as List).cast<Word>()` | words 非 List 或元素非 Word | **Critical** |
| `/quick_spell` | `args as Map<String, dynamic>?` + `(a['words'] as List).cast<Word>()` | words 非 List 或元素非 Word | **Critical** |
| `/word_export` | `args as Map<String, dynamic>?` + `a['bookId'] as int` | bookId 非 int 类型 | **Critical** |

**崩溃示例：**
```dart
// 如果调用方错误地传入了 String 而非 Map：
Navigator.pushNamed(context, '/sentence_detail', arguments: 'hello');
// → _buildPage 中 args as Map<String, dynamic>? 抛出 TypeCastException → 红屏
```

**修复建议：** 统一使用安全转换：
```dart
final a = args is Map<String, dynamic> ? args : null;
if (a == null) return const Scaffold(body: Center(child: Text('参数错误')));
```

### 1.2 null 参数降级为 SplashPage（体验断层）

以下路由在 args 为 null 时显示 SplashPage 作为 fallback，用户会看到启动页而非预期内容：

| 路由 | fallback | 用户感知 |
|------|---------|---------|
| `/listen_mode_select` | `const SplashPage()` | 突然看到启动页，不知所措 |
| `/listening_player` | `const SplashPage()` | 同上 |
| `/dictation_session` | `const SplashPage()` | 同上 |
| `/quick_spell` | `const SplashPage()` | 同上 |
| `/word_export` | `const SplashPage()` | 同上 |

**修复建议：** 改为显示错误提示页 + 返回按钮，而非 SplashPage。

---

## 二、逐路由 UX 走查

### 路由 1：`/` → MainShell（首页三Tab）

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 无参数 |
| 加载态 | ✅ | IndexedStack 保持状态 |
| 空状态 | ⚠️ | 首页无空状态（始终有内容） |
| 导航死路 | ✅ | 三个 Tab 均可切换 |
| 错误处理 | ✅ | 全局 ErrorWidget 兜底 |

### 路由 2：`/splash` → SplashPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 无参数 |
| 加载态 | ✅ | 品牌动画 + 2秒延迟 |
| 导航死路 | ✅ | 自动跳转首页或登录 |
| 错误处理 | ⚠️ | 若 LearningState 构造异常，可能卡在 Splash |

### 路由 3：`/login` → LoginPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 无参数 |
| 加载态 | ✅ | `_isLoading` 控制按钮禁用态 |
| 错误提示 | ✅ | SnackBar 提示登录失败 |
| 导航死路 | ⚠️ | 主视图无返回按钮（设计正确但系统返回直接退出App） |
| 空状态 | ✅ | 有输入引导 |

### 路由 4：`/word_detail` → WordDetailPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ⚠️ | 无路由参数，通过 `_resolveTargetWord` 从 LearningState 获取。若 state.currentWord 为 null，显示"暂无单词" |
| 加载态 | ✅ | 笔记加载有 CircularProgressIndicator |
| 空状态 | ✅ | 笔记为空时有引导文案"暂无笔记" |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 5：`/sentence_detail` → SentenceDetailPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | **Critical** | `args as Map<String, dynamic>?` 类型转换不安全 |
| 空值处理 | ✅ | `a?['word'] ?? ''` 有兜底 |
| 导航死路 | ✅ | 有返回按钮 |

**崩溃风险：** 若 args 为非 Map 类型（如 String、int），`as Map<String, dynamic>?` 抛出异常。

### 路由 6：`/spell_check` → SpellCheckPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | **Critical** | `args as Map<String, dynamic>?` 类型转换不安全 |
| 空值处理 | ⚠️ | word 默认空字符串，phonetic 可为 null |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 7：`/check_in_history` → CheckInHistoryPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 无参数 |
| 加载态 | ✅ | CircularProgressIndicator |
| 空状态 | ✅ | 有插画+文案+操作按钮 |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 8：`/my_content` → MyContentPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 无参数 |
| 导航死路 | ✅ | 有返回按钮 |
| 空按钮 | ⚠️ | 第137行 `onPressed: () {}` 空回调 |

### 路由 9：`/my_space` → MySpacePage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 无参数 |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 10：`/lib_select` → LibSelectPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 无参数 |
| 加载态 | ✅ | FutureBuilder + CircularProgressIndicator |
| 空状态 | ⚠️ | 仅显示"暂无词书"纯文字，无插画 |
| 错误处理 | ⚠️ | FutureBuilder error 仅显示 `Text('加载失败: ${snapshot.error}')` |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 11：`/listening_player` → ListeningPlayerPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | **Critical** | 双重类型转换：`args as Map` + `(a['words'] as List).cast<Word>()` |
| null fallback | ⚠️ | null args 时显示 SplashPage（体验断层） |
| 导航死路 | ✅ | 有返回按钮 |

**崩溃风险：** 若 `a['words']` 不是 List 或包含非 Word 对象，`.cast<Word>()` 抛出异常。

### 路由 12：`/listen_mode_select` → ExtensiveModelSelectPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | **Critical** | `args as Map<String, dynamic>?` 类型转换不安全 |
| null fallback | ⚠️ | null args 时显示 SplashPage |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 13：`/dictation_session` → DictationSessionPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | **Critical** | 双重类型转换 |
| null fallback | ⚠️ | null args 时显示 SplashPage |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 14：`/quick_spell` → QuickSpellPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | **Critical** | 双重类型转换 |
| null fallback | ⚠️ | null args 时显示 SplashPage |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 15：`/book_words` → BookWordsPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 兼容 Book 对象和 Map 两种传参，有完整兜底 |
| 空值处理 | ✅ | bookId 默认 0，bookName 默认"词书" |
| 导航死路 | ✅ | 有返回按钮 |

**评价：** 参数处理是所有路由中最健壮的。

### 路由 16：`/word_export` → WordExportPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | **Critical** | `a['bookId'] as int` 无安全转换 |
| null fallback | ⚠️ | null args 时显示 SplashPage |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 17：`/course` → 未注册

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 路由存在 | ❌ | 路由表中无 `/course`，`onGenerateRoute` 返回 null → 白屏 |

### 路由 18：`/linked_me` → LinkedMeMiddlePage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | **Critical** | `args as Map<String, dynamic>?` 类型转换不安全 |
| 空值处理 | ✅ | word/association 有默认空值 |
| 导航死路 | ✅ | 有返回按钮 |

### 路由 19：`/dashboard` → DashboardPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 无参数 |
| 导航死路 | ✅ | 有返回按钮 |
| 空按钮 | ⚠️ | 第82行 share 按钮 `onPressed: () {}` 空回调 |

### 路由 20：`/list_words` → ListWordsPage（抽象类）

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 路由存在 | ⚠️ | 路由表中无 `/list_words`，但作为抽象基类被 BookWordsPage 等继承 |
| 直接访问 | ❌ | 若直接 pushNamed('/list_words') → 返回 null → 白屏 |

### 路由 21：`/review` → ReviewPage

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 参数传递 | ✅ | 无参数 |
| 加载态 | ✅ | CircularProgressIndicator |
| 空状态 | ⚠️ | 无内容时显示"暂无单词"纯文字 |
| 错误处理 | ⚠️ | `_initReview` 无 try-catch，异常白屏 |
| 导航死路 | ⚠️ | 复习完成页返回按钮用 `Navigator.pop`，但若通过 pushReplacement 进入会黑屏 |

---

## 三、错误风险汇总

### 3.1 按严重度排序

#### Critical（8处类型转换崩溃风险）

| 路由 | 文件:行号 | 问题 |
|------|----------|------|
| `/sentence_detail` | main.dart:319 | `args as Map<String, dynamic>?` |
| `/listen_mode_select` | main.dart:337 | `args as Map<String, dynamic>?` |
| `/spell_check` | main.dart:351 | `args as Map<String, dynamic>?` |
| `/linked_me` | main.dart:356 | `args as Map<String, dynamic>?` |
| `/listening_player` | main.dart:362-364 | 双重转换 `.cast<Word>()` |
| `/dictation_session` | main.dart:371-373 | 双重转换 `.cast<Word>()` |
| `/quick_spell` | main.dart:378-380 | 双重转换 `.cast<Word>()` |
| `/word_export` | main.dart:388-389 | `a['bookId'] as int` |

#### Major（5处体验断层）

| 路由 | 问题 |
|------|------|
| `/listen_mode_select` | null fallback 显示 SplashPage |
| `/listening_player` | null fallback 显示 SplashPage |
| `/dictation_session` | null fallback 显示 SplashPage |
| `/quick_spell` | null fallback 显示 SplashPage |
| `/word_export` | null fallback 显示 SplashPage |

#### Minor（3处未注册/空回调）

| 路由 | 问题 |
|------|------|
| `/course` | 路由未注册，访问白屏 |
| `/list_words` | 抽象类不可直接实例化 |
| 多处 | `onPressed: () {}` 空回调（dashboard/share、learn/more、my_content） |

---

## 四、修复建议

### 4.1 统一安全参数解析（P0）

创建通用安全解析函数，替换所有裸 `as` 转换：

```dart
/// 安全路由参数解析
Map<String, dynamic>? safeRouteArgs(RouteSettings settings) {
  final args = settings.arguments;
  if (args is Map<String, dynamic>) return args;
  return null;
}
```

然后每个路由改为：
```dart
case '/sentence_detail':
  final a = safeRouteArgs(settings);
  if (a == null) return const _ErrorPage(message: '参数错误');
  return SentenceDetailPage(
    word: a['word'] as String? ?? '',
    sentence: a['sentence'] as String? ?? '',
    ...
  );
```

### 4.2 替换 SplashPage fallback（P1）

将所有 `const SplashPage()` fallback 改为错误提示页：

```dart
case '/listening_player':
  final a = safeRouteArgs(settings);
  if (a == null) return const _ErrorPage(message: '参数缺失，无法播放');
  ...
```

### 4.3 注册缺失路由（P2）

- `/course` → 注册为 CoursesPage 或移除引用
- `/list_words` → 不应作为独立路由注册（抽象类）

### 4.4 空回调清理（P2）

移除或实现所有 `onPressed: () {}` 空回调。

---

## 五、路由健壮性评分

| 路由 | 参数安全 | 加载态 | 空状态 | 错误处理 | 导航 | 总分 |
|------|---------|--------|--------|---------|------|------|
| `/book_words` | ✅✅ | ✅ | ✅ | ✅ | ✅ | **5/5** |
| `/check_in_history` | ✅ | ✅ | ✅ | ✅ | ✅ | **5/5** |
| `/word_detail` | ✅ | ✅ | ✅ | ✅ | ✅ | **5/5** |
| `/` MainShell | ✅ | ✅ | ⚠️ | ✅ | ✅ | **4/5** |
| `/login` | ✅ | ✅ | ✅ | ✅ | ⚠️ | **4/5** |
| `/lib_select` | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | **3/5** |
| `/review` | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ | **2/5** |
| `/sentence_detail` | ❌ | — | ✅ | — | ✅ | **2/5** |
| `/spell_check` | ❌ | — | ⚠️ | — | ✅ | **1/5** |
| `/listening_player` | ❌ | — | — | — | ✅ | **1/5** |
| `/dictation_session` | ❌ | — | — | — | ✅ | **1/5** |
| `/quick_spell` | ❌ | — | — | — | ✅ | **1/5** |
| `/word_export` | ❌ | — | — | — | ✅ | **1/5** |
| `/listen_mode_select` | ❌ | — | — | — | ✅ | **1/5** |
| `/linked_me` | ❌ | — | ✅ | — | ✅ | **1/5** |
| `/course` | — | — | — | — | — | **0/5** 未注册 |
