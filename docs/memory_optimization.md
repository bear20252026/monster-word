# Monster Word 内存使用与泄漏调研

**日期**: 2026-08-25  
**项目**: Monster Word v2.0.0  
**审查范围**: 全部 lib/ 目录

---

## 一、内存泄漏风险总览

| 风险类型 | 数量 | 严重度 |
|---------|------|--------|
| AudioPlayer 未释放 | 7处 | Critical |
| AnimationController 管理 | 42文件 | 需逐文件确认 |
| StreamSubscription 管理 | 3文件 | 已正确处理 |
| 全局状态过大 | 1处 | Medium |
| 数据库连接未关闭 | 2处 | Medium |
| SharedPreferences 大量读写 | 多处 | Low |

---

## 二、AudioPlayer 内存泄漏（Critical）

### 2.1 问题描述

多个页面在发音按钮点击时直接 `new AudioPlayer()` 创建实例，播放完成后**未调用 `dispose()`**。AudioPlayer 底层持有原生平台资源（Android ExoPlayer / iOS AVAudioPlayer），不释放会导致内存持续增长。

### 2.2 泄漏位置

| 文件 | 行号 | 创建方式 | 是否 dispose | 严重度 |
|------|------|---------|-------------|--------|
| `learn_page.dart` | 37 | `AudioPlayer()` 内联 | ❌ 无 dispose | Critical |
| `review_page.dart` | 561 | `AudioPlayer()` 内联 | ❌ 无 dispose | Critical |
| `search_page.dart` | 452 | `AudioPlayer()` 内联 | ❌ 无 dispose | Critical |
| `dictionary_page.dart` | 695 | `AudioPlayer()` 内联 | ❌ 无 dispose | Critical |
| `word_detail_page.dart` | 763 | `AudioPlayer()` 内联 | ❌ 无 dispose | Critical |
| `word_machine_page.dart` | 631 | `AudioPlayer()` 内联 | ❌ 无 dispose | Critical |
| `services/audio_service.dart` | 23 | `AudioPlayer()` 内联 | ❌ 无 dispose | Critical |

### 2.3 已正确处理的位置

| 文件 | 行号 | 方式 |
|------|------|------|
| `spell_session_page.dart` | 23,44 | 成员变量 + `dispose()` |
| `spell_check_page.dart` | 30,47 | 成员变量 + `dispose()` |
| `player/audio_players.dart` | 118 | `BBAudioPlayer` 封装 + `dispose()` |
| `lock/lock_media.dart` | 14-15 | 成员变量 + `dispose()` |

### 2.4 修复建议

**方案A（推荐）：** 创建全局单例 `AudioPlayerManager`，复用同一个 AudioPlayer 实例：

```dart
class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._();
  factory AudioPlayerManager() => _instance;
  AudioPlayerManager._();
  
  final AudioPlayer _player = AudioPlayer();
  
  Future<void> play(String url) async {
    await _player.stop();
    await _player.play(UrlSource(url));
  }
  
  void dispose() => _player.dispose();
}
```

**方案B：** 在每个内联 AudioPlayer 调用后添加 `.dispose()`，但需注意播放完成前不能 dispose。

---

## 三、AnimationController 管理

### 3.1 统计

- 全局共 **132 处** AnimationController 创建，分布在 **42 个文件**
- 全局共 **172 处** `.dispose()` 调用，分布在 **61 个文件**

### 3.2 高风险文件（Controller 数量多）

| 文件 | Controller 数量 | dispose 数量 | 状态 |
|------|----------------|-------------|------|
| `lock_screen_page.dart` | 6 | 7 | ✅ |
| `spring_calendar.dart` | 4 (List) | 3 (List) | ⚠️ 见下 |
| `learn_page.dart` | 6 | 5 | ⚠️ 见下 |
| `morphing_tabs.dart` | 8 | 6 | ⚠️ 见下 |
| `halo_search.dart` | 6 | 6 | ✅ |
| `liquid_logo.dart` | 6 | 5 | ⚠️ 见下 |
| `app_dock.dart` | 2 (List) | 2 (List) | ✅ |

### 3.3 具体风险

