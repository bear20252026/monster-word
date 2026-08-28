# WS-5 D5 例句卡片接入音频播放按钮

> 日期：2026-08-28
> 任务：为 5 个页面的例句卡片接入音频播放按钮
> 模式：统一参照 `lib/screens/learn_session.dart` 与 `lib/pages/word_detail_page.dart`

---

## 改动文件

### 1. `lib/pages/word_machine_page.dart`

- **新增 import**：`import '../core/audio/audio_playback_state.dart';`
- **改动点**：`_buildExampleSection` 方法（约 645 行）
  - 原来每条例句直接 `Text(s.en)`
  - 改为 `Row` 包裹：左侧 `Expanded(Text(s.en))` + 右侧条件音频按钮
  - 当 `s.audioUrl != null && s.audioUrl!.isNotEmpty` 时显示 `IconButton(Icons.volume_up_outlined, size: 14)`，点击调用 `context.read<AudioPlaybackState>().playSentence(s.audioUrl!)`

### 2. `lib/widgets/word_dictionary_popup.dart`

- **新增 import**：`import '../core/audio/audio_playback_state.dart';`
- **改动点**：`_buildExample` 方法末尾（约 200 行）
  - 原来：`example.cn` 文本 + 来源
  - 新增：条件音频按钮（在来源下方），当 `example.audioUrl` 非空时显示 `IconButton(Icons.volume_up_outlined, size: 20)`，点击调用 `context.read<AudioPlaybackState>().playSentence(example.audioUrl!)`

### 3. `lib/pages/listening_player_page.dart`

- **新增 import**：`import '../core/audio/audio_playback_state.dart';` + `import 'package:provider/provider.dart';`
- **改动点**：`_buildStructuredExample` 方法（约 376 行）
  - 原来：每条例句 `Text(s.en)` 后跟 `Text(s.cn)`
  - 改为：`Row` 包裹 `Text(s.en)` + 条件音频按钮（size: 18），然后下方 `Text(s.cn)`

### 4. `lib/pages/quick_spell_page.dart`

- **新增 import**：`import '../core/audio/audio_playback_state.dart';` + `import 'package:provider/provider.dart';`
- **改动点**：例句展示区域（约 322 行）
  - 原来：`Text.rich` 显示 `ex.cleanEn` + `ex.cn`
  - 改为：外层 `Column` + `Row` 包裹 `Expanded(Text.rich(...))` + 条件音频按钮（size: 18）

### 5. `lib/features/search/presentation/search_page.dart`

- **import**：已有 `audio_playback_state.dart`，无需新增
- **改动点**：`_buildExampleCard` 方法末尾（约 350 行）
  - 新增：条件音频按钮（在 `ex.cn` 下方），当 `ex.audioUrl` 非空时显示 `IconButton(Icons.volume_up_outlined, size: 20)`，点击调用 `context.read<AudioPlaybackState>().playSentence(ex.audioUrl!)`

---

## 统一模式

```dart
if (example.audioUrl != null && example.audioUrl!.isNotEmpty)
  IconButton(
    icon: Icon(Icons.volume_up_outlined, color: <skin_accent_color>, size: <appropriate_size>),
    onPressed: () => context.read<AudioPlaybackState>().playSentence(example.audioUrl!),
    tooltip: '播放例句',
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
  ),
```

---

## 测试

- **新增测试文件**：`test/widgets/example_audio_button_test.dart`
- **测试用例**（5 例全绿）：
  1. 有 audioUrl 时显示音频播放按钮 ✅
  2. 无 audioUrl 时不显示音频播放按钮 ✅
  3. 点击音频按钮调用 playSentence ✅
  4. 多条例句各自独立显示音频按钮 ✅
  5. 部分例句有音频、部分没有时只显示对应按钮 ✅
- **运行命令**：`flutter test test/widgets/example_audio_button_test.dart` → All tests passed!

---

## 验证

- `flutter analyze` 5 个文件 → No issues found!
- 测试 5/5 通过