**spring_calendar.dart：**
- 创建了 `List<AnimationController> _controllers`（数量 = days.length，最多 42 个）
- 每次 days 列表变化时，旧 controllers 不会被 dispose（因为 initState 只执行一次）
- 若 days 列表动态变化，会导致 Controller 堆积

**learn_page.dart：**
- 6 个 Controller 全部在 dispose 中释放 ✅
- 但 `_QuizAreaState` 是内部 StatefulWidget，其 Controller 由父级管理 ✅

**morphing_tabs.dart：**
- 8 个 Controller（每个 tab 一个），在 dispose 中用循环释放 ✅
- 但 tab 数量固定，风险低

**liquid_logo.dart：**
- 6 个 Controller，在 dispose 中循环释放 ✅

### 3.4 修复建议

- `spring_calendar.dart`：若 days 列表会变化，在 `didUpdateWidget` 中 dispose 旧 controllers 并重建
- 其他文件：当前实现基本正确，无需修改

---

## 四、StreamSubscription 管理

### 4.1 检查结果

| 文件 | Subscription | cancel 位置 | 状态 |
|------|-------------|-------------|------|
| `word_detail_page.dart` | `_audioSub` | `dispose()` 中 `_audioSub?.cancel()` | ✅ |
| `word_machine_page.dart` | `_audioSub` | `dispose()` 中 `_audioSub?.cancel()` | ✅ |
| `player/audio_players.dart` | 无显式 Subscription | 使用 AudioPlayer 内部管理 | ✅ |

**结论：** StreamSubscription 管理正确，无泄漏风险。

---

## 五、全局状态（LearningState）内存分析

### 5.1 状态规模

`LearningState` 是全局单例 Provider，持有以下数据：

| 字段 | 类型 | 预估内存 | 说明 |
|------|------|---------|------|
| `_queue` | `List<Word>` | ~50KB (50词) | 当前学习队列 |
| `_cards` | `Map<String, FsrsCard>` | ~100KB (1000词) | FSRS 记忆卡片 |
| `_processQueue` | `List<BBWordProcess>` | ~50KB | Leitner 引擎队列 |
| `_choices` | `List<WordChoicePair>` | ~2KB | 4选1选项 |
| `_favoriteWords` | `Set<String>` | ~10KB | 收藏单词 |
| `_masteredWords` | `Set<String>` | ~10KB | 已掌握单词 |
| `_dailyStats` | `Map<String, Map>` | ~20KB | 每日统计 |
| `_activeDates` | `Set<String>` | ~5KB | 活跃日期 |
| **总计** | | **~250KB** | |

### 5.2 风险评估

- **风险等级：Medium**
- 250KB 在移动设备上不算大，但 `_cards` Map 会随使用时间持续增长（每个学过的词一个 FsrsCard）
- 若用户学习 5000+ 词，`_cards` 可能达到 500KB+
- 所有数据在 App 启动时一次性加载到内存

### 5.3 修复建议

- **短期：** 可接受，250KB 不是瓶颈
- **长期：** 考虑将 `_cards` 改为按需加载（LRU Cache），而非全量加载

---

## 六、Provider/Consumer 范围分析

### 6.1 使用模式

| 模式 | 出现次数 | 风险 |
|------|---------|------|
| `context.read<LearningState>()` | ~20处 | ✅ 低（一次性读取） |
| `context.watch<LearningState>()` | ~10处 | ⚠️ 中（任何状态变化触发 rebuild） |
| `Selector<LearningState, ...>` | 3处 | ✅ 低（精确订阅） |
| `Consumer<LearningState>` | 1处 | ✅ 低（限定范围） |

### 6.2 高风险 watch 使用

| 文件 | 影响 |
|------|------|
| `dashboard_page.dart:21` | `watch` 整个 LearningState → 每次答题都 rebuild 整个仪表盘 |
| `foot_mark_page.dart:25` | `watch` 整个 LearningState → 任何变化都 rebuild |
| `learn_page.dart:56` | `watch` 整个 LearningState → 答题时 rebuild 整页（但这是必要的） |
| `my_fav_page.dart:110` | `watch` 整个 LearningState → 任何变化都 rebuild |

### 6.3 修复建议

- `dashboard_page.dart`：改用 `Selector` 仅订阅 `learnedNum`、`total`、`dueCount`
- `foot_mark_page.dart`：改用 `Selector` 仅订阅需要的字段
- `my_fav_page.dart`：改用 `Selector` 仅订阅 `favoriteCount`

---

## 七、数据库内存

### 7.1 连接管理

| 数据库 | 单例 | close() 方法 | 是否调用 | 状态 |
|--------|------|-------------|---------|------|
| WordBookDatabase | ✅ | ✅ 第224行 | ❌ App 退出时不调用 | ⚠️ |
| UserDatabase | ✅ | ✅ 第158行 | ❌ App 退出时不调用 | ⚠️ |
| NoteDatabase | ✅ | ❌ 无 close 方法 | — | ⚠️ |

### 7.2 查询分页

- `WordBookDatabase.getWordsByBook()` 支持 `limit` 和 `offset` 参数 ✅
- `searchWords()` 支持 `limit` 参数 ✅
- 但 `getBooks()` 一次性加载所有词书（约100+本） → 可能几十KB

### 7.3 修复建议

- `NoteDatabase`：添加 `close()` 方法
- App 退出时调用各数据库的 `close()`（或依赖进程退出自动回收）
- `getBooks()`：若词书数量增长，考虑分页加载

---

## 八、图片内存

### 8.1 资源盘点

- **无大图片资源**：App 使用 SVG 图标（flutter_svg）+ 小尺寸 PNG（icon/branding）
- **壁纸图片**：`assets/wallpapers/` 目录下的壁纸在需要时通过 `AssetImage` 加载
- **网络图片**：App 不加载网络图片（发音为音频，非图片）

### 8.2 风险评估

- **风险等级：Low**
- SVG 渲染由 flutter_svg 库管理，自动缓存
- 壁纸图片在切换时旧图片会被 GC 回收
- 无 `ImageProvider` 泄漏风险

---

## 九、SharedPreferences 性能

### 9.1 读写频率

| 操作 | 频率 | 影响 |
|------|------|------|
| `_saveCards()` | 每次答题 | 高频 JSON 序列化 |
| `_saveProgress()` | 每次跳转单词 | 高频写入 |
| `_saveFavorites()` | 每次收藏/取消 | 低频 |
| `_saveMastered()` | 每次标记掌握 | 低频 |
| `_recordActivity()` | 每次答题 | 高频 |

### 9.2 风险

- `_saveCards()` 每次答题都将整个 `_cards` Map JSON 序列化并写入 SharedPreferences
- 若 `_cards` 有 1000+ 项，每次写入可能耗时 50-100ms
- 可能导致答题动画卡顿

### 9.3 修复建议

- **节流写入：** 答题时标记 dirty，每 5 秒或 App 进后台时批量写入
- **或改用 SQLite：** 将 FSRS 卡片存入 SQLite，支持单条更新而非全量序列化

---

## 十、修复优先级

| 优先级 | 问题 | 影响 | 工作量 |
|--------|------|------|--------|
| **P0** | AudioPlayer 内存泄漏（7处） | 每次发音泄漏一个原生播放器 | 0.5天 |
| **P1** | SharedPreferences 高频写入 | 答题动画可能卡顿 | 1天 |
| **P2** | LearningState watch 范围过大 | 不必要的 widget rebuild | 0.5天 |
| **P3** | NoteDatabase 缺少 close() | 轻微资源泄漏 | 0.5小时 |
| **P4** | spring_calendar Controller 管理 | days 变化时可能泄漏 | 0.5小时 |

---

## 十一、总结

| 类别 | 风险等级 | 说明 |
|------|---------|------|
| AudioPlayer 泄漏 | **Critical** | 7处内联创建未释放，每次发音泄漏原生资源 |
| AnimationController | **Low** | 大部分已正确 dispose，仅 spring_calendar 有潜在风险 |
| StreamSubscription | **Low** | 已正确 cancel |
| 全局状态大小 | **Medium** | 250KB 可接受，但 _cards 会持续增长 |
| 数据库连接 | **Low** | 单例管理，进程退出时自动回收 |
| 图片内存 | **Low** | 无大图片，SVG 自动缓存 |
| SharedPreferences | **Medium** | 高频全量序列化可能导致卡顿 |

**最需立即修复：** AudioPlayer 内存泄漏（P0），建议创建全局 AudioPlayerManager 单例。
